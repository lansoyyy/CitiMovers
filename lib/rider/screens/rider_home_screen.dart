import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../services/rider_auth_service.dart';
import 'auth/rider_login_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final _authService = RiderAuthService();
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadRiderData();
  }

  Future<void> _loadRiderData() async {
    final rider = await _authService.getCurrentRider();
    if (rider != null && mounted) {
      setState(() {
        _isOnline = rider.isOnline;
      });
    }
  }

  Future<void> _toggleOnlineStatus() async {
    final success = await _authService.toggleOnlineStatus();
    if (success && mounted) {
      setState(() {
        _isOnline = !_isOnline;
      });
      UIHelpers.showSuccessToast(
        _isOnline ? 'You are now online' : 'You are now offline',
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const RiderLoginScreen(),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rider = _authService.currentRider;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Profile Picture
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.white,
                        child: rider?.photoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  rider!.photoUrl!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.person,
                                    size: 30,
                                    color: AppColors.primaryRed,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 30,
                                color: AppColors.primaryRed,
                              ),
                      ),
                      const SizedBox(width: 16),
                      // Rider Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rider?.name ?? 'Rider',
                              style: const TextStyle(
                                fontSize: 20,
                                fontFamily: 'Bold',
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${rider?.rating.toStringAsFixed(1) ?? '0.0'} • ${rider?.totalDeliveries ?? 0} deliveries',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Regular',
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Logout Button
                      IconButton(
                        onPressed: _handleLogout,
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Online/Offline Toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _isOnline
                                    ? AppColors.success
                                    : AppColors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isOnline
                                  ? 'You are Online'
                                  : 'You are Offline',
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Bold',
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isOnline,
                          onChanged: (value) => _toggleOnlineStatus(),
                          activeColor: AppColors.success,
                          activeTrackColor:
                              AppColors.success.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      size: 100,
                      color: AppColors.lightGrey,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Rider Home Screen',
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: 'Bold',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        'This is a placeholder for the rider home screen. Full functionality will be implemented soon.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
