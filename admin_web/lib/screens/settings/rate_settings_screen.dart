import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../services/rate_config_repository.dart';
import '../../widgets/common_widgets.dart';

class RateSettingsScreen extends StatefulWidget {
  const RateSettingsScreen({super.key});

  @override
  State<RateSettingsScreen> createState() => _RateSettingsScreenState();
}

class _RateSettingsScreenState extends State<RateSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  final Map<String, Map<String, TextEditingController>> _codControllers = {};
  final TextEditingController _fuelController = TextEditingController();
  Map<String, double> _existingContractDefaults = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controllers in _codControllers.values) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
    _fuelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final config = await AdminRateConfigRepository.getRatesConfig();
    final fuel = await AdminRateConfigRepository.getFuelPrice();
    final codRates = Map<String, dynamic>.from(config['codRates'] ?? {});
    final contractDefaults =
        Map<String, dynamic>.from(config['contractDefaults'] ?? {});
    double parseAmount(dynamic value) => switch (value) {
          num v => v.toDouble(),
          String v => double.tryParse(v) ?? 0.0,
          _ => 0.0,
        };
    _existingContractDefaults = {
      for (final entry in contractDefaults.entries)
        entry.key.toString(): parseAmount(entry.value),
    };

    for (final vehicle in AdminRateConfigRepository.vehicleTypes) {
      final vehicleRates = Map<String, dynamic>.from(codRates[vehicle] ?? {});
      _codControllers[vehicle] = {
        'baseFare': TextEditingController(
          text: '${vehicleRates['baseFare'] ?? 0}',
        ),
        'perKmRate': TextEditingController(
          text: '${vehicleRates['perKmRate'] ?? 0}',
        ),
        'minFare': TextEditingController(
          text: '${vehicleRates['minFare'] ?? 0}',
        ),
        'fuelMultiplierNumerator': TextEditingController(
          text:
              '${vehicleRates['fuelMultiplierNumerator'] ?? _defaultFuelNumeratorFor(vehicle)}',
        ),
        'fuelMultiplierDenominator': TextEditingController(
          text:
              '${vehicleRates['fuelMultiplierDenominator'] ?? _defaultFuelDenominatorFor(vehicle)}',
        ),
      };
    }

    _fuelController.text = fuel.toStringAsFixed(0);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final codRates = <String, dynamic>{};

      for (final vehicle in AdminRateConfigRepository.vehicleTypes) {
        final controllers = _codControllers[vehicle]!;
        codRates[vehicle] = {
          'baseFare': double.tryParse(controllers['baseFare']!.text) ?? 0,
          'perKmRate': double.tryParse(controllers['perKmRate']!.text) ?? 0,
          'minFare': double.tryParse(controllers['minFare']!.text) ?? 0,
          'formulaType': _formulaTypeFor(vehicle),
          if (_formulaTypeFor(vehicle).startsWith('fuel_')) ...{
            'fuelMultiplierNumerator': double.tryParse(
                  controllers['fuelMultiplierNumerator']!.text,
                ) ??
                _defaultFuelNumeratorFor(vehicle),
            'fuelMultiplierDenominator': double.tryParse(
                  controllers['fuelMultiplierDenominator']!.text,
                ) ??
                _defaultFuelDenominatorFor(vehicle),
          },
        };
      }

      await AdminRateConfigRepository.saveRatesConfig(
        codRates: codRates,
        contractDefaults: _existingContractDefaults,
        fuelPrice: double.tryParse(_fuelController.text) ?? 95,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rate settings saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save rates: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formulaTypeFor(String vehicle) {
    switch (vehicle) {
      case '10-Wheeler Wingvan':
        return 'fuel_10wheeler';
      case '20-Footer Trailer':
        return 'fuel_20footer';
      case '40-Footer Trailer':
        return 'fuel_40footer';
      default:
        return 'linear';
    }
  }

  double _defaultFuelNumeratorFor(String vehicle) {
    switch (vehicle) {
      case '10-Wheeler Wingvan':
        return 5;
      case '40-Footer Trailer':
        return 4;
      default:
        return 3;
    }
  }

  double _defaultFuelDenominatorFor(String vehicle) {
    switch (vehicle) {
      case '10-Wheeler Wingvan':
        return 2.75;
      case '20-Footer Trailer':
      case '40-Footer Trailer':
        return 2.5;
      default:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Rate Settings',
            trailing: ElevatedButton.icon(
              onPressed: _loading || _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Rates'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure distance-based rates, fuel price, and heavy-vehicle fuel formula factors.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AdminTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _fuelController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Fuel price per liter (PHP)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...AdminRateConfigRepository.vehicleTypes.map((vehicle) {
                    final controllers = _codControllers[vehicle]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_formulaTypeFor(vehicle)
                                .startsWith('fuel_')) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Fare = distance x distance multiplier / fuel consumption x fuel price',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AdminTheme.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _field('Base fare', controllers['baseFare']!),
                                _field('Per km', controllers['perKmRate']!),
                                _field('Min fare', controllers['minFare']!),
                                if (_formulaTypeFor(vehicle)
                                    .startsWith('fuel_')) ...[
                                  _field(
                                    'Distance multiplier',
                                    controllers[
                                        'fuelMultiplierNumerator']!,
                                  ),
                                  _field(
                                    'Fuel consumption (km/L)',
                                    controllers[
                                        'fuelMultiplierDenominator']!,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}
