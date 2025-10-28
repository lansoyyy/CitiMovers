import 'package:citimovers/screens/tabs/notifications_tab.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import 'edit_profile_screen.dart';
import '../help_center_screen.dart';
import '../terms_conditions_screen.dart';
import '../privacy_policy_screen.dart';
import 'change_password_screen.dart';
import '../auth/welcome_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
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
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryRed,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion request submitted'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Photo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryRed.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.primaryRed,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person,
                size: 50,
                color: AppColors.primaryRed,
              ),
            ),

            const SizedBox(height: 16),

            // Name
            const Text(
              'Juan Dela Cruz',
              style: TextStyle(
                fontSize: 22,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 4),

            // Phone
            const Text(
              '+63 912 345 6789',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 32),

            // Account Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Account',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ProfileMenuItem(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              subtitle: 'Update your personal information',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
              },
            ),
            _ProfileMenuItem(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your password',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Settings Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ProfileMenuItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              onTap: () {
                // TODO: Navigate to notifications settings
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsTab(),
                  ),
                );
              },
            ),
            _ProfileMenuItem(
              icon: Icons.language_outlined,
              title: 'Language',
              subtitle: 'English',
              onTap: () {
                // TODO: Navigate to language settings
              },
            ),

            const SizedBox(height: 24),

            // Support Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Support',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ProfileMenuItem(
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'FAQs and support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpCenterScreen(),
                  ),
                );
              },
            ),
            _ProfileMenuItem(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              subtitle: 'Read our terms',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsConditionsScreen(),
                  ),
                );
              },
            ),
            _ProfileMenuItem(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Danger Zone
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Bold',
                  color: AppColors.primaryRed,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ProfileMenuItem(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              textColor: AppColors.primaryRed,
              onTap: () => _handleLogout(context),
            ),
            _ProfileMenuItem(
              icon: Icons.delete_outline,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              textColor: AppColors.primaryRed,
              onTap: () => _handleDeleteAccount(context),
            ),

            const SizedBox(height: 40),

            // App Version
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Regular',
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Profile Menu Item Widget
class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? textColor;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Medium',
            color: color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'Regular',
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: color.withOpacity(0.5),
        ),
      ),
    );
  }
}
