import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/location_model.dart';
import '../../services/maps_service.dart';
import 'map_view_screen.dart';
import 'vehicle_selection_screen.dart';

class BookingStartScreen extends StatefulWidget {
  const BookingStartScreen({super.key});

  @override
  State<BookingStartScreen> createState() => _BookingStartScreenState();
}

class _BookingStartScreenState extends State<BookingStartScreen> {
  final MapsService _mapsService = MapsService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  LocationModel? _pickupLocation;
  LocationModel? _dropoffLocation;
  double? _distance;
  int? _durationMinutes; // Store duration in minutes
  DateTime? _estimatedArrival; // Calculate ETA based on current time + duration
  DateTime?
      _estimatedDelivery; // Calculate delivery time (ETA + loading/unloading time)
  double? _estimatedFare; // Calculate estimated fare
  bool _isCalculating = false;
  bool _isSearching = false;
  List<PlaceSuggestion> _searchSuggestions = [];
  bool _isSelectingPickup = true; // Toggle between pickup and dropoff search
  bool _showLocationFields = true; // Controls visibility of location fields
  Timer? _debounceTimer;
  int _searchCounter = 0; // Prevents stale results from overwriting newer ones
  String? _lastSearchError; // Stores last error for user feedback

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isSearching = false;
        _lastSearchError = null;
      });
      return;
    }

    // Show searching indicator immediately for responsiveness
    setState(() {
      _isSearching = true;
      _lastSearchError = null;
    });

    // Debounce: wait 400ms after last keystroke before calling API
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty || !mounted) return;

    final currentSearch = ++_searchCounter;

    final suggestions = await _mapsService.searchPlaces(query);

    // Only update if this is still the latest search and widget is mounted
    if (mounted && currentSearch == _searchCounter) {
      setState(() {
        _searchSuggestions = suggestions;
        _isSearching = false;
        if (suggestions.isEmpty && query.length >= 3) {
          _lastSearchError = 'No locations found. Try a different search.';
        } else {
          _lastSearchError = null;
        }
      });
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _debounceTimer?.cancel();
    UIHelpers.showLoadingDialog(context);

    final location = await _mapsService.getPlaceDetails(suggestion.placeId);
    _mapsService.resetSessionToken(); // Reset token after selection

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (location != null) {
        setState(() {
          if (_isSelectingPickup) {
            _pickupLocation = location;
          } else {
            _dropoffLocation = location;
            // Hide location fields when dropoff is selected
            _showLocationFields = false;
          }
          _searchController.clear();
          _searchSuggestions = [];
          _isSearching = false;
          _lastSearchError = null;
          _searchFocusNode.unfocus();
        });

        // Calculate distance if both locations are set
        if (_pickupLocation != null && _dropoffLocation != null) {
          _calculateDistance();
        }
      } else {
        UIHelpers.showErrorToast('Failed to get location details');
      }
    }
  }

  void _openMapSelection() {
    Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => MapViewScreen(
          pickupLocation: _isSelectingPickup ? null : _pickupLocation,
          dropoffLocation: !_isSelectingPickup ? null : _dropoffLocation,
          isSelectingPickup: _isSelectingPickup,
          showRoute: false, // Don't show route when selecting
          isEmbedded: false, // Not embedded when used for selection
          // No callback needed here since we're using Navigator.pop to return the location
        ),
      ),
    ).then((location) {
      if (location != null) {
        setState(() {
          if (_isSelectingPickup) {
            _pickupLocation = location;
          } else {
            _dropoffLocation = location;
            // Hide location fields when dropoff is selected
            _showLocationFields = false;
          }
          _searchController.clear();
          _searchSuggestions.clear();
        });

        // Calculate distance if both locations are set
        if (_pickupLocation != null && _dropoffLocation != null) {
          _calculateDistance();
        }
      }
    });
  }

  Future<void> _calculateDistance() async {
    if (_pickupLocation == null || _dropoffLocation == null) return;

    setState(() => _isCalculating = true);

    try {
      final routeInfo = await _mapsService.calculateRoute(
        _pickupLocation!,
        _dropoffLocation!,
      );

      if (routeInfo != null) {
        setState(() {
          _distance = routeInfo.distanceKm;
          _durationMinutes = routeInfo.durationMinutes;
          // Calculate ETA based on current time + duration
          if (_durationMinutes != null) {
            _estimatedArrival =
                DateTime.now().add(Duration(minutes: _durationMinutes!));

            // Calculate estimated delivery time (ETA + 2 hours for loading/unloading)
            _estimatedDelivery =
                _estimatedArrival!.add(const Duration(hours: 2));
          }

          // Calculate estimated fare using default vehicle type
          _estimatedFare = _mapsService.calculateFare(
            distanceKm: _distance!,
            vehicleType: '10-Wheeler Wingvan',
          );

          _isCalculating = false;
        });
      } else {
        // Route calculation failed but we still have both locations
        // Set a fallback distance to enable the button
        setState(() {
          _distance = 0.0; // Will be calculated server-side if needed
          _durationMinutes = 0;
          _estimatedFare = 0.0;
          _isCalculating = false;
        });
        UIHelpers.showErrorToast('Could not calculate route distance');
      }
    } catch (e) {
      debugPrint('Error calculating distance: $e');
      setState(() {
        _isCalculating = false;
      });
      UIHelpers.showErrorToast(
          'Failed to calculate distance. Please try again.');
    }
  }

  void _continueToVehicleSelection() {
    if (_pickupLocation == null ||
        _dropoffLocation == null ||
        _distance == null) {
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
        elevation: 0,
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Stack(
        children: [
          // Map View
          MapViewScreen(
            key: ValueKey(
                'map_${_pickupLocation?.latitude}_${_pickupLocation?.longitude}_${_dropoffLocation?.latitude}_${_dropoffLocation?.longitude}'),
            pickupLocation: _pickupLocation,
            dropoffLocation: _dropoffLocation,
            isSelectingPickup: false,
            showRoute: _pickupLocation != null && _dropoffLocation != null,
            isEmbedded: true,
            onLocationChanged: (pickup, dropoff) {
              setState(() {
                if (pickup != null) {
                  _pickupLocation = pickup;
                }
                if (dropoff != null) {
                  _dropoffLocation = dropoff;
                }
              });

              // Calculate distance if both locations are set
              if (_pickupLocation != null && _dropoffLocation != null) {
                _calculateDistance();
              }
            },
          ),

          // Search Bar and Location Selection
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Column(
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Type Selector
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSelectingPickup = true;
                                  _searchController.clear();
                                  _searchSuggestions.clear();
                                });
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isSelectingPickup
                                      ? AppColors.primaryRed.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.radio_button_checked,
                                      color: _isSelectingPickup
                                          ? AppColors.primaryRed
                                          : AppColors.textHint,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pickup',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Medium',
                                        color: _isSelectingPickup
                                            ? AppColors.primaryRed
                                            : AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSelectingPickup = false;
                                  _searchController.clear();
                                  _searchSuggestions.clear();
                                });
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isSelectingPickup
                                      ? AppColors.primaryBlue.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: !_isSelectingPickup
                                          ? AppColors.primaryBlue
                                          : AppColors.textHint,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Drop-off',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Medium',
                                        color: !_isSelectingPickup
                                            ? AppColors.primaryBlue
                                            : AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Search Input
                      TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText:
                              'Search for ${_isSelectingPickup ? 'pickup' : 'drop-off'} location',
                          prefixIcon: Icon(
                            Icons.search,
                            color: _isSelectingPickup
                                ? AppColors.primaryRed
                                : AppColors.primaryBlue,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _debounceTimer?.cancel();
                                      _searchController.clear();
                                      _searchSuggestions = [];
                                      _isSearching = false;
                                      _lastSearchError = null;
                                    });
                                  },
                                )
                              : IconButton(
                                  icon: const Icon(Icons.map),
                                  onPressed: _openMapSelection,
                                  tooltip: 'Select on map',
                                ),
                          filled: true,
                          fillColor: AppColors.scaffoldBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: _isSelectingPickup
                                  ? AppColors.primaryRed.withOpacity(0.3)
                                  : AppColors.primaryBlue.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: _isSelectingPickup
                                  ? AppColors.primaryRed
                                  : AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search error message
                if (_lastSearchError != null &&
                    _searchSuggestions.isEmpty &&
                    !_isSearching)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lastSearchError!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Regular',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Search Suggestions
                if (_searchSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchSuggestions.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final suggestion = _searchSuggestions[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isSelectingPickup
                                  ? AppColors.primaryRed.withOpacity(0.1)
                                  : AppColors.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: _isSelectingPickup
                                  ? AppColors.primaryRed
                                  : AppColors.primaryBlue,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            suggestion.mainText,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Medium',
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            suggestion.secondaryText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Regular',
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () => _selectSuggestion(suggestion),
                        );
                      },
                    ),
                  ),

                // Selected Locations Display (shown when _showLocationFields is true)
                if (_showLocationFields &&
                    (_pickupLocation != null || _dropoffLocation != null))
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header with title and hide button
                        Row(
                          children: [
                            const Text(
                              'Trip Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Bold',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (_dropoffLocation != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showLocationFields = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.textHint.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility_off,
                                        color: AppColors.textHint,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Hide',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Medium',
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_pickupLocation != null)
                          _SelectedLocationCard(
                            icon: Icons.radio_button_checked,
                            iconColor: AppColors.primaryRed,
                            title: 'Pickup',
                            location: _pickupLocation!,
                            onTap: () {
                              setState(() {
                                _isSelectingPickup = true;
                                _searchController.text =
                                    _pickupLocation!.address;
                              });
                              _searchFocusNode.requestFocus();
                            },
                          ),
                        if (_pickupLocation != null && _dropoffLocation != null)
                          const SizedBox(height: 8),
                        if (_dropoffLocation != null)
                          _SelectedLocationCard(
                            icon: Icons.location_on,
                            iconColor: AppColors.primaryBlue,
                            title: 'Drop-off',
                            location: _dropoffLocation!,
                            onTap: () {
                              setState(() {
                                _isSelectingPickup = false;
                                _searchController.text =
                                    _dropoffLocation!.address;
                              });
                              _searchFocusNode.requestFocus();
                            },
                          ),
                        if (_distance != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryBlue.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Distance and Duration Row
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.route,
                                      color: AppColors.primaryBlue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${_distance!.toStringAsFixed(1)} km',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontFamily: 'Bold',
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                    ),
                                    if (_durationMinutes != null) ...[
                                      const Icon(
                                        Icons.access_time,
                                        color: AppColors.primaryBlue,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDuration(_durationMinutes!),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontFamily: 'Bold',
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                // Delivery Time Row
                                if (_estimatedDelivery != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.local_shipping,
                                        color: AppColors.primaryBlue,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Delivery by: ${_formatTime(_estimatedDelivery!)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Medium',
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                // Fare Row
                                if (_estimatedFare != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.primaryRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.primaryRed
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.payments,
                                          color: AppColors.primaryRed,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Est. Fare: P${_estimatedFare!.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontFamily: 'Bold',
                                              color: AppColors.primaryRed,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '(10-Wheeler Wingvan)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Regular',
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // View Locations Button (shown when _showLocationFields is false and dropoff is selected)
                if (!_showLocationFields && _dropoffLocation != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showLocationFields = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.visibility,
                                color: AppColors.primaryBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'View Trip Details',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Medium',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppColors.textHint,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Loading Indicator - only for route calculation, NOT for search
          if (_isCalculating)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                ),
              ),
            ),
        ],
      ),

      // Continue Button
      bottomNavigationBar: Container(
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
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Format duration into readable text
  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}min';
  }

  // Format time for ETA display
  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}

// Selected Location Card Widget
class _SelectedLocationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final LocationModel location;
  final VoidCallback onTap;

  const _SelectedLocationCard({
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'Medium',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location.shortAddress,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Regular',
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
