import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/download_helpers.dart';

class LandingNavbar extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onScrollToHero;
  final VoidCallback onScrollToFeatures;
  final VoidCallback onScrollToVehicles;
  final VoidCallback onScrollToHowItWorks;
  final VoidCallback onScrollToContact;

  const LandingNavbar({
    super.key,
    required this.scrollController,
    required this.onScrollToHero,
    required this.onScrollToFeatures,
    required this.onScrollToVehicles,
    required this.onScrollToHowItWorks,
    required this.onScrollToContact,
  });

  @override
  State<LandingNavbar> createState() => _LandingNavbarState();
}

class _LandingNavbarState extends State<LandingNavbar> {
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final scrolled = widget.scrollController.offset > 50;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _isScrolled
            ? AppColors.white.withOpacity(0.97)
            : Colors.transparent,
        boxShadow: _isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 60,
            vertical: 16,
          ),
          child: Row(
            children: [
              // Logo
              GestureDetector(
                onTap: widget.onScrollToHero,
                child: Image.asset('assets/images/logo.png', height: 44),
              ),
              const Spacer(),

              // Nav links (desktop only)
              if (!isMobile) ...[
                _NavLink(
                  label: 'Features',
                  isScrolled: _isScrolled,
                  onTap: widget.onScrollToFeatures,
                ),
                const SizedBox(width: 32),
                _NavLink(
                  label: 'Vehicles',
                  isScrolled: _isScrolled,
                  onTap: widget.onScrollToVehicles,
                ),
                const SizedBox(width: 32),
                _NavLink(
                  label: 'How It Works',
                  isScrolled: _isScrolled,
                  onTap: widget.onScrollToHowItWorks,
                ),
                const SizedBox(width: 32),
                _NavLink(
                  label: 'Contact',
                  isScrolled: _isScrolled,
                  onTap: widget.onScrollToContact,
                ),
                const SizedBox(width: 40),
                _DownloadButton(isScrolled: _isScrolled),
              ] else ...[
                _MobileMenuButton(
                  isScrolled: _isScrolled,
                  onFeatures: widget.onScrollToFeatures,
                  onVehicles: widget.onScrollToVehicles,
                  onHowItWorks: widget.onScrollToHowItWorks,
                  onContact: widget.onScrollToContact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final bool isScrolled;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.isScrolled,
    required this.onTap,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _hovered
                ? AppColors.accent
                : widget.isScrolled
                ? AppColors.textDark
                : AppColors.white,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatefulWidget {
  final bool isScrolled;
  const _DownloadButton({required this.isScrolled});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => showGeneralDownloadDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: _hovered
                ? AppColors.accentGradient
                : AppColors.cardGradient,
            borderRadius: BorderRadius.circular(25),
            boxShadow: AppShadows.buttonShadow,
          ),
          child: Text(
            'Get the App',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileMenuButton extends StatelessWidget {
  final bool isScrolled;
  final VoidCallback onFeatures;
  final VoidCallback onVehicles;
  final VoidCallback onHowItWorks;
  final VoidCallback onContact;

  const _MobileMenuButton({
    required this.isScrolled,
    required this.onFeatures,
    required this.onVehicles,
    required this.onHowItWorks,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.menu_rounded,
        color: isScrolled ? AppColors.textDark : AppColors.white,
        size: 28,
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _MobileMenu(
            onFeatures: onFeatures,
            onVehicles: onVehicles,
            onHowItWorks: onHowItWorks,
            onContact: onContact,
          ),
        );
      },
    );
  }
}

class _MobileMenu extends StatelessWidget {
  final VoidCallback onFeatures;
  final VoidCallback onVehicles;
  final VoidCallback onHowItWorks;
  final VoidCallback onContact;

  const _MobileMenu({
    required this.onFeatures,
    required this.onVehicles,
    required this.onHowItWorks,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.heroShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _MobileNavItem(
              label: 'Features',
              icon: Icons.star_rounded,
              onTap: () {
                Navigator.pop(context);
                onFeatures();
              },
            ),
            _MobileNavItem(
              label: 'Vehicles',
              icon: Icons.local_shipping_rounded,
              onTap: () {
                Navigator.pop(context);
                onVehicles();
              },
            ),
            _MobileNavItem(
              label: 'How It Works',
              icon: Icons.help_outline_rounded,
              onTap: () {
                Navigator.pop(context);
                onHowItWorks();
              },
            ),
            _MobileNavItem(
              label: 'Contact Us',
              icon: Icons.contact_mail_rounded,
              onTap: () {
                Navigator.pop(context);
                onContact();
              },
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                showGeneralDownloadDialog(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Get the App',
                    style: GoogleFonts.poppins(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textLight,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
