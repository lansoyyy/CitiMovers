import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../../services/auth_service.dart';
import '../../models/rider_settings_model.dart';
import '../../services/rider_settings_service.dart';

class RiderSettingsScreen extends StatefulWidget {
  const RiderSettingsScreen({super.key});

  @override
  State<RiderSettingsScreen> createState() => _RiderSettingsScreenState();
}

class _RiderSettingsScreenState extends State<RiderSettingsScreen> {
  final AuthService _authService = AuthService();
  final RiderSettingsService _settingsService = RiderSettingsService.instance;

  bool _isLoading = true;
  RiderSettingsModel? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final riderId = _authService.currentUser?.userId;
    if (riderId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final settings = await _settingsService.getRiderSettings(riderId);

      if (settings == null) {
        // Initialize default settings
        final defaultSettings =
            await _settingsService.initializeDefaultSettings(riderId);
        setState(() {
          _settings = defaultSettings;
          _isLoading = false;
        });
      } else {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    try {
      await _settingsService.saveRiderSettings(_settings!);
    } catch (e) {
      debugPrint('Error saving settings: $e');
      UIHelpers.showErrorToast('Failed to save settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: const Text(
            'Settings',
            style: TextStyle(
              fontFamily: 'Bold',
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notifications Section
            _SectionHeader(title: 'Notifications'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                children: [
                  _SwitchTile(
                    icon: FontAwesomeIcons.bell,
                    title: 'Push Notifications',
                    subtitle: 'Receive delivery requests and updates',
                    value: _settings?.pushNotifications ?? true,
                    onChanged: (value) {
                      setState(() {
                        _settings =
                            _settings?.copyWith(pushNotifications: value);
                      });
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1),
                  _SwitchTile(
                    icon: FontAwesomeIcons.envelope,
                    title: 'Email Notifications',
                    subtitle: 'Get updates via email',
                    value: _settings?.emailNotifications ?? false,
                    onChanged: (value) {
                      setState(() {
                        _settings =
                            _settings?.copyWith(emailNotifications: value);
                      });
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1),
                  _SwitchTile(
                    icon: FontAwesomeIcons.message,
                    title: 'SMS Notifications',
                    subtitle: 'Receive SMS for important updates',
                    value: _settings?.smsNotifications ?? true,
                    onChanged: (value) {
                      setState(() {
                        _settings =
                            _settings?.copyWith(smsNotifications: value);
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // App Preferences Section
            _SectionHeader(title: 'App Preferences'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                children: [
                  _SwitchTile(
                    icon: FontAwesomeIcons.volumeHigh,
                    title: 'Sound Effects',
                    subtitle: 'Play sounds for notifications',
                    value: _settings?.soundEffects ?? true,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings?.copyWith(soundEffects: value);
                      });
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1),
                  _SwitchTile(
                    icon: FontAwesomeIcons.mobile,
                    title: 'Vibration',
                    subtitle: 'Vibrate for notifications',
                    value: _settings?.vibration ?? true,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings?.copyWith(vibration: value);
                      });
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1),
                  _SelectTile(
                    icon: FontAwesomeIcons.language,
                    title: 'Language',
                    value: _settings?.language ?? 'English',
                    onTap: () => _showLanguageDialog(),
                  ),
                  const Divider(height: 1),
                  _SelectTile(
                    icon: FontAwesomeIcons.palette,
                    title: 'Theme',
                    value: _settings?.theme ?? 'Light',
                    onTap: () => _showThemeDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Delivery Settings Section
            _SectionHeader(title: 'Delivery Settings'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                children: [
                  _SwitchTile(
                    icon: FontAwesomeIcons.locationDot,
                    title: 'Location Services',
                    subtitle: 'Allow app to access your location',
                    value: _settings?.locationServices ?? true,
                    onChanged: (value) {
                      setState(() {
                        _settings =
                            _settings?.copyWith(locationServices: value);
                      });
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1),
                  _SwitchTile(
                    icon: FontAwesomeIcons.circleCheck,
                    title: 'Auto-Accept Deliveries',
                    subtitle: 'Automatically accept nearby deliveries',
                    value: _settings?.autoAcceptDeliveries ?? false,
                    onChanged: (value) {
                      setState(() {
                        _settings =
                            _settings?.copyWith(autoAcceptDeliveries: value);
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account Actions Section
            _SectionHeader(title: 'Account'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                children: [
                  _ActionTile(
                    icon: FontAwesomeIcons.trashCan,
                    title: 'Clear Cache',
                    onTap: () => _showClearCacheDialog(),
                  ),
                  const Divider(height: 1),
                  _ActionTile(
                    icon: FontAwesomeIcons.circleXmark,
                    title: 'Delete Account',
                    onTap: () => _showDeleteAccountDialog(),
                    isDestructive: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // App Info
            Center(
              child: Column(
                children: [
                  const Text(
                    'CitiMovers Rider',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Bold',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Regular',
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RadioOption(
              title: 'English',
              value: 'English',
              groupValue: _settings?.language ?? 'English',
              onChanged: (value) {
                setState(() {
                  _settings = _settings?.copyWith(language: value!);
                });
                Navigator.pop(context);
                _saveSettings();
              },
            ),
            _RadioOption(
              title: 'Filipino',
              value: 'Filipino',
              groupValue: _settings?.language ?? 'English',
              onChanged: (value) {
                setState(() {
                  _settings = _settings?.copyWith(language: value!);
                });
                Navigator.pop(context);
                _saveSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RadioOption(
              title: 'Light',
              value: 'Light',
              groupValue: _settings?.theme ?? 'Light',
              onChanged: (value) {
                setState(() {
                  _settings = _settings?.copyWith(theme: value!);
                });
                Navigator.pop(context);
                _saveSettings();
              },
            ),
            _RadioOption(
              title: 'Dark',
              value: 'Dark',
              groupValue: _settings?.theme ?? 'Light',
              onChanged: (value) {
                setState(() {
                  _settings = _settings?.copyWith(theme: value!);
                });
                Navigator.pop(context);
                _saveSettings();
              },
            ),
            _RadioOption(
              title: 'System',
              value: 'System',
              groupValue: _settings?.theme ?? 'Light',
              onChanged: (value) {
                setState(() {
                  _settings = _settings?.copyWith(theme: value!);
                });
                Navigator.pop(context);
                _saveSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              UIHelpers.showSuccessToast('Cache cleared');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _authService.requestAccountDeletion();
              if (success) {
                // Navigate to login screen after deletion
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                }
              } else {
                UIHelpers.showErrorToast('Failed to delete account');
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontFamily: 'Bold',
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: AppColors.primaryRed,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontFamily: 'Medium',
          color: AppColors.textPrimary,
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
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryRed,
      ),
    );
  }
}

class _SelectTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SelectTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: AppColors.primaryRed,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontFamily: 'Medium',
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondary,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      onTap: onTap,
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String title;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioOption({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppColors.primaryRed,
    );
  }
}
