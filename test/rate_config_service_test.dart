import 'package:citimovers/services/rate_config_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RateConfigService', () {
    test('calculates linear cod fare with peak surcharge', () {
      final fare = RateConfigService.instance.calculateCodFare(
        distanceKm: 10,
        vehicleType: 'Sedan',
        referenceTime: DateTime(2026, 5, 28, 12),
      );

      expect(fare, 150 + (10 * 12));
    });

    test('applies peak surcharge during rush hour', () {
      final offPeak = RateConfigService.instance.calculateCodFare(
        distanceKm: 10,
        vehicleType: 'Sedan',
        referenceTime: DateTime(2026, 5, 28, 12),
      );
      final peak = RateConfigService.instance.calculateCodFare(
        distanceKm: 10,
        vehicleType: 'Sedan',
        referenceTime: DateTime(2026, 5, 28, 8),
      );

      expect(peak, greaterThan(offPeak));
    });

    test('resolves contract fare from user rates first', () async {
      final fare = await RateConfigService.instance.resolveContractFare(
        vehicleType: '10-Wheeler Wingvan',
        userContractRates: {'10-Wheeler Wingvan': 25000},
      );

      expect(fare, 25000);
    });
  });
}
