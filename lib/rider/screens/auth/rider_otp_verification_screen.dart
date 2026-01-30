import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../services/rider_auth_service.dart';
import '../rider_home_screen.dart';

class RiderOTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isSignup;
  final String? name;
  final String? vehicleType;
  final String? vehiclePlateNumber;
  final String? vehicleModel;
  final String? vehicleColor;
  final Map<String, String?>? documentImagePaths;

  const RiderOTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.isSignup,
    this.name,
    this.vehicleType,
    this.vehiclePlateNumber,
    this.vehicleModel,
    this.vehicleColor,
    this.documentImagePaths,
  });

  @override
  State<RiderOTPVerificationScreen> createState() =>
      _RiderOTPVerificationScreenState();
}

class _RiderOTPVerificationScreenState
    extends State<RiderOTPVerificationScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final _authService = RiderAuthService();

  bool _isLoading = false;
  bool _isResending = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _autoPopulateOTP();
  }

  /// Auto-populate OTP fields with test OTP (for development/testing)
  void _autoPopulateOTP() {
    // Test OTP for development - no SMS required
    const testOTP = '123456';
    for (int i = 0; i < testOTP.length; i++) {
      _otpControllers[i].text = testOTP[i];
    }
    setState(() {});
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
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendOTP() async {
    if (_resendTimer > 0) return;

    setState(() => _isResending = true);

    final success = await _authService.sendOTP(widget.phoneNumber);

    if (!mounted) return;
    setState(() => _isResending = false);

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

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      UIHelpers.showErrorToast('Please enter complete OTP');
      return;
    }

    setState(() => _isLoading = true);

    // Verify OTP
    final isValid = await _authService.verifyOTP(widget.phoneNumber, otp);

    if (!mounted) return;

    if (isValid) {
      if (widget.isSignup) {
        // Register new rider
        final rider = await _authService.registerRider(
          name: widget.name!,
          phoneNumber: widget.phoneNumber,
          vehicleType: widget.vehicleType!,
          vehiclePlateNumber: widget.vehiclePlateNumber,
          vehicleModel: widget.vehicleModel,
          vehicleColor: widget.vehicleColor,
          documentImagePaths: widget.documentImagePaths,
        );

        if (!mounted) return;

        if (rider != null) {
          UIHelpers.showSuccessToast('Registration successful!');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const RiderHomeScreen(),
            ),
            (route) => false,
          );
        } else {
          setState(() => _isLoading = false);
          UIHelpers.showErrorToast('Registration failed. Please try again.');
        }
      } else {
        // Login existing rider
        final rider = await _authService.loginRider(widget.phoneNumber);

        if (!mounted) return;

        if (rider != null) {
          UIHelpers.showSuccessToast('Login successful!');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const RiderHomeScreen(),
            ),
            (route) => false,
          );
        } else {
          setState(() => _isLoading = false);
          UIHelpers.showErrorToast('Login failed. Please try again.');
        }
      }
    } else {
      setState(() => _isLoading = false);
      UIHelpers.showErrorToast('Invalid OTP. Please try again.');
    }
  }

  void _onOTPChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all fields are filled
    if (index == 5 && value.isNotEmpty) {
      final otp = _otpControllers.map((c) => c.text).join();
      if (otp.length == 6) {
        _verifyOTP();
      }
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 60,
                  color: AppColors.white,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Verify Your Number',
                style: TextStyle(
                  fontSize: 28,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                'Enter the 6-digit code sent to\n${widget.phoneNumber}',
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'Regular',
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Dev Mode Indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.developer_mode,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dev Mode: OTP auto-populated (123456)',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Medium',
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

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
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.lightGrey,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryRed,
                            width: 2,
                          ),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _onOTPChanged(index, value),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 40),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
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
                          'Verify & Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Bold',
                            color: AppColors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive the code? ",
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_resendTimer > 0)
                    Text(
                      'Resend in ${_resendTimer}s',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _isResending ? null : _resendOTP,
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryRed,
                                ),
                              ),
                            )
                          : const Text(
                              'Resend',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Bold',
                                color: AppColors.primaryRed,
                              ),
                            ),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.info,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The OTP will expire in 10 minutes',
                        style: TextStyle(
                          fontSize: 12,
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
    );
  }
}
