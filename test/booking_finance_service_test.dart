import 'package:citimovers/services/booking_finance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookingFinanceService.calculate', () {
    test('computes gross, partner net, admin fee, and VAT from fare totals',
        () {
      final breakdown = BookingFinanceService.calculate(
        estimatedFare: 10000,
        loadingDemurrageFee: 500,
        unloadingDemurrageFee: 250,
        tipAmount: 250,
      );

      expect(breakdown.grossAmount, 11000);
      expect(breakdown.partnerNetAmount, 8800);
      expect(breakdown.adminFeeAmount, 2200);
      expect(breakdown.vatAmount, 220);
      expect(breakdown.adminNetAmount, 1980);
    });

    test('keeps a higher persisted final fare when resolving totals', () {
      final resolved = BookingFinanceService.resolveGrossAmount(
        estimatedFare: 10000,
        loadingDemurrageFee: 500,
        unloadingDemurrageFee: 250,
        tipAmount: 250,
        persistedFinalFare: 11500,
      );

      expect(resolved, 11500);
    });
  });
}
