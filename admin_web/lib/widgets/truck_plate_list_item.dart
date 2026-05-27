import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';

class TruckPlateListItem extends StatelessWidget {
  final String plateNumber;
  final bool isSelected;
  final bool hasLiveLocation;
  final VoidCallback? onTap;

  const TruckPlateListItem({
    super.key,
    required this.plateNumber,
    this.isSelected = false,
    this.hasLiveLocation = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final plate = plateNumber.trim().toUpperCase();
    final displayPlate = plate.isEmpty ? 'NO PLATE' : plate;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AdminTheme.primary.withValues(alpha: 0.08)
                : AdminTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AdminTheme.primary : AdminTheme.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            displayPlate,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: hasLiveLocation
                  ? (isSelected ? AdminTheme.primary : AdminTheme.textPrimary)
                  : AdminTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
