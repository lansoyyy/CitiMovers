import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../services/rider_auth_service.dart';
import 'rider_signup_screen.dart';
import '../rider_home_screen.dart';

class RiderLoginScreen extends StatefulWidget {
  const RiderLoginScreen({super.key});

  @override
  State<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends State<RiderLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = RiderAuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _plateController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final plateNumber = RiderAuthService.normalizePlateNumber(_plateController.text);
    final password = _passwordController.text;

    final isRegistered = await _authService.isPlateNumberRegistered(plateNumber);

    if (!mounted) return;

    if (!isRegistered) {
      setState(() => _isLoading = false);
      UIHelpers.showErrorToast(
          'Plate number not registered. Please sign up first.');
      return;
    }

    final rider = await _authService.loginRider(plateNumber, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (rider != null) {
      UIHelpers.showSuccessToast('Login successful!');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RiderHomeScreen()),
        (route) => false,
      );
    } else {
      UIHelpers.showErrorToast(
        _authService.lastLoginBlockMessage ??
            'Invalid plate number or password.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.redGradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_shipping_rounded,
                          color: AppColors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'RIDER LOGIN',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Bold',
                            color: AppColors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'Welcome Back,\nRider!',
                  style: TextStyle(
                    fontSize: 36,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Login to start earning and delivering',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 48),

                const Text(
                  'Vehicle Plate Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s]')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'e.g., ABC 1234',
                    prefixIcon: const Icon(
                      Icons.confirmation_number_outlined,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your vehicle plate number';
                    }
                    if (value.replaceAll(RegExp(r'\s'), '').length < 5) {
                      return 'Please enter a valid plate number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? UIHelpers.loadingThreeBounce(
                            color: AppColors.white,
                            size: 20,
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Bold',
                              color: AppColors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'New Rider?',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RiderSignupScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      side: const BorderSide(
                        color: AppColors.primaryRed,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Create Rider Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Bold',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.info,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Earn money on your own schedule. Drive when you want!',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Regular',
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                 const SizedBox(height: 20),
               Center(
                child:  Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                          ),
                        ),
               ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
