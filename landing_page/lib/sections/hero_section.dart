import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class HeroSection extends StatefulWidget {
  const HeroSection({super.key});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final isTablet = size.width >= 768 && size.width < 1100;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isMobile ? 600 : 700),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF0A84D0)],
        ),
      ),
      child: Stack(
        children: [
          // Background decorative elements
          ..._buildBackgroundDecorations(size),

          // Content
          Padding(
            padding: EdgeInsets.only(
              left: isMobile ? 24 : 60,
              right: isMobile ? 24 : 60,
              top: isMobile ? 120 : 140,
              bottom: isMobile ? 60 : 80,
            ),
            child: isMobile
                ? _buildMobileLayout()
                : _buildDesktopLayout(isTablet),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBackgroundDecorations(Size size) {
    return [
      // Large circle top-right
      Positioned(
        top: -80,
        right: -80,
        child: Container(
          width: 400,
          height: 400,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.04),
          ),
        ),
      ),
      // Medium circle top-right inner
      Positioned(
        top: 20,
        right: 40,
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ),
      // Circle bottom-left
      Positioned(
        bottom: -60,
        left: -60,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.04),
          ),
        ),
      ),
      // Accent stripe
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          height: 4,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFFF6F60), Color(0xFFE53935)],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildDesktopLayout(bool isTablet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left text side
        Expanded(
          flex: isTablet ? 6 : 5,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _buildHeroText(false),
            ),
          ),
        ),
        SizedBox(width: isTablet ? 40 : 80),
        // Right visual side
        Expanded(
          flex: isTablet ? 4 : 5,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: _buildHeroVisual(false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeroText(true),
            const SizedBox(height: 48),
            _buildHeroVisual(true),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroText(bool isMobile) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Now serving Metro Manila',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Headline
        Text(
          'Move Anything,\nAnywhere in the\nCity.',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: isMobile ? 36 : 52,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),

        // Accent underline word
        if (!isMobile)
          Container(
            width: 220,
            height: 4,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(height: 20),

        // Subtitle
        Text(
          'Professional logistics & cargo delivery across Metro Manila. '
          'Book a truck, van, or wingvan — instantly.',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: isMobile ? 14 : 16,
            color: Colors.white.withOpacity(0.80),
            height: 1.7,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 36),

        // CTA Buttons
        Wrap(
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          spacing: 16,
          runSpacing: 12,
          children: [
            _HeroCTAButton(
              label: 'Download App',
              icon: Icons.download_rounded,
              gradient: AppColors.accentGradient,
              shadows: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            _HeroCTAButton(
              label: 'Learn More',
              icon: Icons.play_circle_outline_rounded,
              gradient: const LinearGradient(
                colors: [Colors.white24, Colors.white12],
              ),
              border: Border.all(color: Colors.white38),
            ),
          ],
        ),
        const SizedBox(height: 48),

        // Trust badges
        Wrap(
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          spacing: 24,
          runSpacing: 12,
          children: [
            _TrustBadge(icon: Icons.local_shipping_rounded, label: '7 Vehicle Types'),
            _TrustBadge(icon: Icons.gps_fixed_rounded, label: 'Live GPS Tracking'),
            _TrustBadge(icon: Icons.shield_rounded, label: 'Insured Delivery'),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroVisual(bool isMobile) {
    return Center(
      child: SizedBox(
        width: isMobile ? 280 : 420,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background glow
            Container(
              width: isMobile ? 240 : 360,
              height: isMobile ? 240 : 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Mock phone frame
            _MockPhoneFrame(isMobile: isMobile),
          ],
        ),
      ),
    );
  }
}

class _HeroCTAButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final List<BoxShadow>? shadows;
  final Border? border;

  const _HeroCTAButton({
    required this.label,
    required this.icon,
    required this.gradient,
    this.shadows,
    this.border,
  });

  @override
  State<_HeroCTAButton> createState() => _HeroCTAButtonState();
}

class _HeroCTAButtonState extends State<_HeroCTAButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: widget.shadows,
            border: widget.border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MockPhoneFrame extends StatelessWidget {
  final bool isMobile;
  const _MockPhoneFrame({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final w = isMobile ? 200.0 : 280.0;
    final h = isMobile ? 360.0 : 500.0;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 60,
            offset: const Offset(-10, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Column(
          children: [
            // Status bar notch
            Container(
              height: 28,
              color: Colors.black,
              child: Center(
                child: Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            // App content mock
            Expanded(
              child: Container(
                color: const Color(0xFF0F2044),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: AppColors.cardGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.local_shipping,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CitiMovers',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map placeholder
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      height: isMobile ? 100 : 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3560),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Grid lines to simulate map
                          ...List.generate(
                            4,
                            (i) => Positioned(
                              top: i * (isMobile ? 30.0 : 40.0),
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          ...List.generate(
                            4,
                            (i) => Positioned(
                              left: i * (isMobile ? 30.0 : 60.0),
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 1,
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppColors.accent, size: 28),
                              const SizedBox(height: 4),
                              Text(
                                'Live Tracking',
                                style: GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Book now card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppColors.cardGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Book a Delivery',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MockInputField(
                              icon: Icons.trip_origin, hint: 'Pickup location'),
                          const SizedBox(height: 6),
                          _MockInputField(
                              icon: Icons.location_on, hint: 'Destination'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Vehicle row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MockVehicleChip(Icons.airport_shuttle, 'AUV'),
                          _MockVehicleChip(Icons.local_shipping, 'L300'),
                          _MockVehicleChip(Icons.fire_truck, '6-Wheel'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockInputField extends StatelessWidget {
  final IconData icon;
  final String hint;
  const _MockInputField({required this.icon, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 6),
          Text(
            hint,
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockVehicleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MockVehicleChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white60, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white54,
            fontSize: 8,
          ),
        ),
      ],
    );
  }
}
