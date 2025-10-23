import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/location_model.dart';
import '../../services/maps_service.dart';
import '../../services/location_service.dart';
import 'location_picker_screen.dart';

class MapViewScreen extends StatefulWidget {
  final LocationModel? pickupLocation;
  final LocationModel? dropoffLocation;
  final bool isSelectingPickup;
  final bool showRoute;
  final Function(LocationModel? pickup, LocationModel? dropoff)?
      onLocationChanged;
  final bool isEmbedded;

  const MapViewScreen({
    super.key,
    this.pickupLocation,
    this.dropoffLocation,
    this.isSelectingPickup = true,
    this.showRoute = true,
    this.onLocationChanged,
    this.isEmbedded = false,
  });

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final MapsService _mapsService = MapsService();
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _selectedLocation;
  bool _isLoading = false;
  String? _selectedAddress;
  LatLng? _initialPosition;
  bool _isGettingLocation = true;

  // Internal state for draggable markers
  LocationModel? _currentPickupLocation;
  LocationModel? _currentDropoffLocation;

  @override
  void initState() {
    super.initState();
    // Initialize internal state from widget
    _currentPickupLocation = widget.pickupLocation;
    _currentDropoffLocation = widget.dropoffLocation;
    _getCurrentLocationAndInitializeMap();
  }

  @override
  void didUpdateWidget(MapViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal state when widget changes
    if (oldWidget.pickupLocation != widget.pickupLocation) {
      _currentPickupLocation = widget.pickupLocation;
    }
    if (oldWidget.dropoffLocation != widget.dropoffLocation) {
      _currentDropoffLocation = widget.dropoffLocation;
    }
    // Reinitialize markers when locations change
    _initializeMap();
  }

  Future<void> _getCurrentLocationAndInitializeMap() async {
    // Try to get current location first
    final currentLocation = await _locationService.getCurrentLocation();

    if (currentLocation != null) {
      setState(() {
        _initialPosition =
            LatLng(currentLocation.latitude, currentLocation.longitude);
        _isGettingLocation = false;
      });
    } else {
      // Fallback to default Manila coordinates
      setState(() {
        _initialPosition = const LatLng(14.5995, 120.9842);
        _isGettingLocation = false;
      });
    }

    // Initialize markers after getting location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  void _initializeMap() {
    // Clear existing markers
    setState(() {
      _markers.clear();
      _polylines.clear();
    });

    // Add pickup marker if exists
    if (_currentPickupLocation != null) {
      _addPickupMarker(_currentPickupLocation!);
    }

    // Add dropoff marker if exists
    if (_currentDropoffLocation != null) {
      _addDropoffMarker(_currentDropoffLocation!);
    }

    // Draw route if both locations exist and showRoute is true
    if (widget.showRoute &&
        _currentPickupLocation != null &&
        _currentDropoffLocation != null) {
      _drawRoute();
    }
  }

  void _addPickupMarker(LocationModel location) {
    final marker = Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(location.latitude, location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: 'Pickup Location',
        snippet: location.address,
      ),
      draggable: true,
      onDragEnd: (LatLng newPosition) {
        _onMarkerDragEnd(newPosition, isPickup: true);
      },
    );
    setState(() {
      _markers.add(marker);
    });

    // Move camera to pickup location
    _moveCameraToLocation(location.latitude, location.longitude);
  }

  void _addDropoffMarker(LocationModel location) {
    final marker = Marker(
      markerId: const MarkerId('dropoff'),
      position: LatLng(location.latitude, location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: 'Drop-off Location',
        snippet: location.address,
      ),
      draggable: true,
      onDragEnd: (LatLng newPosition) {
        _onMarkerDragEnd(newPosition, isPickup: false);
      },
    );
    setState(() {
      _markers.add(marker);
    });

    // Move camera to dropoff location
    _moveCameraToLocation(location.latitude, location.longitude);

    // If both locations are set and showRoute is true, draw route
    if (widget.showRoute &&
        _currentPickupLocation != null &&
        _currentDropoffLocation != null) {
      _drawRoute();
    }
  }

  Future<void> _onMarkerDragEnd(LatLng newPosition,
      {required bool isPickup}) async {
    setState(() => _isLoading = true);

    // Get address for the new position
    final address = await _mapsService.getAddressFromCoordinates(
      newPosition.latitude,
      newPosition.longitude,
    );

    if (address != null) {
      final updatedLocation = LocationModel(
        address: address.address,
        latitude: newPosition.latitude,
        longitude: newPosition.longitude,
        city: address.city,
        province: address.province,
        country: address.country,
      );

      // Update the marker with new position
      final updatedMarker = Marker(
        markerId: MarkerId(isPickup ? 'pickup' : 'dropoff'),
        position: newPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isPickup ? BitmapDescriptor.hueRed : BitmapDescriptor.hueBlue,
        ),
        infoWindow: InfoWindow(
          title: isPickup ? 'Pickup Location' : 'Drop-off Location',
          snippet: address.address,
        ),
        draggable: true,
        onDragEnd: (LatLng newPosition) {
          _onMarkerDragEnd(newPosition, isPickup: isPickup);
        },
      );

      setState(() {
        _markers.removeWhere(
            (m) => m.markerId.value == (isPickup ? 'pickup' : 'dropoff'));
        _markers.add(updatedMarker);

        // Update internal location state
        if (isPickup) {
          _currentPickupLocation = updatedLocation;
        } else {
          _currentDropoffLocation = updatedLocation;
        }
      });

      // Only pop if we're in selection mode AND not embedded
      if ((widget.isSelectingPickup || isSelectingDropoff) &&
          !widget.isEmbedded) {
        Navigator.pop(context, updatedLocation);
      } else {
        // If in view mode or embedded, redraw route with new location
        if (widget.showRoute &&
            _currentPickupLocation != null &&
            _currentDropoffLocation != null) {
          _drawRouteWithCurrentLocations();
        }

        // Notify parent widget about the location change
        widget.onLocationChanged?.call(isPickup ? updatedLocation : null,
            isPickup ? null : updatedLocation);
      }
    }

    setState(() => _isLoading = false);
  }

  void _moveCameraToLocation(double latitude, double longitude) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(latitude, longitude),
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  Future<void> _drawRoute() async {
    if (_currentPickupLocation == null || _currentDropoffLocation == null)
      return;

    setState(() => _isLoading = true);

    final routeInfo = await _mapsService.calculateRoute(
      _currentPickupLocation!,
      _currentDropoffLocation!,
    );

    if (routeInfo != null && routeInfo.polylinePoints.isNotEmpty) {
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        color: AppColors.primaryRed,
        width: 5,
        points: routeInfo.polylinePoints
            .map((point) => LatLng(point['latitude']!, point['longitude']!))
            .toList(),
      );

      setState(() {
        _polylines.clear();
        _polylines.add(polyline);
        _isLoading = false;
      });

      // Fit map to show the entire route
      _fitMapToRoute();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _drawRouteWithCurrentLocations() async {
    if (_currentPickupLocation == null || _currentDropoffLocation == null)
      return;

    setState(() => _isLoading = true);

    final routeInfo = await _mapsService.calculateRoute(
      _currentPickupLocation!,
      _currentDropoffLocation!,
    );

    if (routeInfo != null && routeInfo.polylinePoints.isNotEmpty) {
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        color: AppColors.primaryRed,
        width: 5,
        points: routeInfo.polylinePoints
            .map((point) => LatLng(point['latitude']!, point['longitude']!))
            .toList(),
      );

      setState(() {
        _polylines.clear();
        _polylines.add(polyline);
        _isLoading = false;
      });

      // Fit map to show the entire route
      _fitMapToRouteWithCurrentLocations();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _fitMapToRoute() {
    if (_mapController == null ||
        _currentPickupLocation == null ||
        _currentDropoffLocation == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        _currentPickupLocation!.latitude < _currentDropoffLocation!.latitude
            ? _currentPickupLocation!.latitude
            : _currentDropoffLocation!.latitude,
        _currentPickupLocation!.longitude < _currentDropoffLocation!.longitude
            ? _currentPickupLocation!.longitude
            : _currentDropoffLocation!.longitude,
      ),
      northeast: LatLng(
        _currentPickupLocation!.latitude > _currentDropoffLocation!.latitude
            ? _currentPickupLocation!.latitude
            : _currentDropoffLocation!.latitude,
        _currentPickupLocation!.longitude > _currentDropoffLocation!.longitude
            ? _currentPickupLocation!.longitude
            : _currentDropoffLocation!.longitude,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 135.0),
    );
  }

  void _fitMapToRouteWithCurrentLocations() {
    if (_mapController == null ||
        _currentPickupLocation == null ||
        _currentDropoffLocation == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        _currentPickupLocation!.latitude < _currentDropoffLocation!.latitude
            ? _currentPickupLocation!.latitude
            : _currentDropoffLocation!.latitude,
        _currentPickupLocation!.longitude < _currentDropoffLocation!.longitude
            ? _currentPickupLocation!.longitude
            : _currentDropoffLocation!.longitude,
      ),
      northeast: LatLng(
        _currentPickupLocation!.latitude > _currentDropoffLocation!.latitude
            ? _currentPickupLocation!.latitude
            : _currentDropoffLocation!.latitude,
        _currentPickupLocation!.longitude > _currentDropoffLocation!.longitude
            ? _currentPickupLocation!.longitude
            : _currentDropoffLocation!.longitude,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  void _onMapTap(LatLng location) async {
    if (!widget.isSelectingPickup && !isSelectingDropoff) return;

    setState(() {
      _isLoading = true;
      _selectedLocation = location;
      _selectedAddress = 'Getting address...';
    });

    final address = await _mapsService.getAddressFromCoordinates(
      location.latitude,
      location.longitude,
    );

    setState(() {
      _isLoading = false;
      _selectedAddress = address?.address ?? 'Address not found';
    });

    // Add temporary marker
    final tempMarker = Marker(
      markerId: const MarkerId('selected'),
      position: location,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        widget.isSelectingPickup
            ? BitmapDescriptor.hueRed
            : BitmapDescriptor.hueBlue,
      ),
      infoWindow: InfoWindow(
        title:
            widget.isSelectingPickup ? 'Selected Pickup' : 'Selected Drop-off',
        snippet: _selectedAddress,
      ),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'selected');
      _markers.add(tempMarker);
    });
  }

  void _confirmSelection() {
    if (_selectedLocation == null || _selectedAddress == null) {
      UIHelpers.showErrorToast('Please select a location on the map');
      return;
    }

    final location = LocationModel(
      address: _selectedAddress!,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
    );

    Navigator.pop(context, location);
  }

  void _openLocationPicker() async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          title: widget.isSelectingPickup
              ? 'Pickup Location'
              : 'Drop-off Location',
        ),
      ),
    );

    if (location != null) {
      if (widget.isSelectingPickup) {
        _addPickupMarker(location);
      } else {
        _addDropoffMarker(location);
      }

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(location.latitude, location.longitude),
          15.0,
        ),
      );
    }
  }

  void _getCurrentLocation() async {
    // This would integrate with LocationService
    // For now, we'll use a mock location
    final mockLocation = LocationModel(
      address: 'Current Location',
      latitude: 14.5995,
      longitude: 120.9842,
    );

    _onMapTap(LatLng(mockLocation.latitude, mockLocation.longitude));
  }

  bool get isSelectingDropoff => !widget.isSelectingPickup;

  @override
  Widget build(BuildContext context) {
    Widget mapContent = Stack(
      children: [
        // Map
        _isGettingLocation
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                ),
              )
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _initialPosition ?? const LatLng(14.5995, 120.9842),
                  zoom: 15.0,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  // Initialize map after controller is created
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _initializeMap();
                  });
                },
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),

        // Loading Indicator
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
              ),
            ),
          ),

        // Selected Location Info
        if (_selectedLocation != null && _selectedAddress != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child: Container(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selected Location',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Medium',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedAddress!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Confirm Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Bold',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Map Controls
        Positioned(
          right: 16,
          bottom: 50,
          child: Column(
            children: [
              // Zoom In Button
              FloatingActionButton(
                heroTag: "zoom_in",
                onPressed: () {
                  _mapController?.animateCamera(
                    CameraUpdate.zoomIn(),
                  );
                },
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primaryRed,
                mini: true,
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              // Zoom Out Button
              FloatingActionButton(
                heroTag: "zoom_out",
                onPressed: () {
                  _mapController?.animateCamera(
                    CameraUpdate.zoomOut(),
                  );
                },
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primaryRed,
                mini: true,
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ],
    );

    // Only wrap with Scaffold and AppBar if not embedded
    if (widget.isEmbedded) {
      return mapContent;
    } else {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: Text(
            widget.isSelectingPickup
                ? 'Select Pickup Location'
                : 'Select Drop-off Location',
          ),
          actions: [
            if (widget.isSelectingPickup || isSelectingDropoff)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _openLocationPicker,
              ),
          ],
        ),
        body: mapContent,
      );
    }
  }
}
