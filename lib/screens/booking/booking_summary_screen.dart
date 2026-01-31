import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/location_model.dart';
import '../../models/vehicle_model.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../services/maps_service.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_constants.dart';
import '../auth/otp_verification_screen.dart';
import '../terms_conditions_screen.dart';

class BookingSummaryScreen extends StatefulWidget {
  final LocationModel pickupLocation;
  final LocationModel dropoffLocation;
  final VehicleModel vehicle;
  final double distance;

  const BookingSummaryScreen({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.vehicle,
    required this.distance,
  });

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  final TextEditingController _notesController = TextEditingController();
  final BookingService _bookingService = BookingService();
  final MapsService _mapsService = MapsService();

  String _bookingType = 'now'; // 'now' or 'scheduled'
  DateTime? _scheduledDateTime;
  String _selectedPaymentMethod = 'Wallet'; // Default payment method
  bool _isLoading = false;
  int? _travelDurationMinutes; // Store travel duration
  bool _termsAccepted = false; // Terms & Conditions checkbox state

  double get _estimatedFare => _mapsService.calculateFare(
        distanceKm: widget.distance,
        vehicleType: widget.vehicle.name,
      );

  @override
  void initState() {
    super.initState();
    _calculateTravelTime();
  }

  Future<void> _calculateTravelTime() async {
    final routeInfo = await _mapsService.calculateRoute(
      widget.pickupLocation,
      widget.dropoffLocation,
    );
    if (routeInfo != null && mounted) {
      setState(() {
        _travelDurationMinutes = routeInfo.durationMinutes;
      });
    }
  }

  Future<void> _selectScheduledTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _scheduledDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _confirmBooking() async {
    final authService = AuthService();
    final user = authService.currentUser;

    if (user == null) {
      UIHelpers.showErrorToast('Please login to continue');
      return;
    }

    // First show Terms & Conditions
    final termsAccepted = await _showTermsAndConditions();
    if (!termsAccepted) return;

    // Then show confirmation dialog
    final confirmed = await _showBookingConfirmationDialog(user.userId);
    if (!confirmed) return;

    final walletBalance = await WalletService().getWalletBalance(user.userId);
    if (walletBalance < AppConstants.minimumCustomerWalletBalanceToBook) {
      UIHelpers.showErrorToast(
          'Minimum wallet balance required is P${AppConstants.minimumCustomerWalletBalanceToBook.toStringAsFixed(0)}');
      return;
    }

    if (walletBalance < _estimatedFare) {
      UIHelpers.showErrorToast('Insufficient wallet balance for this booking');
      return;
    }

    // Proceed with booking creation
    setState(() => _isLoading = true);

    final booking = await _bookingService.createBooking(
      customerId: user.userId,
      customerName: user.name,
      customerPhone: user.phoneNumber,
      pickupLocation: widget.pickupLocation,
      dropoffLocation: widget.dropoffLocation,
      vehicle: widget.vehicle,
      bookingType: _bookingType,
      scheduledDateTime: _scheduledDateTime,
      distance: widget.distance,
      estimatedFare: _estimatedFare,
      estimatedDurationMinutes: _travelDurationMinutes,
      paymentMethod: 'Wallet',
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (booking != null && mounted) {
      setState(() => _isLoading = true);
      final otpSent = await authService.sendOTP(user.phoneNumber);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!otpSent) {
        UIHelpers.showErrorToast('Failed to send OTP. Please try again.');
        return;
      }

      // Navigate to OTP verification first, then email verification
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerificationScreen(
            phoneNumber: user.phoneNumber,
            isSignup: false,
            isBookingFlow: true,
            booking: BookingModel(
              bookingId: booking.bookingId!,
              customerId: user.userId,
              pickupLocation: booking.pickupLocation,
              dropoffLocation: booking.dropoffLocation,
              vehicle: booking.vehicle,
              bookingType: booking.bookingType,
              distance: booking.distance,
              estimatedFare: booking.estimatedFare,
              paymentMethod: booking.paymentMethod,
              createdAt: booking.scheduledDateTime ?? DateTime.now(),
            ),
          ),
        ),
      );
    } else {
      UIHelpers.showErrorToast('Failed to create booking');
    }
  }

  Future<bool> _showTermsAndConditions() async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) => StatefulBuilder(
              builder: (context, setState) => Container(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.textHint.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Text(
                            'Terms & Conditions',
                            style: TextStyle(
                              fontSize: 20,
                              fontFamily: 'Bold',
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Important Notice',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Bold',
                                color: AppColors.primaryRed,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'CitiMovers does not offer cash on delivery. All payments must be made through our digital payment methods before the delivery is completed.',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'Key Terms:',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Bold',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTermPoint(
                                '• Pre-payment required for all bookings'),
                            _buildTermPoint(
                                '• Cancellation fees apply after 5 minutes'),
                            _buildTermPoint(
                                '• Basic insurance coverage up to ₱5,000 included'),
                            _buildTermPoint(
                                '• Prohibited items: hazardous materials, illegal substances'),
                            _buildTermPoint(
                                '• Report damages within 24 hours of delivery'),
                            _buildTermPoint(
                                '• Dispute resolution within 24 hours of incident'),

                            const SizedBox(height: 16),
                            const Text(
                              'By checking the box below, you acknowledge that you have read, understood, and agree to be bound by the complete Terms & Conditions of CitiMovers.',
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Regular',
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Checkbox
                            Row(
                              children: [
                                Checkbox(
                                  value: _termsAccepted,
                                  onChanged: (value) {
                                    setState(() {
                                      _termsAccepted = value ?? false;
                                    });
                                  },
                                  activeColor: AppColors.primaryRed,
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _termsAccepted = !_termsAccepted;
                                      });
                                    },
                                    child: const Text(
                                      'I accept the Terms & Conditions',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Medium',
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // View Full Terms Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TermsConditionsScreen(),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: AppColors.primaryRed),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'View Full Terms & Conditions',
                                  style: TextStyle(
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
                    ),

                    // Bottom Button
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _termsAccepted
                              ? () => Navigator.pop(context, true)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor:
                                AppColors.textHint.withValues(alpha: 0.3),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 17,
                              fontFamily: 'Bold',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
  }

  Widget _buildTermPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontFamily: 'Regular',
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }

  Future<bool> _showBookingConfirmationDialog(String userId) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => FutureBuilder<double>(
            future: WalletService().getWalletBalance(userId),
            builder: (context, snapshot) {
              final walletBalance = snapshot.data ?? 0.0;
              final meetsMinimum = walletBalance >=
                  AppConstants.minimumCustomerWalletBalanceToBook;
              final enoughForFare = walletBalance >= _estimatedFare;
              final canProceed =
                  snapshot.hasData && meetsMinimum && enoughForFare;

              return AlertDialog(
                title: const Text(
                  'Confirm Booking',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please review your booking details:',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildConfirmRow('Vehicle:', widget.vehicle.name),
                    _buildConfirmRow('Payment:', _selectedPaymentMethod),
                    _buildConfirmRow(
                        'Fare:', 'P${_estimatedFare.toStringAsFixed(0)}'),
                    _buildConfirmRow(
                      'Wallet:',
                      snapshot.connectionState == ConnectionState.waiting
                          ? 'Loading...'
                          : 'P${walletBalance.toStringAsFixed(2)}',
                    ),
                    if (_bookingType == 'scheduled' &&
                        _scheduledDateTime != null)
                      _buildConfirmRow('Schedule:',
                          '${_scheduledDateTime!.day}/${_scheduledDateTime!.month}/${_scheduledDateTime!.year} at ${_scheduledDateTime!.hour}:${_scheduledDateTime!.minute.toString().padLeft(2, '0')}'),
                    const SizedBox(height: 12),
                    if (snapshot.hasData && !meetsMinimum)
                      Text(
                        'Minimum wallet balance required is P${AppConstants.minimumCustomerWalletBalanceToBook.toStringAsFixed(0)}.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Medium',
                          color: AppColors.primaryRed,
                        ),
                      )
                    else if (snapshot.hasData && !enoughForFare)
                      const Text(
                        'Insufficient wallet balance for this booking.',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Medium',
                          color: AppColors.primaryRed,
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        canProceed ? () => Navigator.pop(context, true) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Proceed with Booking',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Bold',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Medium',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Medium',
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Format duration into readable text
  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}min';
  }

  // Calculate ETA based on current time + travel duration
  String _calculateETA() {
    if (_travelDurationMinutes == null) return '';

    final now = DateTime.now();
    final eta = now.add(Duration(minutes: _travelDurationMinutes!));

    final hour = eta.hour;
    final minute = eta.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Booking Summary'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking Type Selection
                  const Text(
                    'Booking Type',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BookingTypeCard(
                          icon: Icons.bolt,
                          title: 'Book Now',
                          subtitle: 'Immediate pickup',
                          isSelected: _bookingType == 'now',
                          onTap: () {
                            setState(() {
                              _bookingType = 'now';
                              _scheduledDateTime = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BookingTypeCard(
                          icon: Icons.schedule,
                          title: 'Schedule',
                          subtitle: 'Pick a time',
                          isSelected: _bookingType == 'scheduled',
                          onTap: () {
                            setState(() => _bookingType = 'scheduled');
                            if (_scheduledDateTime == null) {
                              _selectScheduledTime();
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  if (_bookingType == 'scheduled') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _scheduledDateTime != null
                                  ? '${_scheduledDateTime!.day}/${_scheduledDateTime!.month}/${_scheduledDateTime!.year} at ${_scheduledDateTime!.hour}:${_scheduledDateTime!.minute.toString().padLeft(2, '0')}'
                                  : 'Select date and time',
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _selectScheduledTime,
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Locations
                  const Text(
                    'Route',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LocationCard(
                    icon: Icons.radio_button_checked,
                    iconColor: AppColors.primaryRed,
                    title: 'Pickup',
                    address: widget.pickupLocation.address,
                  ),
                  const SizedBox(height: 8),
                  _LocationCard(
                    icon: Icons.location_on,
                    iconColor: AppColors.primaryBlue,
                    title: 'Drop-off',
                    address: widget.dropoffLocation.address,
                  ),

                  const SizedBox(height: 24),

                  // Vehicle Info
                  const Text(
                    'Vehicle',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: AppColors.primaryRed,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.vehicle.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Bold',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.vehicle.capacity,
                                style: const TextStyle(
                                  fontSize: 13,
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

                  const SizedBox(height: 24),

                  // Notes
                  const Text(
                    'Delivery Notes (Optional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add any special instructions...',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textHint.withValues(alpha: 0.2),
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
                  ),

                  const SizedBox(height: 24),

                  // Travel Time
                  const Text(
                    'Travel Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: AppColors.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estimated Travel Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Medium',
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _travelDurationMinutes != null
                                    ? _formatDuration(_travelDurationMinutes!)
                                    : 'Calculating...',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Bold',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_travelDurationMinutes != null) ...[
                          const Icon(
                            Icons.schedule,
                            color: AppColors.primaryBlue,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _calculateETA(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Medium',
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Method
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _PaymentOption(
                          icon: FontAwesomeIcons.wallet,
                          title: 'Wallet',
                          subtitle: 'Captured immediately upon booking',
                          isSelected: _selectedPaymentMethod == 'Wallet',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Fare Breakdown
                  const Text(
                    'Fare Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        if (widget.vehicle.name == '10-Wheeler Wingvan') ...[
                          _FareRow(
                            label: 'Distance ',
                            value: '(${widget.distance.toStringAsFixed(1)} km)',
                          ),
                          const SizedBox(height: 8),
                          _FareRow(
                            label: 'Calculated Fare',
                            value:
                                'P${((widget.distance * 3 / 2.5) * 60).toStringAsFixed(0)}',
                          ),
                          const SizedBox(height: 8),
                          if (_estimatedFare >= 12000) ...[
                            _FareRow(
                              label: 'Above Minimum',
                              value: 'No minimum applied',
                              valueColor: AppColors.primaryBlue,
                            ),
                          ] else ...[
                            _FareRow(
                              label: 'Minimum Rate Applied',
                              value: 'P12,000 minimum',
                              valueColor: AppColors.primaryRed,
                            ),
                          ],
                        ] else ...[
                          _FareRow(
                            label: 'Base Fare',
                            value:
                                'P${widget.vehicle.baseFare.toStringAsFixed(0)}',
                          ),
                          const SizedBox(height: 8),
                          _FareRow(
                            label: 'Distance ',
                            value: '(${widget.distance.toStringAsFixed(1)} km)',
                          ),
                          const SizedBox(height: 8),
                          _FareRow(
                            label: 'Calculated Fare',
                            value:
                                'P${(widget.distance * widget.vehicle.perKmRate).toStringAsFixed(0)}',
                          ),
                        ],
                        const Divider(height: 24),
                        _FareRow(
                          label: 'Total Fare',
                          value: 'P${_estimatedFare.toStringAsFixed(0)}',
                          isBold: true,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  AppColors.primaryRed.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: AppColors.primaryRed,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Total fare is for distance and base fare only. Additional charges for loading/unloading will be added after delivery completion.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Regular',
                                    color: AppColors.primaryRed,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confirm Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor:
                        AppColors.textHint.withValues(alpha: 0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Confirm Booking',
                          style: TextStyle(
                            fontSize: 17,
                            fontFamily: 'Bold',
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Payment Option Widget
class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryRed.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryRed
                : AppColors.textHint.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryRed.withValues(alpha: 0.2)
                    : AppColors.textHint.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primaryRed : AppColors.textHint,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Medium',
                      color: isSelected
                          ? AppColors.primaryRed
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Booking Type Card Widget
class _BookingTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _BookingTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  isSelected ? AppColors.primaryRed : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Bold',
                color:
                    isSelected ? AppColors.primaryRed : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Location Card Widget
class _LocationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String address;

  const _LocationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Medium',
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Fare Row Widget
class _FareRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _FareRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontFamily: isBold ? 'Bold' : 'Regular',
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontFamily: isBold ? 'Bold' : 'Medium',
            color: valueColor ??
                (isBold ? AppColors.primaryRed : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
