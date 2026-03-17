import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1565C0);      // Deep Blue
  static const Color primaryLight = Color(0xFF1E88E5);  // Medium Blue
  static const Color primaryDark = Color(0xFF0D47A1);   // Dark Blue
  static const Color accent = Color(0xFFE53935);        // Red
  static const Color accentLight = Color(0xFFFF6F60);   // Light Red
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F7FA);
  static const Color darkBg = Color(0xFF0A1628);        // Deep navy dark
  static const Color darkCard = Color(0xFF0F2044);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color success = Color(0xFF10B981);
  static const Color gold = Color(0xFFFFC107);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE53935), Color(0xFFFF6F60)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1628), Color(0xFF0D1F3C)],
  );
}

class AppShadows {
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> heroShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];
}
