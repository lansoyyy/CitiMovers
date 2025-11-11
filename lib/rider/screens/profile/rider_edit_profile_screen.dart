import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../services/rider_auth_service.dart';

class RiderEditProfileScreen extends StatefulWidget {
  const RiderEditProfileScreen({super.key});

  @override
  State<RiderEditProfileScreen> createState() => _RiderEditProfileScreenState();
}

class _RiderEditProfileScreenState extends State<RiderEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = RiderAuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadRiderData();
  }

  void _loadRiderData() {
    final rider = _authService.currentRider;
    if (rider != null) {
      _nameController.text = rider.name;
      _emailController.text = rider.email ?? '';
      _phoneController.text = rider.phoneNumber;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _profileImagePath = image.path;
      });
      UIHelpers.showSuccessToast('Profile picture selected');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: Implement profile update with Firebase
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      UIHelpers.showSuccessToast('Profile updated successfully');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rider = _authService.currentRider;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Profile Picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.lightGrey,
                    backgroundImage: _profileImagePath != null
                        ? null
                        : (rider?.photoUrl != null
                            ? NetworkImage(rider!.photoUrl!)
                            : null),
                    child: _profileImagePath == null && rider?.photoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: AppColors.white,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryRed.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
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
                      decoration: const InputDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline),
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        if (value.length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Email
                    const Text(
                      'Email Address',
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
                        hintText: 'Enter your email',
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

                    // Phone Number (Read-only)
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      enabled: false,
                      decoration: const InputDecoration(
                        hintText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        filled: true,
                        fillColor: AppColors.lightGrey,
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      'Phone number cannot be changed',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? UIHelpers.loadingThreeBounce(
                                color: AppColors.white,
                                size: 20,
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Bold',
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
