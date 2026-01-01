import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Rider Location Service for CitiMovers
/// Handles real-time rider location updates using Firebase Realtime Database
/// Similar to DriverLocationService in para app
class RiderLocationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1Rad = _degreesToRadians(point1.latitude);
    double lon1Rad = _degreesToRadians(point1.longitude);
    double lat2Rad = _degreesToRadians(point2.latitude);
    double lon2Rad = _degreesToRadians(point2.longitude);

    double latDiff = lat2Rad - lat1Rad;
    double lonDiff = lon2Rad - lon1Rad;

    double a = (latDiff / 2).sin() * (latDiff / 2).sin() +
        lat1Rad.cos() *
            lat2Rad.cos() *
            (lonDiff / 2).sin() *
            (lonDiff / 2).sin();
    double c = 2 * a.sqrt().asin();

    return earthRadius * c; // Distance in kilometers
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  /// Update rider location in Realtime Database
  Future<void> updateRiderLocation({
    required String riderId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _database.ref('rider_locations/$riderId').set({
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      print('Rider $riderId location updated: $latitude, $longitude');
    } catch (e) {
      print('Error updating rider location: $e');
    }
  }

  /// Get rider's current location from Realtime Database
  Future<LatLng?> getRiderLocation(String riderId) async {
    try {
      DataSnapshot snapshot =
          await _database.ref('rider_locations/$riderId').get();

      if (snapshot.value != null && snapshot.value is Map) {
        Map<dynamic, dynamic> riderData =
            snapshot.value as Map<dynamic, dynamic>;

        double? lat = riderData['latitude']?.toDouble();
        double? lng = riderData['longitude']?.toDouble();

        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }

      return null;
    } catch (e) {
      print('Error getting rider location: $e');
      return null;
    }
  }

  /// Get all online riders from Realtime Database
  Future<List<Map<String, dynamic>>> getOnlineRiders({
    String? vehicleType,
  }) async {
    try {
      DataSnapshot snapshot = await _database.ref('rider_locations').get();

      if (snapshot.value == null) {
        return [];
      }

      Map<dynamic, dynamic> ridersData =
          snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> onlineRiders = [];

      // First check Firestore for online status and optionally vehicle type
      QuerySnapshot riderDocs = await _firestore
          .collection('riders')
          .where('isOnline', isEqualTo: true)
          .get();

      Set<String> onlineRiderIds = riderDocs.docs.map((doc) => doc.id).toSet();

      // Filter riders from Realtime Database who are online in Firestore
      ridersData.forEach((key, value) {
        if (value is Map && onlineRiderIds.contains(key)) {
          Map<String, dynamic> riderData = Map<String, dynamic>.from(value);
          riderData['riderId'] = key;

          // Check if rider has valid coordinates
          if (riderData.containsKey('latitude') &&
              riderData.containsKey('longitude')) {
            // If vehicle type is specified, check if rider matches
            if (vehicleType != null) {
              // Get rider data from Firestore to check vehicle type
              QueryDocumentSnapshot? riderDoc;
              try {
                riderDoc = riderDocs.docs.firstWhere(
                  (doc) => doc.id == key,
                );
              } catch (e) {
                riderDoc = null;
              }

              if (riderDoc != null) {
                Map<String, dynamic> riderFirestoreData =
                    riderDoc.data() as Map<String, dynamic>;
                String riderVehicleType =
                    riderFirestoreData['vehicleType'] ?? '';

                // Only include riders with matching vehicle type
                if (riderVehicleType == vehicleType) {
                  riderData['vehicleType'] = riderVehicleType;
                  onlineRiders.add(riderData);
                }
              }
            } else {
              // If no vehicle type filter, include all online riders
              onlineRiders.add(riderData);
            }
          }
        }
      });

      return onlineRiders;
    } catch (e) {
      print('Error fetching online riders: $e');
      return [];
    }
  }

  /// Find the nearest rider to a given location
  Future<Map<String, dynamic>?> findNearestRider(
    LatLng pickupLocation, {
    String? vehicleType,
  }) async {
    try {
      List<Map<String, dynamic>> onlineRiders = await getOnlineRiders(
        vehicleType: vehicleType,
      );

      if (onlineRiders.isEmpty) {
        print('No online riders found');
        return null;
      }

      Map<String, dynamic>? nearestRider;
      double minDistance = double.infinity;

      for (var rider in onlineRiders) {
        try {
          double riderLat = rider['latitude']?.toDouble() ?? 0.0;
          double riderLng = rider['longitude']?.toDouble() ?? 0.0;

          LatLng riderLocation = LatLng(riderLat, riderLng);
          double distance = _calculateDistance(pickupLocation, riderLocation);

          print(
              'Rider ${rider['riderId']} is ${distance.toStringAsFixed(2)} km away');

          if (distance < minDistance) {
            minDistance = distance;
            nearestRider = rider;
          }
        } catch (e) {
          print('Error processing rider ${rider['riderId']}: $e');
          continue;
        }
      }

      if (nearestRider != null) {
        print(
            'Nearest rider found: ${nearestRider['riderId']} at ${minDistance.toStringAsFixed(2)} km');
      }

      return nearestRider;
    } catch (e) {
      print('Error finding nearest rider: $e');
      return null;
    }
  }

  /// Get multiple nearest riders sorted by distance
  Future<List<Map<String, dynamic>>> getNearestRiders(
    LatLng pickupLocation, {
    int maxRiders = 5,
    double maxDistanceKm = 10.0, // Maximum distance to consider
    String? vehicleType,
  }) async {
    try {
      List<Map<String, dynamic>> onlineRiders = await getOnlineRiders(
        vehicleType: vehicleType,
      );

      if (onlineRiders.isEmpty) {
        return [];
      }

      List<Map<String, dynamic>> ridersWithDistance = [];

      for (var rider in onlineRiders) {
        try {
          double riderLat = rider['latitude']?.toDouble() ?? 0.0;
          double riderLng = rider['longitude']?.toDouble() ?? 0.0;

          LatLng riderLocation = LatLng(riderLat, riderLng);
          double distance = _calculateDistance(pickupLocation, riderLocation);

          // Only include riders within max distance
          if (distance <= maxDistanceKm) {
            rider['distance'] = distance;
            ridersWithDistance.add(rider);
          }
        } catch (e) {
          print('Error processing rider ${rider['riderId']}: $e');
          continue;
        }
      }

      // Sort by distance (closest first)
      ridersWithDistance.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      // Return only the requested number of riders
      return ridersWithDistance.take(maxRiders).toList();
    } catch (e) {
      print('Error getting nearest riders: $e');
      return [];
    }
  }

  /// Check if a rider is online and available
  Future<bool> isRiderOnline(String riderId) async {
    try {
      DocumentSnapshot riderDoc =
          await _firestore.collection('riders').doc(riderId).get();

      if (riderDoc.exists) {
        Map<String, dynamic> data = riderDoc.data() as Map<String, dynamic>;
        return data['isOnline'] == true && data['isOnTrip'] != true;
      }

      return false;
    } catch (e) {
      print('Error checking rider online status: $e');
      return false;
    }
  }

  /// Listen to rider location updates in real-time
  Stream<LatLng?> listenToRiderLocation(String riderId) {
    return _database.ref('rider_locations/$riderId').onValue.map((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        Map<dynamic, dynamic> riderData =
            event.snapshot.value as Map<dynamic, dynamic>;

        double? lat = riderData['latitude']?.toDouble();
        double? lng = riderData['longitude']?.toDouble();

        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
      return null;
    });
  }
}

// Extension methods for math operations
extension DoubleExtension on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double asin() => math.asin(this);
  double sqrt() => math.sqrt(this);
}
