import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/location_model.dart';
import '../../services/maps_service.dart';
import 'location_picker_screen.dart';
import 'vehicle_selection_screen.dart';

class BookingStartScreen extends StatefulWidget {
  const BookingStartScreen({super.key});

  @override
  State<BookingStartScreen> createState() => _BookingStartScreenState();
}

class _BookingStartScreenState extends State<BookingStartScreen> {
  final MapsService _mapsService = MapsService();
  
  LocationModel? _pickupLocation;
  LocationModel? _dropoffLocation;
  double? _distance;
  bool _isCalculating = false;

  Future<void> _selectPickupLocation() async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(
          title: 'Pickup Location',
        ),
      ),
    );

    if (location != null) {
      setState(() {
        _pickupLocation = location;
      });
      _calculateDistance();
    }
  }

  Future<void> _selectDropoffLocation() async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(
          title: 'Drop-off Location',
        ),
      ),
    );

    if (location != null) {
      setState(() {
        _dropoffLocation = location;
      });
      _calculateDistance();
    }
  }

  Future<void> _calculateDistance() async {
    if (_pickupLocation == null || _dropoffLocation == null) return;

    setState(() => _isCalculating = true);

    final routeInfo = await _mapsService.calculateRoute(
      _pickupLocation!,
      _dropoffLocation!,
    );

    setState(() {
      _distance = routeInfo?.distanceKm;
      _isCalculating = false;
    });
  }

  void _continueToVehicleSelection() {
    if (_pickupLocation == null || _dropoffLocation == null || _distance == null) {
      UIHelpers.showErrorToast('Please select both locations');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleSelectionScreen(
          pickupLocation: _pickupLocation!,
          dropoffLocation: _dropoffLocation!,
          distance: _distance!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('New Booking'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Where would you like to go?',
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your pickup and drop-off locations',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Pickup Location
                  _LocationSelector(
                    icon: Icons.radio_button_checked,
                    iconColor: AppColors.primaryRed,
                    title: 'Pickup Location',
                    location: _pickupLocation,
                    onTap: _selectPickupLocation,
                  ),

                  const SizedBox(height: 16),

                  // Drop-off Location
                  _LocationSelector(
                    icon: Icons.location_on,
                    iconColor: AppColors.primaryBlue,
                    title: 'Drop-off Location',
                    location: _dropoffLocation,
                    onTap: _selectDropoffLocation,
                  ),

                  if (_distance != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.route,
                            color: AppColors.primaryBlue,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Estimated Distance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Regular',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_distance!.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontFamily: 'Bold',
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_isCalculating) ...[
                    const SizedBox(height: 24),
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ],
              ),
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
                  onPressed: _pickupLocation != null &&
                          _dropoffLocation != null &&
                          _distance != null
                      ? _continueToVehicleSelection
                      : null,
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
                    'Select Vehicle',
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

// Location Selector Widget
class _LocationSelector extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final LocationModel? location;
  final VoidCallback onTap;

  const _LocationSelector({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: location != null
                ? iconColor.withOpacity(0.3)
                : AppColors.textHint.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Medium',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location?.address ?? 'Select location',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: location != null ? 'Regular' : 'Medium',
                      color: location != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
