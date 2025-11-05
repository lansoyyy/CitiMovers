import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import 'auth/welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _titleAnimationController;
  late AnimationController _descriptionAnimationController;
  late AnimationController _buttonAnimationController;
  late AnimationController _iconAnimationController;

  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _descriptionFadeAnimation;
  late Animation<Offset> _descriptionSlideAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconRotationAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Fast & Reliable Delivery',
      description:
          'Get your packages delivered quickly and safely with our professional drivers and modern fleet.',
      icon: Icons.local_shipping,
      color: AppColors.primaryRed,
      gradient: AppColors.redGradient,
      image: 'assets/images/onboarding1.png',
    ),
    OnboardingPage(
      title: 'Real-Time Tracking',
      description:
          'Track your delivery in real-time on the map. Know exactly where your package is at all times.',
      icon: Icons.location_on,
      color: AppColors.success,
      gradient: const LinearGradient(
        colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      image: 'assets/images/onboarding2.png',
    ),
    OnboardingPage(
      title: 'Multiple Vehicle Options',
      description:
          'Choose from various vehicle types - motorcycles, vans, trucks, and more to fit your needs.',
      icon: Icons.directions_car,
      color: Colors.orange,
      gradient: const LinearGradient(
        colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      image: 'assets/images/onboarding3.png',
    ),
    OnboardingPage(
      title: 'Easy Booking Process',
      description:
          'Book your delivery in just a few taps. Simple, fast, and convenient for everyone.',
      icon: Icons.touch_app,
      color: AppColors.primaryBlue,
      gradient: AppColors.blueGradient,
      image: 'assets/images/onboarding4.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _titleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _descriptionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _titleAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _descriptionFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _descriptionAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _descriptionSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _descriptionAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _buttonScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _iconRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _iconAnimationController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _titleAnimationController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _descriptionAnimationController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _buttonAnimationController.forward();
      }
    });
  }

  void _resetAnimations() {
    _titleAnimationController.reset();
    _descriptionAnimationController.reset();
    _buttonAnimationController.reset();
    _iconAnimationController.reset();
    _startAnimations();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleAnimationController.dispose();
    _descriptionAnimationController.dispose();
    _buttonAnimationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const WelcomeScreen(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button with animation
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < _pages.length - 1)
                    AnimatedBuilder(
                      animation: _descriptionFadeAnimation,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _descriptionFadeAnimation,
                          child: TextButton(
                            onPressed: _skipOnboarding,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Medium',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            // PageView with custom transitions
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _resetAnimations();
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Enhanced Page Indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildIndicator(index == _currentPage, index),
                ),
              ),
            ),

            // Next/Get Started Button with animation
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: AnimatedBuilder(
                animation: _buttonScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _buttonScaleAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _currentPage == _pages.length - 1
                                ? AppColors.primaryRed.withValues(alpha: 0.3)
                                : AppColors.primaryRed.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentPage == _pages.length - 1
                                ? AppColors.primaryRed
                                : AppColors.primaryRed,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Bold',
                                ),
                              ),
                              if (_currentPage < _pages.length - 1) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: AppColors.white,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Icon/Illustration
          AnimatedBuilder(
            animation: _iconAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _iconScaleAnimation.value,
                child: Transform.rotate(
                  angle: _iconRotationAnimation.value * 0.1,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          page.color.withValues(alpha: 0.15),
                          page.color.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: page.color.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: page.gradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: page.color.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        page.icon,
                        size: 100,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 50),

          // Animated Title
          AnimatedBuilder(
            animation: _titleAnimationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _titleFadeAnimation,
                child: SlideTransition(
                  position: _titleSlideAnimation,
                  child: Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Animated Description
          AnimatedBuilder(
            animation: _descriptionAnimationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _descriptionFadeAnimation,
                child: SlideTransition(
                  position: _descriptionSlideAnimation,
                  child: Text(
                    page.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      height: isActive ? 10 : 8,
      width: isActive ? 32 : 8,
      decoration: BoxDecoration(
        gradient: isActive ? _pages[index].gradient : null,
        color: isActive ? null : AppColors.lightGrey,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _pages[index].color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;
  final String image;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.image,
  });
}
