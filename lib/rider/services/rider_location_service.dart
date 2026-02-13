import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Data class for detailed rider location info
class RiderLocationData {
  final LatLng position;
  final String? address;
  final int? updatedAt;

  RiderLocationData({required this.position, this.address, this.updatedAt});
}

/// Rider Location Service for CitiMovers
/// Handles rider location updates using Firestore
/// Consolidated to use only Firestore for consistency
class RiderLocationService {
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

  /// Update rider location in Firestore
  Future<void> updateRiderLocation({
    required String riderId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final locationData = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      if (address != null) {
        locationData['address'] = address;
      }
      await _firestore.collection('riders').doc(riderId).update({
        'currentLocation': locationData,
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint(
          'RiderLocationService: Rider $riderId location updated: $latitude, $longitude');
    } catch (e) {
      debugPrint('RiderLocationService: Error updating rider location: $e');
    }
  }

  /// Get rider's current location from Firestore
  Future<LatLng?> getRiderLocation(String riderId) async {
    try {
      final doc = await _firestore.collection('riders').doc(riderId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      final currentLocation = data['currentLocation'] as Map<String, dynamic>?;

      if (currentLocation != null) {
        final lat = currentLocation['latitude'] as num?;
        final lng = currentLocation['longitude'] as num?;

        if (lat != null && lng != null) {
          return LatLng(lat.toDouble(), lng.toDouble());
        }
      }

      return null;
    } catch (e) {
      debugPrint('RiderLocationService: Error getting rider location: $e');
      return null;
    }
  }

  /// Get all online riders from Firestore
  Future<List<Map<String, dynamic>>> getOnlineRiders({
    String? vehicleType,
  }) async {
    try {
      QuerySnapshot riderDocs = await _firestore
          .collection('riders')
          .where('isOnline', isEqualTo: true)
          .where('isOnTrip', isEqualTo: false)
          .get();

      List<Map<String, dynamic>> onlineRiders = [];

      for (var doc in riderDocs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final currentLocation =
            data['currentLocation'] as Map<String, dynamic>?;

        // Only include riders with valid location coordinates
        if (currentLocation != null &&
            currentLocation.containsKey('latitude') &&
            currentLocation.containsKey('longitude')) {
          Map<String, dynamic> riderData = Map<String, dynamic>.from(data);
          riderData['riderId'] = doc.id;

          // If vehicle type is specified, check if rider matches
          if (vehicleType != null) {
            String riderVehicleType = data['vehicleType'] ?? '';
            // Only include riders with matching vehicle type
            if (riderVehicleType == vehicleType) {
              riderData['vehicleType'] = riderVehicleType;
              onlineRiders.add(riderData);
            }
          } else {
            // If no vehicle type filter, include all online riders
            onlineRiders.add(riderData);
          }
        }
      }

      return onlineRiders;
    } catch (e) {
      debugPrint('RiderLocationService: Error fetching online riders: $e');
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
        debugPrint('RiderLocationService: No online riders found');
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

          debugPrint(
              'RiderLocationService: Rider ${rider['riderId']} is ${distance.toStringAsFixed(2)} km away');

          if (distance < minDistance) {
            minDistance = distance;
            nearestRider = rider;
          }
        } catch (e) {
          debugPrint(
              'RiderLocationService: Error processing rider ${rider['riderId']}: $e');
          continue;
        }
      }

      if (nearestRider != null) {
        debugPrint(
            'RiderLocationService: Nearest rider found: ${nearestRider['riderId']} at ${minDistance.toStringAsFixed(2)} km');
      }

      return nearestRider;
    } catch (e) {
      debugPrint('RiderLocationService: Error finding nearest rider: $e');
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
          debugPrint(
              'RiderLocationService: Error processing rider ${rider['riderId']}: $e');
          continue;
        }
      }

      // Sort by distance (closest first)
      ridersWithDistance.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      // Return only the requested number of riders
      return ridersWithDistance.take(maxRiders).toList();
    } catch (e) {
      debugPrint('RiderLocationService: Error getting nearest riders: $e');
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
      debugPrint(
          'RiderLocationService: Error checking rider online status: $e');
      return false;
    }
  }

  /// Listen to rider location updates in real-time
  Stream<LatLng?> listenToRiderLocation(String riderId) {
    return listenToRiderLocationDetailed(riderId).map((data) => data?.position);
  }

  /// Listen to rider location updates in real-time with address info
  Stream<RiderLocationData?> listenToRiderLocationDetailed(String riderId) {
    return _firestore
        .collection('riders')
        .doc(riderId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      final currentLocation = data?['currentLocation'] as Map<String, dynamic>?;

      if (currentLocation != null &&
          currentLocation.containsKey('latitude') &&
          currentLocation.containsKey('longitude')) {
        final lat = currentLocation['latitude'] as num?;
        final lng = currentLocation['longitude'] as num?;
        final address = currentLocation['address'] as String?;
        final updatedAt = currentLocation['updatedAt'] as int?;

        if (lat != null && lng != null) {
          return RiderLocationData(
            position: LatLng(lat.toDouble(), lng.toDouble()),
            address: address,
            updatedAt: updatedAt,
          );
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
