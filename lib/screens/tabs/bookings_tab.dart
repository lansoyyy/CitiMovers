import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/booking_status_service.dart';
import '../../services/driver_service.dart';
import '../../models/booking_model.dart';
import '../../models/driver_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../delivery/delivery_tracking_screen.dart';
import '../booking/cancel_booking_dialog.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  final _bookingService = BookingService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // Tab changed - StreamBuilder will handle badge updates
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryRed,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryRed,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: 'Medium',
            fontSize: 16,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Regular',
            fontSize: 16,
          ),
          tabs: [
            Tab(
              child: StreamBuilder<List<BookingModel>>(
                stream: _authService.currentUser != null
                    ? _bookingService
                        .getCustomerBookings(_authService.currentUser!.userId)
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  final activeCount = snapshot.hasData
                      ? _filterBookingsByStatus(snapshot.data!, 'active').length
                      : 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Active'),
                      if (activeCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            activeCount > 9 ? '9+' : '$activeCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'Bold',
                              color: AppColors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Tab(text: 'Completed'),
            const Tab(text: 'Cancelled'),
            const Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList('active'),
          _buildBookingsList('completed'),
          _buildBookingsList('cancelled'),
          _buildBookingsList('all'),
        ],
      ),
    );
  }

  Widget _buildBookingsList(String status) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Please login to view bookings',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Regular',
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return StreamBuilder<List<BookingModel>>(
      stream: _bookingService.getCustomerBookings(user.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: UIHelpers.loadingIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading bookings',
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final bookings = snapshot.data ?? [];
        final filteredBookings = _filterBookingsByStatus(bookings, status);
        final listBookings = status == 'active' && filteredBookings.length > 3
            ? filteredBookings.skip(3).toList()
            : status == 'active'
                ? const <BookingModel>[]
                : filteredBookings;

        if (filteredBookings.isEmpty) {
          return _buildEmptyState(status);
        }

        return Column(
          children: [
            // Active Bookings Section (prominent display at top)
            if (status == 'active' && filteredBookings.isNotEmpty)
              _buildActiveBookingsSection(filteredBookings),
            // Bookings List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: listBookings.length,
                itemBuilder: (context, index) {
                  final booking = listBookings[index];
                  return _bookingCard(booking);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build prominent active bookings section at top of active tab
  Widget _buildActiveBookingsSection(List<BookingModel> bookings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryRed.withOpacity(0.05),
            AppColors.primaryRed.withOpacity(0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_shipping,
                      size: 18,
                      color: AppColors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${bookings.length} Active',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Bold',
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tap on any booking to continue tracking',
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Show up to 3 most recent active bookings
          ...bookings
              .take(3)
              .map((booking) => _buildActiveBookingCard(booking)),
        ],
      ),
    );
  }

  /// Build compact active booking card for the prominent section
  Widget _buildActiveBookingCard(BookingModel booking) {
    final statusColor = _getStatusColor(booking.status);
    final statusText = _getStatusText(booking.status);
    final canCancel = BookingStatusService.canBeCancelled(booking.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tappable card body — navigates to tracking screen
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: InkWell(
              borderRadius: canCancel
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DeliveryTrackingScreen(booking: booking),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Medium',
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  booking.bookingId ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Medium',
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            booking.pickupLocation.address,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Medium',
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: AppColors.textHint,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  booking.dropoffLocation.address,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Medium',
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.textHint,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Cancel button — only shown for cancellable statuses (pending / accepted)
          if (canCancel) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            Material(
              color: Colors.transparent,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: InkWell(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
                onTap: () async {
                  await showCancelBookingDialog(context, booking);
                  // The booking stream auto-refreshes; no manual setState needed.
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        size: 15,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Cancel Booking',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Medium',
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final normalized = BookingStatusService.normalizeStatus(status);
    if (BookingStatusService.isPending(normalized)) {
      return AppColors.warning;
    }
    if (BookingStatusService.isActive(normalized)) {
      return AppColors.primaryBlue;
    }
    if (BookingStatusService.isCompleted(normalized)) {
      return AppColors.success;
    }
    if (BookingStatusService.isCancelled(normalized)) {
      return AppColors.error;
    }
    return AppColors.textSecondary;
  }

  String _getStatusText(String status) {
    return BookingStatusService.getStatusDisplayText(
      BookingStatusService.normalizeStatus(status),
    );
  }

  Widget _buildEmptyState(String status) {
    String title;
    String subtitle;
    IconData icon;

    switch (status) {
      case 'active':
        title = 'No active bookings';
        subtitle = 'You don\'t have any active deliveries';
        icon = Icons.local_shipping_outlined;
        break;
      case 'completed':
        title = 'No completed bookings';
        subtitle = 'You haven\'t completed any deliveries yet';
        icon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        title = 'No cancelled bookings';
        subtitle = 'You don\'t have any cancelled deliveries';
        icon = Icons.cancel_outlined;
        break;
      case 'all':
        title = 'No bookings yet';
        subtitle = 'Your bookings will appear here once created';
        icon = Icons.inventory_2_outlined;
        break;
      default:
        title = 'No bookings';
        subtitle = 'No bookings found';
        icon = Icons.inbox_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'Bold',
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (status == 'active')
            ElevatedButton(
              onPressed: () {
                UIHelpers.showInfoToast('Navigate to booking screen');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: AppColors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Book a Delivery',
                style: TextStyle(
                  fontFamily: 'Medium',
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper methods for Firebase integration
  List<BookingModel> _filterBookingsByStatus(
      List<BookingModel> bookings, String status) {
    return bookings.where((booking) {
      final normalized = BookingStatusService.normalizeStatus(booking.status);
      switch (status) {
        case 'active':
          return BookingStatusService.isPending(normalized) ||
              BookingStatusService.isActive(normalized);
        case 'completed':
          return BookingStatusService.isCompleted(normalized);
        case 'cancelled':
          return BookingStatusService.isCancelled(normalized);
        case 'all':
          return true;
        default:
          return true;
      }
    }).toList();
  }

  Widget _bookingCard(BookingModel booking) {
    return BookingCard(
      booking: booking,
      onTap: () {
        _showBookingDetailsBottomSheet(context, booking);
      },
    );
  }

  void _showBookingDetailsBottomSheet(
      BuildContext context, BookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingDetailsBottomSheet(booking: booking),
    );
  }
}

class BookingCard extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onTap;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
  });

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  final DriverService _driverService = DriverService.instance;
  DriverModel? _driver;

  @override
  void initState() {
    super.initState();
    if (widget.booking.driverId != null) {
      _fetchDriverData();
    }
  }

  Future<void> _fetchDriverData() async {
    final driver = await _driverService.getDriverById(widget.booking.driverId!);
    if (mounted) {
      setState(() {
        _driver = driver;
      });
    }
  }

  // Helper methods to get booking information
  String getVehicleType() {
    return widget.booking.vehicle.type;
  }

  String getBookingId() {
    return widget.booking.bookingId ?? 'Unknown';
  }

  String getDriverName() {
    return _driver?.name ?? 'Driver';
  }

  double getDriverRating() {
    return _driver?.rating ?? 0.0;
  }

  String getFromLocation() {
    return widget.booking.pickupLocation.address;
  }

  String getToLocation() {
    return widget.booking.dropoffLocation.address;
  }

  String getFormattedDate() {
    return '${widget.booking.createdAt.day}/${widget.booking.createdAt.month}/${widget.booking.createdAt.year}';
  }

  String getFormattedTime() {
    return '${widget.booking.createdAt.hour}:${widget.booking.createdAt.minute.toString().padLeft(2, '0')}';
  }

  String getFare() {
    final base =
        (widget.booking.finalFare != null && widget.booking.finalFare! > 0)
            ? widget.booking.finalFare!
            : widget.booking.estimatedFare;
    final loading = widget.booking.loadingDemurrageFee ?? 0.0;
    final unloading = widget.booking.unloadingDemurrageFee ?? 0.0;
    final total = base + loading + unloading;
    return 'P${total.toStringAsFixed(2)}';
  }

  Color getStatusColor() {
    final normalized =
        BookingStatusService.normalizeStatus(widget.booking.status);
    if (BookingStatusService.isPending(normalized)) {
      return AppColors.warning;
    }
    if (BookingStatusService.isActive(normalized)) {
      return AppColors.primaryBlue;
    }
    if (BookingStatusService.isCompleted(normalized)) {
      return AppColors.success;
    }
    if (BookingStatusService.isCancelled(normalized)) {
      return AppColors.error;
    }
    return AppColors.textSecondary;
  }

  String getStatusText() {
    return BookingStatusService.getStatusDisplayText(
      BookingStatusService.normalizeStatus(widget.booking.status),
    );
  }

  void _showReviewDetails() {
    // For now, just show a simple dialog with review info
    // This can be enhanced to navigate to a full review detail screen later
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.booking.rating != null) ...[
              Row(
                children: [
                  const Text('Rating: '),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.booking.rating!.toInt(),
                      (index) =>
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (widget.booking.tipAmount != null &&
                widget.booking.tipAmount! > 0) ...[
              Row(
                children: [
                  const Icon(FontAwesomeIcons.handHoldingDollar,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('Tip: ₱${widget.booking.tipAmount!.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
                'Date: ${widget.booking.reviewedAt != null ? _formatReviewDate(widget.booking.reviewedAt!) : 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatReviewDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(widget.booking.bookingId),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with vehicle type, ID and status
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryRed,
                                  AppColors.primaryRed.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryRed.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_shipping,
                              color: AppColors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                getVehicleType(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Bold',
                                  color: AppColors.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${getBookingId()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Medium',
                                  color: AppColors.textSecondary,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: getStatusColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: getStatusColor().withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          getStatusText(),
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Medium',
                            color: getStatusColor(),
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Date and Time Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getFormattedDate(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Medium',
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          getFormattedTime(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Driver Info (simplified for card view)
                if (widget.booking.driverId != null)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              getDriverName(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  getDriverRating() > 0
                                      ? '${getDriverRating().toStringAsFixed(1)} rating'
                                      : 'New Driver',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Regular',
                                    color: AppColors.textSecondary,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                if (widget.booking.driverId != null) const SizedBox(height: 20),

                // Simplified Route
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.lightGrey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'From',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Medium',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              getFromLocation(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: AppColors.textHint,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'To',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Medium',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              getToLocation(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Footer with fare and quick action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        getFare(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.primaryRed,
                          height: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Medium',
                              color: AppColors.textSecondary,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Review & Tip Status
                if (widget.booking.reviewId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryRed.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.rate_review,
                          color: AppColors.primaryRed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.booking.rating != null
                                    ? 'You rated this delivery ${widget.booking.rating!.toStringAsFixed(1)} stars'
                                    : 'You reviewed this delivery',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Medium',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (widget.booking.tipAmount != null &&
                                  widget.booking.tipAmount! > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      FontAwesomeIcons.handHoldingDollar,
                                      color: AppColors.success,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tip: ₱${widget.booking.tipAmount!.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Bold',
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showReviewDetails(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Medium',
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Booking Details Bottom Sheet
class BookingDetailsBottomSheet extends StatefulWidget {
  final BookingModel booking;

  const BookingDetailsBottomSheet({
    super.key,
    required this.booking,
  });

  @override
  State<BookingDetailsBottomSheet> createState() =>
      _BookingDetailsBottomSheetState();
}

class _BookingDetailsBottomSheetState extends State<BookingDetailsBottomSheet> {
  final DriverService _driverService = DriverService.instance;
  DriverModel? _driver;

  @override
  void initState() {
    super.initState();
    if (widget.booking.driverId != null) {
      _fetchDriverData();
    }
  }

  Future<void> _fetchDriverData() async {
    final driver = await _driverService.getDriverById(widget.booking.driverId!);
    if (mounted) {
      setState(() {
        _driver = driver;
      });
    }
  }

  // Helper methods for BookingDetailsBottomSheet
  String getVehicleType() {
    return widget.booking.vehicle.type;
  }

  String getBookingId() {
    return widget.booking.bookingId ?? 'Unknown';
  }

  String getStatusText() {
    switch (widget.booking.status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Driver Assigned';
      case 'in_progress':
        return 'In Transit';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color getStatusColor() {
    switch (widget.booking.status) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.primaryBlue;
      case 'in_progress':
        return AppColors.primaryBlue;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String getFormattedDate() {
    return '${widget.booking.createdAt.day}/${widget.booking.createdAt.month}/${widget.booking.createdAt.year}';
  }

  String getFormattedTime() {
    return '${widget.booking.createdAt.hour}:${widget.booking.createdAt.minute.toString().padLeft(2, '0')}';
  }

  String getDriverName() {
    return _driver?.name ?? 'Driver';
  }

  double getDriverRating() {
    return _driver?.rating ?? 0.0;
  }

  String getDriverContact() {
    return _driver?.phoneNumber ?? 'N/A';
  }

  String getVehicleNumber() {
    return _driver?.vehiclePlateNumber ?? 'N/A';
  }

  String getFromLocation() {
    return widget.booking.pickupLocation.address;
  }

  String getToLocation() {
    return widget.booking.dropoffLocation.address;
  }

  String getFare() {
    final base =
        (widget.booking.finalFare != null && widget.booking.finalFare! > 0)
            ? widget.booking.finalFare!
            : widget.booking.estimatedFare;
    final loading = widget.booking.loadingDemurrageFee ?? 0.0;
    final unloading = widget.booking.unloadingDemurrageFee ?? 0.0;
    final total = base + loading + unloading;
    return 'P${total.toStringAsFixed(2)}';
  }

  String getPaymentMethod() {
    // Get payment method from booking data
    return widget.booking.paymentMethod;
  }

  String getPackageType() {
    // Package type based on vehicle type
    switch (widget.booking.vehicle.type) {
      case 'Motorcycle':
        return 'Small Package';
      case 'Sedan':
        return 'Standard Package';
      case 'AUV':
        return 'Medium Package';
      case '4-Wheeler Closed Van':
      case '4-Wheeler': // legacy
        return 'Large Package';
      case '6-Wheeler Closed Van':
      case '6-Wheeler': // legacy
        return 'Extra Large Package';
      case '6-Wheeler Forward Wingvan':
      case 'Wingvan': // legacy
        return 'Heavy Package';
      case '10-Wheeler Wingvan':
        return 'Industrial Package';
      case '20-Footer Trailer':
      case '40-Footer Trailer':
      case 'Trailer': // legacy
        return 'Oversized Package';
      default:
        return 'Standard Delivery';
    }
  }

  String getWeight() {
    // Weight based on vehicle type
    switch (widget.booking.vehicle.type) {
      case 'Motorcycle':
        return 'Up to 10 kg';
      case 'Sedan':
        return 'Up to 200 kg';
      case 'AUV':
        return 'Up to 1,000 kg';
      case '4-Wheeler Closed Van':
      case '4-Wheeler': // legacy
        return 'Up to 2,000 kg';
      case '6-Wheeler Closed Van':
      case '6-Wheeler': // legacy
        return 'Up to 3,000 kg';
      case '6-Wheeler Forward Wingvan':
      case 'Wingvan': // legacy
        return 'Up to 7,000 kg';
      case '10-Wheeler Wingvan':
        return 'Up to 12,000 kg';
      case '20-Footer Trailer':
        return 'Up to 20,000 kg';
      case '40-Footer Trailer':
        return 'Up to 32,000 kg';
      case 'Trailer': // legacy
        return 'Up to 5,000 kg';
      default:
        return 'Up to 200 kg';
    }
  }

  String getInsurance() {
    // Insurance based on fare amount
    final base =
        (widget.booking.finalFare != null && widget.booking.finalFare! > 0)
            ? widget.booking.finalFare!
            : widget.booking.estimatedFare;
    final fare = base +
        (widget.booking.loadingDemurrageFee ?? 0.0) +
        (widget.booking.unloadingDemurrageFee ?? 0.0);
    if (fare < 500) return 'Basic Coverage';
    if (fare < 1000) return 'Standard Coverage';
    if (fare < 2000) return 'Premium Coverage';
    return 'Full Coverage';
  }

  String getSpecialInstructions() {
    // Get special instructions from notes
    return widget.booking.notes ?? 'None';
  }

  String getEstimatedTime() {
    // Calculate estimated time based on distance
    final distance = widget.booking.distance;
    if (distance <= 0) return 'Unknown';
    // Assume average speed of 30 km/h for urban delivery
    final timeInMinutes = (distance / 30 * 60).round();
    return '$timeInMinutes mins';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(widget.booking.bookingId),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryRed,
                        AppColors.primaryRed.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getVehicleType(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Booking ID: ${getBookingId()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: getStatusColor().withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    getStatusText(),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Medium',
                      color: getStatusColor(),
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Schedule Information
                  _buildSectionCard(
                    'Schedule Information',
                    Icons.calendar_today,
                    [
                      _buildDetailRow('Date', getFormattedDate()),
                      _buildDetailRow('Time', getFormattedTime()),
                      if (widget.booking.status == 'in_progress' ||
                          widget.booking.status == 'accepted')
                        _buildDetailRow('Estimated Time', getEstimatedTime()),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Driver Information
                  if (widget.booking.driverId != null) ...[
                    _buildSectionCard(
                      'Driver Information',
                      Icons.person,
                      [
                        _buildDetailRow('Name', getDriverName()),
                        if (getDriverRating() > 0)
                          _buildDetailRow('Rating',
                              '${getDriverRating().toStringAsFixed(1)} ⭐'),
                        _buildDetailRow('Contact', getDriverContact()),
                        _buildDetailRow('Vehicle Number', getVehicleNumber()),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Route Details
                  _buildRouteSection(),

                  const SizedBox(height: 20),

                  // Payment Information
                  _buildSectionCard(
                    'Payment Information',
                    Icons.payment,
                    [
                      _buildDetailRow('Total Fare', getFare()),
                      _buildDetailRow('Payment Method', getPaymentMethod()),
                      _buildDetailRow(
                          'Payment Status',
                          widget.booking.status == 'Completed'
                              ? 'Paid'
                              : 'Pending'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Additional Information
                  _buildSectionCard(
                    'Additional Information',
                    Icons.info_outline,
                    [
                      _buildDetailRow('Package Type', getPackageType()),
                      _buildDetailRow('Weight', getWeight()),
                      _buildDetailRow('Insurance', getInsurance()),
                      _buildDetailRow(
                          'Special Instructions', getSpecialInstructions()),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Primary Action
                if (widget.booking.status == 'in_progress' ||
                    widget.booking.status == 'accepted') ...[
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryRed,
                          AppColors.primaryRed.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DeliveryTrackingScreen(
                              booking: widget.booking,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.track_changes, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Track Delivery',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Cancel Booking Button
                if (BookingStatusService.canBeCancelled(
                    widget.booking.status)) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancelBookingDialog(),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text(
                        'Cancel Booking',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Medium',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],

                // Secondary Actions Row
                // Row(
                //   children: [
                //     Expanded(
                //       child: OutlinedButton(
                //         onPressed: () {
                //           Navigator.pop(context);
                //           UIHelpers.showInfoToast(
                //               'Contact driver feature coming soon');
                //         },
                //         style: OutlinedButton.styleFrom(
                //           padding: const EdgeInsets.symmetric(vertical: 16),
                //           shape: RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(12),
                //           ),
                //           side: BorderSide(
                //             color: AppColors.primaryRed.withOpacity(0.3),
                //             width: 1,
                //           ),
                //         ),
                //         child: Row(
                //           mainAxisAlignment: MainAxisAlignment.center,
                //           children: [
                //             Icon(
                //               Icons.phone,
                //               size: 18,
                //               color: AppColors.primaryRed,
                //             ),
                //             const SizedBox(width: 8),
                //             Text(
                //               'Contact',
                //               style: TextStyle(
                //                 fontSize: 14,
                //                 fontFamily: 'Medium',
                //                 color: AppColors.primaryRed,
                //               ),
                //             ),
                //           ],
                //         ),
                //       ),
                //     ),
                //     const SizedBox(width: 12),
                //     Expanded(
                //       child: OutlinedButton(
                //         onPressed: () {
                //           Navigator.pop(context);
                //           UIHelpers.showInfoToast(
                //               'Support feature coming soon');
                //         },
                //         style: OutlinedButton.styleFrom(
                //           padding: const EdgeInsets.symmetric(vertical: 16),
                //           shape: RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(12),
                //           ),
                //           side: BorderSide(
                //             color: AppColors.textHint.withOpacity(0.3),
                //             width: 1,
                //           ),
                //         ),
                //         child: Row(
                //           mainAxisAlignment: MainAxisAlignment.center,
                //           children: [
                //             Icon(
                //               Icons.support_agent,
                //               size: 18,
                //               color: AppColors.textSecondary,
                //             ),
                //             const SizedBox(width: 8),
                //             Text(
                //               'Support',
                //               style: TextStyle(
                //                 fontSize: 14,
                //                 fontFamily: 'Medium',
                //                 color: AppColors.textSecondary,
                //               ),
                //             ),
                //           ],
                //         ),
                //       ),
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show cancel booking dialog
  Future<void> _showCancelBookingDialog() async {
    final result = await showCancelBookingDialog(context, widget.booking);
    if (result == true && mounted) {
      // Booking was cancelled, close the bottom sheet
      Navigator.pop(context);
    }
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.lightGrey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Medium',
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.lightGrey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.route,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Route Details',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pickup Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.radio_button_checked,
                  size: 16,
                  color: AppColors.primaryRed,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup Location',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getFromLocation(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Route Line
          Container(
            margin: const EdgeInsets.only(left: 11),
            height: 30,
            child: const VerticalDivider(
              color: AppColors.textHint,
              thickness: 1,
            ),
          ),

          const SizedBox(height: 16),

          // Drop-off Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Drop-off Location',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getToLocation(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Distance
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.straighten,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Estimated Distance: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${widget.booking.distance.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 12,
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
}
