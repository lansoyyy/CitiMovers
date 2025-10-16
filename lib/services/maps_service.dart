import 'dart:math';
import '../models/location_model.dart';

/// Maps Service for CitiMovers
/// Handles Google Maps API interactions
/// Ready for integration with Google Maps and Places API
class MapsService {
  // Singleton pattern
  static final MapsService _instance = MapsService._internal();
  factory MapsService() => _instance;
  MapsService._internal();

  // TODO: Add your Google Maps API Key
  static const String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /// Search places using Google Places Autocomplete API
  /// TODO: Implement with google_places_flutter or http package
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    try {
      // TODO: Implement Google Places Autocomplete
      // final response = await http.get(
      //   Uri.parse(
      //     'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      //     '?input=$query'
      //     '&key=$_apiKey'
      //     '&components=country:ph' // Philippines only
      //   ),
      // );

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 800));

      return [
        PlaceSuggestion(
          placeId: 'place_1',
          description: 'SM Mall of Asia, Pasay City, Metro Manila',
          mainText: 'SM Mall of Asia',
          secondaryText: 'Pasay City, Metro Manila',
        ),
        PlaceSuggestion(
          placeId: 'place_2',
          description: 'Ayala Center, Makati City, Metro Manila',
          mainText: 'Ayala Center',
          secondaryText: 'Makati City, Metro Manila',
        ),
        PlaceSuggestion(
          placeId: 'place_3',
          description: 'Bonifacio Global City, Taguig, Metro Manila',
          mainText: 'Bonifacio Global City',
          secondaryText: 'Taguig, Metro Manila',
        ),
      ];
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  /// Get place details from place ID
  /// TODO: Implement with Google Places Details API
  Future<LocationModel?> getPlaceDetails(String placeId) async {
    try {
      // TODO: Implement Google Places Details API
      // final response = await http.get(
      //   Uri.parse(
      //     'https://maps.googleapis.com/maps/api/place/details/json'
      //     '?place_id=$placeId'
      //     '&key=$_apiKey'
      //   ),
      // );

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));

      return LocationModel(
        address: 'Sample Address for $placeId',
        latitude: 14.5995,
        longitude: 120.9842,
        city: 'Manila',
        province: 'Metro Manila',
        country: 'Philippines',
      );
    } catch (e) {
      print('Error getting place details: $e');
      return null;
    }
  }

  /// Calculate route between two points
  /// TODO: Implement with Google Directions API
  Future<RouteInfo?> calculateRoute(
    LocationModel origin,
    LocationModel destination,
  ) async {
    try {
      // TODO: Implement Google Directions API
      // final response = await http.get(
      //   Uri.parse(
      //     'https://maps.googleapis.com/maps/api/directions/json'
      //     '?origin=${origin.latitude},${origin.longitude}'
      //     '&destination=${destination.latitude},${destination.longitude}'
      //     '&key=$_apiKey'
      //   ),
      // );

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 800));

      // Calculate simple distance
      final distance = _calculateDistance(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );

      // Estimate duration (assuming 30 km/h average speed)
      final durationMinutes = (distance / 30 * 60).round();

      return RouteInfo(
        distanceKm: distance,
        durationMinutes: durationMinutes,
        polylinePoints: [], // TODO: Decode polyline from API response
      );
    } catch (e) {
      print('Error calculating route: $e');
      return null;
    }
  }

  /// Get estimated fare based on distance and vehicle type
  double calculateFare({
    required double distanceKm,
    required String vehicleType,
  }) {
    // Base fare rates per vehicle type (in PHP)
    const Map<String, Map<String, double>> fareRates = {
      'AUV': {'base': 100, 'perKm': 15},
      '4-Wheeler': {'base': 150, 'perKm': 20},
      '6-Wheeler': {'base': 300, 'perKm': 35},
      'Wingvan': {'base': 500, 'perKm': 50},
      'Trailer': {'base': 800, 'perKm': 80},
    };

    final rates = fareRates[vehicleType] ?? fareRates['AUV']!;
    final baseFare = rates['base']!;
    final perKmRate = rates['perKm']!;

    // Calculate total fare
    double totalFare = baseFare + (distanceKm * perKmRate);

    // Add peak hour surcharge (20%) if needed
    final now = DateTime.now();
    if ((now.hour >= 7 && now.hour <= 9) || (now.hour >= 17 && now.hour <= 19)) {
      totalFare *= 1.2;
    }

    return totalFare;
  }

  /// Calculate distance using Haversine formula
  double _calculateDistance(
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
}

/// Place Suggestion Model
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

/// Route Information Model
class RouteInfo {
  final double distanceKm;
  final int durationMinutes;
  final List<Map<String, double>> polylinePoints;

  RouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polylinePoints,
  });

  String get distanceText {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get durationText {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return '${hours}h ${mins}min';
  }
}
