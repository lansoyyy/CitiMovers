import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class AdminAuthService {
  static final AdminAuthService _instance = AdminAuthService._internal();
  factory AdminAuthService() => _instance;
  AdminAuthService._internal();

  bool _isAuthenticated = false;
  String _role = 'admin'; // 'admin' | 'coordinator' | 'manager' | 'president'

  bool get isAuthenticated => _isAuthenticated;
  String get currentRole => _role;

  /// Returns true if the logged-in user is a coordinator (CSR-only access).
  bool get isCoordinator => _role == 'coordinator';

  /// Returns true if the logged-in user can handle manager-queue tickets.
  bool get isManager =>
      _role == 'manager' || _role == 'admin' || _role == 'president';

  /// Returns true if the logged-in user can handle presidential-appeal tickets.
  bool get isPresident => _role == 'admin' || _role == 'president';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool(AdminConstants.sessionKey) ?? false;
    _role = prefs.getString(AdminConstants.sessionRoleKey) ?? 'admin';
  }

  Future<bool> login(String username, String password) async {
    String? role;
    if (username.trim() == AdminConstants.adminUsername &&
        password == AdminConstants.adminPassword) {
      role = 'admin';
    } else if (username.trim() == AdminConstants.coordinatorUsername &&
        password == AdminConstants.coordinatorPassword) {
      role = 'coordinator';
    } else if (username.trim() == AdminConstants.managerUsername &&
        password == AdminConstants.managerPassword) {
      role = 'manager';
    } else if (username.trim() == AdminConstants.presidentUsername &&
        password == AdminConstants.presidentPassword) {
      role = 'president';
    }

    if (role != null) {
      _isAuthenticated = true;
      _role = role;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AdminConstants.sessionKey, true);
      await prefs.setString(AdminConstants.sessionRoleKey, role);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _role = 'admin';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AdminConstants.sessionKey);
    await prefs.remove(AdminConstants.sessionRoleKey);
  }
}
