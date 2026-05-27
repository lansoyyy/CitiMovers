import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverMapMarker extends StatelessWidget {
  final String plateNumber;
  final Color markerColor;
  final bool isSelected;

  const DriverMapMarker({
    super.key,
    required this.plateNumber,
    required this.markerColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final plate = plateNumber.trim().toUpperCase();
    final iconSize = isSelected ? 34.0 : 22.0;

    return AnimatedScale(
      scale: isSelected ? 1.08 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isSelected) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: markerColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                plate.isEmpty ? '—' : plate,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Icon(
            Icons.local_shipping_rounded,
            color: markerColor,
            size: iconSize,
            shadows: _iconShadows(isSelected),
          ),
        ],
      ),
    );
  }

  static List<Shadow> _iconShadows(bool isSelected) {
    return [
      const Shadow(color: Colors.white, offset: Offset(-1.5, -1.5), blurRadius: 0),
      const Shadow(color: Colors.white, offset: Offset(1.5, -1.5), blurRadius: 0),
      const Shadow(color: Colors.white, offset: Offset(-1.5, 1.5), blurRadius: 0),
      const Shadow(color: Colors.white, offset: Offset(1.5, 1.5), blurRadius: 0),
      Shadow(
        color: Colors.black.withValues(alpha: isSelected ? 0.5 : 0.25),
        offset: Offset(0, isSelected ? 3 : 2),
        blurRadius: isSelected ? 8 : 4,
      ),
    ];
  }
}
