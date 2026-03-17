import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 60 : 100,
        horizontal: isMobile ? 24 : 60,
      ),
      child: Column(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(
                  'Simple Process',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Book a Delivery\nin 4 Easy Steps',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 26 : 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  'Getting your cargo delivered with CitiMovers is fast, '
                  'transparent, and stress-free from start to finish.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.textGrey,
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: isMobile ? 48 : 80),

          isMobile ? _buildMobileSteps() : _buildDesktopSteps(),
        ],
      ),
    );
  }

  Widget _buildDesktopSteps() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _StepCard(step: 1, icon: Icons.pin_drop_rounded, title: 'Set Locations', description: 'Enter your pickup address and delivery destination. Use autocomplete to find any address in Metro Manila quickly.')),
        _StepConnector(),
        Expanded(child: _StepCard(step: 2, icon: Icons.local_shipping_rounded, title: 'Choose Vehicle', description: 'Select the right vehicle for your cargo — from an AUV for small items up to a 10-Wheeler Wingvan for heavy loads.')),
        _StepConnector(),
        Expanded(child: _StepCard(step: 3, icon: Icons.check_circle_rounded, title: 'Confirm & Pay', description: 'Review your fare estimate, confirm the booking, and pay seamlessly via your in-app wallet.')),
        _StepConnector(),
        Expanded(child: _StepCard(step: 4, icon: Icons.gps_fixed_rounded, title: 'Track Live', description: 'Watch your driver on the real-time map. Get notified at every step — from accepted to delivered.')),
      ],
    );
  }

  Widget _buildMobileSteps() {
    return Column(
      children: [
        _StepCard(step: 1, icon: Icons.pin_drop_rounded, title: 'Set Locations', description: 'Enter your pickup address and delivery destination using Google Places autocomplete.'),
        const SizedBox(height: 16),
        _StepCard(step: 2, icon: Icons.local_shipping_rounded, title: 'Choose Vehicle', description: 'Select the right vehicle for your cargo size and budget.'),
        const SizedBox(height: 16),
        _StepCard(step: 3, icon: Icons.check_circle_rounded, title: 'Confirm & Pay', description: 'Review the fare, confirm booking, and pay via in-app wallet.'),
        const SizedBox(height: 16),
        _StepCard(step: 4, icon: Icons.gps_fixed_rounded, title: 'Track Live', description: 'Watch your driver on real-time GPS. Get notified every step of the way.'),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: SizedBox(
        width: 40,
        child: Row(
          children: List.generate(
            5,
            (i) => Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i % 2 == 0
                      ? AppColors.primary.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatefulWidget {
  final int step;
  final IconData icon;
  final String title;
  final String description;

  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.primary.withOpacity(0.03) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? AppColors.primary.withOpacity(0.18)
                : AppColors.borderLight,
          ),
        ),
        child: isMobile
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepIcon(),
                  const SizedBox(width: 20),
                  Expanded(child: _buildContent()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildStepIcon(),
                  const SizedBox(height: 20),
                  _buildContent(centered: true),
                ],
              ),
      ),
    );
  }

  Widget _buildStepIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppShadows.buttonShadow,
          ),
          child: Icon(widget.icon, color: Colors.white, size: 28),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                '${widget.step}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent({bool centered = false}) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (centered) const SizedBox(height: 4),
        Text(
          widget.title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.description,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            color: AppColors.textGrey,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
