import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';

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
              UIHelpers.showInfoToast(
                  'View booking details for ${bookings[index].id}');
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with vehicle type and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: AppColors.primaryRed,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.vehicleType,
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Bold',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${booking.id}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Regular',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: booking.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        booking.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Medium',
                          color: booking.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date and Time
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${booking.date} at ${booking.time}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Driver Info (for active and completed bookings)
                if (booking.driverName != 'Not Assigned')
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              booking.driverName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'Regular',
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (booking.driverRating > 0)
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  booking.driverRating.toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Medium',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                // Route
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _RoutePoint(
                        icon: Icons.radio_button_checked,
                        label: 'From',
                        location: booking.from,
                        color: AppColors.primaryRed,
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: SizedBox(
                          height: 20,
                          child: VerticalDivider(
                            color: AppColors.textHint,
                            thickness: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RoutePoint(
                        icon: Icons.location_on,
                        label: 'To',
                        location: booking.to,
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Footer with fare and action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fare',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          booking.fare,
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'Bold',
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ],
                    ),
                    if (booking.status == 'In Transit' ||
                        booking.status == 'Driver Assigned')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              booking.estimatedTime,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Medium',
                                color: AppColors.primaryRed,
                              ),
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
