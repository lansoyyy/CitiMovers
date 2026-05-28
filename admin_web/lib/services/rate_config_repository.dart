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
    return doc.data() ?? _defaultRatesDocument();
  }

  static Future<double> getFuelPrice() async {
    final doc = await _db.collection('configs').doc('app').get();
    final fuel = doc.data()?['fuel'];
    if (fuel is num) return fuel.toDouble();
    return 130;
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
          'peakSurchargePercent': 20,
        },
        'AUV': {
          'baseFare': 100,
          'perKmRate': 15,
          'formulaType': 'linear',
          'minFare': 0,
          'peakSurchargePercent': 20,
        },
        '4-Wheeler Closed Van': {
          'baseFare': 150,
          'perKmRate': 20,
          'formulaType': 'linear',
          'minFare': 0,
          'peakSurchargePercent': 20,
        },
        '6-Wheeler Closed Van': {
          'baseFare': 300,
          'perKmRate': 35,
          'formulaType': 'linear',
          'minFare': 0,
          'peakSurchargePercent': 20,
        },
        '6-Wheeler Forward Wingvan': {
          'baseFare': 500,
          'perKmRate': 50,
          'formulaType': 'linear',
          'minFare': 0,
          'peakSurchargePercent': 20,
        },
        '10-Wheeler Wingvan': {
          'baseFare': 0,
          'perKmRate': 0,
          'formulaType': 'fuel_10wheeler',
          'minFare': 19500,
          'peakSurchargePercent': 20,
          'fuelMultiplierNumerator': 3,
          'fuelMultiplierDenominator': 2,
        },
        '20-Footer Trailer': {
          'baseFare': 0,
          'perKmRate': 0,
          'formulaType': 'fuel_20footer',
          'minFare': 15600,
          'peakSurchargePercent': 20,
          'fuelMultiplierNumerator': 3,
          'fuelMultiplierDenominator': 2.5,
        },
        '40-Footer Trailer': {
          'baseFare': 0,
          'perKmRate': 0,
          'formulaType': 'fuel_40footer',
          'minFare': 20800,
          'peakSurchargePercent': 20,
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
