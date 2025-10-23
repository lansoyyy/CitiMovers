import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/location_model.dart';
import '../../models/vehicle_model.dart';
import '../../services/booking_service.dart';
import '../../services/maps_service.dart';

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
  String _selectedPaymentMethod = 'Gcash'; // Default payment method
  bool _isLoading = false;
  int? _travelDurationMinutes; // Store travel duration

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
    setState(() => _isLoading = true);

    final booking = await _bookingService.createBooking(
      customerId: 'customer_001', // TODO: Get from auth
      pickupLocation: widget.pickupLocation,
      dropoffLocation: widget.dropoffLocation,
      vehicle: widget.vehicle,
      bookingType: _bookingType,
      scheduledDateTime: _scheduledDateTime,
      distance: widget.distance,
      estimatedFare: _estimatedFare,
      paymentMethod: _selectedPaymentMethod,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (booking != null && mounted) {
      UIHelpers.showSuccessToast('Booking created successfully!');
      // Navigate to booking confirmation or home
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      UIHelpers.showErrorToast('Failed to create booking');
    }
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
                            color: AppColors.primaryRed.withOpacity(0.1),
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
                          color: AppColors.textHint.withOpacity(0.2),
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
                          icon: FontAwesomeIcons.g,
                          title: 'Gcash',
                          subtitle: 'Digital wallet',
                          isSelected: _selectedPaymentMethod == 'Gcash',
                          onTap: () =>
                              setState(() => _selectedPaymentMethod = 'Gcash'),
                        ),
                        const SizedBox(height: 8),
                        _PaymentOption(
                          icon: FontAwesomeIcons.m,
                          title: 'Maya',
                          subtitle: 'Digital wallet',
                          isSelected: _selectedPaymentMethod == 'Maya',
                          onTap: () =>
                              setState(() => _selectedPaymentMethod = 'Maya'),
                        ),
                        const SizedBox(height: 8),
                        _PaymentOption(
                          icon: FontAwesomeIcons.creditCard,
                          title: 'Debit Card',
                          subtitle: 'Bank debit card',
                          isSelected: _selectedPaymentMethod == 'Debit Card',
                          onTap: () => setState(
                              () => _selectedPaymentMethod = 'Debit Card'),
                        ),
                        const SizedBox(height: 8),
                        _PaymentOption(
                          icon: FontAwesomeIcons.creditCard,
                          title: 'Credit Card',
                          subtitle: 'Bank credit card',
                          isSelected: _selectedPaymentMethod == 'Credit Card',
                          onTap: () => setState(
                              () => _selectedPaymentMethod = 'Credit Card'),
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
                  color: Colors.black.withOpacity(0.05),
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
                        AppColors.textHint.withOpacity(0.3),
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
              ? AppColors.primaryRed.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryRed
                : AppColors.textHint.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryRed.withOpacity(0.2)
                    : AppColors.textHint.withOpacity(0.1),
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
