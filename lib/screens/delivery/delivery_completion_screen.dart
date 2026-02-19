import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../services/auth_service.dart';
import '../../services/driver_service.dart';

class DeliveryCompletionScreen extends StatefulWidget {
  final BookingModel booking;
  final double loadingDemurrage;
  final double unloadingDemurrage;

  const DeliveryCompletionScreen({
    super.key,
    required this.booking,
    required this.loadingDemurrage,
    required this.unloadingDemurrage,
  });

  @override
  State<DeliveryCompletionScreen> createState() =>
      _DeliveryCompletionScreenState();
}

class _DeliveryCompletionScreenState extends State<DeliveryCompletionScreen>
    with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final AuthService _authService = AuthService();
  final DriverService _driverService = DriverService.instance;

  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _customTipController = TextEditingController();
  final TextEditingController _otherTipReasonController =
      TextEditingController();

  double _rating = 0.0;
  bool _isSubmitting = false;
  String? _driverName;
  Map<String, dynamic>? _deliveryPhotos;

  // Picklist items
  List<Map<String, dynamic>> _picklistItems = [];

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

  double get _totalFare {
    final finalFare = widget.booking.finalFare;
    if (finalFare != null && finalFare > 0) return finalFare;
    return widget.booking.estimatedFare;
  }

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

    // Fetch driver name, delivery photos, and picklist
    _fetchDriverName();
    _fetchDeliveryPhotos();
    _fetchPicklistItems();
  }

  Future<void> _fetchPicklistItems() async {
    try {
      final bookingId = widget.booking.bookingId;
      if (bookingId == null || bookingId.isEmpty) {
        setState(() {
          _picklistItems = _parsePicklistItems(widget.booking.picklistItems);
        });
        return;
      }

      final bookingData = await _bookingService.getBookingById(bookingId);
      setState(() {
        _picklistItems = _parsePicklistItems(
          bookingData?.picklistItems ?? widget.booking.picklistItems,
        );
      });
    } catch (e) {
      debugPrint('Error fetching picklist items: $e');
      setState(() {
        _picklistItems = _parsePicklistItems(widget.booking.picklistItems);
      });
    }
  }

  Future<void> _fetchDriverName() async {
    if (widget.booking.driverId != null) {
      final driver =
          await _driverService.getDriverById(widget.booking.driverId!);
      if (driver != null) {
        setState(() {
          _driverName = driver.name;
        });
      }
    }
  }

  Future<void> _fetchDeliveryPhotos() async {
    try {
      final bookingId = widget.booking.bookingId;
      if (bookingId == null || bookingId.isEmpty) {
        setState(() {
          _deliveryPhotos = _normalizePhotosMap(widget.booking.deliveryPhotos);
        });
        return;
      }

      final bookingData = await _bookingService.getBookingById(bookingId);
      setState(() {
        _deliveryPhotos = _normalizePhotosMap(
          bookingData?.deliveryPhotos ?? widget.booking.deliveryPhotos,
        );
      });
    } catch (e) {
      debugPrint('Error fetching delivery photos: $e');
      setState(() {
        _deliveryPhotos = _normalizePhotosMap(widget.booking.deliveryPhotos);
      });
    }
  }

  List<Map<String, dynamic>> _parsePicklistItems(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic>? _normalizePhotosMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  String _extractDeliveryValueAsString(dynamic value) {
    if (value is String) return value.trim();
    if (value is Map) {
      final url = value['url'];
      if (url is String && url.trim().isNotEmpty) return url.trim();
      final text = value['value'] ?? value['text'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
    }
    return '';
  }

  String? _firstNonEmptyPhotoUrl(List<String> keys) {
    for (final key in keys) {
      final url = _extractDeliveryValueAsString(_deliveryPhotos?[key]);
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
    }
    return null;
  }

  String _getMetadataText(String key) {
    final value = _extractDeliveryValueAsString(_deliveryPhotos?[key]);
    return value;
  }

  String? _getPhotoUrl(String key) {
    switch (key) {
      case 'start_loading':
        return _firstNonEmptyPhotoUrl(['start_loading', 'start_loading_photo']);
      case 'finish_loading':
        return _firstNonEmptyPhotoUrl(
            ['finish_loading', 'finished_loading', 'finish_loading_photo']);
      case 'start_unloading':
        return _firstNonEmptyPhotoUrl(
            ['start_unloading', 'start_unloading_photo']);
      case 'finish_unloading':
        return _firstNonEmptyPhotoUrl([
          'finish_unloading',
          'finished_unloading',
          'finish_unloading_photo'
        ]);
      case 'destination_arrival':
        return _firstNonEmptyPhotoUrl(
            ['destination_arrival', 'dropoff_arrival']);
      case 'receiver_id':
        return _firstNonEmptyPhotoUrl(['receiver_id', 'receiver_id_photo']);
      case 'receiver_signature':
        return _firstNonEmptyPhotoUrl(['receiver_signature', 'signature']);
      case 'damage_photo':
        return _firstNonEmptyPhotoUrl(
            ['damage_photo', 'damaged_boxes', 'empty_truck']);
      case 'service_invoice':
        final photos = _deliveryPhotos;
        if (photos == null) return null;
        final invoiceEntries = photos.entries
            .where((entry) => entry.key.startsWith('service_invoice_'))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final entry in invoiceEntries) {
          final url = _extractDeliveryValueAsString(entry.value);
          if (url.startsWith('http://') || url.startsWith('https://')) {
            return url;
          }
        }
        return _firstNonEmptyPhotoUrl(['service_invoice']);
      default:
        return _firstNonEmptyPhotoUrl([key]);
    }
  }

  void _viewSignatureFullScreen(String? imageUrl, String title) {
    if (imageUrl == null || imageUrl.isEmpty) {
      debugPrint('_viewSignatureFullScreen: No image URL provided');
      return;
    }

    debugPrint(
        '_viewSignatureFullScreen: Viewing signature with URL: $imageUrl');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor:
              Colors.white, // WHITE background for signature visibility
          appBar: AppBar(
            backgroundColor: AppColors.white,
            title: Text(title),
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppColors.primaryRed,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading signature image: $error');
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.primaryRed, size: 50),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load signature',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'URL: ${imageUrl.substring(0, imageUrl.length > 50 ? 50 : imageUrl.length)}...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewImageFullScreen(String? imageUrl, String title) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(title),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 50),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reviewController.dispose();
    _customTipController.dispose();
    _otherTipReasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      UIHelpers.showErrorToast('Please provide a rating');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Get current user
    final user = _authService.currentUser;
    if (user == null) {
      UIHelpers.showErrorToast('Please login to submit review');
      setState(() => _isSubmitting = false);
      return;
    }

    final bookingId = widget.booking.bookingId;
    final riderId = widget.booking.driverId;
    if (bookingId == null ||
        bookingId.isEmpty ||
        riderId == null ||
        riderId.isEmpty) {
      UIHelpers.showErrorToast(
          'Missing booking or rider details. Please try again.');
      setState(() => _isSubmitting = false);
      return;
    }

    // Submit review to Firebase
    final success = await _bookingService.submitReview(
      bookingId: bookingId,
      customerId: user.userId,
      riderId: riderId,
      rating: _rating,
      review: _reviewController.text.trim().isEmpty
          ? null
          : _reviewController.text.trim(),
      tipAmount: _wantsToTip ? _selectedTipAmount : null,
      tipReasons: _selectedTipReasons.isNotEmpty ? _selectedTipReasons : null,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        // Show success message with tip info
        String message = 'Thank you for your feedback!';
        if (_wantsToTip &&
            _selectedTipAmount != null &&
            _selectedTipAmount! > 0) {
          message =
              'Thank you for your feedback and generous tip of P${_selectedTipAmount!.toStringAsFixed(0)}!';
        }
        UIHelpers.showSuccessToast(message);

        // Navigate back to home or bookings
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        UIHelpers.showErrorToast('Failed to submit review. Please try again.');
      }
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
                          'Booking ID: ${widget.booking.bookingId}',
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
                      widget.booking.vehicle.name),
                  _buildSummaryRow(
                      Icons.person, 'Driver', _driverName ?? 'Loading...'),
                  if (widget.booking.receiverName != null &&
                      widget.booking.receiverName!.isNotEmpty)
                    _buildSummaryRow(Icons.verified_user, 'Receiver',
                        widget.booking.receiverName!),
                  _buildSummaryRow(Icons.calendar_today, 'Date',
                      '${widget.booking.createdAt.day}/${widget.booking.createdAt.month}/${widget.booking.createdAt.year}'),
                  _buildSummaryRow(Icons.access_time, 'Time',
                      '${widget.booking.createdAt.hour}:${widget.booking.createdAt.minute.toString().padLeft(2, '0')}'),
                  _buildSummaryRow(Icons.route, 'Distance',
                      '${widget.booking.distance.toStringAsFixed(0)} KM'),
                  _buildSummaryRow(Icons.payments, 'Total Fare',
                      'P${_totalFare.toStringAsFixed(2)}'),
                ],
              ),
            ),

            const SizedBox(height: 16),

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
                    'Trip Amount Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAmountRow('Distance',
                      '${widget.booking.distance.toStringAsFixed(0)} KM'),
                  _buildAmountRow(
                    'Total Fare',
                    'P${_totalFare.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

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
                    'Proof of Delivery',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Arrival Photos',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Medium',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProofImageBox(
                            'Arrived at Warehouse', 'warehouse_arrival'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildProofImageBox(
                            'Arrived at Dropoff', 'destination_arrival'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading Photos',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Medium',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProofImageBox(
                            'Start Loading', 'start_loading'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildProofImageBox(
                            'Finished Loading', 'finish_loading'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unloading Photos',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Medium',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProofImageBox(
                            'Start Unloading', 'start_unloading'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildProofImageBox(
                            'Finished Unloading', 'finish_unloading'),
                      ),
                    ],
                  ),
                  // Damage Report Section
                  if (_deliveryPhotos?['has_damage'] == true ||
                      _deliveryPhotos?['damaged_items'] != null ||
                      _getPhotoUrl('damage_photo') != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Damage Report',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _deliveryPhotos?['has_damage'] == true
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_outline,
                                color: _deliveryPhotos?['has_damage'] == true
                                    ? AppColors.primaryRed
                                    : AppColors.success,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _deliveryPhotos?['has_damage'] == true
                                    ? 'Damaged Items Reported'
                                    : 'No Damage Reported',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Medium',
                                  color: _deliveryPhotos?['has_damage'] == true
                                      ? AppColors.primaryRed
                                      : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          if (_deliveryPhotos?['damaged_items'] != null) ...[
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text(
                              'DAMAGED ITEMS',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Bold',
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...(() {
                              final damagedItems =
                                  _deliveryPhotos?['damaged_items'];
                              if (damagedItems is List) {
                                return damagedItems.map<Widget>((item) {
                                  final name =
                                      (item is Map ? (item['item'] ?? '') : '')
                                          .toString();
                                  final qty = (item is Map
                                          ? (item['quantity'] ?? '')
                                          : '')
                                      .toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(name,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                        Text(qty,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontFamily: 'Medium')),
                                      ],
                                    ),
                                  );
                                }).toList();
                              }
                              return [];
                            })(),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primaryRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total',
                                      style: TextStyle(
                                          fontSize: 13, fontFamily: 'Bold')),
                                  Text(
                                    '${() {
                                      final damagedItems =
                                          _deliveryPhotos?['damaged_items'];
                                      if (damagedItems is List) {
                                        return damagedItems.fold(0,
                                            (sum, item) {
                                          if (item is Map) {
                                            return sum +
                                                (int.tryParse(item['quantity']
                                                            ?.toString() ??
                                                        '0') ??
                                                    0);
                                          }
                                          return sum;
                                        });
                                      }
                                      return 0;
                                    }()}',
                                    style: const TextStyle(
                                        fontSize: 13, fontFamily: 'Bold'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Multiple Damage Photos
                    if (_deliveryPhotos?['damage_photos'] is List) ...[
                      Builder(
                        builder: (context) {
                          final damagePhotos =
                              _deliveryPhotos?['damage_photos'] as List;
                          if (damagePhotos.isEmpty) {
                            return _buildProofImageBox(
                              _deliveryPhotos?['has_damage'] == true
                                  ? 'Photo of Damaged Boxes'
                                  : 'Photo of Empty Truck',
                              'damage_photo',
                            );
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                List.generate(damagePhotos.length, (index) {
                              final url = damagePhotos[index]?.toString() ?? '';
                              if (url.isEmpty) return const SizedBox.shrink();
                              return GestureDetector(
                                onTap: () => _viewImageFullScreen(
                                  url,
                                  '${_deliveryPhotos?['has_damage'] == true ? 'Damaged Boxes' : 'Empty Truck'} Photo ${index + 1}',
                                ),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: AppColors.scaffoldBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: AppColors.lightGrey),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primaryRed,
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: AppColors.scaffoldBackground,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: AppColors.textHint,
                                            size: 32,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ] else
                      _buildProofImageBox(
                        _deliveryPhotos?['has_damage'] == true
                            ? 'Photo of Damaged Boxes'
                            : 'Photo of Empty Truck',
                        'damage_photo',
                      ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Receiver ID Photo',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Medium',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProofImageBox('Receiver ID', 'receiver_id'),
                  const SizedBox(height: 16),
                  const Text(
                    'Service Invoice',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Medium',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProofImageBox('Invoice Copy', 'service_invoice'),
                  const SizedBox(height: 16),
                  const Text(
                    'Receiver Signature',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Medium',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSignaturePlaceholderBox(),
                  // Picklist Section
                  if (_picklistItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Picklist Items',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPicklistSection(),
                  ],
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
                                  'You are tipping P${_selectedTipAmount!.toStringAsFixed(0)} to Driver',
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

  Widget _buildAmountRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontFamily: isTotal ? 'Medium' : 'Regular',
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontFamily: 'Bold',
              color: isTotal ? AppColors.primaryRed : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofImageBox(String title, String photoKey) {
    final imageUrl = _getPhotoUrl(photoKey);
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: hasImage ? () => _viewImageFullScreen(imageUrl, title) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? AppColors.success : AppColors.lightGrey,
            width: hasImage ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: hasImage ? Colors.transparent : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: hasImage
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !hasImage
                  ? const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: AppColors.textHint,
                        size: 28,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Medium',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasImage ? 'Tap to view' : 'No image available',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Regular',
                color: hasImage ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignaturePlaceholderBox() {
    final imageUrl =
        _firstNonEmptyPhotoUrl(['receiver_signature', 'signature']);
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    debugPrint(
        '_buildSignaturePlaceholderBox: imageUrl=$imageUrl, hasImage=$hasImage');
    debugPrint(
        '_buildSignaturePlaceholderBox: _deliveryPhotos=$_deliveryPhotos');

    // Get the timestamp from delivery photos
    final timestampStr =
        _getMetadataText('receiver_signature_timestamp').isNotEmpty
            ? _getMetadataText('receiver_signature_timestamp')
            : _getMetadataText('received_at_pht');

    // Format timestamp if available
    String formattedTimestamp = '';
    if (timestampStr.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(timestampStr);
        formattedTimestamp =
            '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        formattedTimestamp = timestampStr;
      }
    }

    return GestureDetector(
      onTap: hasImage
          ? () => _viewSignatureFullScreen(imageUrl, 'Receiver Signature')
          : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white, // WHITE background for visibility
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? AppColors.success : AppColors.lightGrey,
            width: hasImage ? 2 : 1,
          ),
          boxShadow: hasImage
              ? [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: hasImage ? AppColors.white : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                image: hasImage
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.contain,
                      )
                    : null,
              ),
              child: !hasImage
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.border_color,
                            color: AppColors.textHint,
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No signature captured',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  hasImage ? Icons.check_circle : Icons.pending,
                  size: 14,
                  color: hasImage ? AppColors.success : AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  'Signature',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Medium',
                    color:
                        hasImage ? AppColors.textPrimary : AppColors.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              hasImage
                  ? 'Tap to view full signature'
                  : 'Signature not available',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Regular',
                color: hasImage ? AppColors.success : AppColors.textSecondary,
              ),
            ),
            if (hasImage && formattedTimestamp.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Received: $formattedTimestamp',
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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

  Widget _buildPicklistSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _picklistItems.map((item) {
          final itemName = (item['item'] ?? '').toString();
          final qty = (item['quantity'] ?? '').toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Medium',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Qty: $qty',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Bold',
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
