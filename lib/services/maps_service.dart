import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/location_model.dart';
import '../utils/retry_utility.dart';

/// Maps Service for CitiMovers
/// Handles Google Maps API interactions
///
/// NOTE: Google Maps API key must be configured in build configuration
/// Add to android/app/build.gradle or ios/Runner/Info.plist:
/// Android: manifestPlaceholders = [googleMapsApiKey: "YOUR_GOOGLE_MAPS_API_KEY"]
/// iOS: Add to Info.plist with key "GoogleMapsApiKey"
class MapsService {
  // Singleton pattern
  static final MapsService _instance = MapsService._internal();
  factory MapsService() => _instance;
  MapsService._internal();

  // Google Maps API Key - configured via build environment
  static const String _apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'YOUR_GOOGLE_MAPS_API_KEY',
  );

  /// Check if Google Maps API is properly configured
  static bool get isConfigured =>
      _apiKey != 'YOUR_GOOGLE_MAPS_API_KEY' && _apiKey.isNotEmpty;

  // Base URLs for Google Maps APIs
  static const String _placesApiBase =
      'https://maps.googleapis.com/maps/api/place';
  static const String _directionsApiBase =
      'https://maps.googleapis.com/maps/api/directions';
  static const String _geocodingApiBase =
      'https://maps.googleapis.com/maps/api/geocode';

  /// Search places using Google Places Autocomplete API
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (!isConfigured) {
      debugPrint('Google Maps API key not configured. Using mock data.');
      // Return mock data if API key is not set
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
    }

    try {
      final response = await RetryUtility.retryMapsOperation(() async {
        return await http.get(
          Uri.parse('$_placesApiBase/autocomplete/json'
              '?input=${Uri.encodeComponent(query)}'
              '&key=$_apiKey'
              '&components=country:ph' // Philippines only
              '&sessiontoken=${_generateSessionToken()}'),
        );
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions.map((prediction) {
            return PlaceSuggestion(
              placeId: prediction['place_id'],
              description: prediction['description'],
              mainText: prediction['structured_formatting']['main_text'],
              secondaryText:
                  prediction['structured_formatting']['secondary_text'] ?? '',
            );
          }).toList();
        } else if (data['status'] == 'ZERO_RESULTS') {
          debugPrint('No places found for query: $query');
          return [];
        } else if (data['status'] == 'OVER_QUERY_LIMIT') {
          debugPrint('Google Maps API query limit exceeded');
          return [];
        } else if (data['status'] == 'REQUEST_DENIED') {
          debugPrint('Google Maps API request denied - check API key');
          return [];
        } else if (data['status'] == 'INVALID_REQUEST') {
          debugPrint(
              'Google Maps API invalid request: ${data['error_message']}');
          return [];
        }
      } else {
        debugPrint('Google Maps API error: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      debugPrint('Error searching places: $e');
      return [];
    }
  }

  /// Get place details from place ID
  Future<LocationModel?> getPlaceDetails(String placeId) async {
    if (!isConfigured) {
      debugPrint('Google Maps API key not configured. Using mock data.');
      // Return mock data if API key is not set
      await Future.delayed(const Duration(milliseconds: 500));
      return LocationModel(
        address: 'Sample Address for $placeId',
        latitude: 14.5995,
        longitude: 120.9842,
        city: 'Manila',
        province: 'Metro Manila',
        country: 'Philippines',
      );
    }

    try {
      final response = await RetryUtility.retryMapsOperation(() async {
        return await http.get(
          Uri.parse('$_placesApiBase/details/json'
              '?place_id=$placeId'
              '&key=$_apiKey'
              '&fields=name,formatted_address,geometry,address_component'),
        );
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          final addressComponents = result['address_components'] as List;

          String? city, province, country;

          for (var component in addressComponents) {
            final types = component['types'] as List;
            if (types.contains('locality')) {
              city = component['long_name'];
            } else if (types.contains('administrative_area_level_1')) {
              province = component['long_name'];
            } else if (types.contains('country')) {
              country = component['long_name'];
            }
          }

          return LocationModel(
            address: result['formatted_address'],
            latitude: location['lat'],
            longitude: location['lng'],
            city: city,
            province: province,
            country: country,
          );
        } else if (data['status'] == 'NOT_FOUND') {
          debugPrint('Place not found: $placeId');
          return null;
        } else if (data['status'] == 'REQUEST_DENIED') {
          debugPrint('Google Maps API request denied - check API key');
          return null;
        } else if (data['status'] == 'INVALID_REQUEST') {
          debugPrint(
              'Google Maps API invalid request: ${data['error_message']}');
          return null;
        }
      } else {
        debugPrint('Google Maps API error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      debugPrint('Error getting place details: $e');
      return null;
    }
  }

  /// Calculate route between two points
  Future<RouteInfo?> calculateRoute(
    LocationModel origin,
    LocationModel destination,
  ) async {
    if (!isConfigured) {
      debugPrint(
          'Google Maps API key not configured. Using Haversine formula for distance.');
      // Mock implementation if API key is not set
      await Future.delayed(const Duration(milliseconds: 800));
      final distance = _calculateDistance(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );
      final durationMinutes = (distance / 30 * 60).round();
      return RouteInfo(
        distanceKm: distance,
        durationMinutes: durationMinutes,
        polylinePoints: [],
      );
    }

    try {
      final response = await RetryUtility.retryMapsOperation(() async {
        return await http.get(
          Uri.parse('$_directionsApiBase/json'
              '?origin=${origin.latitude},${origin.longitude}'
              '&destination=${destination.latitude},${destination.longitude}'
              '&key=$_apiKey'
              '&alternatives=false'),
        );
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          final distance = leg['distance']['value'] / 1000; // Convert to km
          final duration = leg['duration']['value'] / 60; // Convert to minutes
          final polylinePoints =
              _decodePolyline(route['overview_polyline']['points']);

          return RouteInfo(
            distanceKm: distance,
            durationMinutes: duration.round(),
            polylinePoints: polylinePoints,
          );
        } else if (data['status'] == 'ZERO_RESULTS') {
          debugPrint('No route found between locations');
          return null;
        } else if (data['status'] == 'NOT_FOUND') {
          debugPrint('One or more locations not found');
          return null;
        } else if (data['status'] == 'REQUEST_DENIED') {
          debugPrint('Google Maps API request denied - check API key');
          return null;
        } else if (data['status'] == 'INVALID_REQUEST') {
          debugPrint(
              'Google Maps API invalid request: ${data['error_message']}');
          return null;
        }
      } else {
        debugPrint('Google Maps API error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      debugPrint('Error calculating route: $e');
      return null;
    }
  }

  /// Get estimated fare based on distance and vehicle type
  double calculateFare({
    required double distanceKm,
    required String vehicleType,
  }) {
    // New fare calculation formula: Distance x 3 / 2.5 x 60
    // With minimum rate of ₱12,000 for 10-wheeler wingvan
    double calculatedFare = 0.0;

    switch (vehicleType) {
      case '10-Wheeler Wingvan':
        calculatedFare = (distanceKm * 3 / 2.5) * 60;
        // Apply minimum rate of ₱12,000
        if (calculatedFare < 12000) {
          calculatedFare = 12000;
        }
        break;
      case 'AUV':
        // Using existing rates for other vehicle types until new formulas are provided
        calculatedFare = 100 + (distanceKm * 15);
        break;
      case '4-Wheeler':
        calculatedFare = 150 + (distanceKm * 20);
        break;
      case '6-Wheeler':
        calculatedFare = 300 + (distanceKm * 35);
        break;
      case 'Wingvan':
        calculatedFare = 500 + (distanceKm * 50);
        break;
      case 'Trailer':
        calculatedFare = 800 + (distanceKm * 80);
        break;
      default:
        // Default to AUV rates
        calculatedFare = 100 + (distanceKm * 15);
    }

    // Add peak hour surcharge (20%) if needed
    final now = DateTime.now();
    if ((now.hour >= 7 && now.hour <= 9) ||
        (now.hour >= 17 && now.hour <= 19)) {
      calculatedFare *= 1.2;
    }

    return calculatedFare;
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

  /// Generate a session token for Places API
  String _generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Decode Google Maps polyline
  List<Map<String, double>> _decodePolyline(String encoded) {
    List<Map<String, double>> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add({
        'latitude': lat / 1E5,
        'longitude': lng / 1E5,
      });
    }
    return points;
  }

  /// Get address from coordinates (reverse geocoding)
  Future<LocationModel?> getAddressFromCoordinates(
      double lat, double lng) async {
    if (!isConfigured) {
      debugPrint('Google Maps API key not configured. Using mock data.');
      // Mock implementation if API key is not set
      await Future.delayed(const Duration(milliseconds: 500));
      return LocationModel(
        address: 'Mock Address for $lat, $lng',
        latitude: lat,
        longitude: lng,
        city: 'Manila',
        province: 'Metro Manila',
        country: 'Philippines',
      );
    }

    try {
      final response = await RetryUtility.retryMapsOperation(() async {
        return await http.get(
          Uri.parse('$_geocodingApiBase/json'
              '?latlng=$lat,$lng'
              '&key=$_apiKey'),
        );
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['results'][0];
          final addressComponents = result['address_components'] as List;

          String? city, province, country;

          for (var component in addressComponents) {
            final types = component['types'] as List;
            if (types.contains('locality')) {
              city = component['long_name'];
            } else if (types.contains('administrative_area_level_1')) {
              province = component['long_name'];
            } else if (types.contains('country')) {
              country = component['long_name'];
            }
          }

          return LocationModel(
            address: result['formatted_address'],
            latitude: lat,
            longitude: lng,
            city: city,
            province: province,
            country: country,
          );
        } else if (data['status'] == 'ZERO_RESULTS') {
          debugPrint('No address found for coordinates: $lat, $lng');
          return null;
        } else if (data['status'] == 'REQUEST_DENIED') {
          debugPrint('Google Maps API request denied - check API key');
          return null;
        } else if (data['status'] == 'INVALID_REQUEST') {
          debugPrint(
              'Google Maps API invalid request: ${data['error_message']}');
          return null;
        }
      } else {
        debugPrint('Google Maps API error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Get coordinates from address (forward geocoding)
  Future<LocationModel?> getCoordinatesFromAddress(String address) async {
    if (!isConfigured) {
      debugPrint('Google Maps API key not configured. Using mock data.');
      // Mock implementation if API key is not set
      await Future.delayed(const Duration(milliseconds: 500));
      return LocationModel(
        address: address,
        latitude: 14.5995,
        longitude: 120.9842,
        city: 'Manila',
        province: 'Metro Manila',
        country: 'Philippines',
      );
    }

    try {
      final response = await RetryUtility.retryMapsOperation(() async {
        return await http.get(
          Uri.parse('$_geocodingApiBase/json'
              '?address=${Uri.encodeComponent(address)}'
              '&key=$_apiKey'),
        );
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          final addressComponents = result['address_components'] as List;

          String? city, province, country;

          for (var component in addressComponents) {
            final types = component['types'] as List;
            if (types.contains('locality')) {
              city = component['long_name'];
            } else if (types.contains('administrative_area_level_1')) {
              province = component['long_name'];
            } else if (types.contains('country')) {
              country = component['long_name'];
            }
          }

          return LocationModel(
            address: result['formatted_address'],
            latitude: location['lat'],
            longitude: location['lng'],
            city: city,
            province: province,
            country: country,
          );
        } else if (data['status'] == 'ZERO_RESULTS') {
          debugPrint('No coordinates found for address: $address');
          return null;
        } else if (data['status'] == 'REQUEST_DENIED') {
          debugPrint('Google Maps API request denied - check API key');
          return null;
        } else if (data['status'] == 'INVALID_REQUEST') {
          debugPrint(
              'Google Maps API invalid request: ${data['error_message']}');
          return null;
        }
      } else {
        debugPrint('Google Maps API error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      debugPrint('Error getting coordinates from address: $e');
      return null;
    }
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
