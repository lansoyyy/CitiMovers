import 'package:citimovers/services/booking_service.dart';
import 'package:citimovers/services/rate_config_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RateConfigService', () {
    test('calculates linear cod fare without peak surcharge', () {
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

      expect(offPeak, 150 + (10 * 12));
      expect(peak, offPeak);
    });

    test('calculates the 10-wheeler fuel formula', () {
      final fare = RateConfigService.instance.calculateCodFare(
        distanceKm: 130,
        vehicleType: '10-Wheeler Wingvan',
      );

      expect(fare, closeTo(130 * 5 / 2.75 * 95, 0.01));
    });

    test('resolves contract fare from user rates first', () async {
      final fare = await RateConfigService.instance.resolveContractFare(
        vehicleType: '10-Wheeler Wingvan',
        userContractRates: {'10-Wheeler Wingvan': 25000},
      );

      expect(fare, 25000);
    });

    test('booking fare uses distance and vehicle formula', () async {
      final fare = await BookingService.resolveBookingFare(
        distanceKm: 130,
        vehicleType: '10-Wheeler Wingvan',
      );

      expect(fare, closeTo(130 * 5 / 2.75 * 95, 0.01));
    });
  });
}
