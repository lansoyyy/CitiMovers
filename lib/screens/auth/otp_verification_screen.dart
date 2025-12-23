import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/booking_model.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';
import '../delivery/delivery_tracking_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isSignup;
  final String? name;
  final VoidCallback? onVerified;
  final bool isBookingFlow;
  final BookingModel? booking;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.isSignup,
    this.name,
    this.booking,
    this.onVerified,
    this.isBookingFlow = false,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _authService = AuthService();

  bool _isLoading = false;
  bool _canResend = false;
  int _resendTimer = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
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
    _resendTimer = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);
    final success = await _authService.sendOTP(widget.phoneNumber);
    setState(() => _isLoading = false);

    if (success) {
      UIHelpers.showSuccessToast('OTP resent successfully');
      _startResendTimer();
      // Clear OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } else {
      UIHelpers.showErrorToast('Failed to resend OTP');
    }
  }

  String _getOTPCode() {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _verifyOTP() async {
    final otpCode = _getOTPCode();

    if (otpCode.length != 6) {
      UIHelpers.showWarningToast('Please enter complete OTP code');
      return;
    }

    setState(() => _isLoading = true);

    // Verify OTP
    final isValid = await _authService.verifyOTP(widget.phoneNumber, otpCode);

    if (!mounted) return;

    if (!isValid) {
      setState(() => _isLoading = false);
      UIHelpers.showErrorToast('Invalid OTP code. Please try again.');

      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
      return;
    }

    if (widget.isBookingFlow) {
      setState(() => _isLoading = false);

      widget.onVerified?.call();

      if (widget.booking != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DeliveryTrackingScreen(booking: widget.booking!),
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }

      return;
    }

    if (widget.isSignup) {
      if (widget.name == null || widget.name!.trim().isEmpty) {
        setState(() => _isLoading = false);
        UIHelpers.showErrorToast('Missing name. Please go back and try again.');
        return;
      }

      final user = await _authService.registerUser(
        name: widget.name!.trim(),
        phoneNumber: widget.phoneNumber,
      );

      if (!mounted) return;

      if (user == null) {
        setState(() => _isLoading = false);
        UIHelpers.showErrorToast('Registration failed. Please try again.');
        return;
      }

      UIHelpers.showSuccessToast('Registration successful!');
    } else {
      final user = await _authService.loginUser(widget.phoneNumber);

      if (!mounted) return;

      if (user == null) {
        setState(() => _isLoading = false);
        UIHelpers.showErrorToast('Login failed. Please try again.');
        return;
      }

      UIHelpers.showSuccessToast('Login successful!');
    }

    setState(() => _isLoading = false);

    widget.onVerified?.call();

    if (widget.isBookingFlow && widget.booking != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DeliveryTrackingScreen(booking: widget.booking!),
        ),
      );
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
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
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.message_outlined,
                    size: 50,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Center(
                child: Text(
                  'Verify Your Number',
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
                  'Enter the 6-digit code sent to\n${widget.phoneNumber}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 48),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    height: 60,
                    child: TextFormField(
                      controller: _otpControllers[index],
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
                          _verifyOTP();
                        }
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // Resend OTP
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: _resendOTP,
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'Bold',
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      )
                    : Text(
                        'Resend OTP in $_resendTimer seconds',
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
                  onPressed: _isLoading ? null : _verifyOTP,
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
                      : Text(
                          'Verify & Continue',
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'Bold',
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Change Number
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  label: const Text(
                    'Change Phone Number',
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
