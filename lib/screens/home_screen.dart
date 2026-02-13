import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/app_colors.dart';
import '../services/auth_service.dart';
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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAndResumeActiveBooking();
  }

  /// Check if there is an active booking and resume tracking
  Future<void> _checkAndResumeActiveBooking() async {
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      if (user == null || !mounted) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: user.userId)
          .where('status', whereIn: [
            'pending',
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
      final booking = BookingModel.fromMap({
        ...doc.data(),
        'bookingId': doc.id,
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryTrackingScreen(booking: booking),
        ),
      );
    } catch (e) {
      debugPrint('Error checking active booking: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final List<Widget> _screens = [
    const HomeTab(),
    const BookingsTab(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    _tabController.animateTo(index);
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
              icon: Icon(FontAwesomeIcons.rectangleList),
              text: 'Bookings',
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
