import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../delivery/delivery_tracking_screen.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });
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
          _buildBookingsList(BookingStatus.active),
          _buildBookingsList(BookingStatus.completed),
          _buildBookingsList(BookingStatus.cancelled),
        ],
      ),
    );
  }

  Widget _buildBookingsList(BookingStatus status) {
    if (_isLoading) {
      return Center(child: UIHelpers.loadingIndicator());
    }

    // Sample booking data based on status
    final List<BookingData> bookings = _getBookingsByStatus(status);

    if (bookings.isEmpty) {
      return _buildEmptyState(status);
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: AppColors.primaryRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return BookingCard(
            booking: bookings[index],
            onTap: () {
              _showBookingDetailsBottomSheet(context, bookings[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BookingStatus status) {
    String title;
    String subtitle;
    IconData icon;

    switch (status) {
      case BookingStatus.active:
        title = 'No active bookings';
        subtitle = 'You don\'t have any active deliveries';
        icon = Icons.local_shipping_outlined;
        break;
      case BookingStatus.completed:
        title = 'No completed bookings';
        subtitle = 'You haven\'t completed any deliveries yet';
        icon = Icons.check_circle_outline;
        break;
      case BookingStatus.cancelled:
        title = 'No cancelled bookings';
        subtitle = 'You don\'t have any cancelled deliveries';
        icon = Icons.cancel_outlined;
        break;
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
          if (status == BookingStatus.active)
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

  List<BookingData> _getBookingsByStatus(BookingStatus status) {
    switch (status) {
      case BookingStatus.active:
        return [
          BookingData(
            id: 'BK001',
            vehicleType: 'Wingvan',
            driverName: 'Juan Dela Cruz',
            driverRating: 4.8,
            from: 'Quezon City',
            to: 'Makati City',
            date: 'Oct 24, 2025',
            time: '10:30 AM',
            fare: 'P850',
            status: 'In Transit',
            statusColor: AppColors.primaryBlue,
            estimatedTime: '45 mins',
          ),
          BookingData(
            id: 'BK002',
            vehicleType: '4-Wheeler',
            driverName: 'Pedro Santos',
            driverRating: 4.9,
            from: 'Manila',
            to: 'Pasig City',
            date: 'Oct 24, 2025',
            time: '2:15 PM',
            fare: 'P320',
            status: 'Driver Assigned',
            statusColor: AppColors.warning,
            estimatedTime: '30 mins',
          ),
        ];
      case BookingStatus.completed:
        return [
          BookingData(
            id: 'BK003',
            vehicleType: 'Motorcycle',
            driverName: 'Maria Reyes',
            driverRating: 4.7,
            from: 'Mandaluyong',
            to: 'San Juan',
            date: 'Oct 23, 2025',
            time: '9:00 AM',
            fare: 'P150',
            status: 'Completed',
            statusColor: AppColors.success,
            estimatedTime: 'Delivered',
          ),
          BookingData(
            id: 'BK004',
            vehicleType: '6-Wheeler',
            driverName: 'Carlos Mendoza',
            driverRating: 4.6,
            from: 'Caloocan',
            to: 'Taguig',
            date: 'Oct 22, 2025',
            time: '3:30 PM',
            fare: 'P1,200',
            status: 'Completed',
            statusColor: AppColors.success,
            estimatedTime: 'Delivered',
          ),
        ];
      case BookingStatus.cancelled:
        return [
          BookingData(
            id: 'BK005',
            vehicleType: 'Wingvan',
            driverName: 'Not Assigned',
            driverRating: 0,
            from: 'Pasay',
            to: 'Paranaque',
            date: 'Oct 21, 2025',
            time: '11:00 AM',
            fare: 'P750',
            status: 'Cancelled',
            statusColor: AppColors.error,
            estimatedTime: 'Cancelled by user',
          ),
        ];
    }
  }

  void _showBookingDetailsBottomSheet(
      BuildContext context, BookingData booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingDetailsBottomSheet(booking: booking),
    );
  }
}

class BookingCard extends StatelessWidget {
  final BookingData booking;
  final VoidCallback onTap;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          onTap: onTap,
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
                              booking.vehicleType,
                              style: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'Bold',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${booking.id}',
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
                        color: booking.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: booking.statusColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        booking.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Medium',
                          color: booking.statusColor,
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
                          booking.date,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Medium',
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          booking.time,
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
                if (booking.driverName != 'Not Assigned')
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
                              booking.driverName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            if (booking.driverRating > 0)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${booking.driverRating} rating',
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

                if (booking.driverName != 'Not Assigned')
                  const SizedBox(height: 20),

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
                              booking.from,
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
                              booking.to,
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
                        booking.fare,
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

class BookingData {
  final String id;
  final String vehicleType;
  final String driverName;
  final double driverRating;
  final String from;
  final String to;
  final String date;
  final String time;
  final String fare;
  final String status;
  final Color statusColor;
  final String estimatedTime;

  BookingData({
    required this.id,
    required this.vehicleType,
    required this.driverName,
    required this.driverRating,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.fare,
    required this.status,
    required this.statusColor,
    required this.estimatedTime,
  });
}

enum BookingStatus {
  active,
  completed,
  cancelled,
}

// Booking Details Bottom Sheet
class BookingDetailsBottomSheet extends StatelessWidget {
  final BookingData booking;

  const BookingDetailsBottomSheet({
    super.key,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                        booking.vehicleType,
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Booking ID: ${booking.id}',
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
                    color: booking.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: booking.statusColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    booking.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Medium',
                      color: booking.statusColor,
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
                      _buildDetailRow('Date', booking.date),
                      _buildDetailRow('Time', booking.time),
                      if (booking.status == 'In Transit' ||
                          booking.status == 'Driver Assigned')
                        _buildDetailRow(
                            'Estimated Time', booking.estimatedTime),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Driver Information
                  if (booking.driverName != 'Not Assigned') ...[
                    _buildSectionCard(
                      'Driver Information',
                      Icons.person,
                      [
                        _buildDetailRow('Name', booking.driverName),
                        if (booking.driverRating > 0)
                          _buildDetailRow(
                              'Rating', '${booking.driverRating} ⭐'),
                        _buildDetailRow('Contact', '+63 912 345 6789'),
                        _buildDetailRow('Vehicle Number', 'ABC 1234'),
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
                      _buildDetailRow('Total Fare', booking.fare),
                      _buildDetailRow('Payment Method', 'Cash on Delivery'),
                      _buildDetailRow('Payment Status',
                          booking.status == 'Completed' ? 'Paid' : 'Pending'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Additional Information
                  _buildSectionCard(
                    'Additional Information',
                    Icons.info_outline,
                    [
                      _buildDetailRow('Package Type', 'Standard Delivery'),
                      _buildDetailRow('Weight', 'Up to 500kg'),
                      _buildDetailRow('Insurance', 'Basic Coverage'),
                      _buildDetailRow(
                          'Special Instructions', 'Handle with care'),
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
                if (booking.status == 'In Transit' ||
                    booking.status == 'Driver Assigned') ...[
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
                              booking: booking,
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

                // Secondary Actions Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast(
                              'Contact driver feature coming soon');
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: AppColors.primaryRed.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone,
                              size: 18,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Contact',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast(
                              'Support feature coming soon');
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: AppColors.textHint.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.support_agent,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Support',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                      booking.from,
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
                      booking.to,
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
                  '12.5 km',
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
