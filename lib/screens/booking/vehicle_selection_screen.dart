import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../models/vehicle_model.dart';
import '../../models/location_model.dart';
import 'booking_summary_screen.dart';

class VehicleSelectionScreen extends StatefulWidget {
  final LocationModel pickupLocation;
  final LocationModel dropoffLocation;
  final double distance;

  const VehicleSelectionScreen({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.distance,
  });

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
  final List<VehicleModel> _vehicles = VehicleModel.getAvailableVehicles();
  VehicleModel? _selectedVehicle;

  void _selectVehicle(VehicleModel vehicle) {
    setState(() {
      _selectedVehicle = vehicle;
    });
  }

  void _continueToSummary() {
    if (_selectedVehicle == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingSummaryScreen(
          pickupLocation: widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          vehicle: _selectedVehicle!,
          distance: widget.distance,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Select Vehicle'),
      ),
      body: Column(
        children: [
          // Distance Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: AppColors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.route,
                        color: AppColors.primaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimated Distance',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Regular',
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.distance.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 20,
                              fontFamily: 'Bold',
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vehicle List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];
                final isSelected = _selectedVehicle?.id == vehicle.id;
                final estimatedFare = vehicle.getEstimatedFare(widget.distance);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryRed
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    onTap: () => _selectVehicle(vehicle),
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: AppColors.primaryRed,
                        size: 32,
                      ),
                    ),
                    title: Text(
                      vehicle.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'Bold',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          vehicle.description,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          vehicle.capacity,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Medium',
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: vehicle.features.take(2).map((feature) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.scaffoldBackground,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                feature,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Regular',
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${estimatedFare.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontFamily: 'Bold',
                            color: AppColors.primaryRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Estimated',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Continue Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedVehicle != null ? _continueToSummary : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: AppColors.textHint.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 17,
                      fontFamily: 'Bold',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
