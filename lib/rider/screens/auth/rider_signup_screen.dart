import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../../models/vehicle_model.dart';
import '../../services/rider_auth_service.dart';
import 'rider_otp_verification_screen.dart';

class RiderSignupScreen extends StatefulWidget {
  const RiderSignupScreen({super.key});

  @override
  State<RiderSignupScreen> createState() => _RiderSignupScreenState();
}

class _RiderSignupScreenState extends State<RiderSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _authService = RiderAuthService();
  bool _isLoading = false;
  bool _agreedToTerms = false;
  String _selectedVehicleType = 'AUV';

  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, String?> _documentImagePaths = {
    "Driver's License": null,
    'Vehicle Registration (OR/CR)': null,
    'NBI Clearance': null,
    'Insurance': null,
  };

  final Set<String> _requiredDocuments = {
    "Driver's License",
    'Vehicle Registration (OR/CR)',
    'NBI Clearance',
  };

  // Get vehicle types from VehicleModel
  final List<String> _vehicleTypes =
      VehicleModel.getAvailableVehicles().map((v) => v.type).toList();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _plateNumberController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String value) {
    String digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = '63${digits.substring(1)}';
    }
    if (!digits.startsWith('63')) {
      digits = '63$digits';
    }
    return '+$digits';
  }

  bool _hasAllRequiredDocuments() {
    for (final docName in _requiredDocuments) {
      final path = _documentImagePaths[docName];
      if (path == null || path.isEmpty) return false;
    }
    return true;
  }

  Future<ImageSource?> _selectImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDocument(String documentName) async {
    try {
      final source = await _selectImageSource();
      if (source == null) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (!mounted) return;

      if (image == null) return;

      setState(() {
        _documentImagePaths[documentName] = image.path;
      });

      UIHelpers.showSuccessToast('$documentName selected');
    } catch (e) {
      UIHelpers.showErrorToast('Failed to pick document. Please try again.');
    }
  }

  Widget _buildDocumentTile(String documentName) {
    final imagePath = _documentImagePaths[documentName];
    final isRequired = _requiredDocuments.contains(documentName);
    final hasImage = imagePath != null && imagePath.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasImage
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.lightGrey,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: hasImage
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.textHint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.description,
                        color: AppColors.success,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.upload_file,
                    color: AppColors.textSecondary,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        documentName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Bold',
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hasImage ? 'Selected' : 'Not uploaded',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Medium',
                    color:
                        hasImage ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _isLoading ? null : () => _pickDocument(documentName),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryRed,
              side: const BorderSide(color: AppColors.primaryRed),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(
              hasImage ? 'Change' : 'Upload',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Bold',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasAllRequiredDocuments()) {
      UIHelpers.showErrorToast('Please upload all required documents');
      return;
    }

    if (!_agreedToTerms) {
      UIHelpers.showErrorToast('Please agree to the terms and conditions');
      return;
    }

    setState(() => _isLoading = true);

    final phoneNumber = _formatPhoneNumber(_phoneController.text);

    // Check if phone is already registered
    final isRegistered = await _authService.isPhoneRegistered(phoneNumber);

    if (!mounted) return;

    if (isRegistered) {
      setState(() => _isLoading = false);
      UIHelpers.showErrorToast(
          'Phone number already registered. Please login.');
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
            isSignup: true,
            name: _nameController.text,
            email: _emailController.text.isEmpty ? null : _emailController.text,
            vehicleType: _selectedVehicleType,
            vehiclePlateNumber: _plateNumberController.text,
            vehicleModel: _vehicleModelController.text.isEmpty
                ? null
                : _vehicleModelController.text,
            vehicleColor: _vehicleColorController.text.isEmpty
                ? null
                : _vehicleColorController.text,
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_shipping_rounded,
                          color: AppColors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'BECOME A RIDER',
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

                const SizedBox(height: 32),

                // Title
                const Text(
                  'Join Our Team',
                  style: TextStyle(
                    fontSize: 32,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Start earning by delivering packages',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                // Full Name Field
                const Text(
                  'Full Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Juan Dela Cruz',
                    prefixIcon: Icon(Icons.person_outline),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

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

                const SizedBox(height: 20),

                // Email Field (Optional)
                const Text(
                  'Email Address (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'juan@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Vehicle Type Dropdown
                const Text(
                  'Vehicle Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.directions_car_outlined),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  items: _vehicleTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedVehicleType = newValue;
                      });
                    }
                  },
                ),

                const SizedBox(height: 20),

                // Vehicle Plate Number Field
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
                  controller: _plateNumberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'ABC 1234',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your vehicle plate number';
                    }
                    if (value.length < 5) {
                      return 'Please enter a valid plate number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Vehicle Model Field (Optional)
                const Text(
                  'Vehicle Model (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vehicleModelController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Toyota Hilux, Honda XRM',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                ),

                const SizedBox(height: 20),

                // Vehicle Color Field (Optional)
                const Text(
                  'Vehicle Color (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vehicleColorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g., White, Black, Red',
                    prefixIcon: Icon(Icons.palette_outlined),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Required Documents',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primaryBlue,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Upload clear photos of your documents. These are required to complete your registration.',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Regular',
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildDocumentTile("Driver's License"),
                _buildDocumentTile('Vehicle Registration (OR/CR)'),
                _buildDocumentTile('NBI Clearance'),
                _buildDocumentTile('Insurance'),

                const SizedBox(height: 10),

                // Terms and Conditions Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreedToTerms = value ?? false;
                        });
                      },
                      activeColor: AppColors.primaryRed,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _agreedToTerms = !_agreedToTerms;
                            });
                          },
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Regular',
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms and Conditions',
                                  style: TextStyle(
                                    color: AppColors.primaryRed,
                                    fontFamily: 'Bold',
                                  ),
                                ),
                                TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: AppColors.primaryRed,
                                    fontFamily: 'Bold',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
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
                            'Create Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Bold',
                              color: AppColors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login Link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Bold',
                            color: AppColors.primaryRed,
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
