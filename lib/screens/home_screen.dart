import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/app_colors.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../services/booking_status_service.dart';
import '../models/booking_model.dart';
import 'delivery/delivery_tracking_screen.dart';
import 'profile/profile_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/bookings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final BookingService _bookingService = BookingService();

  bool _hasCheckedActiveBooking = false;
  bool _isCheckingActiveBooking = false;
  String? _lastResumedBookingId;
  DateTime? _lastResumeAt;

  bool _isDuplicateResume(String bookingId) {
    if (_lastResumedBookingId != bookingId) return false;
    if (_lastResumeAt == null) return false;
    return DateTime.now().difference(_lastResumeAt!) <
        const Duration(seconds: 3);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndResumeActiveBooking();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _hasCheckedActiveBooking = false;
      _checkAndResumeActiveBooking(force: true);
    }
  }

  /// Check if there is an active/pending booking and resume tracking.
  Future<void> _checkAndResumeActiveBooking({bool force = false}) async {
    if (_isCheckingActiveBooking) return;
    if (_hasCheckedActiveBooking && !force) return;

    _isCheckingActiveBooking = true;
    _hasCheckedActiveBooking = true;

    try {
      final user = await _authService.getCurrentUser();
      if (user == null || !mounted) return;

      BookingModel? bookingToResume;

      // Fast-path: restore from saved active state if possible.
      final savedState = _authService.getActiveBookingState();
      final savedBookingId = savedState?['bookingId']?.toString() ?? '';
      if (savedBookingId.isNotEmpty) {
        final fromSaved = await _bookingService.getBookingById(savedBookingId);
        if (fromSaved != null &&
            fromSaved.customerId == user.userId &&
            _bookingService.isBookingEligibleForAutoContinue(fromSaved)) {
          bookingToResume = fromSaved;
        } else {
          await _authService.clearActiveBookingState();
        }
      }

      if (bookingToResume != null) {
        final normalized =
            BookingStatusService.normalizeStatus(bookingToResume.status);
        final message = BookingStatusService.isPending(normalized)
            ? 'Resuming your booking search...'
            : 'Resuming your active delivery...';
        await _resumeBooking(bookingToResume, message: message);
        return;
      }

      final activeBooking =
          await _bookingService.getMostRecentActiveUserBooking(user.userId);
      if (activeBooking != null) {
        await _resumeBooking(activeBooking,
            message: 'Resuming your active delivery...');
        return;
      }

      final pendingBooking =
          await _bookingService.getMostRecentPendingUserBooking(user.userId);
      if (pendingBooking != null) {
        await _resumeBooking(pendingBooking,
            message: 'Resuming your booking search...');
        return;
      }

      await _authService.clearActiveBookingState();
    } catch (e) {
      debugPrint('Error checking active booking: $e');
    } finally {
      _isCheckingActiveBooking = false;
    }
  }

  Future<void> _resumeBooking(BookingModel booking,
      {required String message}) async {
    final bookingId = booking.bookingId;
    if (bookingId == null || bookingId.isEmpty) return;
    if (_isDuplicateResume(bookingId) || !mounted) return;

    _lastResumedBookingId = bookingId;
    _lastResumeAt = DateTime.now();

    await _authService.saveActiveBookingState(
      bookingId: bookingId,
      status: booking.status,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryTrackingScreen(booking: booking),
      ),
    ).then((_) {
      _hasCheckedActiveBooking = false;
    });
  }

  @override
  void deactivate() {
    _hasCheckedActiveBooking = false;
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  final List<Widget> _screens = [
    const HomeTab(),
    const BookingsTab(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: _screens,
          ),
          if (_isCheckingActiveBooking)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
      bottomNavigationBar: TabBar(
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
            icon: Icon(FontAwesomeIcons.rectangleList),
            text: 'Bookings',
          ),
          Tab(
            icon: Icon(FontAwesomeIcons.user),
            text: 'Profile',
          ),
        ],
      ),
    );
  }
}
