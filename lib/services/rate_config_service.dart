import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class VehicleRateConfig {
  final String vehicleType;
  final double baseFare;
  final double perKmRate;
  final String formulaType;
  final double minFare;
  final double? fuelMultiplierNumerator;
  final double? fuelMultiplierDenominator;

  const VehicleRateConfig({
    required this.vehicleType,
    required this.baseFare,
    required this.perKmRate,
    this.formulaType = 'linear',
    this.minFare = 0,
    this.fuelMultiplierNumerator,
    this.fuelMultiplierDenominator,
  });

  factory VehicleRateConfig.fromMap(String vehicleType, Map<String, dynamic> map) {
    return VehicleRateConfig(
      vehicleType: vehicleType,
      baseFare: _readDouble(map['baseFare']),
      perKmRate: _readDouble(map['perKmRate']),
      formulaType: (map['formulaType'] ?? 'linear').toString(),
      minFare: _readDouble(map['minFare']),
      fuelMultiplierNumerator: _readOptionalDouble(map['fuelMultiplierNumerator']),
      fuelMultiplierDenominator:
          _readOptionalDouble(map['fuelMultiplierDenominator']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'baseFare': baseFare,
      'perKmRate': perKmRate,
      'formulaType': formulaType,
      'minFare': minFare,
      if (fuelMultiplierNumerator != null)
        'fuelMultiplierNumerator': fuelMultiplierNumerator,
      if (fuelMultiplierDenominator != null)
        'fuelMultiplierDenominator': fuelMultiplierDenominator,
    };
  }

  static double _readDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static double? _readOptionalDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class RateConfigService {
  RateConfigService._() {
    _cachedCodRates = Map<String, VehicleRateConfig>.from(defaultCodRates);
    _cachedContractDefaults = Map<String, double>.from(defaultContractRates);
  }

  static final RateConfigService instance = RateConfigService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Map<String, VehicleRateConfig>? _cachedCodRates;
  Map<String, double>? _cachedContractDefaults;
  double _fuelPricePerLiter = 95.0;
  DateTime? _lastLoadedAt;

  static Map<String, VehicleRateConfig> get defaultCodRates => {
        'Sedan': const VehicleRateConfig(
          vehicleType: 'Sedan',
          baseFare: 150,
          perKmRate: 12,
        ),
        'AUV': const VehicleRateConfig(
          vehicleType: 'AUV',
          baseFare: 100,
          perKmRate: 15,
        ),
        '4-Wheeler Closed Van': const VehicleRateConfig(
          vehicleType: '4-Wheeler Closed Van',
          baseFare: 150,
          perKmRate: 20,
        ),
        '6-Wheeler Closed Van': const VehicleRateConfig(
          vehicleType: '6-Wheeler Closed Van',
          baseFare: 300,
          perKmRate: 35,
        ),
        '6-Wheeler Forward Wingvan': const VehicleRateConfig(
          vehicleType: '6-Wheeler Forward Wingvan',
          baseFare: 500,
          perKmRate: 50,
        ),
        '10-Wheeler Wingvan': const VehicleRateConfig(
          vehicleType: '10-Wheeler Wingvan',
          baseFare: 0,
          perKmRate: 0,
          formulaType: 'fuel_10wheeler',
          minFare: 17272.73,
          fuelMultiplierNumerator: 5,
          fuelMultiplierDenominator: 2.75,
        ),
        '20-Footer Trailer': const VehicleRateConfig(
          vehicleType: '20-Footer Trailer',
          baseFare: 0,
          perKmRate: 0,
          formulaType: 'fuel_20footer',
          minFare: 15600,
          fuelMultiplierNumerator: 3,
          fuelMultiplierDenominator: 2.5,
        ),
        '40-Footer Trailer': const VehicleRateConfig(
          vehicleType: '40-Footer Trailer',
          baseFare: 0,
          perKmRate: 0,
          formulaType: 'fuel_40footer',
          minFare: 20800,
          fuelMultiplierNumerator: 4,
          fuelMultiplierDenominator: 2.5,
        ),
      };

  static Map<String, double> get defaultContractRates => {
        'Sedan': 3500,
        'AUV': 4500,
        '4-Wheeler Closed Van': 6500,
        '6-Wheeler Closed Van': 9500,
        '6-Wheeler Forward Wingvan': 12500,
        '10-Wheeler Wingvan': 23400,
        '20-Footer Trailer': 28000,
        '40-Footer Trailer': 36000,
      };

  Future<void> ensureLoaded({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedCodRates != null &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) <
            const Duration(minutes: 5)) {
      return;
    }

    try {
      final ratesDoc =
          await _firestore.collection('configs').doc('rates').get();
      final appDoc = await _firestore.collection('configs').doc('app').get();

      final fuel = appDoc.data()?['fuel'];
      if (fuel is num) {
        _fuelPricePerLiter = fuel.toDouble();
      }

      final data = ratesDoc.data() ?? {};
      final codRaw = data['codRates'];
      final contractRaw = data['contractDefaults'];
      final formulaVersion = (data['formulaVersion'] as num?)?.toInt() ?? 1;
      final rawTenWheeler =
          codRaw is Map ? codRaw['10-Wheeler Wingvan'] : null;
      double? parseRateValue(dynamic value) {
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value);
        return null;
      }

      final codRates = Map<String, VehicleRateConfig>.from(defaultCodRates);
      if (codRaw is Map) {
        codRaw.forEach((key, value) {
          if (value is Map) {
            codRates[key.toString()] = VehicleRateConfig.fromMap(
              key.toString(),
              Map<String, dynamic>.from(value),
            );
          }
        });
      }

      if (formulaVersion < 2) {
        final isLegacyTenWheeler = rawTenWheeler is Map &&
            ((parseRateValue(rawTenWheeler['fuelMultiplierNumerator']) == 3 &&
                    parseRateValue(
                          rawTenWheeler['fuelMultiplierDenominator'],
                        ) ==
                        2) ||
                parseRateValue(rawTenWheeler['minFare']) == 19500);
        if (isLegacyTenWheeler) {
          codRates['10-Wheeler Wingvan'] =
              defaultCodRates['10-Wheeler Wingvan']!;
        }
        if (_fuelPricePerLiter == 130.0) {
          _fuelPricePerLiter = 95.0;
        }
      }

      final contractDefaults = Map<String, double>.from(defaultContractRates);
      if (contractRaw is Map) {
        contractRaw.forEach((key, value) {
          final amount = switch (value) {
            num v => v.toDouble(),
            String v => double.tryParse(v),
            _ => null,
          };
          if (amount != null) {
            contractDefaults[key.toString()] = amount;
          }
        });
      }

      _cachedCodRates = codRates;
      _cachedContractDefaults = contractDefaults;
      _lastLoadedAt = DateTime.now();
    } catch (error) {
      debugPrint('RateConfigService: failed to load rates, using defaults: $error');
      _cachedCodRates ??= Map<String, VehicleRateConfig>.from(defaultCodRates);
      _cachedContractDefaults ??=
          Map<String, double>.from(defaultContractRates);
    }
  }

  Map<String, VehicleRateConfig> get codRates =>
      _cachedCodRates ?? Map<String, VehicleRateConfig>.from(defaultCodRates);

  Map<String, double> get contractDefaults =>
      _cachedContractDefaults ?? Map<String, double>.from(defaultContractRates);

  double get fuelPricePerLiter => _fuelPricePerLiter;

  double calculateCodFare({
    required double distanceKm,
    required String vehicleType,
    DateTime? referenceTime,
  }) {
    final config = codRates[vehicleType] ?? codRates.values.first;
    return _calculateBaseFare(config, distanceKm);
  }

  double _calculateBaseFare(VehicleRateConfig config, double distanceKm) {
    switch (config.formulaType) {
      case 'fuel_10wheeler':
      case 'fuel_20footer':
      case 'fuel_40footer':
        final numerator = config.fuelMultiplierNumerator ?? 3;
        final denominator = config.fuelMultiplierDenominator ?? 2;
        final calculated =
            (distanceKm * numerator / denominator) * _fuelPricePerLiter;
        return calculated < config.minFare ? config.minFare : calculated;
      case 'linear':
      default:
        return config.baseFare + (distanceKm * config.perKmRate);
    }
  }

  Future<double> resolveContractFare({
    required String vehicleType,
    Map<String, double> userContractRates = const {},
  }) async {
    await ensureLoaded();
    if (userContractRates.containsKey(vehicleType)) {
      return userContractRates[vehicleType]!;
    }
    return contractDefaults[vehicleType] ?? 0;
  }

  static Map<String, dynamic> defaultRatesDocument() {
    return {
      'codRates': {
        for (final entry in defaultCodRates.entries)
          entry.key: entry.value.toMap(),
      },
      'contractDefaults': defaultContractRates,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}
