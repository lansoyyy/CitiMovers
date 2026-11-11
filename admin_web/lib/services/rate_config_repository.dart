import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRateConfigRepository {
  AdminRateConfigRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> vehicleTypes = [
    'Sedan',
    'AUV',
    '4-Wheeler Closed Van',
    '6-Wheeler Closed Van',
    '6-Wheeler Forward Wingvan',
    '10-Wheeler Wingvan',
    '20-Footer Trailer',
    '40-Footer Trailer',
  ];

  static Future<Map<String, dynamic>> getRatesConfig() async {
    final doc = await _db.collection('configs').doc('rates').get();
    final raw = doc.data();
    if (raw == null) return _defaultRatesDocument();
    final version = (raw['formulaVersion'] as num?)?.toInt() ?? 1;
    if (version >= 2) return raw;

    final migrated = Map<String, dynamic>.from(raw);
    final codRates = Map<String, dynamic>.from(migrated['codRates'] ?? {});
    final rawTenWheeler = codRates['10-Wheeler Wingvan'];
    if (rawTenWheeler is Map) {
      final numerator = _toDouble(rawTenWheeler['fuelMultiplierNumerator']);
      final denominator =
          _toDouble(rawTenWheeler['fuelMultiplierDenominator']);
      final legacyMinFare = _toDouble(rawTenWheeler['minFare']) == 19500;
      if ((numerator == 3 && denominator == 2) || legacyMinFare) {
        final defaults = _defaultRatesDocument()['codRates'];
        if (defaults is Map) {
          codRates['10-Wheeler Wingvan'] = defaults['10-Wheeler Wingvan'];
        }
      }
    }
    migrated['codRates'] = codRates;
    return migrated;
  }

  static Future<double> getFuelPrice() async {
    final ratesDoc = await _db.collection('configs').doc('rates').get();
    final version =
        (ratesDoc.data()?['formulaVersion'] as num?)?.toInt() ?? 1;
    final doc = await _db.collection('configs').doc('app').get();
    final fuel = doc.data()?['fuel'];
    if (fuel is num) {
      final price = fuel.toDouble();
      if (version < 2 && price == 130) return 95;
      return price;
    }
    return 95;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static Future<void> saveRatesConfig({
    required Map<String, dynamic> codRates,
    required Map<String, double> contractDefaults,
    required double fuelPrice,
  }) async {
    await _db.collection('configs').doc('rates').set(
      {
        'codRates': codRates,
        'contractDefaults': contractDefaults,
        'formulaVersion': 2,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _db.collection('configs').doc('app').set(
      {'fuel': fuelPrice},
      SetOptions(merge: true),
    );
  }

  static Map<String, dynamic> _defaultRatesDocument() {
    return {
      'codRates': {
        'Sedan': {
          'baseFare': 150,
          'perKmRate': 12,
          'formulaType': 'linear',
          'minFare': 0,
        },
        'AUV': {
          'baseFare': 100,
          'perKmRate': 15,
          'formulaType': 'linear',
          'minFare': 0,
        },
        '4-Wheeler Closed Van': {
          'baseFare': 150,
          'perKmRate': 20,
          'formulaType': 'linear',
          'minFare': 0,
        },
        '6-Wheeler Closed Van': {
          'baseFare': 300,
          'perKmRate': 35,
          'formulaType': 'linear',
          'minFare': 0,
        },
        '6-Wheeler Forward Wingvan': {
          'baseFare': 500,
          'perKmRate': 50,
          'formulaType': 'linear',
          'minFare': 0,
        },
        '10-Wheeler Wingvan': {
          'baseFare': 0,
          'perKmRate': 0,
          'formulaType': 'fuel_10wheeler',
          'minFare': 17272.73,
          'fuelMultiplierNumerator': 5,
          'fuelMultiplierDenominator': 2.75,
        },
        '20-Footer Trailer': {
          'baseFare': 0,
          'perKmRate': 0,
          'formulaType': 'fuel_20footer',
          'minFare': 15600,
          'fuelMultiplierNumerator': 3,
          'fuelMultiplierDenominator': 2.5,
        },
        '40-Footer Trailer': {
          'baseFare': 0,
          'perKmRate': 0,
          'formulaType': 'fuel_40footer',
          'minFare': 20800,
          'fuelMultiplierNumerator': 4,
          'fuelMultiplierDenominator': 2.5,
        },
      },
      'contractDefaults': {
        'Sedan': 3500,
        'AUV': 4500,
        '4-Wheeler Closed Van': 6500,
        '6-Wheeler Closed Van': 9500,
        '6-Wheeler Forward Wingvan': 12500,
        '10-Wheeler Wingvan': 23400,
        '20-Footer Trailer': 28000,
        '40-Footer Trailer': 36000,
      },
    };
  }
}
