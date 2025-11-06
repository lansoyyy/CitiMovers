import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../services/rider_auth_service.dart';
import 'rider_signup_screen.dart';
import 'rider_otp_verification_screen.dart';

class RiderLoginScreen extends StatefulWidget {
  const RiderLoginScreen({super.key});

  @override
  State<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends State<RiderLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _authService = RiderAuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String value) {
    // Remove all non-digit characters
    String digits = value.replaceAll(RegExp(r'\D'), '');

    // Add +63 prefix if not present
    if (digits.startsWith('0')) {
      digits = '63${digits.substring(1)}';
    }
    if (!digits.startsWith('63')) {
      digits = '63$digits';
    }

    return '+$digits';
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final phoneNumber = _formatPhoneNumber(_phoneController.text);

    // Check if phone is registered
    final isRegistered = await _authService.isPhoneRegistered(phoneNumber);

    if (!mounted) return;

    if (!isRegistered) {
      setState(() => _isLoading = false);
      UIHelpers.showErrorToast(
          'Phone number not registered. Please sign up first.');
      return;
    }

    // Send OTP
    final otpSent = await _authService.sendOTP(phoneNumber);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (otpSent) {
      UIHelpers.showSuccessToast('OTP sent to your phone');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RiderOTPVerificationScreen(
            phoneNumber: phoneNumber,
            isSignup: false,
          ),
        ),
      );
    } else {
      UIHelpers.showErrorToast('Failed to send OTP. Please try again.');
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

                // Rider Badge
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

                // Title
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

                // Phone Number Field
                const Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    hintText: '09XX XXX XXXX',
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.network(
                            'https://flagcdn.com/w40/ph.png',
                            width: 24,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.flag, size: 24),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '+63',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Medium',
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 24,
                            width: 1,
                            color: AppColors.lightGrey,
                          ),
                        ],
                      ),
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your mobile number';
                    }
                    if (value.length < 10) {
                      return 'Please enter a valid mobile number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Login Button
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
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Bold',
                              color: AppColors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // Divider
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

                // Sign Up Button
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

                // Info Card
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
