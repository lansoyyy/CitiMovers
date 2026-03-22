import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/download_helpers.dart';

class DownloadSection extends StatefulWidget {
  const DownloadSection({super.key});

  @override
  State<DownloadSection> createState() => _DownloadSectionState();
}

class _DownloadSectionState extends State<DownloadSection> {
  bool _androidHovered = false;
  bool _iosHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 60 : 100,
        horizontal: isMobile ? 24 : 60,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
        ),
      ),
      child: Stack(
        children: [
          // Background decorations
          Positioned(
            right: -60,
            top: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Ready to Move?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 30 : 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Download the CitiMovers app and book your first delivery today. '
                    'Fast, reliable, and just a few taps away.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 14 : 16,
                      color: Colors.white.withOpacity(0.78),
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Download buttons
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      MouseRegion(
                        onEnter: (_) => setState(() => _androidHovered = true),
                        onExit: (_) => setState(() => _androidHovered = false),
                        child: AnimatedScale(
                          scale: _androidHovered ? 1.04 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          child: GestureDetector(
                            onTap: () => showGooglePlayChoiceDialog(context),
                            child: _StoreButton(
                              icon: Icons.android_rounded,
                              label: 'Get it on',
                              storeName: 'Google Play',
                              isHovered: _androidHovered,
                            ),
                          ),
                        ),
                      ),
                      MouseRegion(
                        onEnter: (_) => setState(() => _iosHovered = true),
                        onExit: (_) => setState(() => _iosHovered = false),
                        child: AnimatedScale(
                          scale: _iosHovered ? 1.04 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          child: GestureDetector(
                            onTap: () => showAppStoreComingSoonDialog(context),
                            child: _StoreButton(
                              icon: Icons.apple_rounded,
                              label: 'Download on the',
                              storeName: 'App Store',
                              isHovered: _iosHovered,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Rating row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...List.generate(
                        5,
                        (_) => const Icon(
                          Icons.star_rounded,
                          color: AppColors.gold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Trusted by businesses across Metro Manila',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String storeName;
  final bool isHovered;

  const _StoreButton({
    required this.icon,
    required this.label,
    required this.storeName,
    required this.isHovered,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isHovered ? Colors.white : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHovered ? Colors.white : Colors.white.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isHovered ? AppColors.primary : Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isHovered ? AppColors.textGrey : Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                storeName,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isHovered ? AppColors.textDark : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
