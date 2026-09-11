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

    test('returns zero for negative durations (awaiting call time)', () {
      final fee = DemurrageUtils.calculateFee(
        const Duration(hours: -2),
        1000,
      );

      expect(fee, 0);
    });
  });

  group('DemurrageUtils.resolveDemurrageStart', () {
    test('late arrival counts from the actual arrival (rule 4)', () {
      final arrival = DateTime(2026, 3, 25, 11, 0);
      final callTime = DateTime(2026, 3, 25, 10, 0);

      final result = DemurrageUtils.resolveDemurrageStart(
        arrival: arrival,
        callTime: callTime,
      );

      expect(result.start, arrival);
      expect(result.source, DemurrageUtils.sourceArrival);
    });

    test(
        'early arrival with loading after the call time counts from call time '
        '(rules 1/5)', () {
      final arrival = DateTime(2026, 3, 25, 8, 0);
      final callTime = DateTime(2026, 3, 25, 10, 0);
      final loadingStart = DateTime(2026, 3, 25, 10, 30);

      final result = DemurrageUtils.resolveDemurrageStart(
        arrival: arrival,
        loadingStart: loadingStart,
        callTime: callTime,
      );

      expect(result.start, callTime);
      expect(result.source, DemurrageUtils.sourceCallTime);
    });

    test(
        'early arrival with loading before the call time counts from the '
        'loading start (rule 6)', () {
      final arrival = DateTime(2026, 3, 25, 8, 0);
      final callTime = DateTime(2026, 3, 25, 10, 0);
      final loadingStart = DateTime(2026, 3, 25, 9, 0);

      final result = DemurrageUtils.resolveDemurrageStart(
        arrival: arrival,
        loadingStart: loadingStart,
        callTime: callTime,
      );

      expect(result.start, loadingStart);
      expect(result.source, DemurrageUtils.sourceLoadingStart);
    });

    test('no call time degrades gracefully to the arrival', () {
      final arrival = DateTime(2026, 3, 25, 11, 0);
      final loadingStart = DateTime(2026, 3, 25, 11, 30);

      final result = DemurrageUtils.resolveDemurrageStart(
        arrival: arrival,
        loadingStart: loadingStart,
      );

      expect(result.start, arrival);
      expect(result.source, DemurrageUtils.sourceArrival);
    });

    test('no call time and no loading start uses the arrival', () {
      final arrival = DateTime(2026, 3, 25, 11, 0);

      final result = DemurrageUtils.resolveDemurrageStart(arrival: arrival);

      expect(result.start, arrival);
      expect(result.source, DemurrageUtils.sourceArrival);
    });

    test('on-time arrival exactly at the call time counts from arrival', () {
      final same = DateTime(2026, 3, 25, 10, 0);

      final result = DemurrageUtils.resolveDemurrageStart(
        arrival: same,
        callTime: same,
      );

      // The call time only supersedes an EARLIER arrival; equal instants
      // keep the arrival as the demurrage start.
      expect(result.start, same);
      expect(result.source, DemurrageUtils.sourceArrival);
    });
  });
}
