import 'package:citimovers/rider/services/rider_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiderAuthService.plateNumberQueryVariants', () {
    test('includes uppercase, lowercase, and spaced forms', () {
      final variants = RiderAuthService.plateNumberQueryVariants('ccp7285');

      expect(variants, contains('CCP7285'));
      expect(variants, contains('ccp7285'));
      expect(variants, contains('CCP 7285'));
      expect(variants, contains('ccp 7285'));
    });

    test('normalizes input with spaces before building variants', () {
      final variants = RiderAuthService.plateNumberQueryVariants('CCP 7285');

      expect(variants, contains('CCP7285'));
      expect(variants, contains('ccp7285'));
    });

    test('handles plates without a letter-number split', () {
      final variants = RiderAuthService.plateNumberQueryVariants('12345');

      expect(variants, ['12345']);
    });
  });

  group('RiderAuthService.normalizePlateNumber', () {
    test('strips spaces and uppercases plate numbers', () {
      expect(
        RiderAuthService.normalizePlateNumber(' ccp 7285 '),
        'CCP7285',
      );
    });
  });
}
