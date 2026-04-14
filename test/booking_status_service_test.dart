import 'package:citimovers/services/booking_status_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookingStatusService.normalizeStatus', () {
    test('maps legacy assigned and transit aliases', () {
      expect(
        BookingStatusService.normalizeStatus('driver_assigned'),
        BookingStatusService.STATUS_ACCEPTED,
      );
      expect(
        BookingStatusService.normalizeStatus('in_progress'),
        BookingStatusService.STATUS_IN_TRANSIT,
      );
    });

    test('maps legacy cancellation aliases', () {
      expect(
        BookingStatusService.normalizeStatus('customer_cancelled'),
        BookingStatusService.STATUS_CANCELLED_BY_CUSTOMER,
      );
      expect(
        BookingStatusService.normalizeStatus('rider_cancelled'),
        BookingStatusService.STATUS_CANCELLED_BY_RIDER,
      );
    });
  });

  group('BookingStatusService.canBeCancelled', () {
    test('allows customer cancellation for legacy assigned states', () {
      expect(BookingStatusService.canBeCancelled('driver_assigned'), isTrue);
    });

    test('blocks customer cancellation after transit starts', () {
      expect(BookingStatusService.canBeCancelled('in_transit'), isFalse);
    });
  });

  group('BookingStatusService.isAssignedRiderLiveStatus', () {
    test('treats loading and unloading states as live rider work', () {
      expect(BookingStatusService.isAssignedRiderLiveStatus('loading'), isTrue);
      expect(
        BookingStatusService.isAssignedRiderLiveStatus('unloading'),
        isTrue,
      );
    });

    test('treats cancelled and completed states as not live', () {
      expect(
        BookingStatusService.isAssignedRiderLiveStatus('customer_cancelled'),
        isFalse,
      );
      expect(
          BookingStatusService.isAssignedRiderLiveStatus('delivered'), isFalse);
    });
  });

  group('BookingStatusService.canAdminCancel', () {
    test('allows admin cancellation for active trips', () {
      expect(BookingStatusService.canAdminCancel('unloading'), isTrue);
    });

    test('blocks admin cancellation for final states', () {
      expect(BookingStatusService.canAdminCancel('completed'), isFalse);
      expect(
        BookingStatusService.canAdminCancel('cancelled_by_customer'),
        isFalse,
      );
    });
  });
}
