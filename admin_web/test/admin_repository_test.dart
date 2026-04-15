import 'package:admin_web/services/admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminRepository.canCancelBookingStatus', () {
    test('allows live bookings to be cancelled', () {
      expect(AdminRepository.canCancelBookingStatus('pending'), isTrue);
      expect(AdminRepository.canCancelBookingStatus('payment_locked'), isTrue);
      expect(AdminRepository.canCancelBookingStatus('loading'), isTrue);
    });

    test('blocks completed and cancelled legacy statuses', () {
      expect(AdminRepository.canCancelBookingStatus('completed'), isFalse);
      expect(AdminRepository.canCancelBookingStatus('cancelled'), isFalse);
      expect(
        AdminRepository.canCancelBookingStatus('customer_cancelled'),
        isFalse,
      );
      expect(
        AdminRepository.canCancelBookingStatus('rider_cancelled'),
        isFalse,
      );
      expect(AdminRepository.canCancelBookingStatus('delivered'), isFalse);
    });
  });
}
