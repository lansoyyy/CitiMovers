import 'package:citimovers/utils/rider_booking_capacity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> booking(
    String id,
    String type, {
    String status = 'accepted',
  }) {
    return {
      'bookingId': id,
      'bookingType': type,
      'status': status,
    };
  }

  group('RiderBookingCapacity.normalizeType', () {
    test('keeps scheduled bookings distinct', () {
      expect(
        RiderBookingCapacity.normalizeType('scheduled'),
        RiderBookingCapacity.scheduledType,
      );
      expect(RiderBookingCapacity.isScheduled('SCHEDULED'), isTrue);
    });

    test('treats now and on-demand bookings as realtime pickup', () {
      expect(
        RiderBookingCapacity.normalizeType('now'),
        RiderBookingCapacity.realtimeType,
      );
      expect(
        RiderBookingCapacity.normalizeType('on_demand'),
        RiderBookingCapacity.realtimeType,
      );
      expect(
        RiderBookingCapacity.normalizeType(null),
        RiderBookingCapacity.realtimeType,
      );
    });
  });

  group('RiderBookingCapacity.conflictMessage', () {
    test('allows one scheduled plus one realtime booking', () {
      final conflict = RiderBookingCapacity.conflictMessage(
        candidateBookingType: 'now',
        liveBookings: [booking('scheduled-1', 'scheduled')],
      );
      expect(conflict, isNull);
    });

    test('blocks a second realtime booking', () {
      final conflict = RiderBookingCapacity.conflictMessage(
        candidateBookingType: 'now',
        liveBookings: [booking('realtime-1', 'now')],
      );
      expect(conflict, contains('active realtime pickup booking'));
    });

    test('blocks a second scheduled booking', () {
      final conflict = RiderBookingCapacity.conflictMessage(
        candidateBookingType: 'scheduled',
        liveBookings: [booking('scheduled-1', 'scheduled')],
      );
      expect(conflict, contains('active scheduled booking'));
    });

    test('blocks any third booking when both slots are occupied', () {
      final conflict = RiderBookingCapacity.conflictMessage(
        candidateBookingType: 'on_demand',
        liveBookings: [
          booking('scheduled-1', 'scheduled'),
          booking('realtime-1', 'on_demand'),
        ],
      );
      expect(conflict, contains('maximum of 2 active bookings'));
    });

    test('ignores the booking being accepted', () {
      final conflict = RiderBookingCapacity.conflictMessage(
        candidateBookingType: 'now',
        liveBookings: [booking('realtime-1', 'now')],
        excludingBookingId: 'realtime-1',
      );
      expect(conflict, isNull);
    });
  });

  group('RiderBookingCapacity.slotConflictMessage', () {
    test('allows filling the opposite slot', () {
      final conflict = RiderBookingCapacity.slotConflictMessage(
        candidateBookingType: 'now',
        scheduledBookingId: 'scheduled-1',
        realtimeBookingId: null,
        candidateBookingId: 'realtime-2',
      );
      expect(conflict, isNull);
    });

    test('blocks a duplicate type in the same slot', () {
      final conflict = RiderBookingCapacity.slotConflictMessage(
        candidateBookingType: 'scheduled',
        scheduledBookingId: 'scheduled-1',
        realtimeBookingId: null,
        candidateBookingId: 'scheduled-2',
      );
      expect(conflict, contains('active scheduled booking'));
    });

    test('blocks a third booking when both slots are occupied', () {
      final conflict = RiderBookingCapacity.slotConflictMessage(
        candidateBookingType: 'now',
        scheduledBookingId: 'scheduled-1',
        realtimeBookingId: 'realtime-1',
        candidateBookingId: 'realtime-2',
      );
      expect(conflict, contains('maximum of 2 active bookings'));
    });

    test('allows the booking that already owns the slot', () {
      final conflict = RiderBookingCapacity.slotConflictMessage(
        candidateBookingType: 'now',
        scheduledBookingId: null,
        realtimeBookingId: 'realtime-1',
        candidateBookingId: 'realtime-1',
      );
      expect(conflict, isNull);
    });
  });
}
