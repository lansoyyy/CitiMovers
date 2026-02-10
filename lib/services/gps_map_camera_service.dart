import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Add GPS watermark to an image file
  Future<File> addGpsWatermark(
      File imageFile, GpsLocationData locationData) async {
    try {
      // Read the image file
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Add watermark
      final img.Image watermarkedImage =
          _drawGpsWatermark(originalImage, locationData);

      // Save to temp file
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath =
          '${tempDir.path}/gps_watermarked_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Uint8List watermarkedBytes =
          img.encodeJpg(watermarkedImage, quality: 90);
      final File watermarkedFile = File(tempPath);
      await watermarkedFile.writeAsBytes(watermarkedBytes);

      return watermarkedFile;
    } catch (e) {
      debugPrint('Error adding GPS watermark: $e');
      // Return original file if watermark fails
      return imageFile;
    }
  }

  /// Draw GPS watermark on image
  img.Image _drawGpsWatermark(img.Image image, GpsLocationData location) {
    final int width = image.width;
    final int height = image.height;

    // Calculate watermark height (about 25% of image height)
    final int watermarkHeight = (height * 0.28).round();

    // Create overlay at bottom
    final int overlayY = height - watermarkHeight;

    // Draw semi-transparent black background
    for (int y = overlayY; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();

        // Blend with black (70% opacity)
        const double opacity = 0.70;
        final int newR = (r * (1 - opacity)).round();
        final int newG = (g * (1 - opacity)).round();
        final int newB = (b * (1 - opacity)).round();

        image.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
      }
    }

    // Format timestamp (Philippine Time UTC+8)
    final DateTime pht =
        location.timestamp.toUtc().add(const Duration(hours: 8));
    final String dateTimeStr =
        DateFormat('EEEE, MM/dd/yyyy hh:mm a').format(pht);
    final String timeZoneStr = 'GMT+08:00';

    // Draw text lines
    final List<String> lines = [];

    // Main location (city, province)
    final String mainLocation =
        '${location.city}, ${location.province}${location.country.isNotEmpty ? ', ${location.country}' : ''}';
    if (mainLocation.trim().isNotEmpty && mainLocation != ', ') {
      lines.add(mainLocation);
    }

    // Detailed address
    if (location.detailedAddress.isNotEmpty) {
      // Wrap address if too long
      final List<String> wrappedAddress =
          _wrapText(location.detailedAddress, 50);
      lines.addAll(wrappedAddress);
    }

    // Coordinates
    lines.add(
        'Lat ${location.latitude.toStringAsFixed(6)}° Long ${location.longitude.toStringAsFixed(6)}°');

    // Date and time
    lines.add('$dateTimeStr $timeZoneStr');

    // GPS Map Camera label
    lines.add('GPS Map Camera');

    // Draw each line of text
    final int fontSize = (width * 0.035).round().clamp(12, 24);
    final int lineHeight = (fontSize * 1.5).round();
    final int startX = (width * 0.05).round();
    int currentY = overlayY + (watermarkHeight * 0.15).round();

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      final bool isLastLine = i == lines.length - 1;
      final bool isMainLocation = i == 0 && line == mainLocation;

      // Make main location and GPS label bold/bigger
      final int currentFontSize =
          isMainLocation || isLastLine ? (fontSize * 1.2).round() : fontSize;

      final img.Color textColor = isLastLine
          ? img.ColorRgb8(100, 200, 255) // Light blue for GPS label
          : img.ColorRgb8(255, 255, 255); // White for other text

      // Draw text using simple bitmap font
      _drawText(image, line, startX, currentY, currentFontSize, textColor);

      currentY += (lineHeight * (isMainLocation ? 1.3 : 1.0)).round();
    }

    return image;
  }

  /// Wrap text to fit within max length
  List<String> _wrapText(String text, int maxLength) {
    if (text.length <= maxLength) return [text];

    final List<String> words = text.split(' ');
    final List<String> lines = [];
    String currentLine = '';

    for (final word in words) {
      if ((currentLine + ' ' + word).length > maxLength) {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine.trim());
        }
        currentLine = word;
      } else {
        currentLine = currentLine.isEmpty ? word : '$currentLine $word';
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine.trim());
    }

    return lines;
  }

  /// Draw text on image using bitmap font approach
  void _drawText(img.Image image, String text, int x, int y, int fontSize,
      img.Color color) {
    // Simple bitmap font drawing - using rectangles to approximate letters
    // This is a basic implementation - for production, consider using a proper font package

    int currentX = x;
    final int charWidth = (fontSize * 0.6).round();
    final int charHeight = fontSize;

    for (int i = 0; i < text.length; i++) {
      final String char = text[i];

      if (char == ' ') {
        currentX += (charWidth / 2).round();
        continue;
      }

      // Draw character as a simple rectangle with slight variations
      _drawChar(image, char, currentX, y, charWidth, charHeight, color);

      currentX += charWidth;
    }
  }

  /// Draw a character (simplified bitmap representation)
  void _drawChar(img.Image image, String char, int x, int y, int width,
      int height, img.Color color) {
    // Draw simple filled rectangle for each character
    // This is a placeholder - real implementation would use proper font glyphs
    for (int dy = 1; dy < height - 1; dy++) {
      for (int dx = 1; dx < width - 1; dx++) {
        final int px = x + dx;
        final int py = y + dy;

        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          // Make it look like text by varying opacity based on position
          final double opacity = _getCharOpacity(char, dx, dy, width, height);
          if (opacity > 0.3) {
            image.setPixel(px, py, color);
          }
        }
      }
    }
  }

  /// Get opacity for a character pixel based on char and position
  double _getCharOpacity(String char, int x, int y, int w, int h) {
    // Simplified character shapes - returns opacity based on character pattern

    // Use position and char code to create different patterns
    final double normalizedX = x / w;
    final double normalizedY = y / h;

    // Basic pattern - most chars have vertical line on left
    if (normalizedX < 0.2) return 0.9;

    // Different patterns based on character type
    if ('AEIOU'.contains(char.toUpperCase())) {
      // Vowels - more open
      if (normalizedY < 0.3 || normalizedY > 0.7) return 0.8;
      return 0.3;
    } else if ('BMNP'.contains(char.toUpperCase())) {
      // Letters with vertical lines
      if (normalizedX > 0.8) return 0.8;
      if (normalizedY > 0.45 && normalizedY < 0.55) return 0.7;
      return 0.4;
    } else if (char == '.' || char == ',') {
      // Punctuation at bottom
      if (normalizedY > 0.7) return 0.9;
      return 0.1;
    } else if (RegExp(r'[0-9]').hasMatch(char)) {
      // Numbers
      if (normalizedY < 0.15 || normalizedY > 0.85) return 0.8;
      if (normalizedX < 0.15 || normalizedX > 0.85) return 0.8;
      return 0.3;
    }

    // Default pattern
    return 0.5 + (normalizedX * normalizedY * 0.5);
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
