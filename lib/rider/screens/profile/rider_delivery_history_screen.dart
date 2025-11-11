import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../utils/app_colors.dart';

class RiderDeliveryHistoryScreen extends StatefulWidget {
  const RiderDeliveryHistoryScreen({super.key});

  @override
  State<RiderDeliveryHistoryScreen> createState() =>
      _RiderDeliveryHistoryScreenState();
}

class _RiderDeliveryHistoryScreenState
    extends State<RiderDeliveryHistoryScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'This Week', 'This Month', 'Last Month'];

  // Mock data
  final List<DeliveryHistory> _deliveries = [
    DeliveryHistory(
      bookingId: 'BK1005',
      date: 'Nov 6, 2025',
      time: '2:30 PM',
      from: 'Quezon City',
      to: 'Makati City',
      distance: '12.5 km',
      duration: '45 mins',
      fare: 450.0,
      customerName: 'Juan Dela Cruz',
      vehicleType: '4-Wheeler',
      rating: 5.0,
    ),
    DeliveryHistory(
      bookingId: 'BK1004',
      date: 'Nov 5, 2025',
      time: '10:15 AM',
      from: 'Manila',
      to: 'Pasig City',
      distance: '8.2 km',
      duration: '30 mins',
      fare: 320.0,
      customerName: 'Maria Santos',
      vehicleType: 'AUV',
      rating: 4.5,
    ),
    DeliveryHistory(
      bookingId: 'BK1003',
      date: 'Nov 4, 2025',
      time: '4:45 PM',
      from: 'Taguig',
      to: 'Paranaque',
      distance: '15.8 km',
      duration: '55 mins',
      fare: 580.0,
      customerName: 'Pedro Garcia',
      vehicleType: 'Wingvan',
      rating: 5.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Delivery History',
          style: TextStyle(
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // Stats Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: FontAwesomeIcons.truck,
                    value: '${_deliveries.length}',
                    label: 'Total',
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatBox(
                    icon: FontAwesomeIcons.pesoSign,
                    value: '₱${_deliveries.fold<double>(0, (sum, item) => sum + item.fare).toStringAsFixed(0)}',
                    label: 'Earned',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatBox(
                    icon: FontAwesomeIcons.star,
                    value: '${(_deliveries.fold<double>(0, (sum, item) => sum + item.rating) / _deliveries.length).toStringAsFixed(1)}',
                    label: 'Rating',
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryRed
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        filter,
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
                }).toList(),
              ),
            ),
          ),

          // Delivery List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _deliveries.length,
              itemBuilder: (context, index) {
                final delivery = _deliveries[index];
                return _DeliveryHistoryCard(delivery: delivery);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryHistory {
  final String bookingId;
  final String date;
  final String time;
  final String from;
  final String to;
  final String distance;
  final String duration;
  final double fare;
  final String customerName;
  final String vehicleType;
  final double rating;

  DeliveryHistory({
    required this.bookingId,
    required this.date,
    required this.time,
    required this.from,
    required this.to,
    required this.distance,
    required this.duration,
    required this.fare,
    required this.customerName,
    required this.vehicleType,
    required this.rating,
  });
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Bold',
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryHistoryCard extends StatelessWidget {
  final DeliveryHistory delivery;

  const _DeliveryHistoryCard({required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                delivery.bookingId,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Bold',
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Date & Time
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '${delivery.date} • ${delivery.time}',
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Regular',
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Locations
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 30,
                    color: AppColors.lightGrey,
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.from,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      delivery.to,
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

          const SizedBox(height: 12),

          // Details
          Row(
            children: [
              _DetailChip(
                icon: Icons.straighten,
                text: delivery.distance,
              ),
              const SizedBox(width: 8),
              _DetailChip(
                icon: Icons.access_time,
                text: delivery.duration,
              ),
              const SizedBox(width: 8),
              _DetailChip(
                icon: Icons.local_shipping,
                text: delivery.vehicleType,
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    delivery.customerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Medium',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        delivery.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${delivery.fare.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Medium',
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
