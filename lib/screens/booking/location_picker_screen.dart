import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/location_model.dart';
import '../../services/location_service.dart';
import '../../services/maps_service.dart';
import 'saved_locations_screen.dart';

class LocationPickerScreen extends StatefulWidget {
  final String title; // "Pickup Location" or "Drop-off Location"
  final LocationModel? initialLocation;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();
  final MapsService _mapsService = MapsService();

  List<PlaceSuggestion> _suggestions = [];
  List<LocationModel> _recentLocations = [];
  bool _isSearching = false;
  bool _isLoadingCurrent = false;
  Timer? _debounceTimer;
  int _searchCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadRecentLocations();
    if (widget.initialLocation != null) {
      _searchController.text = widget.initialLocation!.address;
    }
  }

  void _loadRecentLocations() {
    setState(() {
      _recentLocations = _locationService.getRecentLocations();
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty || !mounted) return;

    final currentSearch = ++_searchCounter;

    final suggestions = await _mapsService.searchPlaces(query);

    if (mounted && currentSearch == _searchCounter) {
      setState(() {
        _suggestions = suggestions;
        _isSearching = false;
      });
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _debounceTimer?.cancel();
    UIHelpers.showLoadingDialog(context);

    final location = await _mapsService.getPlaceDetails(suggestion.placeId);
    _mapsService.resetSessionToken();

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (location != null) {
        _locationService.addToRecentLocations(location);
        Navigator.pop(context, location);
      } else {
        UIHelpers.showErrorToast('Failed to get location details');
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingCurrent = true);

    final location = await _locationService.getCurrentLocation();

    setState(() => _isLoadingCurrent = false);

    if (location != null) {
      _locationService.addToRecentLocations(location);
      if (mounted) {
        Navigator.pop(context, location);
      }
    } else {
      UIHelpers.showErrorToast('Failed to get current location');
    }
  }

  Future<void> _selectFromSaved() async {
    final selected = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const SavedLocationsScreen(),
      ),
    );

    if (selected != null && mounted) {
      Navigator.pop(context, selected);
    }
  }

  void _selectRecentLocation(LocationModel location) {
    Navigator.pop(context, location);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search for a location',
                    prefixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryRed),
                              ),
                            ),
                          )
                        : const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _debounceTimer?.cancel();
                                _searchController.clear();
                                _suggestions = [];
                                _isSearching = false;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Quick Actions
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.my_location,
                        label: 'Current',
                        isLoading: _isLoadingCurrent,
                        onTap: _useCurrentLocation,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.bookmark,
                        label: 'Saved',
                        onTap: _selectFromSaved,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _suggestions.isNotEmpty
                ? _buildSuggestionsList()
                : _buildRecentLocationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on,
              color: AppColors.primaryRed,
            ),
          ),
          title: Text(
            suggestion.mainText,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Medium',
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            suggestion.secondaryText,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
          ),
          onTap: () => _selectSuggestion(suggestion),
        );
      },
    );
  }

  Widget _buildRecentLocationsList() {
    if (_recentLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No recent locations',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Medium',
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search for a location to get started',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Recent Locations',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _recentLocations.length,
          (index) {
            final location = _recentLocations[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: AppColors.primaryBlue,
                  ),
                ),
                title: Text(
                  location.shortAddress,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  location.address,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _selectRecentLocation(location),
              ),
            );
          },
        ),
      ],
    );
  }
}

// Quick Action Button Widget
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryRed,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: AppColors.primaryRed.withOpacity(0.3),
          ),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                  ),
                ),
              ],
            ),
    );
  }
}
