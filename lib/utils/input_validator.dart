import 'package:flutter/foundation.dart';

/// Input Validator Utility for CitiMovers
/// Provides validation methods for various user inputs
class InputValidator {
  // Private constructor to prevent instantiation
  InputValidator._();

  /// Validate email address
  /// Returns null if valid, error message otherwise
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }

    // Basic email format validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    // Check for common typos
    if (email.contains('..') || email.startsWith('.') || email.endsWith('.')) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validate Philippine phone number
  /// Accepts formats: 09XXXXXXXXX, +639XXXXXXXXX, 639XXXXXXXXX
  /// Returns null if valid, error message otherwise
  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Phone number is required';
    }

    // Remove spaces, dashes, and parentheses
    final cleanedPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check for Philippine phone number format
    final phoneRegex = RegExp(r'^(\+63|0)?9\d{9}$');
    if (!phoneRegex.hasMatch(cleanedPhone)) {
      return 'Please enter a valid Philippine phone number (09XXXXXXXXX)';
    }

    return null;
  }

  /// Normalize Philippine phone number to standard format
  /// Returns phone number in format 09XXXXXXXXX
  static String normalizePhone(String phone) {
    final cleanedPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // If starts with +63, replace with 0
    if (cleanedPhone.startsWith('+63')) {
      return '0${cleanedPhone.substring(3)}';
    }

    // If starts with 63 and not +, replace with 0
    if (cleanedPhone.startsWith('63') && cleanedPhone.length == 12) {
      return '0${cleanedPhone.substring(2)}';
    }

    // Already in correct format
    return cleanedPhone;
  }

  /// Validate name (first name, last name, or full name)
  /// Returns null if valid, error message otherwise
  static String? validateName(String? name, {String fieldName = 'Name'}) {
    if (name == null || name.isEmpty) {
      return '$fieldName is required';
    }

    // Check minimum length
    if (name.length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    // Check maximum length
    if (name.length > 100) {
      return '$fieldName must not exceed 100 characters';
    }

    // Check for valid characters (letters, spaces, hyphens)
    final nameRegex = RegExp(r'^[a-zA-Z\s\-]+$');
    if (!nameRegex.hasMatch(name)) {
      return '$fieldName can only contain letters, spaces, and hyphens';
    }

    return null;
  }

  /// Validate address
  /// Returns null if valid, error message otherwise
  static String? validateAddress(String? address) {
    if (address == null || address.isEmpty) {
      return 'Address is required';
    }

    // Check minimum length
    if (address.length < 10) {
      return 'Address must be at least 10 characters';
    }

    // Check maximum length
    if (address.length > 500) {
      return 'Address must not exceed 500 characters';
    }

    return null;
  }

  /// Validate amount (fare, payment, etc.)
  /// Returns null if valid, error message otherwise
  static String? validateAmount(
    String? amount, {
    double min = 0.01,
    double max = 1000000.0,
    String fieldName = 'Amount',
  }) {
    if (amount == null || amount.isEmpty) {
      return '$fieldName is required';
    }

    final parsedAmount = double.tryParse(amount);
    if (parsedAmount == null) {
      return 'Please enter a valid $fieldName';
    }

    if (parsedAmount < min) {
      return '$fieldName must be at least ${min.toStringAsFixed(2)}';
    }

    if (parsedAmount > max) {
      return '$fieldName must not exceed ${max.toStringAsFixed(2)}';
    }

    return null;
  }

  /// Validate vehicle plate number (Philippines format)
  /// Accepts formats: ABC 1234, ABC-1234, ABC1234
  /// Returns null if valid, error message otherwise
  static String? validateVehiclePlate(String? plate) {
    if (plate == null || plate.isEmpty) {
      return 'Vehicle plate number is required';
    }

    // Remove spaces and dashes for validation
    final cleanedPlate = plate.replaceAll(RegExp(r'[\s\-]'), '');

    // Check for Philippine plate format: 3 letters followed by 3-4 numbers
    final plateRegex = RegExp(r'^[A-Z]{3}\d{3,4}$');
    if (!plateRegex.hasMatch(cleanedPlate.toUpperCase())) {
      return 'Please enter a valid vehicle plate number (e.g., ABC 1234)';
    }

    return null;
  }

  /// Validate license number (Philippines format)
  /// Accepts formats: N01-12-345678, N0112345678
  /// Returns null if valid, error message otherwise
  static String? validateLicenseNumber(String? license) {
    if (license == null || license.isEmpty) {
      return 'License number is required';
    }

    // Remove spaces and dashes for validation
    final cleanedLicense = license.replaceAll(RegExp(r'[\s\-]'), '');

    // Check for Philippine license format: N + 2 digits + 2 digits + 6 digits
    final licenseRegex = RegExp(r'^N\d{2}\d{2}\d{6}$');
    if (!licenseRegex.hasMatch(cleanedLicense.toUpperCase())) {
      return 'Please enter a valid license number (e.g., N01-12-345678)';
    }

    return null;
  }

  /// Validate password
  /// Returns null if valid, error message otherwise
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    // Check minimum length
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    // Check maximum length
    if (password.length > 50) {
      return 'Password must not exceed 50 characters';
    }

    return null;
  }

  /// Validate OTP code
  /// Returns null if valid, error message otherwise
  static String? validateOTP(String? otp) {
    if (otp == null || otp.isEmpty) {
      return 'OTP is required';
    }

    // Check for exactly 6 digits
    final otpRegex = RegExp(r'^\d{6}$');
    if (!otpRegex.hasMatch(otp)) {
      return 'Please enter a valid 6-digit OTP';
    }

    return null;
  }

  /// Validate coordinates (latitude and longitude)
  /// Returns null if valid, error message otherwise
  static String? validateCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'Location is required';
    }

    // Check latitude range (-90 to 90)
    if (latitude < -90 || latitude > 90) {
      return 'Invalid latitude value';
    }

    // Check longitude range (-180 to 180)
    if (longitude < -180 || longitude > 180) {
      return 'Invalid longitude value';
    }

    return null;
  }

  /// Validate vehicle type
  /// Returns null if valid, error message otherwise
  static String? validateVehicleType(String? vehicleType) {
    if (vehicleType == null || vehicleType.isEmpty) {
      return 'Vehicle type is required';
    }

    // Check for valid vehicle types
    final validTypes = [
      'AUV',
      'L300',
      '4-Wheeler',
      '6-Wheeler',
      'Wingvan',
      'Trailer',
      '10-Wheeler Wingvan',
      'motorcycle',
      'sedan',
      'van',
      'truck',
    ];

    if (!validTypes.contains(vehicleType)) {
      return 'Invalid vehicle type';
    }

    return null;
  }

  /// Validate package type
  /// Returns null if valid, error message otherwise
  static String? validatePackageType(String? packageType) {
    if (packageType == null || packageType.isEmpty) {
      return 'Package type is required';
    }

    // Check minimum length
    if (packageType.length < 2) {
      return 'Package type must be at least 2 characters';
    }

    // Check maximum length
    if (packageType.length > 50) {
      return 'Package type must not exceed 50 characters';
    }

    return null;
  }

  /// Validate weight (in kg)
  /// Returns null if valid, error message otherwise
  static String? validateWeight(
    String? weight, {
    double min = 0.1,
    double max = 10000.0,
  }) {
    if (weight == null || weight.isEmpty) {
      return 'Weight is required';
    }

    final parsedWeight = double.tryParse(weight);
    if (parsedWeight == null) {
      return 'Please enter a valid weight';
    }

    if (parsedWeight < min) {
      return 'Weight must be at least ${min.toStringAsFixed(1)} kg';
    }

    if (parsedWeight > max) {
      return 'Weight must not exceed ${max.toStringAsFixed(1)} kg';
    }

    return null;
  }

  /// Validate notes or special instructions
  /// Returns null if valid, error message otherwise
  static String? validateNotes(
    String? notes, {
    int maxLength = 500,
    String fieldName = 'Notes',
  }) {
    if (notes != null && notes.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }

    return null;
  }

  /// Validate distance (in km)
  /// Returns null if valid, error message otherwise
  static String? validateDistance(double? distance) {
    if (distance == null) {
      return 'Distance is required';
    }

    if (distance <= 0) {
      return 'Distance must be greater than 0';
    }

    if (distance > 10000) {
      return 'Distance must not exceed 10,000 km';
    }

    return null;
  }

  /// Validate booking ID
  /// Returns null if valid, error message otherwise
  static String? validateBookingId(String? bookingId) {
    if (bookingId == null || bookingId.isEmpty) {
      return 'Booking ID is required';
    }

    // Check minimum length
    if (bookingId.length < 5) {
      return 'Invalid booking ID';
    }

    return null;
  }

  /// Validate user ID
  /// Returns null if valid, error message otherwise
  static String? validateUserId(String? userId) {
    if (userId == null || userId.isEmpty) {
      return 'User ID is required';
    }

    // Check minimum length
    if (userId.length < 5) {
      return 'Invalid user ID';
    }

    return null;
  }

  /// Sanitize string input to prevent XSS and injection attacks
  static String sanitizeString(String input) {
    // Remove potentially dangerous characters
    String sanitized = input;

    // Remove script tags
    final scriptRegex =
        RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false);
    sanitized = sanitized.replaceAll(scriptRegex, '');

    // Remove HTML tags
    final htmlRegex = RegExp(r'<[^>]+>', caseSensitive: false);
    sanitized = sanitized.replaceAll(htmlRegex, '');

    return sanitized;
  }

  /// Validate URL
  /// Returns null if valid, error message otherwise
  static String? validateUrl(String? url) {
    if (url == null || url.isEmpty) {
      return 'URL is required';
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(url)) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  /// Validate date of birth (must be at least 18 years old)
  /// Returns null if valid, error message otherwise
  static String? validateDateOfBirth(DateTime? dateOfBirth) {
    if (dateOfBirth == null) {
      return 'Date of birth is required';
    }

    final now = DateTime.now();
    final age = now.year - dateOfBirth.year;

    if (age < 18) {
      return 'You must be at least 18 years old';
    }

    if (age > 120) {
      return 'Please enter a valid date of birth';
    }

    return null;
  }

  /// Validate file size (in MB)
  /// Returns null if valid, error message otherwise
  static String? validateFileSize(int fileSizeBytes, double maxSizeMB) {
    final fileSizeMB = fileSizeBytes / (1024 * 1024);

    if (fileSizeMB > maxSizeMB) {
      return 'File size must not exceed ${maxSizeMB.toStringAsFixed(1)} MB';
    }

    return null;
  }

  /// Validate image file extension
  /// Returns null if valid, error message otherwise
  static String? validateImageExtension(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    final validExtensions = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'];

    if (!validExtensions.contains(extension)) {
      return 'Invalid image format. Please use JPG, PNG, or WebP';
    }

    return null;
  }

  /// Debug log for validation errors
  static void logValidationError(String field, String? error) {
    if (error != null) {
      debugPrint('InputValidator: $field validation failed - $error');
    }
  }
}
