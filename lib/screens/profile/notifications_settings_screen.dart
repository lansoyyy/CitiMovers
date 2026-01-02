import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../../utils/app_colors.dart';

/// Notification preferences model
class NotificationPreferences {
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool bookingUpdates;
  final bool promotionalOffers;
  final bool driverUpdates;
  final bool paymentAlerts;

  NotificationPreferences({
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.bookingUpdates = true,
    this.promotionalOffers = true,
    this.driverUpdates = true,
    this.paymentAlerts = true,
  });

  NotificationPreferences copyWith({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? bookingUpdates,
    bool? promotionalOffers,
    bool? driverUpdates,
    bool? paymentAlerts,
  }) {
    return NotificationPreferences(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      bookingUpdates: bookingUpdates ?? this.bookingUpdates,
      promotionalOffers: promotionalOffers ?? this.promotionalOffers,
      driverUpdates: driverUpdates ?? this.driverUpdates,
      paymentAlerts: paymentAlerts ?? this.paymentAlerts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'smsNotifications': smsNotifications,
      'bookingUpdates': bookingUpdates,
      'promotionalOffers': promotionalOffers,
      'driverUpdates': driverUpdates,
      'paymentAlerts': paymentAlerts,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      pushNotifications: map['pushNotifications'] ?? true,
      emailNotifications: map['emailNotifications'] ?? true,
      smsNotifications: map['smsNotifications'] ?? false,
      bookingUpdates: map['bookingUpdates'] ?? true,
      promotionalOffers: map['promotionalOffers'] ?? true,
      driverUpdates: map['driverUpdates'] ?? true,
      paymentAlerts: map['paymentAlerts'] ?? true,
    );
  }
}

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  final GetStorage _storage = GetStorage();
  late NotificationPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    final prefsMap = _storage.read('notificationPreferences');
    if (prefsMap != null && prefsMap is Map) {
      setState(() {
        _preferences = NotificationPreferences.fromMap(
          Map<String, dynamic>.from(prefsMap),
        );
      });
    } else {
      setState(() {
        _preferences = NotificationPreferences();
      });
    }
  }

  Future<void> _savePreferences() async {
    await _storage.write('notificationPreferences', _preferences.toMap());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification preferences saved'),
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
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _savePreferences,
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Bold',
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification Channels Section
            const Text(
              'Notification Channels',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            _buildSwitchTile(
              icon: Icons.notifications_active,
              title: 'Push Notifications',
              subtitle: 'Receive notifications on your device',
              value: _preferences.pushNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences =
                      _preferences.copyWith(pushNotifications: value);
                });
              },
            ),

            _buildSwitchTile(
              icon: Icons.email_outlined,
              title: 'Email Notifications',
              subtitle: 'Receive updates via email',
              value: _preferences.emailNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences =
                      _preferences.copyWith(emailNotifications: value);
                });
              },
            ),

            _buildSwitchTile(
              icon: Icons.sms_outlined,
              title: 'SMS Notifications',
              subtitle: 'Receive updates via text message',
              value: _preferences.smsNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(smsNotifications: value);
                });
              },
            ),

            const SizedBox(height: 32),

            // Notification Types Section
            const Text(
              'Notification Types',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            _buildSwitchTile(
              icon: Icons.local_shipping_outlined,
              title: 'Booking Updates',
              subtitle: 'Updates about your deliveries',
              value: _preferences.bookingUpdates,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(bookingUpdates: value);
                });
              },
            ),

            _buildSwitchTile(
              icon: Icons.directions_car_outlined,
              title: 'Driver Updates',
              subtitle: 'Driver location and status updates',
              value: _preferences.driverUpdates,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(driverUpdates: value);
                });
              },
            ),

            _buildSwitchTile(
              icon: Icons.payment_outlined,
              title: 'Payment Alerts',
              subtitle: 'Payment confirmations and receipts',
              value: _preferences.paymentAlerts,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(paymentAlerts: value);
                });
              },
            ),

            _buildSwitchTile(
              icon: Icons.local_offer_outlined,
              title: 'Promotional Offers',
              subtitle: 'Discounts and special offers',
              value: _preferences.promotionalOffers,
              onChanged: (value) {
                setState(() {
                  _preferences =
                      _preferences.copyWith(promotionalOffers: value);
                });
              },
            ),

            const SizedBox(height: 32),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'You can manage system-level notification permissions in your device settings.',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Reset Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _preferences = NotificationPreferences();
                  });
                  _savePreferences();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryRed),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Reset to Default',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Medium',
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryBlue,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'Medium',
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Regular',
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primaryBlue,
        ),
      ),
    );
  }
}
