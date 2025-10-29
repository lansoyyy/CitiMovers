import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../tabs/bookings_tab.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final BookingData booking;

  const DeliveryTrackingScreen({
    super.key,
    required this.booking,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Timer? _locationUpdateTimer;

  // Hardcoded locations for simulation (using Manila coordinates)
  static const LatLng _pickupLocation = LatLng(14.5995, 120.9842); // Manila
  static const LatLng _dropoffLocation = LatLng(14.5764, 121.0851); // Pasig
  LatLng _driverLocation = const LatLng(14.5900, 120.9900); // Starting position

  // Route points for polyline
  final List<LatLng> _routePoints = [
    const LatLng(14.5995, 120.9842), // Pickup location
    const LatLng(14.5950, 121.0100),
    const LatLng(14.5900, 121.0200),
    const LatLng(14.5850, 121.0300),
    const LatLng(14.5800, 121.0400),
    const LatLng(14.5764, 121.0851), // Drop-off location
  ];

  int _currentRouteIndex = 0;
  bool _isDelivered = false;
  bool _showDeliveryDetails = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startLocationSimulation();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _initializeMap() async {
    // Initialize markers
    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Drop-off Location'),
      ),
    );

    // Create vehicle icon for driver
    final BitmapDescriptor vehicleIcon = await _getVehicleIcon();

    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverLocation,
        icon: vehicleIcon,
        infoWindow: const InfoWindow(title: 'Driver Location'),
        rotation: 45.0,
      ),
    );

    // Initialize polyline from pickup to driver location
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        color: AppColors.primaryRed,
        width: 4,
        points: [
          _pickupLocation,
          _driverLocation
        ], // Start from pickup to current driver location
      ),
    );
  }

  Future<BitmapDescriptor> _getVehicleIcon() async {
    // Use a vehicle-like icon for the driver marker
    // For now, we'll use the default marker with green hue to represent a vehicle
    // In a real app, you would use custom asset images for truck/van icons
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  void _startLocationSimulation() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentRouteIndex < _routePoints.length - 1) {
        setState(() {
          _currentRouteIndex++;
          _driverLocation = _routePoints[_currentRouteIndex];

          // Update driver marker
          _markers.removeWhere((marker) => marker.markerId.value == 'driver');
          _markers.add(
            Marker(
              markerId: const MarkerId('driver'),
              position: _driverLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: 'Driver Location',
                snippet: widget.booking.vehicleType,
              ),
              rotation: _calculateRotation(_currentRouteIndex),
            ),
          );

          // Update polyline to show complete route from pickup to drop-off
          _polylines.clear();

          // Show the complete route from pickup to drop-off location
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: AppColors.primaryRed,
              width: 4,
              points: _routePoints, // Show complete route
            ),
          );
        });

        // Make camera follow driver
        _mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _driverLocation,
              zoom: 15.0,
            ),
          ),
        );

        // Check if delivered
        if (_currentRouteIndex == _routePoints.length - 1) {
          setState(() {
            _isDelivered = true;
          });
          _locationUpdateTimer?.cancel();
          UIHelpers.showSuccessToast('Package delivered successfully!');
        }
      }
    });
  }

  double _calculateRotation(int currentIndex) {
    if (currentIndex >= _routePoints.length - 1) return 0.0;

    final current = _routePoints[currentIndex];
    final next = _routePoints[currentIndex + 1];

    final angle = atan2(
        next.latitude - current.latitude, next.longitude - current.longitude);
    return angle * 180 / pi;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _animateCameraToRoute();
  }

  void _animateCameraToRoute() {
    // Calculate bounds to show the entire route
    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;

    for (final point in _routePoints) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Track Delivery',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Booking ID: ${widget.booking.id}',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong,
                color: AppColors.textPrimary),
            onPressed: _animateCameraToRoute,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isDelivered
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isDelivered
                            ? Icons.check_circle
                            : Icons.local_shipping,
                        color: _isDelivered
                            ? AppColors.success
                            : AppColors.primaryRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isDelivered ? 'Delivered' : 'In Transit',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                              color: _isDelivered
                                  ? AppColors.success
                                  : AppColors.primaryRed,
                            ),
                          ),
                          Text(
                            widget.booking.vehicleType,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Regular',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(_currentRouteIndex / _routePoints.length * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Bold',
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _currentRouteIndex / _routePoints.length,
                  backgroundColor: AppColors.lightGrey,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isDelivered ? AppColors.success : AppColors.primaryRed,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Driver: ${widget.booking.driverName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _isDelivered
                          ? 'Completed'
                          : 'Est. ${widget.booking.estimatedTime}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Delivery Details Toggle Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showDeliveryDetails = !_showDeliveryDetails;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: AppColors.primaryRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Delivery Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Bold',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showDeliveryDetails
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Collapsible Delivery Details Card
          if (_showDeliveryDetails)
            Container(
              margin: const EdgeInsets.only(left: 16, right: 16, top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeliveryDetailRow('Booking ID', widget.booking.id),
                  _buildDeliveryDetailRow('Date', widget.booking.date),
                  _buildDeliveryDetailRow('Time', widget.booking.time),
                  _buildDeliveryDetailRow(
                      'Vehicle', widget.booking.vehicleType),
                  _buildDeliveryDetailRow('Driver', widget.booking.driverName),
                  _buildDeliveryDetailRow(
                      'Rating', '${widget.booking.driverRating} ⭐'),
                  _buildDeliveryDetailRow('Fare', widget.booking.fare),
                  _buildDeliveryDetailRow('Payment', 'Cash on Delivery'),
                  _buildDeliveryDetailRow('Package Type', 'Standard Delivery'),
                  _buildDeliveryDetailRow('Weight', 'Up to 500kg'),
                  _buildDeliveryDetailRow('Insurance', 'Basic Coverage'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pickup',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Medium',
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.booking.from,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Medium',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Drop-off',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Medium',
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.booking.to,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Medium',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Map
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _driverLocation,
                zoom: 13.0,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              compassEnabled: true,
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      UIHelpers.showInfoToast(
                          'Contact driver feature coming soon');
                    },
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text(
                      'Contact Driver',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                          color: AppColors.primaryRed.withOpacity(0.3)),
                      foregroundColor: AppColors.primaryRed,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      UIHelpers.showInfoToast(
                          'Emergency support feature coming soon');
                    },
                    icon: const Icon(
                      Icons.support_agent,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Support',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(
            ':',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Medium',
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
