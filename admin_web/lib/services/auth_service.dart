import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class AdminAuthService {
  static final AdminAuthService _instance = AdminAuthService._internal();
  factory AdminAuthService() => _instance;
  AdminAuthService._internal();

  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool(AdminConstants.sessionKey) ?? false;
  }

  Future<bool> login(String username, String password) async {
    if (username.trim() == AdminConstants.adminUsername &&
        password == AdminConstants.adminPassword) {
      _isAuthenticated = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AdminConstants.sessionKey, true);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AdminConstants.sessionKey);
  }
}
