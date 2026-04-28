import 'package:admin_web/config/app_constants.dart';
import 'package:admin_web/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdminAuthService.canAccessRoute', () {
    final auth = AdminAuthService();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await auth.logout();
    });

    test('allows coordinator to access assignment routes', () async {
      final success = await auth.login(
        AdminConstants.coordinatorUsername,
        AdminConstants.coordinatorPassword,
      );

      expect(success, isTrue);
      expect(auth.canAssignRiders, isTrue);
      expect(auth.canAccessRoute('/dispatch'), isTrue);
      expect(auth.canAccessRoute('/bookings'), isTrue);
      expect(auth.canAccessRoute('/bookings/booking-123'), isTrue);
      expect(auth.canAccessRoute('/support-tickets'), isTrue);
      expect(auth.canAccessRoute('/riders/rider-123'), isFalse);
      expect(auth.canAccessRoute('/finance'), isFalse);
    });

    test('keeps full route access for admin', () async {
      final success = await auth.login(
        AdminConstants.adminUsername,
        AdminConstants.adminPassword,
      );

      expect(success, isTrue);
      expect(auth.canAssignRiders, isTrue);
      expect(auth.canAccessRoute('/dispatch'), isTrue);
      expect(auth.canAccessRoute('/riders/rider-123'), isTrue);
      expect(auth.canAccessRoute('/finance'), isTrue);
    });
  });
}
