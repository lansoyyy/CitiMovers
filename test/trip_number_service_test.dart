import 'package:citimovers/services/trip_number_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripNumberService', () {
    final service = TripNumberService();

    test('builds a daily date key in YYYY-MM-DD format', () {
      expect(service.buildDateKey(DateTime(2026, 4, 9)), '2026-04-09');
    });

    test('builds a zero-padded trip number that resets by date key', () {
      expect(
        service.buildTripNumber(DateTime(2026, 4, 9), 1),
        '2026-04-09-00001',
      );
      expect(
        service.buildTripNumber(DateTime(2026, 4, 9), 27),
        '2026-04-09-00027',
      );
    });
  });
}
