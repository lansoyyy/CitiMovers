import 'package:flutter/material.dart';
import 'sections/hero_section.dart';
import 'sections/stats_section.dart';
import 'sections/features_section.dart';
import 'sections/vehicles_section.dart';
import 'sections/how_it_works_section.dart';
import 'sections/download_section.dart';
import 'sections/contact_section.dart';
import 'widgets/navbar.dart';
import 'widgets/footer.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _vehiclesKey = GlobalKey();
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // Scrollable body
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                SizedBox(key: _heroKey, child: const HeroSection()),
                const StatsSection(),
                SizedBox(key: _featuresKey, child: const FeaturesSection()),
                SizedBox(key: _vehiclesKey, child: const VehiclesSection()),
                SizedBox(key: _howItWorksKey, child: const HowItWorksSection()),
                const DownloadSection(),
                SizedBox(key: _contactKey, child: const ContactSection()),
                const LandingFooter(),
              ],
            ),
          ),

          // Sticky navbar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LandingNavbar(
              scrollController: _scrollController,
              onScrollToHero: () => _scrollToKey(_heroKey),
              onScrollToFeatures: () => _scrollToKey(_featuresKey),
              onScrollToVehicles: () => _scrollToKey(_vehiclesKey),
              onScrollToHowItWorks: () => _scrollToKey(_howItWorksKey),
              onScrollToContact: () => _scrollToKey(_contactKey),
            ),
          ),

          // Floating scroll-to-top button
          Positioned(
            bottom: 32,
            right: 32,
            child: _ScrollToTopButton(scrollController: _scrollController),
          ),
        ],
      ),
    );
  }
}

class _ScrollToTopButton extends StatefulWidget {
  final ScrollController scrollController;
  const _ScrollToTopButton({required this.scrollController});

  @override
  State<_ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<_ScrollToTopButton>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final shouldShow = widget.scrollController.offset > 300;
    if (shouldShow != _visible) {
      setState(() => _visible = shouldShow);
      if (_visible) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: IgnorePointer(
        ignoring: !_visible,
        child: GestureDetector(
          onTap: () => widget.scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          ),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_upward_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
