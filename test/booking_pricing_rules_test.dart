import 'package:citimovers/models/booking_model.dart';
import 'package:citimovers/models/location_model.dart';
import 'package:citimovers/models/vehicle_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookingModel pricing rules', () {
    test('computes total fare from locked fare, demurrage, and tip', () {
      final booking = _buildBooking(
        finalFare: null,
        loadingDemurrageFee: 1500,
        unloadingDemurrageFee: 500,
        tipAmount: 200,
      );

      expect(booking.totalDemurrageFee, 2000);
      expect(booking.totalFare, 27200);
    });

    test('does not allow persisted final fare to fall below locked fare', () {
      final booking = _buildBooking(
        finalFare: 19000,
        loadingDemurrageFee: 0,
        unloadingDemurrageFee: 0,
      );

      expect(booking.lockedFare, 25000);
      expect(booking.totalFare, 25000);
    });
  });

  group('BookingModel cancellation rules', () {
    test('allows cancellation while payment is locked', () {
      final booking = _buildBooking(status: 'payment_locked');

      expect(booking.canBeCancelled, isTrue);
    });

    test('blocks cancellation after the trip is in transit', () {
      final booking = _buildBooking(status: 'in_transit');

      expect(booking.canBeCancelled, isFalse);
    });
  });
}

BookingModel _buildBooking({
  String status = 'pending',
  double? finalFare = 25000,
  double? loadingDemurrageFee,
  double? unloadingDemurrageFee,
  double? tipAmount,
}) {
  return BookingModel(
    bookingId: 'booking-1',
    customerId: 'customer-1',
    customerName: 'Customer',
    customerPhone: '09170000000',
    driverId: 'rider-1',
    pickupLocation: LocationModel(
      address: 'Pickup',
      latitude: 14.0,
      longitude: 121.0,
    ),
    dropoffLocation: LocationModel(
      address: 'Dropoff',
      latitude: 15.0,
      longitude: 122.0,
    ),
    vehicle: VehicleModel(
      id: '10wheeler',
      name: '10-Wheeler Wingvan',
      type: '10-Wheeler Wingvan',
      description: 'Heavy duty transport',
      baseFare: 0,
      perKmRate: 0,
      capacity: 'Up to 12,000 kg',
      features: const ['Bulk delivery'],
      imageUrl: 'assets/images/10wheeler_wingvan.png',
    ),
    bookingType: 'now',
    distance: 100,
    estimatedFare: 25000,
    finalFare: finalFare,
    status: status,
    paymentMethod: 'Wallet',
    createdAt: DateTime(2026, 4, 4),
    loadingDemurrageFee: loadingDemurrageFee,
    unloadingDemurrageFee: unloadingDemurrageFee,
    tipAmount: tipAmount,
  );
}