import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../../models/vehicle_model.dart';
import '../../services/rider_auth_service.dart';

class RiderVehicleDetailsScreen extends StatefulWidget {
  const RiderVehicleDetailsScreen({super.key});

  @override
  State<RiderVehicleDetailsScreen> createState() =>
      _RiderVehicleDetailsScreenState();
}

class _RiderVehicleDetailsScreenState extends State<RiderVehicleDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = RiderAuthService();
  final _plateNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  bool _isLoading = false;
  String _selectedVehicleType = 'AUV';

  final List<String> _vehicleTypes =
      VehicleModel.getAvailableVehicles().map((v) => v.type).toList();

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }

  void _loadVehicleData() {
    final rider = _authService.currentRider;
    if (rider != null) {
      _selectedVehicleType = rider.vehicleType;
      _plateNumberController.text = rider.vehiclePlateNumber ?? '';
      _vehicleModelController.text = rider.vehicleModel ?? '';
      _vehicleColorController.text = rider.vehicleColor ?? '';
    }
  }

  @override
  void dispose() {
    _plateNumberController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicleDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: Implement vehicle update with Firebase
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      UIHelpers.showSuccessToast('Vehicle details updated successfully');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Vehicle Details',
          style: TextStyle(
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primaryBlue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Keep your vehicle information up to date for better service',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Regular',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Vehicle Type
                const Text(
                  'Vehicle Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.directions_car_outlined),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  items: _vehicleTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedVehicleType = newValue;
                      });
                    }
                  },
                ),

                const SizedBox(height: 20),

                // Plate Number
                const Text(
                  'Plate Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _plateNumberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'ABC 1234',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter plate number';
                    }
                    if (value.length < 5) {
                      return 'Please enter a valid plate number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Vehicle Model
                const Text(
                  'Vehicle Model',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vehicleModelController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Toyota Hilux, Honda XRM',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                ),

                const SizedBox(height: 20),

                // Vehicle Color
                const Text(
                  'Vehicle Color',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vehicleColorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g., White, Black, Red',
                    prefixIcon: Icon(Icons.palette_outlined),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                ),

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveVehicleDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? UIHelpers.loadingThreeBounce(
                            color: AppColors.white,
                            size: 20,
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
