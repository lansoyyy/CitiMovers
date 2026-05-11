import 'package:citimovers/rider/models/rider_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiderModel.fromMap', () {
    test('restores mixed cached value types without throwing', () {
      final rider = RiderModel.fromMap({
        'riderId': 9171234567,
        'name': 'Juan Dela Cruz',
        'phoneNumber': 9171234567,
        'email': 123,
        'photoUrl': Uri.parse('https://example.com/rider.jpg'),
        'vehicleType': null,
        'vehiclePlateNumber': 4567,
        'vehicleModel': 2024,
        'vehicleColor': true,
        'accountStatus': 1,
        'isOnline': 'true',
        'rating': '4.8',
        'totalDeliveries': '12',
        'totalEarnings': '1999.50',
        'currentLatitude': '14.5995',
        'currentLongitude': '120.9842',
        'createdAt': '2026-05-12T08:30:00.000Z',
        'updatedAt': '2026-05-12T09:30:00.000Z',
      });

      expect(rider.riderId, '9171234567');
      expect(rider.phoneNumber, '9171234567');
      expect(rider.email, '123');
      expect(rider.photoUrl, 'https://example.com/rider.jpg');
      expect(rider.vehicleType, 'AUV');
      expect(rider.vehiclePlateNumber, '4567');
      expect(rider.vehicleModel, '2024');
      expect(rider.vehicleColor, 'true');
      expect(rider.status, '1');
      expect(rider.isOnline, isTrue);
      expect(rider.rating, closeTo(4.8, 0.0001));
      expect(rider.totalDeliveries, 12);
      expect(rider.totalEarnings, closeTo(1999.5, 0.0001));
      expect(rider.currentLatitude, closeTo(14.5995, 0.0001));
      expect(rider.currentLongitude, closeTo(120.9842, 0.0001));
    });

    test('restores nested helper maps from cached rider data', () {
      final rider = RiderModel.fromMap({
        'riderId': '+639171234567',
        'name': 'Juan Dela Cruz',
        'phoneNumber': '+639171234567',
        'vehicleType': 'Truck',
        'status': 'active',
        'createdAt': '2026-05-12T08:30:00.000Z',
        'updatedAt': '2026-05-12T09:30:00.000Z',
        'helper1': {
          'name': 'Mario Santos',
          'phoneNumber': 9123456789,
          'photoUrl': Uri.parse('https://example.com/helper.jpg'),
          'documents': {
            'valid_id': {'url': 'https://example.com/id.jpg'},
          },
        },
      });

      expect(rider.helper1, isNotNull);
      expect(rider.helper1!.name, 'Mario Santos');
      expect(rider.helper1!.phoneNumber, '9123456789');
      expect(rider.helper1!.photoUrl, 'https://example.com/helper.jpg');
      expect(rider.helper1!.documents, contains('valid_id'));
    });
  });
}