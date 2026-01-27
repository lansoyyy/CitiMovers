import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../../utils/app_colors.dart';

/// Supported languages for the app
enum AppLanguage {
  english('English', 'en', '🇺🇸');
  // filipino('Filipino', 'fil', '🇵🇭'),
  // spanish('Español', 'es', '🇪🇸'),
  // chinese('中文', 'zh', '🇨🇳'),
  // japanese('日本語', 'ja', '🇯🇵'),
  // korean('한국어', 'ko', '🇰🇷');

  const AppLanguage(this.displayName, this.code, this.flag);

  final String displayName;
  final String code;
  final String flag;
}

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final GetStorage _storage = GetStorage();
  AppLanguage _selectedLanguage = AppLanguage.english;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  void _loadLanguage() {
    final savedLanguageCode = _storage.read('appLanguage') as String?;
    if (savedLanguageCode != null) {
      final language = AppLanguage.values.firstWhere(
        (lang) => lang.code == savedLanguageCode,
        orElse: () => AppLanguage.english,
      );
      setState(() {
        _selectedLanguage = language;
      });
    }
  }

  Future<void> _saveLanguage(AppLanguage language) async {
    await _storage.write('appLanguage', language.code);
    setState(() {
      _selectedLanguage = language;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Language changed to ${language.displayName}'),
          backgroundColor: AppColors.success,
        ),
      );
    }

    // Note: In a production app, you would typically:
    // 1. Update the app's locale using a localization package like flutter_localizations
    // 2. Reload the app or rebuild the widget tree with the new locale
    // 3. Persist the language preference to user's profile in Firestore
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
          'Language',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    Icons.translate,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select your preferred language for the CitiMovers app.',
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

            const SizedBox(height: 24),

            // Language List
            const Text(
              'Available Languages',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            ...AppLanguage.values.map((language) {
              return _buildLanguageTile(language);
            }).toList(),

            const SizedBox(height: 32),

            // Note Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Language translations are currently in progress. Some features may still display in English.',
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
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile(AppLanguage language) {
    final isSelected = _selectedLanguage == language;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => _saveLanguage(language),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              language.flag,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        title: Text(
          language.displayName,
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Medium',
            color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          language.code.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Regular',
            color: AppColors.textSecondary,
          ),
        ),
        trailing: isSelected
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.white,
                  size: 20,
                ),
              )
            : null,
      ),
    );
  }
}
