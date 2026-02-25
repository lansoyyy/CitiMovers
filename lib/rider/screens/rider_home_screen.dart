import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../utils/app_colors.dart';
import '../models/delivery_request_model.dart';
import '../services/rider_auth_service.dart';
import 'delivery/rider_delivery_progress_screen.dart';
import 'tabs/rider_home_tab.dart';
import 'tabs/rider_deliveries_tab.dart';
import 'tabs/rider_earnings_tab.dart';
import 'tabs/rider_profile_tab.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late List<Widget> _screens;
  final RiderAuthService _authService = RiderAuthService();
  final BookingService _bookingService = BookingService();

  bool _hasCheckedActiveDriverBooking = false;
  bool _isCheckingActiveDriverBooking = false;
  String? _lastResumedBookingId;
  DateTime? _lastResumeAt;

  bool _isDuplicateResume(String bookingId) {
    if (!ModalRoute.of(context)!.isCurrent) return true;
    if (_lastResumedBookingId != bookingId) return false;
    if (_lastResumeAt == null) return false;
    return DateTime.now().difference(_lastResumeAt!) <
        const Duration(seconds: 3);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _screens = [
      RiderHomeTab(tabController: _tabController),
      const RiderDeliveriesTab(),
      const RiderEarningsTab(),
      const RiderProfileTab(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndResumeActiveDelivery();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _hasCheckedActiveDriverBooking = false;
      _checkAndResumeActiveDelivery(force: true);
    }
  }

  /// Check if there is an active delivery and resume progress screen
  Future<void> _checkAndResumeActiveDelivery({bool force = false}) async {
    if (_isCheckingActiveDriverBooking) return;
    if (_hasCheckedActiveDriverBooking && !force) return;

    _hasCheckedActiveDriverBooking = true;
    _isCheckingActiveDriverBooking = true;

    try {
      final rider = await _authService.getCurrentRider();
      if (rider == null || !mounted) return;

      BookingModel? booking;

      // Fast-path: restore from saved active state if possible.
      final savedState = _authService.getActiveDeliveryState();
      final savedBookingId = savedState?['bookingId']?.toString() ?? '';
      if (savedBookingId.isNotEmpty) {
        final fromSaved = await _bookingService.getBookingById(savedBookingId);
        if (fromSaved != null &&
            fromSaved.driverId == rider.riderId &&
            _bookingService.isBookingEligibleForAutoContinue(fromSaved)) {
          booking = fromSaved;
        }
      }

      booking ??=
          await _bookingService.getMostRecentActiveDriverBooking(rider.riderId);

      if (booking == null) {
        await _authService.clearActiveDeliveryState();
        return;
      }

      await _resumeActiveDriverBooking(booking);
    } catch (e) {
      debugPrint('Error checking active delivery: $e');
    } finally {
      _isCheckingActiveDriverBooking = false;
    }
  }

  Future<void> _resumeActiveDriverBooking(BookingModel booking) async {
    final bookingId = booking.bookingId ?? '';
    if (bookingId.isEmpty || !mounted) return;
    if (_isDuplicateResume(bookingId)) return;

    _lastResumedBookingId = bookingId;
    _lastResumeAt = DateTime.now();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text(
          'Resuming your active delivery...',
          style: TextStyle(color: Colors.white),
        ),
        duration: Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final request = _bookingToDeliveryRequest(booking);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RiderDeliveryProgressScreen(request: request),
      ),
    ).then((_) {
      _hasCheckedActiveDriverBooking = false;
    });
  }

  /// Convert BookingModel into DeliveryRequest for rider progress screen.
  DeliveryRequest _bookingToDeliveryRequest(BookingModel booking) {
    final bookingId = booking.bookingId ?? '';
    final createdDate = booking.createdAt;
    final difference = DateTime.now().difference(createdDate);
    String requestTime;
    if (difference.inMinutes < 1) {
      requestTime = 'Just now';
    } else if (difference.inMinutes < 60) {
      requestTime = '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      requestTime = '${difference.inHours} hours ago';
    } else {
      requestTime = '${difference.inDays} days ago';
    }

    final customerName = booking.customerName ?? 'Unknown';
    final customerPhone = booking.customerPhone ?? 'N/A';

    final pickupLocation = booking.pickupLocation.address;
    final deliveryLocation = booking.dropoffLocation.address;

    final distance = booking.distance;
    final estimatedDuration = (booking.estimatedDuration ?? 0).toDouble();
    final fare = ((booking.finalFare ?? 0) > 0)
        ? booking.finalFare!
        : booking.estimatedFare;

    final vehicleType = booking.vehicle.type;
    final vehicleCapacity = booking.vehicle.capacity;
    final packageType = vehicleType.isNotEmpty ? vehicleType : 'Standard';
    final weight = vehicleCapacity.isNotEmpty ? vehicleCapacity : 'N/A';
    final specialInstructions = booking.notes ?? 'None';
    const urgency = 'Normal';

    return DeliveryRequest(
      id: bookingId,
      customerName: customerName,
      customerPhone: customerPhone,
      pickupLocation: pickupLocation,
      deliveryLocation: deliveryLocation,
      distance: '${distance.toStringAsFixed(1)} km',
      estimatedTime: '${estimatedDuration.toStringAsFixed(0)} mins',
      fare: 'P${fare.toStringAsFixed(0)}',
      packageType: packageType,
      weight: weight,
      urgency: urgency,
      specialInstructions: specialInstructions,
      requestTime: requestTime,
    );
  }

  @override
  void deactivate() {
    _hasCheckedActiveDriverBooking = false;
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          onTap: (index) {
            _tabController.animateTo(index);
          },
          indicatorColor: Colors.transparent,
          labelColor: AppColors.primaryRed,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontFamily: 'Medium',
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Regular',
            fontSize: 12,
          ),
          tabs: const [
            Tab(
              icon: Icon(FontAwesomeIcons.house),
              text: 'Home',
            ),
            Tab(
              icon: Icon(FontAwesomeIcons.truck),
              text: 'Deliveries',
            ),
            Tab(
              icon: Icon(FontAwesomeIcons.moneyBill),
              text: 'Earnings',
            ),
            Tab(
              icon: Icon(FontAwesomeIcons.user),
              text: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
