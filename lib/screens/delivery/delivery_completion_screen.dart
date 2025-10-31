import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../tabs/bookings_tab.dart';

class DeliveryCompletionScreen extends StatefulWidget {
  final BookingData booking;

  const DeliveryCompletionScreen({
    super.key,
    required this.booking,
  });

  @override
  State<DeliveryCompletionScreen> createState() =>
      _DeliveryCompletionScreenState();
}

class _DeliveryCompletionScreenState extends State<DeliveryCompletionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _customTipController = TextEditingController();
  final TextEditingController _otherTipReasonController =
      TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];

  double _rating = 0.0;
  bool _isConfirmed = false;
  bool _isSubmitting = false;

  // Tip-related variables
  bool _wantsToTip = false;
  double? _selectedTipAmount;
  final List<String> _selectedTipReasons = [];
  bool _isCustomTip = false;

  // Predefined tip amounts
  final List<double> _tipAmounts = [20, 50, 100, 150, 200];

  // Tip reasons
  final List<Map<String, dynamic>> _tipReasons = [
    {'icon': Icons.favorite, 'label': 'Handled with care'},
    {'icon': Icons.speed, 'label': 'Fast delivery'},
    {'icon': Icons.directions, 'label': 'Good in instruction'},
    {'icon': Icons.chat_bubble, 'label': 'Responsive'},
    {'icon': Icons.star, 'label': 'Excellent service'},
    {'icon': Icons.more_horiz, 'label': 'Others'},
  ];

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reviewController.dispose();
    _customTipController.dispose();
    _otherTipReasonController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
        UIHelpers.showSuccessToast('Image added successfully');
      }
    } catch (e) {
      UIHelpers.showErrorToast('Failed to pick image: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: AppColors.primaryRed,
                  ),
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: AppColors.primaryRed,
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    if (!_isConfirmed) {
      UIHelpers.showErrorToast('Please confirm delivery receipt');
      return;
    }

    if (_rating == 0) {
      UIHelpers.showErrorToast('Please provide a rating');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Simulate API call with tip data
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      // Show success message with tip info
      String message = 'Thank you for your feedback!';
      if (_wantsToTip &&
          _selectedTipAmount != null &&
          _selectedTipAmount! > 0) {
        message =
            'Thank you for your feedback and generous tip of P${_selectedTipAmount!.toStringAsFixed(0)}!';
      }
      UIHelpers.showSuccessToast(message);

      // Log tip data (in real app, send to API)
      if (_wantsToTip && _selectedTipAmount != null) {
        debugPrint('Tip Amount: P${_selectedTipAmount}');
        debugPrint('Tip Reasons: ${_selectedTipReasons.join(", ")}');
        if (_selectedTipReasons.contains('Others') &&
            _otherTipReasonController.text.isNotEmpty) {
          debugPrint('Other Reason: ${_otherTipReasonController.text}');
        }
      }

      // Navigate back to home or bookings
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Delivery Completed',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Success Animation Header
            Container(
              width: double.infinity,
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 60,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        const Text(
                          'Delivery Completed!',
                          style: TextStyle(
                            fontSize: 24,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Booking ID: ${widget.booking.id}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Delivery Summary Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow(Icons.local_shipping, 'Vehicle',
                      widget.booking.vehicleType),
                  _buildSummaryRow(
                      Icons.person, 'Driver', widget.booking.driverName),
                  _buildSummaryRow(
                      Icons.calendar_today, 'Date', widget.booking.date),
                  _buildSummaryRow(
                      Icons.access_time, 'Time', widget.booking.time),
                  _buildSummaryRow(Icons.payments, 'Fare', widget.booking.fare),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Confirmation Checkbox
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _isConfirmed,
                    onChanged: (value) {
                      setState(() {
                        _isConfirmed = value ?? false;
                      });
                    },
                    activeColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'I confirm that I have received my delivery in good condition',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Rating Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rate Your Experience',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'How was your delivery experience?',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _rating = index + 1.0;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              size: 40,
                              color: index < _rating
                                  ? Colors.amber
                                  : AppColors.lightGrey,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  if (_rating > 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _getRatingText(_rating),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Medium',
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Review Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Write a Review (Optional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Share your experience with us...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.scaffoldBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Image Upload Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Photos (Optional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share photos of your delivery',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Grid
                  if (_selectedImages.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_selectedImages[index].path),
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                  if (_selectedImages.isNotEmpty) const SizedBox(height: 12),

                  // Add Photo Button
                  if (_selectedImages.length < 5)
                    GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryRed.withOpacity(0.3),
                            width: 1.5,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              color: AppColors.primaryRed,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add Photo (${_selectedImages.length}/5)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tip Section
            if (_rating >= 4)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism,
                            color: Colors.amber,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add a Tip (Optional)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Bold',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Show your appreciation',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Regular',
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _wantsToTip,
                          onChanged: (value) {
                            setState(() {
                              _wantsToTip = value;
                              if (!value) {
                                _selectedTipAmount = null;
                                _selectedTipReasons.clear();
                                _isCustomTip = false;
                                _customTipController.clear();
                                _otherTipReasonController.clear();
                              }
                            });
                          },
                          activeColor: AppColors.success,
                        ),
                      ],
                    ),
                    if (_wantsToTip) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Why are you tipping?',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tip Reasons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tipReasons.map((reason) {
                          final isSelected =
                              _selectedTipReasons.contains(reason['label']);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedTipReasons.remove(reason['label']);
                                  // Clear custom reason text when "Others" is deselected
                                  if (reason['label'] == 'Others') {
                                    _otherTipReasonController.clear();
                                  }
                                } else {
                                  _selectedTipReasons.add(reason['label']);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryRed.withOpacity(0.1)
                                    : AppColors.scaffoldBackground,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryRed
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    reason['icon'],
                                    size: 16,
                                    color: isSelected
                                        ? AppColors.primaryRed
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    reason['label'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'Medium',
                                      color: isSelected
                                          ? AppColors.primaryRed
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Custom Tip Reason Input (when "Others" is selected)
                      if (_selectedTipReasons.contains('Others')) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _otherTipReasonController,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText: 'Please specify your reason...',
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Regular',
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.scaffoldBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                            prefixIcon: const Icon(
                              Icons.edit,
                              color: AppColors.primaryRed,
                              size: 20,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Regular',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Text(
                        'Select tip amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tip Amount Options
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._tipAmounts.map((amount) {
                            final isSelected =
                                _selectedTipAmount == amount && !_isCustomTip;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTipAmount = amount;
                                  _isCustomTip = false;
                                  _customTipController.clear();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.success
                                      : AppColors.scaffoldBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.success
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  'P${amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Bold',
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }),

                          // Custom Amount Button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isCustomTip = true;
                                _selectedTipAmount = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _isCustomTip
                                    ? AppColors.success
                                    : AppColors.scaffoldBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isCustomTip
                                      ? AppColors.success
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Custom',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Bold',
                                  color: _isCustomTip
                                      ? AppColors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Custom Tip Input
                      if (_isCustomTip) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customTipController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter custom amount',
                            prefixText: 'P ',
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Regular',
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.scaffoldBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                          onChanged: (value) {
                            final amount = double.tryParse(value);
                            if (amount != null && amount > 0) {
                              setState(() {
                                _selectedTipAmount = amount;
                              });
                            }
                          },
                        ),
                      ],

                      // Tip Summary
                      if (_selectedTipAmount != null &&
                          _selectedTipAmount! > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: AppColors.success,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You are tipping P${_selectedTipAmount!.toStringAsFixed(0)} to ${widget.booking.driverName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Medium',
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Submit Button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.white),
                        ),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Bold',
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Skip Button
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                'Skip for now',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Medium',
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent!';
    if (rating >= 4) return 'Great!';
    if (rating >= 3) return 'Good';
    if (rating >= 2) return 'Fair';
    return 'Poor';
  }
}
