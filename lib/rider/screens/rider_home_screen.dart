import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _screens = [
      RiderHomeTab(tabController: _tabController),
      const RiderDeliveriesTab(),
      const RiderEarningsTab(),
      const RiderProfileTab(),
    ];
    _checkAndResumeActiveDelivery();
  }

  /// Check if there is an active delivery and resume progress screen
  Future<void> _checkAndResumeActiveDelivery() async {
    try {
      final authService = RiderAuthService();
      final rider = await authService.getCurrentRider();
      if (rider == null || !mounted) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('driverId', isEqualTo: rider.riderId)
          .where('status', whereIn: [
            'accepted',
            'arrived_at_pickup',
            'loading_complete',
            'in_transit',
            'in_progress',
            'arrived_at_dropoff',
            'unloading_complete',
          ])
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty || !mounted) return;

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final request = _bookingToDeliveryRequest(doc.id, data);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RiderDeliveryProgressScreen(request: request),
        ),
      );
    } catch (e) {
      debugPrint('Error checking active delivery: $e');
    }
  }

  /// Convert a Firestore booking document to DeliveryRequest
  DeliveryRequest _bookingToDeliveryRequest(
      String bookingId, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    DateTime createdDate;
    if (createdAt is int) {
      createdDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else if (createdAt is Timestamp) {
      createdDate = createdAt.toDate();
    } else {
      createdDate = DateTime.now();
    }
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

    final customerName = data['customerName'] as String? ?? 'Unknown';
    final customerPhone = data['customerPhone'] as String? ?? 'N/A';

    final pickupLocationRaw = data['pickupLocation'];
    final dropoffLocationRaw = data['dropoffLocation'];
    final pickupLocation = pickupLocationRaw is Map
        ? (pickupLocationRaw['address'] ?? '').toString()
        : (pickupLocationRaw ?? '').toString();
    final deliveryLocation = dropoffLocationRaw is Map
        ? (dropoffLocationRaw['address'] ?? '').toString()
        : (dropoffLocationRaw ?? '').toString();

    final distance = (data['distance'] as num?)?.toDouble() ?? 0.0;
    final estimatedDuration =
        (data['estimatedDuration'] as num?)?.toDouble() ?? 0.0;
    final fare = ((data['finalFare'] as num?)?.toDouble() ?? 0.0) > 0
        ? (data['finalFare'] as num).toDouble()
        : (data['estimatedFare'] as num?)?.toDouble() ?? 0.0;

    final vehicleRaw = data['vehicle'];
    final vehicleType =
        vehicleRaw is Map ? (vehicleRaw['type'] ?? '').toString() : '';
    final vehicleCapacity =
        vehicleRaw is Map ? (vehicleRaw['capacity'] ?? '').toString() : '';
    final packageType = vehicleType.isNotEmpty ? vehicleType : 'Standard';
    final weight = vehicleCapacity.isNotEmpty ? vehicleCapacity : 'N/A';
    final specialInstructions = data['notes'] as String? ?? 'None';
    final urgency = data['urgency'] as String? ?? 'Normal';

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
  void dispose() {
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
