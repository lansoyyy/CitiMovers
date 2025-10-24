import 'package:flutter/material.dart';

/// App color palette for CitiMovers
/// Primary colors: Red and Blue
class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primaryRed = Color(0xFF1E88E5);
  static const Color primaryBlue = Color(0xFFE53935);

  // Red Shades
  static const Color lightRed = Color(0xFFEF5350);
  static const Color darkRed = Color(0xFFC62828);
  static const Color redAccent = Color(0xFFFF5252);

  // Blue Shades
  static const Color lightBlue = Color(0xFF42A5F5);
  static const Color darkBlue = Color(0xFF1565C0);
  static const Color blueAccent = Color(0xFF448AFF);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color lightGrey = Color(0xFFE0E0E0);
  static const Color darkGrey = Color(0xFF424242);

  // Background Colors
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFFAFAFA);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryRed, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redGradient = LinearGradient(
    colors: [lightRed, darkRed],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [lightBlue, darkBlue],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
