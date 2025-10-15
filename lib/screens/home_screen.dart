import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/ui_helpers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const BookingsTab(),
    const ProfileTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// Home Tab
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              AppColors.primaryRed,
              AppColors.scaffoldBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Regular',
                                color: AppColors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              AppConstants.appName,
                              style: TextStyle(
                                fontSize: 28,
                                fontFamily: 'Bold',
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_rounded,
                            color: AppColors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Main content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Actions
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.local_shipping_rounded,
                                title: 'Book Delivery',
                                color: AppColors.primaryRed,
                                onTap: () {
                                  UIHelpers.showInfoToast('Book Delivery tapped');
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.history_rounded,
                                title: 'Track Order',
                                color: AppColors.primaryBlue,
                                onTap: () {
                                  UIHelpers.showInfoToast('Track Order tapped');
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Vehicle Types
                        const Text(
                          'Choose Vehicle Type',
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _VehicleTypeCard(
                          icon: Icons.two_wheeler_rounded,
                          title: 'Motorcycle',
                          description: 'Small items, quick delivery',
                          price: '₱50 - ₱150',
                          onTap: () {
                            UIHelpers.showSuccessToast('Motorcycle selected');
                          },
                        ),
                        const SizedBox(height: 12),
                        _VehicleTypeCard(
                          icon: Icons.directions_car_rounded,
                          title: 'Sedan',
                          description: 'Medium items, comfortable',
                          price: '₱150 - ₱300',
                          onTap: () {
                            UIHelpers.showSuccessToast('Sedan selected');
                          },
                        ),
                        const SizedBox(height: 12),
                        _VehicleTypeCard(
                          icon: Icons.local_shipping_rounded,
                          title: 'Van',
                          description: 'Large items, spacious',
                          price: '₱300 - ₱500',
                          onTap: () {
                            UIHelpers.showSuccessToast('Van selected');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick Action Card Widget
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Medium',
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Vehicle Type Card Widget
class _VehicleTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String price;
  final VoidCallback onTap;

  const _VehicleTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryRed,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Bold',
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bookings Tab
class BookingsTab extends StatelessWidget {
  const BookingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UIHelpers.loadingIndicator(),
            const SizedBox(height: 20),
            const Text(
              'No bookings yet',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Medium',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Profile Tab
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            UIHelpers.showSuccessToast('Profile updated successfully!');
          },
          child: const Text('Test Toast'),
        ),
      ),
    );
  }
}
