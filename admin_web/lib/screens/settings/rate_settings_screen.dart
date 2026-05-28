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
  final Map<String, TextEditingController> _contractControllers = {};
  final TextEditingController _fuelController = TextEditingController();

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
    for (final controller in _contractControllers.values) {
      controller.dispose();
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
        'peakSurchargePercent': TextEditingController(
          text: '${vehicleRates['peakSurchargePercent'] ?? 20}',
        ),
      };
      _contractControllers[vehicle] = TextEditingController(
        text: '${contractDefaults[vehicle] ?? 0}',
      );
    }

    _fuelController.text = fuel.toStringAsFixed(0);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final codRates = <String, dynamic>{};
      final contractDefaults = <String, double>{};

      for (final vehicle in AdminRateConfigRepository.vehicleTypes) {
        final controllers = _codControllers[vehicle]!;
        codRates[vehicle] = {
          'baseFare': double.tryParse(controllers['baseFare']!.text) ?? 0,
          'perKmRate': double.tryParse(controllers['perKmRate']!.text) ?? 0,
          'minFare': double.tryParse(controllers['minFare']!.text) ?? 0,
          'peakSurchargePercent':
              double.tryParse(controllers['peakSurchargePercent']!.text) ?? 20,
          'formulaType': _formulaTypeFor(vehicle),
          if (_formulaTypeFor(vehicle).startsWith('fuel_')) ...{
            'fuelMultiplierNumerator': _fuelNumeratorFor(vehicle),
            'fuelMultiplierDenominator': _fuelDenominatorFor(vehicle),
          },
        };
        contractDefaults[vehicle] =
            double.tryParse(_contractControllers[vehicle]!.text) ?? 0;
      }

      await AdminRateConfigRepository.saveRatesConfig(
        codRates: codRates,
        contractDefaults: contractDefaults,
        fuelPrice: double.tryParse(_fuelController.text) ?? 130,
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

  double _fuelNumeratorFor(String vehicle) {
    switch (vehicle) {
      case '40-Footer Trailer':
        return 4;
      default:
        return 3;
    }
  }

  double _fuelDenominatorFor(String vehicle) {
    switch (vehicle) {
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
            'Configure COD calculator rates and default contract fixed rates per vehicle type.',
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
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _field('Base fare', controllers['baseFare']!),
                                _field('Per km', controllers['perKmRate']!),
                                _field('Min fare', controllers['minFare']!),
                                _field(
                                  'Peak surcharge %',
                                  controllers['peakSurchargePercent']!,
                                ),
                                _field(
                                  'Contract default',
                                  _contractControllers[vehicle]!,
                                ),
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
