import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      width: double.infinity,
      color: AppColors.offWhite,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 60 : 100,
        horizontal: isMobile ? 24 : 60,
      ),
      child: Column(
        children: [
          _SectionHeader(
            tag: 'Why CitiMovers?',
            title: 'Everything You Need\nfor Hassle-Free Delivery',
            subtitle:
                'From instant booking to real-time tracking, we\'ve built every feature '
                'you need to move cargo safely and efficiently across Metro Manila.',
          ),
          SizedBox(height: isMobile ? 48 : 72),

          // Features grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 600
                  ? 1
                  : constraints.maxWidth < 1000
                      ? 2
                      : 3;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: _features
                    .map((f) => SizedBox(
                          width: (constraints.maxWidth -
                                  (crossAxisCount - 1) * 24) /
                              crossAxisCount,
                          child: _FeatureCard(feature: f),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  static final _features = [
    _Feature(
      icon: Icons.bolt_rounded,
      color: const Color(0xFF1565C0),
      title: 'Instant Booking',
      description:
          'Book a delivery in seconds. Choose your pickup and drop-off, pick a vehicle, and confirm — all in a few taps.',
    ),
    _Feature(
      icon: Icons.gps_fixed_rounded,
      color: const Color(0xFF10B981),
      title: 'Real-Time GPS Tracking',
      description:
          'Watch your driver move on live Google Maps. Know exactly where your cargo is at every moment of the journey.',
    ),
    _Feature(
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFF7C3AED),
      title: 'Multiple Vehicle Options',
      description:
          'From AUVs and L300 vans to 10-Wheeler Wingvans — pick exactly the right vehicle for your load size and budget.',
    ),
    _Feature(
      icon: Icons.schedule_rounded,
      color: const Color(0xFFE53935),
      title: 'Book Now or Schedule',
      description:
          'Need it now or planning ahead? Book an on-demand delivery or schedule it for a specific date and time.',
    ),
    _Feature(
      icon: Icons.timer_rounded,
      color: const Color(0xFFFF8C00),
      title: 'Demurrage Protection',
      description:
          'Automatic timer tracks loading/unloading time. Transparent extra fees applied only if the driver is kept waiting.',
    ),
    _Feature(
      icon: Icons.photo_camera_rounded,
      color: const Color(0xFF0891B2),
      title: 'Photo Proof of Delivery',
      description:
          'Drivers capture photos of your items before and after delivery — full photographic record of your cargo.',
    ),
    _Feature(
      icon: Icons.account_balance_wallet_rounded,
      color: const Color(0xFF059669),
      title: 'Digital Wallet',
      description:
          'Top up your in-app wallet and pay seamlessly. Full transaction history and easy balance management.',
    ),
    _Feature(
      icon: Icons.star_rounded,
      color: const Color(0xFFFFC107),
      title: 'Rating & Tips',
      description:
          'Rate your driver and leave a tip after every delivery. We keep quality high by rewarding great service.',
    ),
    _Feature(
      icon: Icons.chat_bubble_rounded,
      color: const Color(0xFF6366F1),
      title: 'In-App Messaging',
      description:
          'Chat directly with your driver in real time. Coordinate special instructions and get instant updates.',
    ),
  ];
}

class _Feature {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.feature.color.withOpacity(0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  )
                ]
              : AppShadows.cardShadow,
          border: Border.all(
            color: _hovered
                ? widget.feature.color.withOpacity(0.25)
                : AppColors.borderLight,
          ),
        ),
        transform: _hovered
            ? (Matrix4.identity()..translate(0.0, -4.0))
            : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: widget.feature.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.feature.icon,
                  color: widget.feature.color, size: 26),
            ),
            const SizedBox(height: 18),
            Text(
              widget.feature.title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.feature.description,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: AppColors.textGrey,
                height: 1.65,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String tag;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.tag,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Text(
            tag,
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
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 768 ? 26 : 36,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: AppColors.textGrey,
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }
}
