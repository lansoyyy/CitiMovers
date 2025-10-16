import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/driver_model.dart';
import 'driver_credentials_screen.dart';

class DriverInfoScreen extends StatelessWidget {
  final DriverModel driver;

  const DriverInfoScreen({
    super.key,
    required this.driver,
  });

  void _callDriver(BuildContext context) {
    // TODO: Implement phone call
    UIHelpers.showInfoToast('Calling ${driver.name}...');
  }

  void _messageDriver(BuildContext context) {
    // TODO: Implement messaging
    UIHelpers.showInfoToast('Opening chat with ${driver.name}...');
  }

  void _viewCredentials(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverCredentialsScreen(driver: driver),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Driver Information'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Legal Notice'),
                  content: const Text(
                    'Driver credentials are provided for verification purposes only. '
                    'Unauthorized use, reproduction, or distribution is strictly prohibited. '
                    'These credentials will be automatically hidden after delivery completion.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Understood'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Driver Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Photo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: driver.isVerified
                            ? AppColors.success
                            : AppColors.textHint,
                        width: 3,
                      ),
                      image: driver.photoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(driver.photoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: AppColors.primaryRed.withOpacity(0.1),
                    ),
                    child: driver.photoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: AppColors.primaryRed,
                          )
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Driver Name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (driver.isVerified) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified,
                          color: AppColors.success,
                          size: 24,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Rating and Deliveries
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          driver.ratingText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Bold',
                            color: Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          driver.deliveriesText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Medium',
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _callDriver(context),
                          icon: const Icon(Icons.phone, size: 20),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _messageDriver(context),
                          icon: const Icon(Icons.message, size: 20),
                          label: const Text('Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Contact Information
            _InfoSection(
              title: 'Contact Information',
              children: [
                _InfoItem(
                  icon: Icons.phone,
                  label: 'Phone Number',
                  value: driver.phoneNumber,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: driver.phoneNumber));
                    UIHelpers.showSuccessToast('Phone number copied');
                  },
                ),
                if (driver.email != null)
                  _InfoItem(
                    icon: Icons.email,
                    label: 'Email',
                    value: driver.email!,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: driver.email!));
                      UIHelpers.showSuccessToast('Email copied');
                    },
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Vehicle Information
            _InfoSection(
              title: 'Vehicle Information',
              children: [
                _InfoItem(
                  icon: Icons.local_shipping,
                  label: 'Vehicle Type',
                  value: driver.vehicleType,
                ),
                _InfoItem(
                  icon: Icons.confirmation_number,
                  label: 'Plate Number',
                  value: driver.vehiclePlateNumber,
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: driver.vehiclePlateNumber));
                    UIHelpers.showSuccessToast('Plate number copied');
                  },
                ),
                if (driver.vehiclePhotoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        driver.vehiclePhotoUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            color: AppColors.scaffoldBackground,
                            child: const Center(
                              child: Icon(
                                Icons.local_shipping,
                                size: 50,
                                color: AppColors.textHint,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // View Credentials Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _viewCredentials(context),
                  icon: const Icon(Icons.badge, size: 24),
                  label: const Text(
                    'View Driver Credentials',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Legal Notice
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Credentials are for verification only. Will be hidden after delivery.',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// Info Section Widget
class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// Info Item Widget
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontFamily: 'Medium',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.copy,
                size: 18,
                color: AppColors.textHint,
              ),
          ],
        ),
      ),
    );
  }
}
