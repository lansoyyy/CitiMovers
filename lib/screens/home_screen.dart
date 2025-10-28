import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/ui_helpers.dart';
import 'profile/profile_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/bookings_tab.dart';
import 'tabs/notifications_tab.dart';

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
