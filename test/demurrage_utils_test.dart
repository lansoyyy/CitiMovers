import 'package:citimovers/utils/demurrage_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemurrageUtils.calculateFee', () {
    test('does not charge below the first 4-hour block', () {
      final fee = DemurrageUtils.calculateFee(
        const Duration(hours: 3, minutes: 59),
        1000,
      );

      expect(fee, 0);
    });

    test('charges one block at exactly four hours', () {
      final fee = DemurrageUtils.calculateFee(
        const Duration(hours: 4),
        1000,
      );

      expect(fee, 250);
    });

    test('keeps accumulating across midnight based on elapsed duration', () {
      final start = DateTime(2026, 3, 25, 22, 0);
      final end = DateTime(2026, 3, 26, 7, 0);

      final fee = DemurrageUtils.calculateFee(end.difference(start), 800);

      expect(fee, 400);
    });
  });
}
