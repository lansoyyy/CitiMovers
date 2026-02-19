import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Service for adding GPS watermark to photos similar to GPS Map Camera app
class GpsMapCameraService {
  static final GpsMapCameraService _instance = GpsMapCameraService._internal();
  factory GpsMapCameraService() => _instance;
  GpsMapCameraService._internal();

  /// Get current location with detailed address
  Future<GpsLocationData> getCurrentLocationData() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied');
      }

      // Get current position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      String city = '';
      String province = '';
      String country = '';
      String detailedAddress = '';

      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks.first;
          city = place.locality ?? place.subLocality ?? '';
          province = place.administrativeArea ?? '';
          country = place.country ?? '';

          // Build detailed address
          final List<String> addressParts = [];
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }
          if (place.country != null && place.country!.isNotEmpty) {
            addressParts.add(place.country!);
          }
          detailedAddress = addressParts.join(', ');
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
        detailedAddress =
            'Lat: ${position.latitude.toStringAsFixed(6)}, Long: ${position.longitude.toStringAsFixed(6)}';
      }

      return GpsLocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        city: city,
        province: province,
        country: country,
        detailedAddress: detailedAddress,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      rethrow;
    }
  }

  /// Add GPS watermark to an image file (disabled - returns original)
  Future<File> addGpsWatermark(
      File imageFile, GpsLocationData locationData) async {
    // Return original file without watermark
    return imageFile;
  }
}

/// Data class for GPS location information
class GpsLocationData {
  final double latitude;
  final double longitude;
  final String city;
  final String province;
  final String country;
  final String detailedAddress;
  final DateTime timestamp;

  GpsLocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.province,
    required this.country,
    required this.detailedAddress,
    required this.timestamp,
  });

  String get shortLocation =>
      '$city, $province${country.isNotEmpty ? ', $country' : ''}';
  String get coordinates =>
      'Lat: ${latitude.toStringAsFixed(6)}°, Long: ${longitude.toStringAsFixed(6)}°';
}
