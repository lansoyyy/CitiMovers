import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/ui_helpers.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import 'auth/welcome_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _navigateToHome();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Check if user has seen onboarding
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // If first time, show onboarding
    if (!hasSeenOnboarding) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
      return;
    }

    // Check if user is logged in
    final authService = AuthService();
    final isLoggedIn = authService.isLoggedIn;

    if (isLoggedIn) {
      final user = await authService.getCurrentUser();
      if (!mounted) return;

      if (user != null) {
        await PaymentService().reconcilePendingTransactionsForUser(user.userId);
      }
    }

    // Navigate to appropriate screen
    final destination = isLoggedIn ? const HomeScreen() : const WelcomeScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated logo/icon
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Image.asset(
                        AppConstants.logo,
                        width: 250,
                        height: 250,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // App name
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          AppConstants.appName,
                          style: const TextStyle(
                            fontSize: 36,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppConstants.appTagline,
                          style: const TextStyle(
                            fontSize: 15,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(flex: 2),

              // Loading indicator
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        UIHelpers.loadingThreeBounce(
                          color: AppColors.primaryRed,
                          size: 22,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 50),

              // Version info
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Version ${AppConstants.appVersion}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Regular',
                        color: AppColors.textHint,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
