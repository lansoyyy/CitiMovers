import 'package:admin_web/utils/dispatch_map_colocation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('ridersNear returns riders within the configured radius', () {
    const depot = LatLng(14.5995, 120.9842);
    const nearbyPoint = LatLng(14.59952, 120.98422);
    const farPoint = LatLng(14.61, 120.99);

    final riders = [
      {
        'id': 'rider-a',
        'plateNumber': 'ABC 1234',
        'currentLatitude': depot.latitude,
        'currentLongitude': depot.longitude,
      },
      {
        'id': 'rider-b',
        'plateNumber': 'XYZ 9999',
        'currentLatitude': nearbyPoint.latitude,
        'currentLongitude': nearbyPoint.longitude,
      },
      {
        'id': 'rider-c',
        'plateNumber': 'FAR 0001',
        'currentLatitude': farPoint.latitude,
        'currentLongitude': farPoint.longitude,
      },
    ];

    final nearby = DispatchMapColocation.ridersNear(riders, depot);

    expect(nearby.length, 2);
    expect(nearby.map((rider) => rider['id']), ['rider-a', 'rider-b']);
  });

  test('ridersNear sorts results by plate number', () {
    const point = LatLng(14.5995, 120.9842);

    final riders = [
      {
        'id': '2',
        'plateNumber': 'ZZZ 9999',
        'currentLatitude': point.latitude,
        'currentLongitude': point.longitude,
      },
      {
        'id': '1',
        'plateNumber': 'AAA 1111',
        'currentLatitude': point.latitude,
        'currentLongitude': point.longitude,
      },
    ];

    final nearby = DispatchMapColocation.ridersNear(riders, point);

    expect(nearby.first['id'], '1');
    expect(nearby.last['id'], '2');
  });
}
