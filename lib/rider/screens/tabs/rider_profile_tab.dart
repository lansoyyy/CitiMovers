import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../services/rider_auth_service.dart';
import '../auth/rider_login_screen.dart';
import '../profile/rider_edit_profile_screen.dart';
import '../profile/rider_vehicle_details_screen.dart';
import '../profile/rider_documents_screen.dart';
import '../profile/rider_delivery_history_screen.dart';
import '../profile/rider_payment_methods_screen.dart';
import '../profile/rider_settings_screen.dart';

class RiderProfileTab extends StatefulWidget {
  const RiderProfileTab({super.key});

  @override
  State<RiderProfileTab> createState() => _RiderProfileTabState();
}

class _RiderProfileTabState extends State<RiderProfileTab> {
  final _authService = RiderAuthService();

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
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Profile Picture
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.white,
                          child: rider?.photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    rider!.photoUrl!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: AppColors.primaryRed,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppColors.primaryRed,
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      rider?.name ?? 'Rider',
                      style: const TextStyle(
                        fontSize: 24,
                        fontFamily: 'Bold',
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rider?.phoneNumber ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Regular',
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Rating and Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StatBadge(
                          icon: Icons.star,
                          value: rider?.rating.toStringAsFixed(1) ?? '0.0',
                          label: 'Rating',
                        ),
                        const SizedBox(width: 24),
                        _StatBadge(
                          icon: Icons.local_shipping,
                          value: '${rider?.totalDeliveries ?? 0}',
                          label: 'Deliveries',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Vehicle Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
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
                      const Row(
                        children: [
                          Icon(
                            Icons.directions_car,
                            color: AppColors.primaryRed,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Vehicle Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Bold',
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        label: 'Type',
                        value: rider?.vehicleType ?? 'N/A',
                      ),
                      _InfoRow(
                        label: 'Plate Number',
                        value: rider?.vehiclePlateNumber ?? 'N/A',
                      ),
                      if (rider?.vehicleModel != null)
                        _InfoRow(
                          label: 'Model',
                          value: rider!.vehicleModel!,
                        ),
                      if (rider?.vehicleColor != null)
                        _InfoRow(
                          label: 'Color',
                          value: rider!.vehicleColor!,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Menu Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: FontAwesomeIcons.user,
                      title: 'Edit Profile',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RiderEditProfileScreen(),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: FontAwesomeIcons.car,
                      title: 'Vehicle Details',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RiderVehicleDetailsScreen(),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: FontAwesomeIcons.fileLines,
                      title: 'Documents',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RiderDocumentsScreen(),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: FontAwesomeIcons.wallet,
                      title: 'Payment Methods',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RiderPaymentMethodsScreen(),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: FontAwesomeIcons.gear,
                      title: 'Settings',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RiderSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: FontAwesomeIcons.circleQuestion,
                      title: 'Help & Support',
                      onTap: () {
                        UIHelpers.showInfoToast('Coming soon');
                      },
                    ),
                    _MenuTile(
                      icon: FontAwesomeIcons.shield,
                      title: 'Privacy Policy',
                      onTap: () {
                        UIHelpers.showInfoToast('Coming soon');
                      },
                    ),
                    _MenuTile(
                      icon: FontAwesomeIcons.rightFromBracket,
                      title: 'Logout',
                      onTap: _handleLogout,
                      isDestructive: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.amber,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontFamily: 'Bold',
              color: AppColors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Regular',
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isDestructive ? AppColors.error : AppColors.primaryRed)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDestructive ? AppColors.error : AppColors.primaryRed,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontFamily: 'Medium',
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDestructive ? AppColors.error : AppColors.textSecondary,
        ),
      ),
    );
  }
}
