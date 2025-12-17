import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../services/rider_auth_service.dart';
import '../auth/rider_login_screen.dart';
import '../profile/rider_edit_profile_screen.dart';
import '../profile/rider_vehicle_details_screen.dart';
import '../profile/rider_documents_screen.dart';
import '../profile/rider_payment_methods_screen.dart';
import '../profile/rider_settings_screen.dart';

class RiderProfileTab extends StatefulWidget {
  const RiderProfileTab({super.key});

  @override
  State<RiderProfileTab> createState() => _RiderProfileTabState();
}

class _RiderProfileTabState extends State<RiderProfileTab> {
  final _authService = RiderAuthService();

  static const Map<String, String> _documentKeyToLabel = {
    'drivers_license': "Driver's License",
    'vehicle_registration': 'Vehicle Registration (OR/CR)',
    'nbi_clearance': 'NBI Clearance',
    'insurance': 'Insurance',
  };

  String _formatDateTime(DateTime? value) {
    if (value == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }

  Color _documentStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _documentStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending Review';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Not Uploaded';
    }
  }

  void _showDocumentViewer({
    required BuildContext context,
    required String title,
    required String url,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: AppColors.white,
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.lightGrey.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: AppColors.scaffoldBackground,
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return UIHelpers.loadingThreeBounce(
                              color: AppColors.primaryRed,
                              size: 20,
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    size: 42,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Unable to preview this file.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Medium',
                                      color: AppColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  void _showHelpSupportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HelpSupportBottomSheet(),
    );
  }

  void _showPrivacyPolicyBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PrivacyPolicyBottomSheet(),
    );
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

                    if (rider?.email != null && rider!.email!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        rider.email!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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

              // Account Info
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
                            Icons.badge,
                            color: AppColors.primaryRed,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Account Information',
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
                        label: 'Rider ID',
                        value: rider?.riderId.isNotEmpty == true
                            ? rider!.riderId
                            : 'N/A',
                      ),
                      _InfoRow(
                        label: 'Email',
                        value:
                            (rider?.email != null && rider!.email!.isNotEmpty)
                                ? rider.email!
                                : 'N/A',
                      ),
                      _InfoRow(
                        label: 'Status',
                        value: rider?.status ?? 'N/A',
                      ),
                      _InfoRow(
                        label: 'Online',
                        value: rider?.isOnline == true ? 'Yes' : 'No',
                      ),
                      _InfoRow(
                        label: 'Total Earnings',
                        value: rider != null
                            ? 'P${rider.totalEarnings.toStringAsFixed(2)}'
                            : 'N/A',
                      ),
                      _InfoRow(
                        label: 'Latitude',
                        value: rider?.currentLatitude != null
                            ? rider!.currentLatitude!.toStringAsFixed(6)
                            : 'N/A',
                      ),
                      _InfoRow(
                        label: 'Longitude',
                        value: rider?.currentLongitude != null
                            ? rider!.currentLongitude!.toStringAsFixed(6)
                            : 'N/A',
                      ),
                      _InfoRow(
                        label: 'Created At',
                        value: rider != null
                            ? _formatDateTime(rider.createdAt)
                            : 'N/A',
                      ),
                      _InfoRow(
                        label: 'Updated At',
                        value: rider != null
                            ? _formatDateTime(rider.updatedAt)
                            : 'N/A',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

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
                            Icons.description,
                            color: AppColors.primaryRed,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Uploaded Documents',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Bold',
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (rider == null)
                        const Text(
                          'Please login as rider first.',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('riders')
                              .doc(rider.riderId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: UIHelpers.loadingThreeBounce(
                                  color: AppColors.primaryRed,
                                  size: 18,
                                ),
                              );
                            }

                            final data = snapshot.data?.data();
                            final documents = (data?['documents'] as Map?)?.map(
                                    (k, v) => MapEntry(k.toString(), v)) ??
                                <String, dynamic>{};

                            return Column(
                              children: _documentKeyToLabel.entries.map((e) {
                                final key = e.key;
                                final label = e.value;
                                final doc = documents[key];
                                final docMap = doc is Map
                                    ? doc.map(
                                        (k, v) => MapEntry(k.toString(), v),
                                      )
                                    : null;
                                final url = (docMap?['url'] ?? '').toString();
                                final status = (docMap?['status'] ??
                                        (url.isNotEmpty
                                            ? 'pending'
                                            : 'not_uploaded'))
                                    .toString();
                                final color = _documentStatusColor(status);
                                final statusText = _documentStatusText(status);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.scaffoldBackground,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.description,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              label,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontFamily: 'Bold',
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'Medium',
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton(
                                        onPressed: url.isEmpty
                                            ? null
                                            : () => _showDocumentViewer(
                                                  context: context,
                                                  title: label,
                                                  url: url,
                                                ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primaryRed,
                                          side: const BorderSide(
                                            color: AppColors.primaryRed,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                        ),
                                        child: const Text(
                                          'View',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'Bold',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(growable: false),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

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
                        _showHelpSupportBottomSheet(context);
                      },
                    ),
                    _MenuTile(
                      icon: FontAwesomeIcons.shield,
                      title: 'Privacy Policy',
                      onTap: () {
                        _showPrivacyPolicyBottomSheet(context);
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

// Help & Support Bottom Sheet
class HelpSupportBottomSheet extends StatelessWidget {
  const HelpSupportBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppColors.redGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.circleQuestion,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Help Section
                  _buildSectionCard(
                    'Quick Help',
                    FontAwesomeIcons.bolt,
                    [
                      _buildHelpItem(
                        icon: FontAwesomeIcons.book,
                        title: 'User Guide',
                        subtitle: 'Learn how to use the app',
                        onTap: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast('Opening user guide...');
                        },
                      ),
                      _buildHelpItem(
                        icon: FontAwesomeIcons.video,
                        title: 'Video Tutorials',
                        subtitle: 'Watch step-by-step guides',
                        onTap: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast('Opening video tutorials...');
                        },
                      ),
                      _buildHelpItem(
                        icon: FontAwesomeIcons.circleQuestion,
                        title: 'FAQs',
                        subtitle: 'Frequently asked questions',
                        onTap: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast('Opening FAQs...');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Contact Support Section
                  _buildSectionCard(
                    'Contact Support',
                    FontAwesomeIcons.headset,
                    [
                      _buildHelpItem(
                        icon: FontAwesomeIcons.phone,
                        title: 'Call Support',
                        subtitle: '+63 2 8123 4567',
                        onTap: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast('Calling support...');
                        },
                      ),
                      _buildHelpItem(
                        icon: FontAwesomeIcons.envelope,
                        title: 'Email Support',
                        subtitle: 'support@citimovers.com',
                        onTap: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast('Opening email app...');
                        },
                      ),
                      _buildHelpItem(
                        icon: FontAwesomeIcons.comments,
                        title: 'Live Chat',
                        subtitle: 'Chat with our support team',
                        onTap: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast('Starting live chat...');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Report Issue Section
                  _buildSectionCard(
                    'Report an Issue',
                    FontAwesomeIcons.triangleExclamation,
                    [
                      _buildHelpItem(
                        icon: FontAwesomeIcons.bug,
                        title: 'Report a Bug',
                        subtitle: 'Help us improve the app',
                        onTap: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast('Opening bug report form...');
                        },
                      ),
                      _buildHelpItem(
                        icon: FontAwesomeIcons.flag,
                        title: 'Report a Driver',
                        subtitle: 'Report driver misconduct',
                        onTap: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast(
                              'Opening driver report form...');
                        },
                      ),
                      _buildHelpItem(
                        icon: FontAwesomeIcons.fileContract,
                        title: 'Report Delivery Issue',
                        subtitle: 'Problems with your delivery',
                        onTap: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast(
                              'Opening delivery issue form...');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom Action Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  UIHelpers.showInfoToast(
                      'Emergency support feature coming soon');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FontAwesomeIcons.phoneVolume, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Emergency Support',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Bold',
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
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
        border: Border.all(
          color: AppColors.lightGrey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.lightGrey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primaryBlue,
                    size: 18,
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
                          fontSize: 14,
                          fontFamily: 'Medium',
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Privacy Policy Bottom Sheet
class PrivacyPolicyBottomSheet extends StatelessWidget {
  const PrivacyPolicyBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppColors.redGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.shield,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Last Updated
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.lightGrey.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Last Updated: November 1, 2025',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Medium',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Privacy Sections
                  _buildPrivacySection(
                    'Information We Collect',
                    FontAwesomeIcons.database,
                    [
                      'Personal identification information (name, phone number, email)',
                      'Vehicle information (type, model, license plate)',
                      'Location data for delivery tracking',
                      'Payment and financial information',
                      'Usage data and app interactions',
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildPrivacySection(
                    'How We Use Your Information',
                    FontAwesomeIcons.gears,
                    [
                      'To provide delivery services',
                      'To process payments and manage earnings',
                      'To verify your identity and vehicle',
                      'To improve our services and user experience',
                      'To communicate with you about your deliveries',
                      'To ensure safety and security',
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildPrivacySection(
                    'Information Sharing',
                    FontAwesomeIcons.shareNodes,
                    [
                      'We only share information with customers for delivery purposes',
                      'Payment processors for transaction processing',
                      'Law enforcement when required by law',
                      'Service providers who help operate our platform',
                      'We never sell your personal information to third parties',
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildPrivacySection(
                    'Data Security',
                    FontAwesomeIcons.lock,
                    [
                      'Industry-standard encryption for data protection',
                      'Secure servers and regular security audits',
                      'Limited access to personal information',
                      'Regular backup and disaster recovery procedures',
                      'Compliance with data protection regulations',
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildPrivacySection(
                    'Your Rights',
                    FontAwesomeIcons.userShield,
                    [
                      'Access to your personal information',
                      'Correction of inaccurate information',
                      'Deletion of your account and data',
                      'Opt-out of marketing communications',
                      'Data portability upon request',
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildPrivacySection(
                    'Contact Us',
                    FontAwesomeIcons.envelope,
                    [
                      'For privacy concerns: privacy@citimovers.com',
                      'For data requests: dpo@citimovers.com',
                      'Hotline: +63 2 8123 4567',
                      'Office: 123 Delivery Street, Manila, Philippines',
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      UIHelpers.showInfoToast('Downloading privacy policy...');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: AppColors.primaryRed.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download,
                          size: 18,
                          color: AppColors.primaryRed,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Download',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Medium',
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.redGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'I Understand',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Bold',
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(
      String title, IconData icon, List<String> points) {
    return Container(
      width: double.infinity,
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
        border: Border.all(
          color: AppColors.lightGrey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...points.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        point,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
