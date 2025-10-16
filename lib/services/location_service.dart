import 'dart:math';
import '../models/location_model.dart';

/// Location Service for CitiMovers
/// Handles location permissions, current location, and saved locations
/// Ready for integration with geolocator and geocoding packages
class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Mock saved locations
  final List<LocationModel> _savedLocations = [];
  final List<LocationModel> _recentLocations = [];

  /// Get current device location
  /// TODO: Implement with geolocator package
  Future<LocationModel?> getCurrentLocation() async {
    try {
      // TODO: Check location permissions
      // final permission = await Geolocator.checkPermission();
      // if (permission == LocationPermission.denied) {
      //   await Geolocator.requestPermission();
      // }

      // TODO: Get current position
      // final position = await Geolocator.getCurrentPosition();

      // TODO: Get address from coordinates using geocoding
      // final placemarks = await placemarkFromCoordinates(
      //   position.latitude,
      //   position.longitude,
      // );

      // Mock implementation
      await Future.delayed(const Duration(seconds: 1));

      return LocationModel(
        address: '123 Sample Street, Manila, Metro Manila, Philippines',
        latitude: 14.5995,
        longitude: 120.9842,
        city: 'Manila',
        province: 'Metro Manila',
        country: 'Philippines',
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Check if location services are enabled
  /// TODO: Implement with geolocator package
  Future<bool> isLocationServiceEnabled() async {
    try {
      // TODO: Check if location services are enabled
      // return await Geolocator.isLocationServiceEnabled();

      // Mock implementation
      return true;
    } catch (e) {
      print('Error checking location service: $e');
      return false;
    }
  }

  /// Request location permission
  /// TODO: Implement with geolocator package
  Future<bool> requestLocationPermission() async {
    try {
      // TODO: Request location permission
      // final permission = await Geolocator.requestPermission();
      // return permission == LocationPermission.always ||
      //        permission == LocationPermission.whileInUse;

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  /// Get address from coordinates (Reverse Geocoding)
  /// TODO: Implement with geocoding package
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      // TODO: Implement reverse geocoding
      // final placemarks = await placemarkFromCoordinates(latitude, longitude);
      // if (placemarks.isNotEmpty) {
      //   final place = placemarks.first;
      //   return '${place.street}, ${place.locality}, ${place.administrativeArea}';
      // }

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 800));
      return 'Sample Address at $latitude, $longitude';
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Get coordinates from address (Forward Geocoding)
  /// TODO: Implement with geocoding package
  Future<Map<String, double>?> getCoordinatesFromAddress(
    String address,
  ) async {
    try {
      // TODO: Implement forward geocoding
      // final locations = await locationFromAddress(address);
      // if (locations.isNotEmpty) {
      //   final location = locations.first;
      //   return {
      //     'latitude': location.latitude,
      //     'longitude': location.longitude,
      //   };
      // }

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 800));
      return {
        'latitude': 14.5995,
        'longitude': 120.9842,
      };
    } catch (e) {
      print('Error getting coordinates from address: $e');
      return null;
    }
  }

  /// Save a favorite location
  Future<bool> saveFavoriteLocation(LocationModel location) async {
    try {
      // TODO: Save to Firestore
      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(userId)
      //     .collection('saved_locations')
      //     .add(location.toMap());

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));
      _savedLocations.add(location.copyWith(
        id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
        isFavorite: true,
        createdAt: DateTime.now(),
      ));
      return true;
    } catch (e) {
      print('Error saving favorite location: $e');
      return false;
    }
  }

  /// Get all saved locations
  Future<List<LocationModel>> getSavedLocations() async {
    try {
      // TODO: Fetch from Firestore
      // final snapshot = await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(userId)
      //     .collection('saved_locations')
      //     .where('isFavorite', isEqualTo: true)
      //     .get();
      // return snapshot.docs.map((doc) => LocationModel.fromMap(doc.data())).toList();

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));

      if (_savedLocations.isEmpty) {
        // Add mock saved locations
        _savedLocations.addAll([
          LocationModel(
            id: 'loc_1',
            label: 'Home',
            address: '123 Main Street, Quezon City, Metro Manila',
            latitude: 14.6760,
            longitude: 121.0437,
            city: 'Quezon City',
            province: 'Metro Manila',
            country: 'Philippines',
            isFavorite: true,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
          LocationModel(
            id: 'loc_2',
            label: 'Work',
            address: '456 Business Ave, Makati City, Metro Manila',
            latitude: 14.5547,
            longitude: 121.0244,
            city: 'Makati City',
            province: 'Metro Manila',
            country: 'Philippines',
            isFavorite: true,
            createdAt: DateTime.now().subtract(const Duration(days: 20)),
          ),
        ]);
      }

      return List.from(_savedLocations);
    } catch (e) {
      print('Error getting saved locations: $e');
      return [];
    }
  }

  /// Delete a saved location
  Future<bool> deleteSavedLocation(String locationId) async {
    try {
      // TODO: Delete from Firestore
      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(userId)
      //     .collection('saved_locations')
      //     .doc(locationId)
      //     .delete();

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));
      _savedLocations.removeWhere((loc) => loc.id == locationId);
      return true;
    } catch (e) {
      print('Error deleting saved location: $e');
      return false;
    }
  }

  /// Update a saved location
  Future<bool> updateSavedLocation(LocationModel location) async {
    try {
      // TODO: Update in Firestore
      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(userId)
      //     .collection('saved_locations')
      //     .doc(location.id)
      //     .update(location.toMap());

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));
      final index = _savedLocations.indexWhere((loc) => loc.id == location.id);
      if (index != -1) {
        _savedLocations[index] = location;
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating saved location: $e');
      return false;
    }
  }

  /// Add to recent locations
  void addToRecentLocations(LocationModel location) {
    // Remove if already exists
    _recentLocations.removeWhere((loc) =>
        loc.latitude == location.latitude && loc.longitude == location.longitude);

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
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // TODO: Use geolocator's distanceBetween method
    // return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;

    // Haversine formula (simplified)
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
}
