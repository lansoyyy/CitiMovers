import 'package:get_storage/get_storage.dart';

/// Language Service for CitiMovers
/// Manages app language settings and monitoring
class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal() {
    _loadLanguageFromStorage();
  }

  final GetStorage _storage = GetStorage();

  static const String _keyLanguage = 'app_language';
  static const String _keyShowAmounts = 'show_amounts';

  String? _currentLanguage;
  bool _showAmounts = true;

  /// Get current language
  String? get currentLanguage => _currentLanguage;

  /// Get whether amounts are shown
  bool get showAmounts => _showAmounts;

  /// Load language from storage
  void _loadLanguageFromStorage() {
    _currentLanguage = _storage.read(_keyLanguage) as String? ?? 'en';
    _showAmounts = _storage.read(_keyShowAmounts) as bool? ?? true;
  }

  /// Set language
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    await _storage.write(_keyLanguage, language);
  }

  /// Toggle amount display
  Future<void> toggleShowAmounts(bool show) async {
    _showAmounts = show;
    await _storage.write(_keyShowAmounts, show);
  }

  /// Get localized string
  String getLocalizedText(Map<String, String> texts) {
    final lang = _currentLanguage ?? 'en';
    return texts[lang] ?? texts['en'] ?? '';
  }
}
