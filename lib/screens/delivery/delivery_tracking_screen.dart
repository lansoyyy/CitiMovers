import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/booking_model.dart';
import '../../models/driver_model.dart';
import '../../rider/services/rider_location_service.dart';
import 'delivery_completion_screen.dart';

enum DeliveryStep {
  headingToWarehouse,
  loading, // Includes "Arrived" -> "Start Loading" -> "Finish Loading"
  delivering,
  unloading, // Includes "Arrived" -> "Start Unloading" -> "Finish Unloading"
  receiving,
  completed
}

enum LoadingSubStep { arrived, startLoading, finishLoading }

enum UnloadingSubStep { arrived, startUnloading, finishUnloading }

class DeliveryTrackingScreen extends StatefulWidget {
  final BookingModel booking;

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
  Timer? _loadingTimer;
  Timer? _unloadingTimer;
  StreamSubscription? _riderLocationSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _bookingSubscription;

  String? _trackingRiderId;

  late BookingModel _booking;

  DeliveryStep _currentStep = DeliveryStep.headingToWarehouse;
  LoadingSubStep? _loadingSubStep;
  UnloadingSubStep? _unloadingSubStep;

  // Demurrage Tracking (Loading)
  Duration _loadingDuration = Duration.zero;
  double _loadingDemurrageFee = 0.0;
  bool _loadingDemurrageStarted = false;

  // Demurrage Tracking (Unloading)
  Duration _unloadingDuration = Duration.zero;
  double _unloadingDemurrageFee = 0.0;
  bool _unloadingDemurrageStarted = false;

  // Photo status tracking
  bool _startLoadingPhotoTaken = false;
  bool _finishLoadingPhotoTaken = false;
  bool _startUnloadingPhotoTaken = false;
  bool _finishUnloadingPhotoTaken = false;
  bool _receiverIdPhotoTaken = false;
  bool _receiverSignatureTaken = false;

  // Firebase Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RiderLocationService _riderLocationService = RiderLocationService();

  // Driver data
  DriverModel? _driver;
  bool _isLoadingDriver = true;

  // Real-time locations from booking
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  LatLng? _driverLocation;
  String? _driverAddress;
  bool _followDriver = true;

  // Route points for polyline
  List<LatLng> _routePoints = [];

  bool _isDelivered = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _initializeLocations();
    _fetchDriverData();
    _startRealTimeLocationTracking();
    _listenToBookingStatus();
  }

  // Fetch driver data from Firestore
  Future<void> _fetchDriverData() async {
    final driverId = _booking.driverId;
    if (driverId != null && driverId.isNotEmpty) {
      try {
        final doc = await _firestore.collection('riders').doc(driverId).get();

        if (doc.exists && doc.data() != null) {
          setState(() {
            _driver = DriverModel.fromMap(doc.data()!);
            _isLoadingDriver = false;
          });
        } else {
          setState(() {
            _isLoadingDriver = false;
          });
        }
      } catch (e) {
        debugPrint('Error fetching driver data: $e');
        setState(() {
          _isLoadingDriver = false;
        });
      }
    } else {
      setState(() {
        _isLoadingDriver = false;
      });
    }
  }

  @override
  void dispose() {
    _riderLocationSubscription?.cancel();
    _bookingSubscription?.cancel();
    _loadingTimer?.cancel();
    _unloadingTimer?.cancel();
    super.dispose();
  }

  /// Initialize locations from booking data
  void _initializeLocations() {
    _pickupLocation = LatLng(
      widget.booking.pickupLocation.latitude,
      widget.booking.pickupLocation.longitude,
    );
    _dropoffLocation = LatLng(
      widget.booking.dropoffLocation.latitude,
      widget.booking.dropoffLocation.longitude,
    );

    // Initialize route points
    _routePoints = [
      _pickupLocation!,
      _dropoffLocation!,
    ];

    // Initialize markers
    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
            title: 'Pickup: ${widget.booking.pickupLocation.address}'),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
            title: 'Drop-off: ${widget.booking.dropoffLocation.address}'),
      ),
    );

    // Initialize polyline from pickup to dropoff
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        color: AppColors.primaryRed,
        width: 4,
        points: _routePoints,
      ),
    );
  }

  Future<BitmapDescriptor> _getVehicleIcon() async {
    // Use a vehicle-like icon for driver marker
    // For now, we'll use default marker with green hue to represent a vehicle
    // In a real app, you would use custom asset images for truck/van icons
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  /// Start real-time location tracking from Firestore
  void _startRealTimeLocationTracking() {
    final driverId = _booking.driverId;

    if (driverId == null || driverId.isEmpty) {
      _riderLocationSubscription?.cancel();
      _riderLocationSubscription = null;
      _trackingRiderId = null;
      return;
    }

    if (_trackingRiderId == driverId && _riderLocationSubscription != null) {
      return;
    }

    _riderLocationSubscription?.cancel();
    _riderLocationSubscription = null;
    _trackingRiderId = driverId;

    _riderLocationSubscription = _riderLocationService
        .listenToRiderLocationDetailed(driverId)
        .listen((locationData) {
      if (!mounted) return;
      if (locationData != null) {
        setState(() {
          _driverLocation = locationData.position;
          _driverAddress = locationData.address;
          _updateDriverMarker();
        });

        // Animate camera to follow driver if follow mode is on
        if (_followDriver && _driverLocation != null) {
          try {
            _mapController.animateCamera(
              CameraUpdate.newLatLng(_driverLocation!),
            );
          } catch (_) {
            // Map controller may not be initialized yet
          }
        }
      }
    });
  }

  /// Listen to booking status changes from Firestore
  void _listenToBookingStatus() {
    final bookingId = widget.booking.bookingId;
    if (bookingId == null || bookingId.isEmpty) return;

    _bookingSubscription = _firestore
        .collection('bookings')
        .doc(bookingId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null || !mounted) return;
      final booking = BookingModel.fromMap({
        ...snapshot.data()!,
        'bookingId': snapshot.id,
      });
      _applyBookingUpdate(booking);
    });
  }

  double get _baseFare {
    final finalFare = _booking.finalFare;
    if (finalFare != null && finalFare > 0) return finalFare;
    return _booking.estimatedFare;
  }

  double _computeDemurrageFee(Duration duration, double baseFare) {
    final blocks = duration.inHours ~/ 4;
    if (blocks <= 0) return 0.0;
    return blocks * 0.25 * baseFare;
  }

  void _applyBookingUpdate(BookingModel booking) {
    final previousDriverId = _booking.driverId;
    final now = DateTime.now();

    final loadingStartedAt = booking.loadingStartedAt;
    final loadingCompletedAt = booking.loadingCompletedAt;
    final unloadingStartedAt = booking.unloadingStartedAt;
    final unloadingCompletedAt = booking.unloadingCompletedAt;

    final loadingDuration = (loadingStartedAt == null)
        ? Duration.zero
        : (loadingCompletedAt ?? now).difference(loadingStartedAt);

    final unloadingDuration = (unloadingStartedAt == null)
        ? Duration.zero
        : (unloadingCompletedAt ?? now).difference(unloadingStartedAt);

    final loadingActive =
        loadingStartedAt != null && loadingCompletedAt == null;
    final unloadingActive =
        unloadingStartedAt != null && unloadingCompletedAt == null;

    final baseFare = (booking.finalFare != null && booking.finalFare! > 0)
        ? booking.finalFare!
        : booking.estimatedFare;

    final loadingFee = booking.loadingDemurrageFee ??
        _computeDemurrageFee(loadingDuration, baseFare);
    final unloadingFee = booking.unloadingDemurrageFee ??
        _computeDemurrageFee(unloadingDuration, baseFare);

    setState(() {
      _booking = booking;
      _updateDeliveryStepFromStatus(booking.status);

      _loadingDuration = loadingDuration;
      _unloadingDuration = unloadingDuration;
      _loadingDemurrageStarted = loadingActive;
      _unloadingDemurrageStarted = unloadingActive;
      _loadingDemurrageFee = loadingFee;
      _unloadingDemurrageFee = unloadingFee;

      final photos = booking.deliveryPhotos;
      if (photos != null) {
        bool hasPhoto(String key) {
          final v = photos[key];
          if (v is String) return v.isNotEmpty;
          if (v is Map) {
            final url = v['url'];
            return url is String && url.isNotEmpty;
          }
          return false;
        }

        _startLoadingPhotoTaken =
            hasPhoto('start_loading') || hasPhoto('start_loading_photo');
        _finishLoadingPhotoTaken = hasPhoto('finish_loading') ||
            hasPhoto('finished_loading') ||
            hasPhoto('finish_loading_photo');
        _startUnloadingPhotoTaken =
            hasPhoto('start_unloading') || hasPhoto('start_unloading_photo');
        _finishUnloadingPhotoTaken = hasPhoto('finish_unloading') ||
            hasPhoto('finished_unloading') ||
            hasPhoto('finish_unloading_photo');
        _receiverIdPhotoTaken =
            hasPhoto('receiver_id') || hasPhoto('receiver_id_photo');
        _receiverSignatureTaken =
            hasPhoto('receiver_signature') || hasPhoto('signature');
      }
    });

    if (loadingActive) {
      if (_loadingTimer == null) _startLoadingTimer();
    } else {
      _loadingTimer?.cancel();
      _loadingTimer = null;
    }

    if (unloadingActive) {
      if (_unloadingTimer == null) _startUnloadingTimer();
    } else {
      _unloadingTimer?.cancel();
      _unloadingTimer = null;
    }

    final currentDriverId = booking.driverId;
    if (currentDriverId != previousDriverId) {
      _fetchDriverData();
      _startRealTimeLocationTracking();
    }
  }

  /// Update delivery step based on booking status
  void _updateDeliveryStepFromStatus(String status) {
    switch (status) {
      case 'pending':
        _currentStep = DeliveryStep.headingToWarehouse;
        break;
      case 'accepted':
        _currentStep = DeliveryStep.headingToWarehouse;
        break;
      case 'arrived_at_pickup':
        _currentStep = DeliveryStep.loading;
        _loadingSubStep = LoadingSubStep.arrived;
        break;
      case 'loading_complete':
        _currentStep = DeliveryStep.delivering;
        break;
      case 'in_transit':
      case 'in_progress':
        _currentStep = DeliveryStep.delivering;
        break;
      case 'arrived_at_dropoff':
        _currentStep = DeliveryStep.unloading;
        _unloadingSubStep = UnloadingSubStep.arrived;
        break;
      case 'unloading_complete':
        _currentStep = DeliveryStep.receiving;
        break;
      case 'completed':
      case 'delivered':
        _currentStep = DeliveryStep.completed;
        if (!_isDelivered) {
          _isDelivered = true;
          UIHelpers.showSuccessToast('Package has arrived at destination!');
        }
        break;
      case 'cancelled':
      case 'cancelled_by_rider':
      case 'rejected':
        _currentStep = DeliveryStep.completed;
        break;
    }
  }

  /// Update driver marker on the map
  void _updateDriverMarker() async {
    if (_driverLocation == null) return;

    final vehicleIcon = await _getVehicleIcon();

    _markers.removeWhere((marker) => marker.markerId.value == 'driver');
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverLocation!,
        icon: vehicleIcon,
        infoWindow: InfoWindow(
          title: 'Driver: ${_driver?.name ?? 'Unknown'}',
          snippet: _driverAddress ?? widget.booking.vehicle.name,
        ),
        rotation: _calculateRotation(),
      ),
    );

    // Update polyline to show route from pickup to driver location
    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        color: AppColors.primaryRed,
        width: 4,
        points: [
          _pickupLocation!,
          _driverLocation!,
          _dropoffLocation!,
        ],
      ),
    );
  }

  void _startLoadingTimer() {
    if (_loadingTimer != null) return;
    _loadingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final start = _booking.loadingStartedAt;
      if (_booking.loadingCompletedAt != null) {
        timer.cancel();
        _loadingTimer = null;
        return;
      }
      if (start == null || !mounted) return;
      setState(() {
        _loadingDuration = DateTime.now().difference(start);
        _calculateLoadingFee();
      });
    });
  }

  void _calculateLoadingFee() {
    // "Every 4 hours - 25% of the delivery fare"
    int blocks = _loadingDuration.inHours ~/ 4;
    if (blocks > 0) {
      final baseFare = _baseFare;
      _loadingDemurrageFee = blocks * 0.25 * baseFare;
    } else {
      _loadingDemurrageFee = 0.0;
    }
  }

  void _startUnloadingTimer() {
    if (_unloadingTimer != null) return;
    _unloadingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final start = _booking.unloadingStartedAt;
      if (_booking.unloadingCompletedAt != null) {
        timer.cancel();
        _unloadingTimer = null;
        return;
      }
      if (start == null || !mounted) return;
      setState(() {
        _unloadingDuration = DateTime.now().difference(start);
        _calculateUnloadingFee();
      });
    });
  }

  void _calculateUnloadingFee() {
    int blocks = _unloadingDuration.inHours ~/ 4;
    if (blocks > 0) {
      final baseFare = _baseFare;
      _unloadingDemurrageFee = blocks * 0.25 * baseFare;
    } else {
      _unloadingDemurrageFee = 0.0;
    }
  }

  double _calculateRotation() {
    if (_driverLocation == null || _pickupLocation == null) return 0.0;

    // Calculate rotation based on direction from pickup to current driver location
    final angle = atan2(
      _driverLocation!.latitude - _pickupLocation!.latitude,
      _driverLocation!.longitude - _pickupLocation!.longitude,
    );
    return angle * 180 / pi;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _animateCameraToRoute();
  }

  void _animateCameraToRoute() {
    if (_pickupLocation == null || _dropoffLocation == null) return;

    // Calculate bounds to show the entire route
    double minLat = _pickupLocation!.latitude;
    double maxLat = _pickupLocation!.latitude;
    double minLng = _pickupLocation!.longitude;
    double maxLng = _pickupLocation!.longitude;

    if (_dropoffLocation != null) {
      minLat = min(minLat, _dropoffLocation!.latitude);
      maxLat = max(maxLat, _dropoffLocation!.latitude);
      minLng = min(minLng, _dropoffLocation!.longitude);
      maxLng = max(maxLng, _dropoffLocation!.longitude);
    }

    if (_driverLocation != null) {
      minLat = min(minLat, _driverLocation!.latitude);
      maxLat = max(maxLat, _driverLocation!.latitude);
      minLng = min(minLng, _driverLocation!.longitude);
      maxLng = max(maxLng, _driverLocation!.longitude);
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
              'Booking ID: ${widget.booking.bookingId}',
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
          // Main scrollable / flexible content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Detailed Step-by-Step Timeline
                  _buildDetailedTimeline(),

                  const SizedBox(height: 16),

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
                                    _getDeliveryStatusText(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Bold',
                                      color: _isDelivered
                                          ? AppColors.success
                                          : AppColors.primaryRed,
                                    ),
                                  ),
                                  Text(
                                    widget.booking.vehicle.name,
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
                                '${_calculateProgress()}%',
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
                          value: _calculateProgress() / 100,
                          backgroundColor: AppColors.lightGrey,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isDelivered
                                ? AppColors.success
                                : AppColors.primaryRed,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isLoadingDriver
                                  ? 'Driver: Loading...'
                                  : 'Driver: ${_driver?.name ?? 'Unknown'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Medium',
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              _isDelivered ? 'Completed' : 'Est. 30 mins',
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

                  // Demurrage Summary
                  _buildDemurrageSummaryCard(),
                  const SizedBox(height: 10),

                  // Current Step Details
                  if (_currentStep != DeliveryStep.completed)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                      child: _buildCurrentStepDetails(),
                    ),

                  const SizedBox(height: 10),

                  // Map (fixed height inside scroll view)
                  SizedBox(
                    height: 300,
                    child: GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _driverLocation ??
                            _pickupLocation ??
                            const LatLng(14.5995, 120.9842),
                        zoom: 13.0,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      gestureRecognizers: <Factory<
                          OneSequenceGestureRecognizer>>{
                        Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer()),
                      },
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      mapToolbarEnabled: false,
                      compassEnabled: true,
                    ),
                  ),
                ],
              ),
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
              child: _isDelivered
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DeliveryCompletionScreen(
                                    booking: _booking,
                                    loadingDemurrage: _loadingDemurrageFee,
                                    unloadingDemurrage: _unloadingDemurrageFee,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.check_circle,
                              size: 20,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Confirm Receipt & Review',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Bold',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Row(
                        //   children: [
                        //     Expanded(
                        //       child: OutlinedButton.icon(
                        //         onPressed: () {
                        //           UIHelpers.showInfoToast(
                        //               'Contact driver feature coming soon');
                        //         },
                        //         icon: const Icon(Icons.phone, size: 18),
                        //         label: const Text(
                        //           'Contact',
                        //           style: TextStyle(
                        //             fontSize: 14,
                        //             fontFamily: 'Medium',
                        //           ),
                        //         ),
                        //         style: OutlinedButton.styleFrom(
                        //           padding:
                        //               const EdgeInsets.symmetric(vertical: 12),
                        //           side: BorderSide(
                        //               color:
                        //                   AppColors.primaryRed.withOpacity(0.3)),
                        //           foregroundColor: AppColors.primaryRed,
                        //         ),
                        //       ),
                        //     ),
                        //     const SizedBox(width: 12),
                        //     Expanded(
                        //       child: OutlinedButton.icon(
                        //         onPressed: () {
                        //           UIHelpers.showInfoToast(
                        //               'Report issue feature coming soon');
                        //         },
                        //         icon: const Icon(Icons.report_problem, size: 18),
                        //         label: const Text(
                        //           'Report',
                        //           style: TextStyle(
                        //             fontSize: 14,
                        //             fontFamily: 'Medium',
                        //           ),
                        //         ),
                        //         style: OutlinedButton.styleFrom(
                        //           padding:
                        //               const EdgeInsets.symmetric(vertical: 12),
                        //           side: BorderSide(
                        //               color:
                        //                   AppColors.primaryRed.withOpacity(0.3)),
                        //           foregroundColor: AppColors.primaryRed,
                        //         ),
                        //       ),
                        //     ),
                        //   ],
                        // ),
                      ],
                    )
                  : null),
        ],
      ),
    );
  }

  String _getDeliveryStatusText() {
    switch (_currentStep) {
      case DeliveryStep.headingToWarehouse:
        return 'Heading to Warehouse';
      case DeliveryStep.loading:
        if (_loadingSubStep == LoadingSubStep.arrived) {
          return 'Arrived at Warehouse';
        }
        if (_loadingSubStep == LoadingSubStep.startLoading) {
          return 'Loading Started';
        }
        if (_loadingSubStep == LoadingSubStep.finishLoading) {
          return 'Loading Completed';
        }
        return 'Loading';
      case DeliveryStep.delivering:
        return 'On the Way';
      case DeliveryStep.unloading:
        if (_unloadingSubStep == UnloadingSubStep.arrived) {
          return 'Arrived at Destination';
        }
        if (_unloadingSubStep == UnloadingSubStep.startUnloading) {
          return 'Unloading Started';
        }
        if (_unloadingSubStep == UnloadingSubStep.finishUnloading) {
          return 'Unloading Completed';
        }
        return 'Unloading';
      case DeliveryStep.receiving:
        return 'Receiving Package';
      case DeliveryStep.completed:
        return 'Delivered';
    }
  }

  String _getPhotoUrl(String key) {
    final photos = _booking.deliveryPhotos;
    if (photos == null) return '';
    final value = photos[key];
    if (value is String) return value;
    if (value is Map && value['url'] is String) return value['url'];
    return '';
  }

  void _viewImageFullScreen(String? imageUrl, String title) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(title),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 50),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewSignatureFullScreen(String? imageUrl, String title) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor:
              Colors.white, // WHITE background for signature visibility
          appBar: AppBar(
            backgroundColor: AppColors.white,
            title: Text(title),
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppColors.primaryRed,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.primaryRed, size: 50),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load signature',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedTimeline() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
          const Row(
            children: [
              Icon(Icons.timeline, color: AppColors.primaryRed, size: 20),
              SizedBox(width: 8),
              Text(
                'Delivery Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Step 1: Heading to Warehouse
          _buildTimelineStep(
            stepNumber: 1,
            title: 'Heading to Warehouse',
            subtitle: 'Driver is en route to pickup location',
            icon: Icons.warehouse,
            isActive: _currentStep == DeliveryStep.headingToWarehouse,
            isCompleted:
                _currentStep.index > DeliveryStep.headingToWarehouse.index,
            subSteps: [],
          ),

          // Step 2: Loading Process
          _buildTimelineStep(
            stepNumber: 2,
            title: 'Loading Process',
            subtitle: 'At warehouse - loading goods',
            icon: Icons.inventory,
            isActive: _currentStep == DeliveryStep.loading,
            isCompleted: _currentStep.index > DeliveryStep.loading.index,
            subSteps: [
              _buildSubStep(
                  'Arrived at Warehouse', _loadingSubStep != null, null),
              _buildSubStep(
                  'Start Loading Photo',
                  _startLoadingPhotoTaken,
                  _startLoadingPhotoTaken
                      ? _getPhotoUrl('start_loading')
                      : null),
              _buildSubStep(
                  'Finish Loading Photo',
                  _finishLoadingPhotoTaken,
                  _finishLoadingPhotoTaken
                      ? _getPhotoUrl('finish_loading')
                      : null),
            ],
          ),

          // Step 3: In Transit
          _buildTimelineStep(
            stepNumber: 3,
            title: 'In Transit',
            subtitle: 'Package is on the way',
            icon: Icons.local_shipping,
            isActive: _currentStep == DeliveryStep.delivering,
            isCompleted: _currentStep.index > DeliveryStep.delivering.index,
            subSteps: [],
          ),

          // Step 4: Unloading Process
          _buildTimelineStep(
            stepNumber: 4,
            title: 'Unloading Process',
            subtitle: 'At destination - unloading goods',
            icon: Icons.unarchive,
            isActive: _currentStep == DeliveryStep.unloading,
            isCompleted: _currentStep.index > DeliveryStep.unloading.index,
            subSteps: [
              _buildSubStep(
                  'Arrived at Destination', 
                  _unloadingSubStep != null, 
                  _unloadingSubStep != null
                      ? (_getPhotoUrl('destination_arrival').isNotEmpty
                          ? _getPhotoUrl('destination_arrival')
                          : _getPhotoUrl('dropoff_arrival'))
                      : null),
              _buildSubStep(
                  'Arrival Remarks',
                  _getPhotoUrl('destination_arrival_remarks').isNotEmpty,
                  null,
                  remark: _booking.deliveryPhotos?['destination_arrival_remarks']?.toString()),
              _buildSubStep(
                  'Start Unloading Photo',
                  _startUnloadingPhotoTaken,
                  _startUnloadingPhotoTaken
                      ? _getPhotoUrl('start_unloading')
                      : null),
              _buildSubStep(
                  'Finish Unloading Photo',
                  _finishUnloadingPhotoTaken,
                  _finishUnloadingPhotoTaken
                      ? _getPhotoUrl('finish_unloading')
                      : null),
            ],
          ),

          // Step 5: Receiving
          _buildTimelineStep(
            stepNumber: 5,
            title: 'Receiving',
            subtitle: 'Handover to receiver',
            icon: Icons.person_pin,
            isActive: _currentStep == DeliveryStep.receiving,
            isCompleted: _currentStep.index > DeliveryStep.receiving.index,
            subSteps: [
              if (_booking.receiverName != null && _booking.receiverName!.isNotEmpty)
                _buildSubStep(
                    'Receiver: ${_booking.receiverName}',
                    true,
                    null),
              _buildSubStep(
                  'Receiver ID Photo',
                  _receiverIdPhotoTaken,
                  _receiverIdPhotoTaken
                      ? (_getPhotoUrl('receiver_id').isNotEmpty
                          ? _getPhotoUrl('receiver_id')
                          : _getPhotoUrl('receiver_id_photo'))
                      : null),
              _buildSubStep(
                  'Digital Signature',
                  _receiverSignatureTaken,
                  _receiverSignatureTaken
                      ? (_getPhotoUrl('receiver_signature').isNotEmpty
                          ? _getPhotoUrl('receiver_signature')
                          : _getPhotoUrl('signature'))
                      : null),
            ],
          ),

          // Step 6: Completed
          _buildTimelineStep(
            stepNumber: 6,
            title: 'Completed',
            subtitle: 'Delivery finished successfully',
            icon: Icons.check_circle,
            isActive: _currentStep == DeliveryStep.completed,
            isCompleted: _currentStep == DeliveryStep.completed,
            subSteps: [],
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required int stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required bool isCompleted,
    required List<Widget> subSteps,
    bool isLast = false,
  }) {
    Color stepColor;
    if (isCompleted) {
      stepColor = AppColors.success;
    } else if (isActive) {
      stepColor = AppColors.primaryRed;
    } else {
      stepColor = AppColors.grey;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and number
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted || isActive
                      ? stepColor.withOpacity(0.1)
                      : AppColors.lightGrey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted || isActive ? stepColor : AppColors.grey,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, size: 16, color: stepColor)
                      : Text(
                          '$stepNumber',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Bold',
                            color: isActive ? stepColor : AppColors.grey,
                          ),
                        ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        isCompleted ? AppColors.success : AppColors.lightGrey,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryRed.withOpacity(0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isActive
                        ? Border.all(
                            color: AppColors.primaryRed.withOpacity(0.2))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 20, color: stepColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: isActive || isCompleted
                                        ? 'Bold'
                                        : 'Medium',
                                    color: isActive || isCompleted
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Bold',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (subSteps.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...subSteps,
                      ],
                    ],
                  ),
                ),
                if (!isLast) const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubStep(String label, bool completed, String? photoUrl, {String? remark}) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 14,
                color: completed ? AppColors.success : AppColors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        completed ? AppColors.textPrimary : AppColors.textSecondary,
                    fontFamily: completed ? 'Medium' : 'Regular',
                  ),
                ),
              ),
              if (completed && photoUrl != null && photoUrl.isNotEmpty)
                GestureDetector(
                  onTap: () => label == 'Digital Signature'
                      ? _viewSignatureFullScreen(photoUrl, label)
                      : _viewImageFullScreen(photoUrl, label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility,
                            size: 12, color: AppColors.primaryBlue),
                        const SizedBox(width: 4),
                        Text(
                          'View',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryBlue,
                            fontFamily: 'Medium',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (remark != null && remark.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  'Remarks: $remark',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIcon(DeliveryStep step, IconData icon, String label) {
    Color color = AppColors.grey;
    if (_currentStep.index >= step.index) color = AppColors.primaryRed;
    if (_currentStep == DeliveryStep.completed) color = AppColors.success;

    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'Medium',
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(DeliveryStep nextStep) {
    bool isActive = _currentStep.index >= nextStep.index;
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? AppColors.primaryRed : AppColors.lightGrey,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      ),
    );
  }

  Widget _buildDemurrageSummaryCard() {
    final double totalDemurrage = _loadingDemurrageFee + _unloadingDemurrageFee;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.timer,
                  color: AppColors.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Demurrage Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDemurrageInfo(
              'Loading', _loadingDuration, _loadingDemurrageFee),
          const SizedBox(height: 8),
          _buildDemurrageInfo(
              'Unloading', _unloadingDuration, _unloadingDemurrageFee),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Demurrage',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Medium',
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'P${totalDemurrage.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.primaryRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Demurrage is charged every 4 hours at 25% of delivery fare.',
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'Regular',
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepDetails() {
    switch (_currentStep) {
      case DeliveryStep.headingToWarehouse:
        return _buildHeadingToWarehouseDetails();
      case DeliveryStep.loading:
        return _buildLoadingDetails();
      case DeliveryStep.delivering:
        return _buildDeliveringDetails();
      case DeliveryStep.unloading:
        return _buildUnloadingDetails();
      case DeliveryStep.receiving:
        return _buildReceivingDetails();
      case DeliveryStep.completed:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeadingToWarehouseDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warehouse, color: AppColors.primaryRed, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Heading to Pickup',
              style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Driver is heading to the warehouse to pick up your package.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          'Distance: Calculating...',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildLoadingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory, color: AppColors.primaryRed, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Loading Process',
              style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildProcessStep('Arrived at Warehouse', _loadingSubStep != null),
        _buildProcessStep('Start Loading Photo', _startLoadingPhotoTaken),
        _buildProcessStep('Finish Loading Photo', _finishLoadingPhotoTaken),
        if (_loadingDemurrageStarted) ...[
          const SizedBox(height: 8),
          _buildDemurrageInfo(
              'Loading', _loadingDuration, _loadingDemurrageFee),
        ],
      ],
    );
  }

  Widget _buildDeliveringDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_shipping,
                color: AppColors.primaryBlue, size: 20),
            const SizedBox(width: 8),
            const Text(
              'On the Way',
              style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Your package is in transit to the destination.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          'Est. Time: 30 mins',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildUnloadingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.unarchive, color: AppColors.primaryRed, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Unloading Process',
              style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildProcessStep('Arrived at Destination', _unloadingSubStep != null),
        _buildProcessStep('Start Unloading Photo', _startUnloadingPhotoTaken),
        _buildProcessStep('Finish Unloading Photo', _finishUnloadingPhotoTaken),
        if (_unloadingDemurrageStarted) ...[
          const SizedBox(height: 8),
          _buildDemurrageInfo(
              'Unloading', _unloadingDuration, _unloadingDemurrageFee),
        ],
      ],
    );
  }

  Widget _buildReceivingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_pin, color: AppColors.primaryRed, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Receiving Process',
              style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildProcessStep('Receiver ID Verified', _receiverIdPhotoTaken),
        _buildProcessStep('Digital Signature', _receiverSignatureTaken),
        const SizedBox(height: 8),
        Text(
          'Package is being handed over to the receiver.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildProcessStep(String label, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: completed ? AppColors.success : AppColors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color:
                  completed ? AppColors.textPrimary : AppColors.textSecondary,
              fontFamily: completed ? 'Medium' : 'Regular',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemurrageInfo(String type, Duration duration, double fee) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String timerText =
        '${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$type Time: $timerText (Fee: P${fee.toStringAsFixed(2)})',
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate delivery progress percentage based on current step
  int _calculateProgress() {
    switch (_currentStep) {
      case DeliveryStep.headingToWarehouse:
        return 10;
      case DeliveryStep.loading:
        if (_loadingSubStep == LoadingSubStep.arrived) return 20;
        if (_loadingSubStep == LoadingSubStep.startLoading) return 30;
        if (_loadingSubStep == LoadingSubStep.finishLoading) return 40;
        return 20;
      case DeliveryStep.delivering:
        return 60;
      case DeliveryStep.unloading:
        if (_unloadingSubStep == UnloadingSubStep.arrived) return 70;
        if (_unloadingSubStep == UnloadingSubStep.startUnloading) return 80;
        if (_unloadingSubStep == UnloadingSubStep.finishUnloading) return 90;
        return 70;
      case DeliveryStep.receiving:
        return 95;
      case DeliveryStep.completed:
        return 100;
    }
  }
}
