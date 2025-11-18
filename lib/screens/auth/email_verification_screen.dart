import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String? phoneNumber;
  final bool isSignup;
  final String? name;
  final bool isBookingFlow;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.phoneNumber,
    required this.isSignup,
    this.name,
    this.isBookingFlow = false,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _authService = AuthService();

  bool _isLoading = false;
  bool _canResend = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _resendEmailCode() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);
    final success = await _authService.sendEmailVerificationCode(widget.email);
    setState(() => _isLoading = false);

    if (success) {
      UIHelpers.showSuccessToast('Verification code resent to your email');
      _startResendTimer();
      // Clear code fields
      for (var controller in _codeControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } else {
      UIHelpers.showErrorToast('Failed to resend verification code');
    }
  }

  String _getVerificationCode() {
    return _codeControllers.map((c) => c.text).join();
  }

  Future<void> _verifyEmailCode() async {
    final code = _getVerificationCode();

    if (code.length != 6) {
      UIHelpers.showWarningToast('Please enter complete verification code');
      return;
    }

    setState(() => _isLoading = true);

    // Verify email code
    final isValid = await _authService.verifyEmailCode(widget.email, code);

    if (!mounted) return;

    if (!isValid) {
      setState(() => _isLoading = false);
      UIHelpers.showErrorToast('Invalid verification code. Please try again.');
      return;
    }

    // If signup, register user
    if (widget.isSignup) {
      final user = await _authService.registerUser(
        name: widget.name!,
        phoneNumber: widget.phoneNumber!,
        email: widget.email,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        UIHelpers.showSuccessToast('Account created successfully!');
        _navigateToHome();
      } else {
        UIHelpers.showErrorToast('Failed to create account');
      }
    } else {
      // If login, authenticate user
      final user = await _authService.loginUser(widget.phoneNumber!);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        UIHelpers.showSuccessToast('Welcome back, ${user.name}!');
        _navigateToHome();
      } else {
        UIHelpers.showErrorToast('Failed to login');
      }
    }
  }

  void _navigateToHome() {
    if (widget.isBookingFlow) {
      // For booking flow, just pop back to continue booking process
      Navigator.pop(context);
    } else {
      // For login/signup flow, navigate to home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    size: 50,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Center(
                child: Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 28,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle
              Center(
                child: Text(
                  'Enter the 6-digit code sent to\n${widget.email}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 48),

              // Email Code Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    height: 60,
                    child: TextFormField(
                      controller: _codeControllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontFamily: 'Bold',
                        color: AppColors.textPrimary,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.lightGrey,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.lightGrey,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryBlue,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        }
                        if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        // Auto verify when all fields are filled
                        if (index == 5 && value.isNotEmpty) {
                          _verifyEmailCode();
                        }
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // Resend Email Code
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: _resendEmailCode,
                        child: const Text(
                          'Resend Email Code',
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'Bold',
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      )
                    : Text(
                        'Resend Email Code in $_resendTimer seconds',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),

              const SizedBox(height: 40),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyEmailCode,
                  style: ElevatedButton.styleFrom(
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
                          'Verify & Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Bold',
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Change Email
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  label: const Text(
                    'Change Email Address',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
