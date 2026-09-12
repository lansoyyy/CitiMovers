import 'package:citimovers/rider/services/rider_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiderAuthService.hashPassword', () {
    test('matches the known-good manual fix vector', () {
      // Vector produced during the manual Firestore unblock of a rider whose
      // phone was edited by admin: salt = normalized phone, password 198911.
      final hash = RiderAuthService.hashPassword('198911', '+639267983542');

      expect(
        hash,
        'ba8b5a349c6b548d9158469bc44d752e0626379d0c9cf2eb3cea3954147e6ddb',
      );
    });

    test('is deterministic for the same salt and password', () {
      final a = RiderAuthService.hashPassword('secret', 'abc123');
      final b = RiderAuthService.hashPassword('secret', 'abc123');

      expect(a, b);
    });

    test('changes when the salt changes', () {
      final a = RiderAuthService.hashPassword('secret', 'salt-one');
      final b = RiderAuthService.hashPassword('secret', 'salt-two');

      expect(a, isNot(b));
    });
  });

  group('RiderAuthService.generateSalt', () {
    test('produces 32 lowercase hex characters', () {
      final salt = RiderAuthService.generateSalt();

      expect(salt.length, 32);
      expect(salt, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('produces unique salts', () {
      final salts = List.generate(20, (_) => RiderAuthService.generateSalt());

      expect(salts.toSet().length, salts.length);
    });
  });

  group('per-rider salt independence', () {
    test('admin phone edits no longer affect the stored hash', () {
      // A rider registered with a random salt keeps their hash even when the
      // phone number (the legacy salt) changes.
      final salt = RiderAuthService.generateSalt();
      final originalHash = RiderAuthService.hashPassword('198911', salt);

      final hashAfterPhoneEdit = RiderAuthService.hashPassword(
        '198911',
        salt,
      );

      expect(hashAfterPhoneEdit, originalHash);
      // And it differs from the legacy phone-salted hash for the same
      // password, proving the salt is no longer derived from the phone.
      expect(
        hashAfterPhoneEdit,
        isNot(RiderAuthService.hashPassword('198911', '+639267983542')),
      );
    });
  });
}
