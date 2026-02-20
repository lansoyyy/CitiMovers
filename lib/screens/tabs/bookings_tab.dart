import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList('active'),
          _buildBookingsList('completed'),
          _buildBookingsList('cancelled'),
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

        if (filteredBookings.isEmpty) {
          return _buildEmptyState(status);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredBookings.length,
          itemBuilder: (context, index) {
            final booking = filteredBookings[index];
            return _bookingCard(booking);
          },
        );
      },
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
    switch (status) {
      case 'active':
        return bookings
            .where((booking) =>
                booking.status == 'awaiting_payment' ||
                booking.status == 'pending' ||
                booking.status == 'accepted' ||
                booking.status == 'in_progress')
            .toList();
      case 'completed':
        return bookings
            .where((booking) => booking.status == 'completed')
            .toList();
      case 'cancelled':
        return bookings
            .where((booking) => booking.status == 'cancelled')
            .toList();
      default:
        return bookings;
    }
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
                Row(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final IconData icon;
  final String label;
  final String location;
  final Color color;

  const _RoutePoint({
    required this.icon,
    required this.label,
    required this.location,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'Medium',
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Regular',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
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
      case '4-Wheeler':
        return 'Large Package';
      case '6-Wheeler':
        return 'Extra Large Package';
      case 'Wingvan':
        return 'Heavy Package';
      case 'Trailer':
        return 'Oversized Package';
      case '10-Wheeler Wingvan':
        return 'Industrial Package';
      default:
        return 'Standard Delivery';
    }
  }

  String getWeight() {
    // Weight based on vehicle type
    switch (widget.booking.vehicle.type) {
      case 'Motorcycle':
        return 'Up to 10kg';
      case 'Sedan':
        return 'Up to 50kg';
      case 'AUV':
        return 'Up to 200kg';
      case '4-Wheeler':
        return 'Up to 500kg';
      case '6-Wheeler':
        return 'Up to 1000kg';
      case 'Wingvan':
        return 'Up to 2000kg';
      case 'Trailer':
        return 'Up to 5000kg';
      case '10-Wheeler Wingvan':
        return 'Up to 10000kg';
      default:
        return 'Up to 500kg';
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

                // Cancel Booking Button (for pending bookings)
                if (widget.booking.status == 'pending') ...[
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
