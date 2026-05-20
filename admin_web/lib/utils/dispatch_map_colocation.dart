import 'package:latlong2/latlong.dart';

class DispatchMapColocation {
  DispatchMapColocation._();

  static const double defaultRadiusMeters = 50;
  static const Distance _distance = Distance();

  static LatLng? riderPoint(Map<String, dynamic> rider) {
    final lat = rider['currentLatitude'];
    final lng = rider['currentLongitude'];
    if (lat is! num || lng is! num) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  static List<Map<String, dynamic>> ridersNear(
    List<Map<String, dynamic>> riders,
    LatLng point, {
    double radiusMeters = defaultRadiusMeters,
  }) {
    final nearby = <Map<String, dynamic>>[];

    for (final rider in riders) {
      final riderLocation = riderPoint(rider);
      if (riderLocation == null) continue;

      final meters = _distance.as(LengthUnit.Meter, riderLocation, point);
      if (meters <= radiusMeters) {
        nearby.add(rider);
      }
    }

    nearby.sort((a, b) {
      final plateCompare = (a['plateNumber'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['plateNumber'] ?? '').toString().toLowerCase());
      if (plateCompare != 0) return plateCompare;

      return (a['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase());
    });

    return nearby;
  }
}
