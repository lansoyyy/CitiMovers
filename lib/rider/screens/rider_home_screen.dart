import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/app_colors.dart';
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
