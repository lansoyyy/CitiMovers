import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';
import 'auth_service.dart';

/// Location Service for CitiMovers
/// Handles location permissions, current location, and saved locations
/// Integrated with geolocator and geocoding packages
class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Recent locations cache (in-memory)
  final List<LocationModel> _recentLocations = [];

  /// Get current device location
  Future<LocationModel?> getCurrentLocation(
      {bool requestPermission = true}) async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: Location services are disabled.');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        if (requestPermission) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            debugPrint('LocationService: Location permissions are denied');
            return null;
          }
        } else {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            'LocationService: Location permissions are permanently denied');
        return null;
      }

      // Get current position with high accuracy
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates using geocoding
      String address = await _getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return LocationModel(
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
        city: '', // Will be populated by geocoding
        province: '', // Will be populated by geocoding
        country: '', // Will be populated by geocoding
      );
    } catch (e) {
      debugPrint('LocationService: Error getting current location: $e');
      return null;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationService: Error checking location service: $e');
      return false;
    }
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('LocationService: Error requesting location permission: $e');
      return false;
    }
  }

  /// Get address from coordinates (Reverse Geocoding)
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      return await _getAddressFromCoordinates(latitude, longitude);
    } catch (e) {
      debugPrint('LocationService: Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Internal method to get address from coordinates
  Future<String> _getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final street =
            place.street?.isNotEmpty == true ? '${place.street}, ' : '';
        final sublocality = place.subLocality?.isNotEmpty == true
            ? '${place.subLocality}, '
            : '';
        final locality =
            place.locality?.isNotEmpty == true ? '${place.locality}, ' : '';
        final administrativeArea = place.administrativeArea?.isNotEmpty == true
            ? '${place.administrativeArea}, '
            : '';
        final country = place.country?.isNotEmpty == true ? place.country : '';

        return '$street$sublocality$locality$administrativeArea$country'.trim();
      }

      return 'Unknown Location';
    } catch (e) {
      debugPrint('LocationService: Error in reverse geocoding: $e');
      return 'Unknown Location';
    }
  }

  /// Get coordinates from address (Forward Geocoding)
  Future<Map<String, double>?> getCoordinatesFromAddress(
    String address,
  ) async {
    try {
      final List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final Location location = locations.first;
        return {
          'latitude': location.latitude,
          'longitude': location.longitude,
        };
      }

      return null;
    } catch (e) {
      debugPrint('LocationService: Error getting coordinates from address: $e');
      return null;
    }
  }

  /// Save a favorite location to Firestore
  Future<bool> saveFavoriteLocation(LocationModel location) async {
    try {
      final authService = AuthService();
      final userId = authService.currentUser?.userId;

      if (userId == null) {
        debugPrint('LocationService: User not authenticated');
        return false;
      }

      final locationData = {
        'name': location.label ?? 'Saved Location',
        'address': location.address,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'type': location.label?.toLowerCase() == 'home'
            ? 'home'
            : location.label?.toLowerCase() == 'work'
                ? 'office'
                : 'other',
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('saved_locations').add(locationData);

      return true;
    } catch (e) {
      debugPrint('LocationService: Error saving favorite location: $e');
      return false;
    }
  }

  /// Get all saved locations from Firestore
  Future<List<LocationModel>> getSavedLocations() async {
    try {
      final authService = AuthService();
      final userId = authService.currentUser?.userId;

      if (userId == null) {
        return [];
      }

      final snapshot = await _firestore
          .collection('saved_locations')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return LocationModel(
          id: doc.id,
          label: data['name'] as String?,
          address: data['address'] as String? ?? '',
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
          city: '',
          province: '',
          country: '',
          isFavorite: true,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('LocationService: Error getting saved locations: $e');
      return [];
    }
  }

  /// Stream of saved locations for real-time updates
  Stream<List<LocationModel>> getSavedLocationsStream() {
    final authService = AuthService();
    final userId = authService.currentUser?.userId;

    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('saved_locations')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return LocationModel(
                id: doc.id,
                label: data['name'] as String?,
                address: data['address'] as String? ?? '',
                latitude: (data['latitude'] as num).toDouble(),
                longitude: (data['longitude'] as num).toDouble(),
                city: '',
                province: '',
                country: '',
                isFavorite: true,
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              );
            }).toList());
  }

  /// Delete a saved location from Firestore
  Future<bool> deleteSavedLocation(String locationId) async {
    try {
      await _firestore.collection('saved_locations').doc(locationId).delete();
      return true;
    } catch (e) {
      debugPrint('LocationService: Error deleting saved location: $e');
      return false;
    }
  }

  /// Update a saved location in Firestore
  Future<bool> updateSavedLocation(LocationModel location) async {
    try {
      await _firestore.collection('saved_locations').doc(location.id).update({
        'name': location.label ?? 'Saved Location',
        'address': location.address,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('LocationService: Error updating saved location: $e');
      return false;
    }
  }

  /// Add to recent locations
  void addToRecentLocations(LocationModel location) {
    // Remove if already exists
    _recentLocations.removeWhere((loc) =>
        loc.latitude == location.latitude &&
        loc.longitude == location.longitude);

    // Add to beginning
    _recentLocations.insert(0, location);

    // Keep only last 10
    if (_recentLocations.length > 10) {
      _recentLocations.removeLast();
    }
  }

  /// Get recent locations
  List<LocationModel> getRecentLocations() {
    return List.from(_recentLocations);
  }

  /// Calculate distance between two coordinates (in kilometers)
  /// Uses geolocator's distanceBetween method for accurate calculation
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    try {
      // Use geolocator's built-in distance calculation (returns meters)
      final distanceInMeters = Geolocator.distanceBetween(
        lat1,
        lon1,
        lat2,
        lon2,
      );
      return distanceInMeters / 1000; // Convert to kilometers
    } catch (e) {
      debugPrint('LocationService: Error calculating distance: $e');
      // Fallback to Haversine formula
      return _haversineDistance(lat1, lon1, lat2, lon2);
    }
  }

  /// Haversine formula as fallback for distance calculation
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  /// Get current position (raw Position object)
  Future<Position?> getCurrentPosition({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
    bool forceAndroidLocationManager = false,
  }) async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: Location services are disabled.');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('LocationService: Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            'LocationService: Location permissions are permanently denied');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: desiredAccuracy,
        forceAndroidLocationManager: forceAndroidLocationManager,
      );
    } catch (e) {
      debugPrint('LocationService: Error getting current position: $e');
      return null;
    }
  }

  /// Get last known position (faster but may be cached)
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      debugPrint('LocationService: Error getting last known position: $e');
      return null;
    }
  }

  /// Get distance between two locations in meters
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Get bearing between two coordinates in degrees
  double distanceBetweenBearing(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Open location settings (useful when location service is disabled)
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('LocationService: Error opening location settings: $e');
      return false;
    }
  }

  /// Open app settings (useful when permission is denied forever)
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('LocationService: Error opening app settings: $e');
      return false;
    }
  }
}
