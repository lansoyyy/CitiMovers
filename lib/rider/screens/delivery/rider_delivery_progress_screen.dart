import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:citimovers/rider/models/delivery_request_model.dart';
import 'package:citimovers/rider/services/rider_auth_service.dart';
import 'package:citimovers/services/booking_service.dart';
import 'package:citimovers/services/storage_service.dart';
import 'package:citimovers/services/location_service.dart';
import 'package:citimovers/services/maps_service.dart';
import 'package:citimovers/utils/app_colors.dart';
import 'package:citimovers/utils/ui_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:citimovers/rider/services/rider_location_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:citimovers/config/integrations_config.dart';
import 'package:citimovers/services/emailjs_service.dart';
import 'package:citimovers/services/wallet_service.dart';
import 'package:citimovers/services/gps_map_camera_service.dart';
import 'package:citimovers/services/chat_service.dart';
import 'package:citimovers/screens/chat/chat_screen.dart';
import 'package:citimovers/models/location_model.dart';
import 'package:citimovers/services/delivery_queue_service.dart';

class RiderDeliveryProgressScreen extends StatefulWidget {
  final DeliveryRequest request;

  const RiderDeliveryProgressScreen({
    super.key,
    required this.request,
  });

  @override
  State<RiderDeliveryProgressScreen> createState() =>
      _RiderDeliveryProgressScreenState();
}

enum DeliveryStep {
  headingToWarehouse,
  loading, // Includes "Arrived" -> "Start Loading" -> "Finish Loading"
  delivering,
  unloading, // Includes "Arrived" -> "Start Unloading" -> "Finish Unloading"
  damageReport, // Report damaged items after unloading
  receiving,
  completed
}

enum LoadingSubStep { arrived, startLoading, finishLoading }

enum UnloadingSubStep { arrived, startUnloading, finishUnloading }

enum ReceivingSubStep { receiverName, receiverIdPhoto, received, signature }

class _RiderDeliveryProgressScreenState
    extends State<RiderDeliveryProgressScreen> with TickerProviderStateMixin {
  final RiderAuthService _riderAuthService = RiderAuthService();
  final BookingService _bookingService = BookingService();
  final StorageService _storageService = StorageService();
  final LocationService _locationService = LocationService();
  final MapsService _mapsService = MapsService();
  final WalletService _walletService = WalletService();
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DeliveryStep _currentStep = DeliveryStep.headingToWarehouse;
  LoadingSubStep? _loadingSubStep;
  UnloadingSubStep? _unloadingSubStep;
  ReceivingSubStep _receivingSubStep = ReceivingSubStep.receiverName;

  // Demurrage Tracking (Loading)
  Timer? _loadingTimer;
  Duration _loadingDuration = Duration.zero;
  double _loadingDemurrageFee = 0.0;
  File? _startLoadingPhoto;
  File? _finishLoadingPhoto;

  // Demurrage Tracking (Unloading)
  Timer? _unloadingTimer;
  Duration _unloadingDuration = Duration.zero;
  double _unloadingDemurrageFee = 0.0;
  File? _startUnloadingPhoto;
  File? _finishUnloadingPhoto;

  // Geofencing
  bool _isWithinGeofence = true;
  String _geofenceStatus = 'Within delivery area';

  // Warehouse Arrival GPS Photo
  File? _warehouseArrivalPhoto;
  String? _warehouseArrivalPhotoUrl;
  final TextEditingController _arrivalRemarksController =
      TextEditingController();
  final GpsMapCameraService _gpsCameraService = GpsMapCameraService();

  /// Offline-first photo-upload queue with 10-minute retry.
  final DeliveryQueueService _deliveryQueue = DeliveryQueueService.instance;

  /// Resolved receiver-signature URL (set via queue callback after upload).
  String? _signatureUrl;

  // Destination Arrival GPS Photo
  File? _destinationArrivalPhoto;
  String? _destinationArrivalPhotoUrl;
  final TextEditingController _destinationArrivalRemarksController =
      TextEditingController();

  // Receiving
  final _receiverNameController = TextEditingController();
  File? _idPhoto;
  List<Offset?> _signaturePoints = [];
  bool _isSignatureEmpty = true;
  final GlobalKey _signatureKey = GlobalKey();

  bool _receiverIdPhotoConfirmed = false;

  final List<File> _serviceInvoicePhotos = [];
  final List<String> _serviceInvoicePhotoUrls = [];

  final List<Map<String, dynamic>> _picklistItems = [];

  // Damage Reporting
  bool _hasDamage = false;
  final List<Map<String, dynamic>> _damagedItems = [];
  final List<File> _damagePhotos = [];
  final List<String> _damagePhotoUrls = [];
  final TextEditingController _damageItemController = TextEditingController();
  final TextEditingController _damageQtyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _geocodeAddresses();
    _startLocationTracking();
    // Start the offline-first upload queue (10-min retry + connectivity trigger)
    _deliveryQueue.start();
    // Register URL-resolved callbacks so in-memory state stays up-to-date
    _registerQueueCallbacks();
  }

  /// Register callbacks that fire whenever the queue successfully uploads a
  /// queued photo.  This keeps all `_xxxPhotoUrl` state variables current.
  void _registerQueueCallbacks() {
    final id = widget.request.id;
    _deliveryQueue.onUrlResolved(id, 'start_loading', (url) {
      if (mounted) setState(() => _startLoadingPhotoUrl = url);
    });
    _deliveryQueue.onUrlResolved(id, 'finished_loading', (url) {
      if (mounted) setState(() => _finishLoadingPhotoUrl = url);
    });
    _deliveryQueue.onUrlResolved(id, 'start_unloading', (url) {
      if (mounted) setState(() => _startUnloadingPhotoUrl = url);
    });
    _deliveryQueue.onUrlResolved(id, 'finished_unloading', (url) {
      if (mounted) setState(() => _finishUnloadingPhotoUrl = url);
    });
    _deliveryQueue.onUrlResolved(id, 'receiver_id', (url) {
      if (mounted) setState(() => _idPhotoUrl = url);
    });
    _deliveryQueue.onUrlResolved(id, 'receiver_signature', (url) {
      if (mounted) setState(() => _signatureUrl = url);
    });
    _deliveryQueue.onUrlResolved(id, 'warehouse_arrival', (url) {
      if (mounted) setState(() => _warehouseArrivalPhotoUrl = url);
    });
    _deliveryQueue.onUrlResolved(id, 'destination_arrival', (url) {
      if (mounted) setState(() => _destinationArrivalPhotoUrl = url);
    });
  }

  Widget _buildTotalDemurrageHoursCard() {
    final totalSeconds =
        _loadingDuration.inSeconds + _unloadingDuration.inSeconds;
    final hours = totalSeconds / 3600.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.timer, color: AppColors.primaryRed),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Total Demurrage Hours',
              style: TextStyle(fontSize: 14, fontFamily: 'Bold'),
            ),
          ),
          Text(
            '${hours.toStringAsFixed(2)} hrs',
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _unloadingTimer?.cancel();
    _locationTrackingTimer?.cancel();
    _receiverNameController.dispose();
    _arrivalRemarksController.dispose();
    _destinationArrivalRemarksController.dispose();

    // Save current delivery state before disposing
    _saveDeliveryState();

    // Stop the offline queue and remove URL callbacks
    _deliveryQueue.stop();
    final id = widget.request.id;
    for (final stage in [
      'start_loading',
      'finished_loading',
      'start_unloading',
      'finished_unloading',
      'receiver_id',
      'receiver_signature',
      'warehouse_arrival',
      'destination_arrival',
    ]) {
      _deliveryQueue.removeUrlCallback(id, stage);
    }

    super.dispose();
  }

  /// Save current delivery state for resume after login
  void _saveDeliveryState() {
    // Only save if not completed
    if (_currentStep == DeliveryStep.completed) {
      _riderAuthService.clearActiveDeliveryState();
      return;
    }

    _riderAuthService.saveActiveDeliveryState(
      bookingId: widget.request.id,
      currentStep: _currentStep.toString(),
      loadingSubStep: _loadingSubStep?.toString(),
      unloadingSubStep: _unloadingSubStep?.toString(),
      receivingSubStep: _receivingSubStep.toString(),
    );
  }

  /// Start periodic location tracking — every 3 seconds for real-time navigation
  void _startLocationTracking() {
    // Do an initial location update immediately
    _updateDriverLocation();

    _locationTrackingTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) return;
      await _updateDriverLocation();
    });
  }

  /// Fetch GPS, reverse-geocode (throttled), push to Firestore, update UI
  Future<void> _updateDriverLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (location == null || !mounted) return;

    final newLatLng = LatLng(location.latitude, location.longitude);

    // Throttle reverse geocoding — only every 15 s or if moved > 100 m
    String? address = _currentDriverAddress;
    final now = DateTime.now();
    final shouldUpdateAddress = _lastAddressUpdate == null ||
        now.difference(_lastAddressUpdate!).inSeconds >= 15 ||
        (_currentDriverLocation != null &&
            _distanceMeters(_currentDriverLocation!, newLatLng) > 100);

    if (shouldUpdateAddress) {
      final result = await _mapsService.getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (result != null) {
        address = result.address;
        _lastAddressUpdate = now;
      }
    }

    if (!mounted) return;

    setState(() {
      _currentDriverLocation = newLatLng;
      _currentDriverAddress = address;
    });

    // Push to Firestore (auth service writes top-level + nested currentLocation)
    await _riderAuthService.updateLocation(
      location.latitude,
      location.longitude,
      address: address,
    );

    // Animate map camera to follow driver - only if map controller is valid
    if (_isMapControllerValid && _activeMapController != null) {
      try {
        await _activeMapController!.animateCamera(
          CameraUpdate.newLatLng(newLatLng),
        );
      } catch (e) {
        // If animation fails, mark controller as invalid
        _isMapControllerValid = false;
        debugPrint(
            'Map camera animation error, marking controller as invalid: $e');
      }
    }
  }

  /// Simple equirectangular distance in metres (good enough for short distances)
  double _distanceMeters(LatLng a, LatLng b) {
    const double earthRadius = 6371000; // metres
    final dLat = (b.latitude - a.latitude) * 3.14159265359 / 180;
    final dLng = (b.longitude - a.longitude) * 3.14159265359 / 180;
    final avgLat = (a.latitude + b.latitude) / 2 * 3.14159265359 / 180;
    final x = dLng * _cos(avgLat);
    return earthRadius * _sqrt(x * x + dLat * dLat);
  }

  double _cos(double rad) => rad.cos();
  double _sqrt(double val) => val.sqrt();

  final ImagePicker _picker = ImagePicker();

  // Photo URLs for Firebase uploads
  String? _startLoadingPhotoUrl;
  String? _finishLoadingPhotoUrl;
  String? _startUnloadingPhotoUrl;
  String? _finishUnloadingPhotoUrl;
  String? _idPhotoUrl;

  // Location tracking timer
  Timer? _locationTrackingTimer;

  // Real-time driver location
  LatLng? _currentDriverLocation;
  String? _currentDriverAddress;
  DateTime? _lastAddressUpdate;
  GoogleMapController? _activeMapController;

  // Flag to track if map controller is valid (not disposed)
  bool _isMapControllerValid = false;

  // In-dialog loading state for GPS photo capture (avoids Navigator.pop race condition)
  bool _isCapturingArrivalPhoto = false;
  bool _isCapturingDestinationPhoto = false;

  // Actual coordinates from geocoding
  LatLng? _pickupCoordinates;
  LatLng? _dropoffCoordinates;

  // Route points for polyline (from Google Maps Directions API)
  List<LatLng> _routePoints = [];

  Set<Marker> _createMarkersWithDriver(
      LatLng position, String id, String title) {
    final markers = <Marker>{
      Marker(
        markerId: MarkerId(id),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
    if (_currentDriverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _currentDriverLocation!,
          infoWindow: InfoWindow(
            title: 'My Location',
            snippet: _currentDriverAddress ?? 'Locating...',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    return markers;
  }

  Set<Marker> _createRouteMarkers() {
    if (_pickupCoordinates == null || _dropoffCoordinates == null) {
      return {};
    }
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupCoordinates!,
        infoWindow: const InfoWindow(title: 'Pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffCoordinates!,
        infoWindow: const InfoWindow(title: 'Dropoff'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
    if (_currentDriverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _currentDriverLocation!,
          infoWindow: InfoWindow(
            title: 'My Location',
            snippet: _currentDriverAddress ?? 'Locating...',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    return markers;
  }

  // --- Actions ---

  void _logActivity(String event) {
    debugPrint(
        'RiderDeliveryProgressScreen(${widget.request.id}) activity: $event');
  }

  /// Geocode address to get coordinates
  Future<void> _geocodeAddresses() async {
    try {
      // Geocode pickup location
      final pickupCoords = await _mapsService.getCoordinatesFromAddress(
        widget.request.pickupLocation,
      );
      if (pickupCoords != null) {
        setState(() {
          _pickupCoordinates = LatLng(
            pickupCoords.latitude,
            pickupCoords.longitude,
          );
        });
      }

      // Geocode dropoff location
      final dropoffCoords = await _mapsService.getCoordinatesFromAddress(
        widget.request.deliveryLocation,
      );
      if (dropoffCoords != null) {
        setState(() {
          _dropoffCoordinates = LatLng(
            dropoffCoords.latitude,
            dropoffCoords.longitude,
          );
        });
      }

      // Fetch route from Google Maps Directions API after coordinates are set
      await _fetchRouteAndDrawPolyline();
    } catch (e) {
      debugPrint('Error geocoding addresses: $e');
      // Fallback to Manila coordinates if geocoding fails
      setState(() {
        _pickupCoordinates = const LatLng(14.5995, 120.9842);
        _dropoffCoordinates = const LatLng(14.5995, 120.9842);
      });
    }
  }

  /// Fetch route from Google Maps Directions API and draw polyline
  Future<void> _fetchRouteAndDrawPolyline() async {
    if (_pickupCoordinates == null || _dropoffCoordinates == null) return;

    try {
      final routeInfo = await _mapsService.calculateRoute(
        LocationModel(
          address: widget.request.pickupLocation,
          latitude: _pickupCoordinates!.latitude,
          longitude: _pickupCoordinates!.longitude,
        ),
        LocationModel(
          address: widget.request.deliveryLocation,
          latitude: _dropoffCoordinates!.latitude,
          longitude: _dropoffCoordinates!.longitude,
        ),
      );

      if (routeInfo != null && routeInfo.polylinePoints.isNotEmpty) {
        setState(() {
          _routePoints = routeInfo.polylinePoints
              .map((point) => LatLng(point['latitude']!, point['longitude']!))
              .toList();
        });
      } else {
        // Fallback to straight line if route API fails
        setState(() {
          _routePoints = [
            _pickupCoordinates!,
            _dropoffCoordinates!,
          ];
        });
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      // Fallback to straight line on error
      setState(() {
        _routePoints = [
          _pickupCoordinates!,
          _dropoffCoordinates!,
        ];
      });
    }
  }

  /// Get center position between pickup and dropoff for map camera
  LatLng _getCenterPosition() {
    if (_pickupCoordinates == null && _dropoffCoordinates == null) {
      return const LatLng(14.5995, 120.9842); // Manila fallback
    }
    if (_pickupCoordinates == null) {
      return _dropoffCoordinates!;
    }
    if (_dropoffCoordinates == null) {
      return _pickupCoordinates!;
    }
    return LatLng(
      (_pickupCoordinates!.latitude + _dropoffCoordinates!.latitude) / 2,
      (_pickupCoordinates!.longitude + _dropoffCoordinates!.longitude) / 2,
    );
  }

  void _arrivedAtWarehouse() async {
    _logActivity('arrived_at_pickup_prompt');

    // Show GPS Photo Capture Dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildWarehouseArrivalDialog(),
    );

    if (result == null || result['confirmed'] != true) {
      // User cancelled
      return;
    }

    _logActivity('arrived_at_pickup');

    setState(() {
      _currentStep = DeliveryStep.loading;
      _loadingSubStep = LoadingSubStep.arrived;
      _startLoadingTimer();
    });

    // Save delivery state
    _saveDeliveryState();

    // Update booking status in Firestore with arrival photo and remarks
    await _bookingService.updateBookingStatusWithDetails(
      bookingId: widget.request.id,
      status: 'arrived_at_pickup',
      loadingStartedAt: DateTime.now(),
      picklistItems: _picklistItems,
      deliveryPhotos: {
        'warehouse_arrival': _warehouseArrivalPhotoUrl,
        'warehouse_arrival_remarks': result['remarks'] ?? '',
      },
    );

    UIHelpers.showSuccessToast(
        'Arrived at warehouse! GPS photo captured. Demurrage timer started.');
  }

  /// Build the warehouse arrival dialog with GPS photo capture and interactive map
  Widget _buildWarehouseArrivalDialog() {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Arrival at Warehouse',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Bold',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // Clear map controller reference before closing dialog
                          _activeMapController = null;
                          _isMapControllerValid = false;
                          Navigator.pop(context, {'confirmed': false});
                        },
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Instructions
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: AppColors.primaryBlue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'REMARKS: Take a photo at the front gate after arrival. GPS location will be embedded in the photo.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Interactive Map Section
                          const Text(
                            'Current Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Interactive Google Map
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.lightGrey),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _currentDriverLocation ??
                                      _pickupCoordinates ??
                                      const LatLng(14.5995, 120.9842),
                                  zoom: 16,
                                ),
                                markers: _createMarkersWithDriver(
                                  _pickupCoordinates ??
                                      const LatLng(14.5995, 120.9842),
                                  'warehouse',
                                  'Warehouse Location',
                                ),
                                gestureRecognizers: <Factory<
                                    OneSequenceGestureRecognizer>>{
                                  Factory<OneSequenceGestureRecognizer>(
                                      () => EagerGestureRecognizer()),
                                },
                                zoomControlsEnabled: true,
                                mapToolbarEnabled: true,
                                myLocationEnabled: true,
                                myLocationButtonEnabled: true,
                                zoomGesturesEnabled: true,
                                scrollGesturesEnabled: true,
                                rotateGesturesEnabled: true,
                                tiltGesturesEnabled: true,
                                onMapCreated: (controller) {
                                  _activeMapController = controller;
                                  _isMapControllerValid = true;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Pinch to zoom, drag to pan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // GPS Photo Section
                          const Text(
                            'GPS Photo at Front Gate',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Photo Preview - No scroll conflicts here
                          if (_isCapturingArrivalPhoto)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          if (!_isCapturingArrivalPhoto)
                            GestureDetector(
                              onTap: () async {
                                await _takeGpsArrivalPhoto(
                                  onPhotoTaken: () => setDialogState(() {}),
                                  setLoading: (v) => setDialogState(
                                      () => _isCapturingArrivalPhoto = v),
                                );
                              },
                              child: Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _warehouseArrivalPhoto != null
                                        ? AppColors.success
                                        : AppColors.lightGrey,
                                    width: 2,
                                  ),
                                  image: _warehouseArrivalPhoto != null
                                      ? DecorationImage(
                                          image: FileImage(
                                              _warehouseArrivalPhoto!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _warehouseArrivalPhoto == null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.camera_alt,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap to take GPS photo',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Location & timestamp will be embedded',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            ),

                          if (_warehouseArrivalPhoto != null) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton.icon(
                                onPressed: () async {
                                  await _takeGpsArrivalPhoto(
                                    onPhotoTaken: () => setDialogState(() {}),
                                    setLoading: (v) => setDialogState(
                                        () => _isCapturingArrivalPhoto = v),
                                  );
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retake Photo'),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Remarks Field
                          const Text(
                            'Remarks (Optional)',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Bold',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _arrivalRemarksController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText:
                                  'Enter any remarks about the arrival...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            // Clear map controller reference before closing dialog
                            _activeMapController = null;
                            _isMapControllerValid = false;
                            Navigator.pop(context, {'confirmed': false});
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _warehouseArrivalPhoto != null
                              ? () {
                                  // Clear map controller reference before closing dialog
                                  _activeMapController = null;
                                  _isMapControllerValid = false;
                                  Navigator.pop(context, {
                                    'confirmed': true,
                                    'remarks': _arrivalRemarksController.text,
                                  });
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Confirm Arrival',
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
              ],
            ),
          ),
        );
      },
    );
  }

  /// Take GPS photo at warehouse arrival.
  /// Uses [setLoading] to show/hide an in-dialog overlay — avoids the
  /// fragile Navigator.pop(context) race condition that caused the stuck CPI.
  Future<void> _takeGpsArrivalPhoto({
    VoidCallback? onPhotoTaken,
    void Function(bool)? setLoading,
  }) async {
    try {
      _logActivity('take_gps_photo:warehouse_arrival');

      // Show loading while getting GPS location
      setLoading?.call(true);
      final locationData = await _gpsCameraService.getCurrentLocationData();

      // Hide loading before opening camera (native activity)
      setLoading?.call(false);

      // Take photo
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) return;

      // Show processing while adding watermark + uploading
      setLoading?.call(true);

      // Add GPS watermark
      final File originalFile = File(image.path);
      final File watermarkedFile = await _gpsCameraService.addGpsWatermark(
        originalFile,
        locationData,
      );

      if (mounted) {
        setState(() {
          _warehouseArrivalPhoto = watermarkedFile;
        });
      }

      // ── Upload queued in background; hide loading and let driver proceed ──
      setLoading?.call(false);

      await _deliveryQueue.enqueuePhotoUpload(
        bookingId: widget.request.id,
        storageStage: 'Warehouse Arrival GPS',
        firestoreStage: 'warehouse_arrival',
        localFilePath: watermarkedFile.path,
      );

      if (mounted) {
        UIHelpers.showSuccessToast(
            'Arrival photo saved! Uploading to cloud in background.');
      }

      // Notify dialog to refresh photo preview
      onPhotoTaken?.call();
    } catch (e) {
      setLoading?.call(false);
      debugPrint('Error taking GPS photo: $e');
      if (mounted) {
        UIHelpers.showErrorToast('Error taking GPS photo: $e');
      }
    }
  }

  void _startLoadingTimer() {
    _loadingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _loadingDuration += const Duration(seconds: 1);
        _loadingDemurrageFee = 0.0;
      });
    });
  }

  void _startLoadingPhotoProcess() {
    setState(() {
      _loadingSubStep = LoadingSubStep.startLoading;
    });
  }

  void _finishLoadingPhotoProcess() {
    setState(() {
      _loadingSubStep = LoadingSubStep.finishLoading;
    });
  }

  Future<void> _takePhoto(Function(File) onPicked, String photoType,
      {Function(File)? onRemove}) async {
    _logActivity('take_photo:$photoType');
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final file = File(image.path);

    // ── Set file in local state immediately so the driver can proceed ──
    setState(() {
      onPicked(file);
    });

    // ── Advance the UI sub-step right away; no need to wait for upload ──
    if (photoType == 'Start Loading') {
      _startLoadingPhotoProcess();
    } else if (photoType == 'Finished Loading') {
      _finishLoadingPhotoProcess();
    } else if (photoType == 'Start Unloading') {
      _startUnloadingPhotoProcess();
    } else if (photoType == 'Finished Unloading') {
      _finishUnloadingPhotoProcess();
    }
    // Damage/truck photos — URL added to list by the queue callback

    // ── Queue upload; retried every 10 min until it succeeds ──
    final firestoreStage = photoType.toLowerCase().replaceAll(' ', '_');
    await _deliveryQueue.enqueuePhotoUpload(
      bookingId: widget.request.id,
      storageStage: photoType,
      firestoreStage: firestoreStage,
      localFilePath: file.path,
    );

    // For damage photos, register a callback that appends the URL to the list
    if (photoType == 'Damaged Boxes' || photoType == 'Empty Truck') {
      _deliveryQueue.onUrlResolved(widget.request.id, firestoreStage, (url) {
        if (mounted) setState(() => _damagePhotoUrls.add(url));
      });
    }

    UIHelpers.showSuccessToast(
        '$photoType photo saved! Uploading in background.');
  }

  Future<void> _persistPicklistItems() async {
    try {
      await _firestore.collection('bookings').doc(widget.request.id).update({
        'picklistItems': _picklistItems,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Error saving picklist items: $e');
    }
  }

  Future<void> _addPicklistItem() async {
    _logActivity('picklist:add');
    final itemController = TextEditingController();
    final qtyController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Picklist Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemController,
              decoration: const InputDecoration(
                labelText: 'Type of Goods/Items',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(
                labelText: 'Quantity/Cases',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final item = itemController.text.trim();
              final qty = qtyController.text.trim();
              if (item.isEmpty || qty.isEmpty) {
                return;
              }
              Navigator.pop(context, {
                'item': item,
                'quantity': qty,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() {
      _picklistItems.add(result);
    });
    await _persistPicklistItems();
  }

  Future<void> _takeServiceInvoicePhoto() async {
    _logActivity('service_invoice:take_photo');
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final file = File(image.path);
    setState(() {
      _serviceInvoicePhotos.add(file);
    });

    final index = _serviceInvoicePhotos.length;
    final stage = 'service_invoice_$index';

    // ── Queue upload; retried every 10 min until success ──
    await _deliveryQueue.enqueuePhotoUpload(
      bookingId: widget.request.id,
      storageStage: stage,
      firestoreStage: stage,
      localFilePath: file.path,
    );

    // When the upload completes, append the URL to the in-memory list
    _deliveryQueue.onUrlResolved(widget.request.id, stage, (url) {
      if (mounted) setState(() => _serviceInvoicePhotoUrls.add(url));
    });

    UIHelpers.showSuccessToast(
        'Service Invoice photo saved! Uploading in background.');
  }

  void _finishLoading() async {
    _logActivity('finish_loading');
    if (_startLoadingPhoto == null || _finishLoadingPhoto == null) {
      UIHelpers.showInfoToast('Please take both photos to finish loading.');
      return;
    }

    // Note: URL gate removed — photos are saved locally and queued for upload.
    // Driver can proceed as soon as both photos are taken.

    // Require Service Invoice photo after finish loading
    if (_serviceInvoicePhotos.isEmpty) {
      UIHelpers.showInfoToast(
          'Please take a photo of the Service Invoice issued by the POD department.');
      return;
    }

    _loadingTimer?.cancel();
    _loadingDemurrageFee = 0.0;

    // Update booking status in Firestore with demurrage data
    // Note: delivery photos are already saved by addDeliveryPhoto when taken
    await _bookingService.updateBookingStatusWithDetails(
      bookingId: widget.request.id,
      status: 'loading_complete',
      loadingCompletedAt: DateTime.now(),
      loadingDemurrageFee: _loadingDemurrageFee,
      loadingDemurrageSeconds: _loadingDuration.inSeconds,
      picklistItems: _picklistItems,
    );

    setState(() {
      _currentStep = DeliveryStep.delivering;
      _loadingSubStep = null;
    });

    // Save delivery state
    _saveDeliveryState();

    UIHelpers.showSuccessToast(
        'Loading completed! Service Invoice captured. Ready for delivery.');
  }

  void _arrivedAtClient() async {
    _logActivity('arrived_at_dropoff_prompt');

    // Geo-fencing check
    if (!_isWithinGeofence) {
      _showGeofenceWarning();
      return;
    }

    // Show GPS Photo Capture Dialog for destination arrival
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildDestinationArrivalDialog(),
    );

    if (result == null || result['confirmed'] != true) {
      // User cancelled
      return;
    }

    _logActivity('arrived_at_dropoff');

    setState(() {
      _currentStep = DeliveryStep.unloading;
      _unloadingSubStep = UnloadingSubStep.arrived;
      _startUnloadingTimer();
    });

    // Save delivery state
    _saveDeliveryState();

    // Update booking status in Firestore with arrival photo and remarks
    await _bookingService.updateBookingStatusWithDetails(
      bookingId: widget.request.id,
      status: 'arrived_at_dropoff',
      unloadingStartedAt: DateTime.now(),
      picklistItems: _picklistItems,
      deliveryPhotos: {
        'destination_arrival': _destinationArrivalPhotoUrl,
        'destination_arrival_remarks': result['remarks'] ?? '',
      },
    );

    UIHelpers.showSuccessToast(
        'Arrived at destination! GPS photo captured. Demurrage timer started.');
  }

  /// Build the destination arrival dialog with GPS photo capture and interactive map
  Widget _buildDestinationArrivalDialog() {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Arrival at Destination',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Bold',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // Clear map controller reference before closing dialog
                          _activeMapController = null;
                          Navigator.pop(context, {'confirmed': false});
                        },
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Instructions
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: AppColors.success),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'REMARKS: Take a photo at the destination front gate. GPS location will be embedded in the photo.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Interactive Map Section
                          const Text(
                            'Current Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Interactive Google Map
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.lightGrey),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _currentDriverLocation ??
                                      _dropoffCoordinates ??
                                      const LatLng(14.5995, 120.9842),
                                  zoom: 16,
                                ),
                                markers: _createMarkersWithDriver(
                                  _dropoffCoordinates ??
                                      const LatLng(14.5995, 120.9842),
                                  'destination',
                                  'Destination Location',
                                ),
                                gestureRecognizers: <Factory<
                                    OneSequenceGestureRecognizer>>{
                                  Factory<OneSequenceGestureRecognizer>(
                                      () => EagerGestureRecognizer()),
                                },
                                zoomControlsEnabled: true,
                                mapToolbarEnabled: true,
                                myLocationEnabled: true,
                                myLocationButtonEnabled: true,
                                zoomGesturesEnabled: true,
                                scrollGesturesEnabled: true,
                                rotateGesturesEnabled: true,
                                tiltGesturesEnabled: true,
                                onMapCreated: (controller) {
                                  _activeMapController = controller;
                                  _isMapControllerValid = true;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Pinch to zoom, drag to pan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // GPS Photo Section
                          const Text(
                            'GPS Photo at Front Gate',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Photo Preview
                          if (_isCapturingDestinationPhoto)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          if (!_isCapturingDestinationPhoto)
                            GestureDetector(
                              onTap: () async {
                                await _takeGpsDestinationPhoto(
                                  onPhotoTaken: () => setDialogState(() {}),
                                  setLoading: (v) => setDialogState(
                                      () => _isCapturingDestinationPhoto = v),
                                );
                              },
                              child: Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _destinationArrivalPhoto != null
                                        ? AppColors.success
                                        : AppColors.lightGrey,
                                    width: 2,
                                  ),
                                  image: _destinationArrivalPhoto != null
                                      ? DecorationImage(
                                          image: FileImage(
                                              _destinationArrivalPhoto!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _destinationArrivalPhoto == null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.camera_alt,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap to take GPS photo',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Location & timestamp will be embedded',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            ),

                          if (_destinationArrivalPhoto != null &&
                              !_isCapturingDestinationPhoto) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton.icon(
                                onPressed: () async {
                                  await _takeGpsDestinationPhoto(
                                    onPhotoTaken: () => setDialogState(() {}),
                                    setLoading: (v) => setDialogState(
                                        () => _isCapturingDestinationPhoto = v),
                                  );
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retake Photo'),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Remarks Field
                          const Text(
                            'Remarks (Optional)',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Bold',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _destinationArrivalRemarksController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText:
                                  'Enter any remarks about the arrival...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            // Clear map controller reference before closing dialog
                            _activeMapController = null;
                            _isMapControllerValid = false;
                            Navigator.pop(context, {'confirmed': false});
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _destinationArrivalPhoto != null
                              ? () {
                                  // Clear map controller reference before closing dialog
                                  _activeMapController = null;
                                  _isMapControllerValid = false;
                                  Navigator.pop(context, {
                                    'confirmed': true,
                                    'remarks':
                                        _destinationArrivalRemarksController
                                            .text,
                                  });
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Confirm Arrival',
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
              ],
            ),
          ),
        );
      },
    );
  }

  /// Take GPS photo at destination arrival.
  /// Uses [setLoading] to show/hide an in-dialog overlay — avoids Navigator.pop race condition.
  Future<void> _takeGpsDestinationPhoto({
    VoidCallback? onPhotoTaken,
    void Function(bool)? setLoading,
  }) async {
    try {
      _logActivity('take_gps_photo:destination_arrival');

      // Show loading while getting GPS location
      setLoading?.call(true);

      // Get current location
      final locationData = await _gpsCameraService.getCurrentLocationData();

      // Hide loading before opening camera (native activity)
      setLoading?.call(false);

      // Take photo
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) return;

      // Show processing while adding watermark + uploading
      setLoading?.call(true);

      // Add GPS watermark
      final File originalFile = File(image.path);
      final File watermarkedFile = await _gpsCameraService.addGpsWatermark(
        originalFile,
        locationData,
      );

      if (mounted) {
        setState(() {
          _destinationArrivalPhoto = watermarkedFile;
        });
      }

      // ── Upload queued in background; hide loading and let driver proceed ──
      setLoading?.call(false);

      await _deliveryQueue.enqueuePhotoUpload(
        bookingId: widget.request.id,
        storageStage: 'Destination Arrival GPS',
        firestoreStage: 'destination_arrival',
        localFilePath: watermarkedFile.path,
      );

      if (mounted) {
        UIHelpers.showSuccessToast(
            'Arrival photo saved! Uploading to cloud in background.');
      }

      // Notify dialog to refresh photo preview
      onPhotoTaken?.call();
    } catch (e) {
      setLoading?.call(false);
      debugPrint('Error taking GPS photo: $e');
      if (mounted) {
        UIHelpers.showErrorToast('Error taking GPS photo: $e');
      }
    }
  }

  void _showGeofenceWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Warning'),
        content: const Text(
          'You are not within the designated delivery area. Please proceed to the correct location to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startUnloadingTimer() {
    _unloadingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _unloadingDuration += const Duration(seconds: 1);
        _unloadingDemurrageFee = 0.0;
      });
    });
  }

  void _startUnloadingPhotoProcess() {
    setState(() {
      _unloadingSubStep = UnloadingSubStep.startUnloading;
    });
  }

  void _finishUnloadingPhotoProcess() {
    setState(() {
      _unloadingSubStep = UnloadingSubStep.finishUnloading;
    });
  }

  void _finishUnloading() async {
    _logActivity('finish_unloading');
    if (_startUnloadingPhoto == null || _finishUnloadingPhoto == null) {
      UIHelpers.showInfoToast('Please take both photos to finish unloading.');
      return;
    }

    // Note: URL gate removed — photos are saved locally and queued for upload.
    // Driver can proceed as soon as both photos are taken.

    _unloadingDemurrageFee = 0.0;

    // Update booking status in Firestore with demurrage data
    // Note: delivery photos are already saved by addDeliveryPhoto when taken
    await _bookingService.updateBookingStatusWithDetails(
      bookingId: widget.request.id,
      status: 'unloading_complete',
      unloadingCompletedAt: DateTime.now(),
      unloadingDemurrageFee: _unloadingDemurrageFee,
      picklistItems: _picklistItems,
    );

    setState(() {
      _currentStep = DeliveryStep.damageReport;
      _unloadingSubStep = null;
      _hasDamage = false;
      _damagedItems.clear();
    });

    // Save delivery state
    _saveDeliveryState();

    UIHelpers.showSuccessToast(
        'Unloading completed! Ready for receiver confirmation.');
  }

  void _completeDelivery() async {
    _logActivity('complete_delivery');
    if (_receiverNameController.text.isEmpty) {
      UIHelpers.showInfoToast('Please enter receiver name.');
      return;
    }
    if (_idPhoto == null) {
      UIHelpers.showInfoToast('Please take ID photo.');
      return;
    }
    if (_isSignatureEmpty) {
      UIHelpers.showInfoToast('Receiver signature is required.');
      return;
    }

    // Note: _idPhotoUrl gate removed — URL is queued and may arrive after completion.
    // The queue callback (_registerQueueCallbacks) will update Firestore when it resolves.

    // ── Capture + attempt immediate signature upload ──
    String? signatureUrl = await _captureAndUploadSignature();

    // Capture Philippine Time (UTC+8) timestamp for receiver signature
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final receivedAt = now;

    // Save demurrage values BEFORE they are reset (used for wallet payout below)
    final savedLoadingDemurrage = _loadingDemurrageFee;
    final savedUnloadingDemurrage = _unloadingDemurrageFee;

    _unloadingTimer?.cancel();
    _unloadingDemurrageFee = 0.0;

    final loadingSeconds = _loadingDuration.inSeconds;
    final destinationSeconds = _unloadingDuration.inSeconds;

    // Update booking status in Firestore with completion data
    await _bookingService.updateBookingStatusWithDetails(
      bookingId: widget.request.id,
      status: 'completed',
      completedAt: DateTime.now(),
      receiverName: _receiverNameController.text,
      loadingDemurrageSeconds: loadingSeconds,
      destinationDemurrageSeconds: destinationSeconds,
      totalDemurrageSeconds: loadingSeconds + destinationSeconds,
      picklistItems: _picklistItems,
      deliveryPhotos: {
        'receiver_id': _idPhotoUrl,
        // Use immediately-uploaded URL, or callback-resolved URL from queue
        'receiver_signature': signatureUrl ?? _signatureUrl,
        'receiver_signature_timestamp': receivedAt.toIso8601String(),
        'received_at_pht': receivedAt.toIso8601String(),
      },
    );

    // --- Wallet: add earnings to rider ---
    final riderId = _riderAuthService.currentRider?.riderId ?? '';
    if (riderId.isNotEmpty) {
      final baseFare = double.tryParse(
              widget.request.fare.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0.0;
      final totalEarnings =
          baseFare + savedLoadingDemurrage + savedUnloadingDemurrage;
      if (totalEarnings > 0) {
        await _walletService.addEarnings(
          riderId: riderId,
          amount: totalEarnings,
          description: 'Delivery earnings - ${widget.request.id}',
          referenceId: widget.request.id,
        );
      }
    }

    // --- Wallet: charge customer for demurrage (if any) ---
    final totalDemurrage = savedLoadingDemurrage + savedUnloadingDemurrage;
    if (totalDemurrage > 0) {
      final bookingDoc = await _getBookingDoc(widget.request.id);
      final customerId = bookingDoc?['customerId'] as String?;
      if (customerId != null && customerId.isNotEmpty) {
        await _walletService.deductFromWallet(
          userId: customerId,
          amount: totalDemurrage,
          description: 'Demurrage fee - ${widget.request.id}',
          referenceId: widget.request.id,
        );
      }
    }

    setState(() {
      _currentStep = DeliveryStep.completed;
    });

    // ── Flush pending uploads before sending the email report ──
    // This gives the queue 30 s to upload any remaining photos (GPS, loading,
    // unloading, ID, signature) so the report includes all attachments.
    UIHelpers.showInfoToast('Syncing delivery data… sending report shortly.');
    await _deliveryQueue.forceSyncForBooking(
      widget.request.id,
      timeout: const Duration(seconds: 30),
    );

    await _sendCompletionEmails();
    UIHelpers.showSuccessToast(
        'Delivery Completed! Confirmation emails sent to Customer, Admin, and Driver.');

    // Navigate back home after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  /// Format a DateTime as "M/d/yyyy HH:mm" (Philippine Time).
  String _formatMilitaryTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('M/d/yyyy HH:mm').format(dateTime);
  }

  Future<Map<String, dynamic>?> _getBookingDoc(String bookingId) async {
    final snap = await _firestore.collection('bookings').doc(bookingId).get();
    return snap.data();
  }

  Future<Map<String, dynamic>?> _getUserDoc(String userId) async {
    final snap = await _firestore.collection('users').doc(userId).get();
    return snap.data();
  }

  Future<Map<String, dynamic>?> _getRiderDoc(String riderId) async {
    final snap = await _firestore.collection('riders').doc(riderId).get();
    return snap.data();
  }

  Future<void> _sendCompletionEmails() async {
    try {
      final now = DateTime.now();

      final bookingData = await _getBookingDoc(widget.request.id);
      final customerId = (bookingData?['customerId'] as String?) ?? '';
      final riderId = (bookingData?['driverId'] as String?) ??
          (_riderAuthService.currentRider?.riderId ?? '');

      final customerData = customerId.isNotEmpty
          ? await _getUserDoc(customerId)
          : <String, dynamic>{};
      final riderData = riderId.isNotEmpty
          ? await _getRiderDoc(riderId)
          : <String, dynamic>{};

      final customerEmail = (customerData?['email'] as String?) ?? '';

      final driverName = (riderData?['name'] as String?) ??
          _riderAuthService.currentRider?.name;
      final driverPhone = (riderData?['phoneNumber'] as String?) ??
          _riderAuthService.currentRider?.phoneNumber ??
          widget.request.customerPhone;

      final driverEmail = (riderData?['email'] as String?) ?? '';

      // Helper / Crew info – stored as flat strings OR nested helper1/helper2 maps
      String helperField(String flatKey, String nestedKey, String subField) {
        final flat = riderData?[flatKey];
        if (flat is String && flat.trim().isNotEmpty) return flat.trim();
        final nested = riderData?[nestedKey];
        if (nested is Map) {
          final val = nested[subField];
          if (val is String && val.trim().isNotEmpty) return val.trim();
        }
        return '';
      }

      final helper1Name = helperField('helper1Name', 'helper1', 'name');
      final helper1Phone =
          helperField('helper1Phone', 'helper1', 'phoneNumber');
      final helper2Name = helperField('helper2Name', 'helper2', 'name');
      final helper2Phone =
          helperField('helper2Phone', 'helper2', 'phoneNumber');

      final plate = (riderData?['vehiclePlateNumber'] as String?) ?? '';

      final vehicleType = (riderData?['vehicleType'] as String?) ??
          (bookingData?['vehicle'] is Map
              ? ((bookingData?['vehicle'] as Map)['name'] as String?)
              : null) ??
          '';

      final pickupAddress = widget.request.pickupLocation;
      final destinationAddress = widget.request.deliveryLocation;

      final bookingCreatedAt = bookingData?['createdAt'];
      DateTime? createdAt;
      if (bookingCreatedAt is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(bookingCreatedAt);
      }

      final scheduledMs = bookingData?['scheduledDateTime'];
      DateTime? scheduledAt;
      if (scheduledMs is int) {
        scheduledAt = DateTime.fromMillisecondsSinceEpoch(scheduledMs);
      }

      DateTime? parseIso(dynamic value) {
        if (value == null) return null;
        if (value is Timestamp) return value.toDate();
        if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
        if (value is num) {
          return DateTime.fromMillisecondsSinceEpoch(value.toInt());
        }
        if (value is String && value.isNotEmpty) {
          return DateTime.tryParse(value);
        }
        return null;
      }

      final pickupArrival = parseIso(bookingData?['loadingStartedAt']);
      final loadingFinish = parseIso(bookingData?['loadingCompletedAt']);

      final destArrival = parseIso(bookingData?['unloadingStartedAt']);
      final unloadingFinish = parseIso(bookingData?['unloadingCompletedAt']);

      final receiverName = (bookingData?['receiverName'] as String?) ??
          _receiverNameController.text;

      final deliveryPhotosRaw = bookingData?['deliveryPhotos'];
      final deliveryPhotos = (deliveryPhotosRaw is Map)
          ? deliveryPhotosRaw.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};

      String? extractUrl(dynamic v) {
        if (v is String) return v;
        if (v is Map) {
          final url = v['url'];
          if (url is String) return url;
        }
        return null;
      }

      final invoiceUrls = <String>[];
      for (final entry in deliveryPhotos.entries) {
        if (!entry.key.startsWith('service_invoice_')) continue;
        final url = extractUrl(entry.value);
        if (url != null && url.isNotEmpty) invoiceUrls.add(url);
      }

      if (invoiceUrls.isEmpty && _serviceInvoicePhotoUrls.isNotEmpty) {
        invoiceUrls.addAll(_serviceInvoicePhotoUrls);
      }

      String formatPicklist(dynamic v) {
        if (v is! List) return '';
        final lines = <String>[];
        for (final raw in v) {
          if (raw is Map) {
            final item = (raw['item'] ?? '').toString();
            final qty = (raw['quantity'] ?? '').toString();
            if (item.isEmpty && qty.isEmpty) continue;
            lines.add('$item - $qty');
          }
        }
        return lines.join('\n');
      }

      final picklistFromBooking = bookingData?['picklistItems'];

      DateTime? extractUploadedAt(dynamic v) {
        if (v is Map) {
          return parseIso(v['uploadedAt']);
        }
        return null;
      }

      final startLoadingUrl = extractUrl(deliveryPhotos['start_loading']) ??
          extractUrl(deliveryPhotos['start_loading_photo']);
      final finishLoadingUrl = extractUrl(deliveryPhotos['finish_loading']) ??
          extractUrl(deliveryPhotos['finished_loading']);
      final startUnloadingUrl = extractUrl(deliveryPhotos['start_unloading']) ??
          extractUrl(deliveryPhotos['start_unloading_photo']);
      final finishUnloadingUrl =
          extractUrl(deliveryPhotos['finish_unloading']) ??
              extractUrl(deliveryPhotos['finished_unloading']);
      final receiverIdUrl = extractUrl(deliveryPhotos['receiver_id']) ??
          extractUrl(deliveryPhotos['receiver_id_photo']);
      final receiverSignatureUrl =
          extractUrl(deliveryPhotos['receiver_signature']) ??
              extractUrl(deliveryPhotos['signature']);

      final startLoadingAt =
          extractUploadedAt(deliveryPhotos['start_loading']) ??
              extractUploadedAt(deliveryPhotos['start_loading_photo']);
      final finishLoadingAt =
          extractUploadedAt(deliveryPhotos['finish_loading']) ??
              extractUploadedAt(deliveryPhotos['finished_loading']) ??
              extractUploadedAt(deliveryPhotos['finish_loading_photo']);
      final startUnloadingAt =
          extractUploadedAt(deliveryPhotos['start_unloading']) ??
              extractUploadedAt(deliveryPhotos['start_unloading_photo']);
      final finishUnloadingAt =
          extractUploadedAt(deliveryPhotos['finish_unloading']) ??
              extractUploadedAt(deliveryPhotos['finished_unloading']) ??
              extractUploadedAt(deliveryPhotos['finish_unloading_photo']);

      // Arrival GPS photo URLs & timestamps
      final warehouseArrivalUrl =
          extractUrl(deliveryPhotos['warehouse_arrival']);
      final warehouseArrivalAt =
          extractUploadedAt(deliveryPhotos['warehouse_arrival']);
      final destinationArrivalUrl =
          extractUrl(deliveryPhotos['destination_arrival']);
      final destinationArrivalAt =
          extractUploadedAt(deliveryPhotos['destination_arrival']);

      // Collect all damage photo URLs from Firestore + in-memory list
      final damagePhotoUrls = <String>[];
      for (final entry in deliveryPhotos.entries) {
        final key = entry.key;
        if (key.startsWith('damaged_boxes') ||
            key.startsWith('empty_truck') ||
            key.startsWith('damage')) {
          final url = extractUrl(entry.value);
          if (url != null && url.isNotEmpty) damagePhotoUrls.add(url);
        }
      }
      for (final url in _damagePhotoUrls) {
        if (!damagePhotoUrls.contains(url)) damagePhotoUrls.add(url);
      }

      final rdd = scheduledAt ?? createdAt ?? now;
      final rddStr = DateFormat('yyyyMMdd').format(rdd);
      final subject =
          '${vehicleType.isNotEmpty ? vehicleType : 'TYPE'}_${plate.isNotEmpty ? plate : 'PLATE'}_${rddStr}_Citimovers';

      final phtNow = DateTime.now().toUtc().add(const Duration(hours: 8));

      final templateParams = <String, dynamic>{
        'sender': IntegrationsConfig.reportSenderEmail,
        'receiver_name': receiverName,
        'type': vehicleType,
        // Vehicle
        'plate': plate,
        // Driver
        'driver_name': driverName ?? '',
        'driver_phone': driverPhone,
        // Helper 1
        'helper1_name': helper1Name,
        'helper1_phone': helper1Phone,
        // Helper 2
        'helper2_name': helper2Name,
        'helper2_phone': helper2Phone,
        'pickup_address': pickupAddress,
        'destination_address': destinationAddress,
        'fo_number': '',
        'trip_number': widget.request.id,
        'rdd': rddStr,
        // Pick-up stage – date + time
        'pickup_arrival_time':
            _formatMilitaryTime(warehouseArrivalAt ?? pickupArrival),
        'pickup_loading_start_time': _formatMilitaryTime(startLoadingAt),
        'pickup_loading_finish_time':
            _formatMilitaryTime(finishLoadingAt ?? loadingFinish),
        // Drop-off stage – date + time
        'dropoff_arrival_time':
            _formatMilitaryTime(destinationArrivalAt ?? destArrival),
        'dropoff_unloading_start_time': _formatMilitaryTime(startUnloadingAt),
        'dropoff_unloading_finish_time':
            _formatMilitaryTime(finishUnloadingAt ?? unloadingFinish),
        // RECEIVED – date + time
        'received_date_time': DateFormat('M/d/yyyy HH:mm').format(phtNow),
        'received_timestamp_pht':
            DateFormat('M/d/yyyy HH:mm:ss').format(phtNow),
        // Arrival GPS photos
        'warehouse_arrival_photo_url': warehouseArrivalUrl ?? '',
        'destination_arrival_photo_url': destinationArrivalUrl ?? '',
        // Loading/Unloading photos
        'loading_photo_url': startLoadingUrl ?? '',
        'unloading_photo_url': finishUnloadingUrl ?? '',
        'start_loading_photo_url': startLoadingUrl ?? '',
        'finish_loading_photo_url': finishLoadingUrl ?? '',
        'start_unloading_photo_url': startUnloadingUrl ?? '',
        'finish_unloading_photo_url': finishUnloadingUrl ?? '',
        // Receiver
        'receiver_id_photo_url': receiverIdUrl ?? '',
        'receiver_signature_url': receiverSignatureUrl ?? '',
        // Damaged items
        'damage_photo_urls': damagePhotoUrls.join('\n'),
        'damage_photo_count': '${damagePhotoUrls.length}',
        // Invoice & picklist
        'service_invoice_urls': invoiceUrls.join('\n'),
        'picklist_items': formatPicklist(
            (picklistFromBooking is List && picklistFromBooking.isNotEmpty)
                ? picklistFromBooking
                : _picklistItems),
        // Required by EmailJS template
        'bcc_emails': '',
        'cc_emails': '',
        'email': customerEmail,
        'to_email': customerEmail,
        'subject':
            '${vehicleType.isNotEmpty ? vehicleType : 'TYPE'}_${plate.isNotEmpty ? plate : 'PLATE'}_${rddStr}_Citimovers',
      };

      // Customer + internal recipients. Internal recipients are sent as individual emails.
      final allRecipients = <String>{
        ...IntegrationsConfig.internalReportRecipients,
      };

      for (final to in IntegrationsConfig.sampleClientReportRecipients) {
        final trimmed = to.trim();
        if (trimmed.isEmpty) continue;
        if (!trimmed.contains('@')) continue;
        allRecipients.add(trimmed);
      }

      final trimmedCustomerEmail = customerEmail.trim();
      if (trimmedCustomerEmail.isNotEmpty &&
          trimmedCustomerEmail.contains('@')) {
        allRecipients.add(trimmedCustomerEmail);
      }

      final trimmedDriverEmail = driverEmail.trim();
      if (trimmedDriverEmail.isNotEmpty && trimmedDriverEmail.contains('@')) {
        allRecipients.add(trimmedDriverEmail);
      }

      final extraRecipientsRaw = bookingData?['reportRecipients'];
      if (extraRecipientsRaw is List) {
        for (final v in extraRecipientsRaw) {
          final to = v.toString().trim();
          if (to.isEmpty) continue;
          if (!to.contains('@')) continue;
          allRecipients.add(to);
        }
      } else if (extraRecipientsRaw is String) {
        final parts = extraRecipientsRaw.split(',');
        for (final p in parts) {
          final to = p.trim();
          if (to.isEmpty) continue;
          if (!to.contains('@')) continue;
          allRecipients.add(to);
        }
      }

      for (final to in allRecipients) {
        // Fetch images and create attachments
        final attachments = <EmailJsAttachment>[];

        // Fetch loading photo
        if (startLoadingUrl != null && startLoadingUrl.isNotEmpty) {
          final attachment =
              await EmailJsService.instance.fetchImageAsAttachment(
            startLoadingUrl,
            'Start_Loading.jpg',
          );
          if (attachment != null) attachments.add(attachment);
        }

        // Fetch finish loading photo
        if (finishLoadingUrl != null && finishLoadingUrl.isNotEmpty) {
          final attachment =
              await EmailJsService.instance.fetchImageAsAttachment(
            finishLoadingUrl,
            'Finish_Loading.jpg',
          );
          if (attachment != null) attachments.add(attachment);
        }

        // Fetch start unloading photo
        if (startUnloadingUrl != null && startUnloadingUrl.isNotEmpty) {
          final attachment =
              await EmailJsService.instance.fetchImageAsAttachment(
            startUnloadingUrl,
            'Start_Unloading.jpg',
          );
          if (attachment != null) attachments.add(attachment);
        }

        // Fetch finish unloading photo
        if (finishUnloadingUrl != null && finishUnloadingUrl.isNotEmpty) {
          final attachment =
              await EmailJsService.instance.fetchImageAsAttachment(
            finishUnloadingUrl,
            'Finish_Unloading.jpg',
          );
          if (attachment != null) attachments.add(attachment);
        }

        // Fetch receiver ID photo
        if (receiverIdUrl != null && receiverIdUrl.isNotEmpty) {
          final attachment =
              await EmailJsService.instance.fetchImageAsAttachment(
            receiverIdUrl,
            'Receiver_ID.jpg',
          );
          if (attachment != null) attachments.add(attachment);
        }

        // Fetch receiver signature
        if (receiverSignatureUrl != null && receiverSignatureUrl.isNotEmpty) {
          final attachment =
              await EmailJsService.instance.fetchImageAsAttachment(
            receiverSignatureUrl,
            'Receiver_Signature.png',
          );
          if (attachment != null) attachments.add(attachment);
        }

        // Fetch warehouse arrival GPS photo
        if (warehouseArrivalUrl != null && warehouseArrivalUrl.isNotEmpty) {
          final attachment =
              await EmailJsService.instance.fetchImageAsAttachment(
            warehouseArrivalUrl,
            'Pickup_Arrival_GPS.jpg',
          );
          if (attachment != null) attachments.add(attachment);
        }

        // Fetch destination arrival GPS photo
        if (destinationArrivalUrl != null && destinationArrivalUrl.isNotEmpty) {
          final attachment =
              await EmailJsService.instance.fetchImageAsAttachment(
            destinationArrivalUrl,
            'Dropoff_Arrival_GPS.jpg',
          );
          if (attachment != null) attachments.add(attachment);
        }

        // Fetch service invoice photos (first 3 max to avoid email size limits)
        for (int i = 0; i < invoiceUrls.length && i < 3; i++) {
          final url = invoiceUrls[i];
          if (url.isNotEmpty) {
            final attachment =
                await EmailJsService.instance.fetchImageAsAttachment(
              url,
              'Service_Invoice_${i + 1}.jpg',
            );
            if (attachment != null) attachments.add(attachment);
          }
        }

        // Fetch damaged item photos (max 5 to stay within email size limits)
        for (int i = 0; i < damagePhotoUrls.length && i < 5; i++) {
          final attachment =
              await EmailJsService.instance.fetchImageAsAttachment(
            damagePhotoUrls[i],
            'Damaged_Item_${i + 1}.jpg',
          );
          if (attachment != null) attachments.add(attachment);
        }

        final success = await EmailJsService.instance.sendTemplateEmail(
          toEmail: to,
          subject: subject,
          templateParams: templateParams,
          attachments: attachments,
        );
        debugPrint('Email sent to $to: ${success ? "SUCCESS" : "FAILED"}');
        debugPrint('Attachments included: ${attachments.length}');

        await Future.delayed(const Duration(milliseconds: 1100));
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending completion emails: $e');
      debugPrint('Stack trace: $stackTrace');
      UIHelpers.showErrorToast(
          'Failed to send report emails. Please check logs.');
    }
  }

  Future<String?> _captureAndUploadSignature() async {
    try {
      final boundary = _signatureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return null;
      }

      final bytes = byteData.buffer.asUint8List();

      // Save to PERSISTENT directory so the queue can retry after app-restart.
      final deliveryDir = await DeliveryQueueService.getLocalDeliveryDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath =
          '${deliveryDir.path}/signature_${widget.request.id}_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // ── Try immediate upload ──
      final url = await _storageService.uploadDeliveryPhoto(
        file,
        widget.request.id,
        'Receiver Signature',
      );

      if (url != null) {
        // Immediate success — record in Firestore and return the URL
        await _bookingService.addDeliveryPhoto(
          bookingId: widget.request.id,
          stage: 'receiver_signature',
          photoUrl: url,
        );
        return url;
      }

      // ── Upload failed (poor signal) — queue for automatic retry ──
      await _deliveryQueue.enqueuePhotoUpload(
        bookingId: widget.request.id,
        storageStage: 'Receiver Signature',
        firestoreStage: 'receiver_signature',
        localFilePath: filePath,
      );

      // Ensure the callback is registered so _signatureUrl is set on success
      _deliveryQueue.onUrlResolved(
        widget.request.id,
        'receiver_signature',
        (resolvedUrl) {
          if (mounted) setState(() => _signatureUrl = resolvedUrl);
        },
      );

      return null; // caller will use forceSyncForBooking if needed
    } catch (e) {
      debugPrint('Error uploading signature: $e');
      return null;
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Delivery Progress'),
        backgroundColor: AppColors.blueAccent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          // Chat button - only show during active delivery
          if (_currentStep != DeliveryStep.completed)
            IconButton(
              icon: const Icon(Icons.chat, color: AppColors.white),
              onPressed: () => _openChatWithCustomer(),
              tooltip: 'Chat with Customer',
            ),
          // Call button - only show during active delivery
          if (_currentStep != DeliveryStep.completed)
            IconButton(
              icon: const Icon(Icons.phone, color: AppColors.white),
              onPressed: () => _callCustomer(),
              tooltip: 'Call Customer',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressHeader(),
            _buildSyncBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepContent(),
              ),
            ),
            if (_currentStep != DeliveryStep.completed) _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBanner() {
    return ValueListenableBuilder<int>(
      valueListenable: _deliveryQueue.pendingCountNotifier,
      builder: (context, pending, _) {
        return ValueListenableBuilder<DeliverySyncStatus>(
          valueListenable: _deliveryQueue.statusNotifier,
          builder: (context, status, _) {
            // Hide when everything is synced
            if (status == DeliverySyncStatus.idle && pending == 0) {
              return const SizedBox.shrink();
            }
            final isSyncing = status == DeliverySyncStatus.syncing;
            const bannerColor = Color(0xFFFFF3CD);
            const textColor = Color(0xFF856404);
            final text = isSyncing
                ? 'Uploading $pending photo${pending == 1 ? '' : 's'} to cloud…'
                : '$pending photo${pending == 1 ? '' : 's'} queued · auto-retry every ${DeliveryQueueService.syncIntervalMinutes} min';

            return Container(
              width: double.infinity,
              color: bannerColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(textColor),
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined,
                          size: 16, color: textColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 12,
                        color: textColor,
                        fontFamily: 'Medium',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStepIcon(
              DeliveryStep.headingToWarehouse, Icons.warehouse, 'Pickup'),
          _buildStepLine(DeliveryStep.loading),
          _buildStepIcon(
              DeliveryStep.delivering, Icons.local_shipping, 'Transit'),
          _buildStepLine(DeliveryStep.unloading),
          _buildStepIcon(DeliveryStep.receiving, Icons.person_pin, 'Dropoff'),
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
          backgroundColor: color.withValues(alpha: 0.1),
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

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case DeliveryStep.headingToWarehouse:
        return _buildHeadingToWarehouseView();
      case DeliveryStep.loading:
        return _buildLoadingView();
      case DeliveryStep.delivering:
        return _buildDeliveringView();
      case DeliveryStep.unloading:
        return _buildUnloadingView();
      case DeliveryStep.damageReport:
        return _buildDamageReportView();
      case DeliveryStep.receiving:
        return _buildReceivingView();
      case DeliveryStep.completed:
        return _buildCompletedView();
    }
  }

  Widget _buildBottomAction() {
    String label = '';
    VoidCallback? onTap;
    Color color = AppColors.primaryRed;

    switch (_currentStep) {
      case DeliveryStep.headingToWarehouse:
        label = 'Arrived at Warehouse';
        onTap = _arrivedAtWarehouse;
        break;
      case DeliveryStep.loading:
        // Managed inside view
        return const SizedBox.shrink();
      case DeliveryStep.delivering:
        label = 'Arrived at Destination';
        onTap = _arrivedAtClient;
        break;
      case DeliveryStep.unloading:
        return const SizedBox.shrink();
      case DeliveryStep.damageReport:
        return const SizedBox.shrink();
      case DeliveryStep.receiving:
        return const SizedBox.shrink();
      case DeliveryStep.completed:
        label = 'Back to Home';
        onTap = () => Navigator.pop(context);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // --- Individual State Views ---

  Widget _buildHeadingToWarehouseView() {
    return Column(
      children: [
        // Map View
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentDriverLocation ??
                    _pickupCoordinates ??
                    const LatLng(14.5995, 120.9842),
                zoom: 14,
              ),
              markers: _createMarkersWithDriver(
                _pickupCoordinates ?? const LatLng(14.5995, 120.9842),
                'warehouse',
                'Pickup Location',
              ),
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer()),
              },
              onMapCreated: (controller) {
                _activeMapController = controller;
                _isMapControllerValid = true;
              },
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.warehouse,
                        color: AppColors.primaryRed),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Heading to Pickup',
                          style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Bold',
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Distance: ${widget.request.distance}',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Pickup Location',
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Bold',
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                widget.request.pickupLocation,
                style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              _buildInfoCard('Navigate to the warehouse to start loading.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDemurrageTimerCard(
            'Loading Demurrage', _loadingDuration, _loadingDemurrageFee),
        const SizedBox(height: 12),
        _buildTotalDemurrageHoursCard(),
        const SizedBox(height: 16),
        _buildPicklistSection(),
        const SizedBox(height: 24),
        const Text('Loading Process',
            style: TextStyle(fontSize: 18, fontFamily: 'Bold')),
        const SizedBox(height: 16),
        _buildPhotoStep(
          'Start Loading',
          _startLoadingPhoto,
          (file) => _startLoadingPhoto = file,
          photoType: 'Start Loading',
        ),
        const SizedBox(height: 16),
        _buildPhotoStep(
          'Finished Loading',
          _finishLoadingPhoto,
          (file) => _finishLoadingPhoto = file,
          photoType: 'Finished Loading',
        ),
        const SizedBox(height: 24),
        _buildServiceInvoiceSection(),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _finishLoading,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Finish Loading',
                style: TextStyle(
                    fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveringView() {
    return Column(
      children: [
        // Map View with Route
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentDriverLocation ?? _getCenterPosition(),
                zoom: 12,
              ),
              markers: _createRouteMarkers(),
              polylines: {
                if (_routePoints.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: _routePoints,
                    color: AppColors.primaryBlue,
                    width: 5,
                  ),
              },
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer()),
              },
              onMapCreated: (controller) {
                _activeMapController = controller;
                _isMapControllerValid = true;
              },
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping,
                        color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'On the Way',
                          style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Bold',
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Est. Time: ${widget.request.estimatedTime}',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Drop-off Location',
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Bold',
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                widget.request.deliveryLocation,
                style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              _buildInfoCard('Deliver the package to the client location.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnloadingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDemurrageTimerCard('Destination Demurrage', _unloadingDuration,
            _unloadingDemurrageFee),
        const SizedBox(height: 12),
        _buildTotalDemurrageHoursCard(),
        const SizedBox(height: 24),
        const Text('Unloading Process',
            style: TextStyle(fontSize: 18, fontFamily: 'Bold')),
        const SizedBox(height: 16),
        _buildPhotoStep(
          'Start Unloading',
          _startUnloadingPhoto,
          (file) => _startUnloadingPhoto = file,
          photoType: 'Start Unloading',
        ),
        const SizedBox(height: 16),
        _buildPhotoStep(
          'Finished Unloading',
          _finishUnloadingPhoto,
          (file) => _finishUnloadingPhoto = file,
          photoType: 'Finished Unloading',
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _finishUnloading,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Finish Unloading',
                style: TextStyle(
                    fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildDamageReportView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTotalDemurrageHoursCard(),
        const SizedBox(height: 24),
        const Text('Damaged While Unloading',
            style: TextStyle(fontSize: 18, fontFamily: 'Bold')),
        const SizedBox(height: 8),
        const Text(
          'Report any damaged items from the delivery. Items must match the picklist.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Picklist Reference
        if (_picklistItems.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PICKLIST REFERENCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Bold',
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(_picklistItems.length, (i) {
                  final item = (_picklistItems[i]['item'] ?? '').toString();
                  final qty = (_picklistItems[i]['quantity'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item, style: const TextStyle(fontSize: 13)),
                        Text(qty,
                            style: const TextStyle(
                                fontSize: 13, fontFamily: 'Medium')),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Damage Check
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _hasDamage = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: !_hasDamage
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          !_hasDamage ? AppColors.success : AppColors.lightGrey,
                      width: !_hasDamage ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: !_hasDamage
                            ? AppColors.success
                            : AppColors.textSecondary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No Damage',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Medium',
                          color: !_hasDamage
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Take photo of empty truck',
                        style: TextStyle(
                          fontSize: 11,
                          color: !_hasDamage
                              ? AppColors.success
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _hasDamage = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hasDamage
                        ? AppColors.primaryRed.withValues(alpha: 0.1)
                        : AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasDamage
                          ? AppColors.primaryRed
                          : AppColors.lightGrey,
                      width: _hasDamage ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: _hasDamage
                            ? AppColors.primaryRed
                            : AppColors.textSecondary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Has Damage',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Medium',
                          color: _hasDamage
                              ? AppColors.primaryRed
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Report damaged items',
                        style: TextStyle(
                          fontSize: 11,
                          color: _hasDamage
                              ? AppColors.primaryRed
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

        const SizedBox(height: 16),

        // Damaged Items Entry (if has damage)
        if (_hasDamage) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryRed.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAMAGED ITEMS',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Bold',
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                // Entry Form
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _picklistItems
                              .map((e) => (e['item'] ?? '').toString())
                              .where((item) => item.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (String selection) {
                          _damageItemController.text = selection;
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          // Sync the autocomplete controller with our controller
                          controller.addListener(() {
                            _damageItemController.text = controller.text;
                          });
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Item Name',
                              hintText: 'Enter item from picklist',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _damageQtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Qty/Cases',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final item = _damageItemController.text.trim();
                        final qty = _damageQtyController.text.trim();
                        if (item.isEmpty || qty.isEmpty) {
                          UIHelpers.showErrorToast(
                              'Please enter item and quantity');
                          return;
                        }
                        // Validate item exists in picklist
                        final exists = _picklistItems.any((e) =>
                            (e['item'] ?? '').toString().toLowerCase() ==
                            item.toLowerCase());
                        if (!exists) {
                          UIHelpers.showErrorToast('Item must match picklist');
                          return;
                        }
                        setState(() {
                          _damagedItems.add({'item': item, 'quantity': qty});
                          _damageItemController.clear();
                          _damageQtyController.clear();
                        });
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Damaged Items List
                if (_damagedItems.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  ...List.generate(_damagedItems.length, (i) {
                    final item = _damagedItems[i]['item'] ?? '';
                    final qty = _damagedItems[i]['quantity'] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Text(qty,
                              style: const TextStyle(
                                  fontSize: 13, fontFamily: 'Medium')),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _damagedItems.removeAt(i);
                              });
                            },
                            icon: const Icon(Icons.close,
                                size: 18, color: AppColors.textHint),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  }),
                  // Total
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(fontSize: 13, fontFamily: 'Bold')),
                        Text(
                          '${_damagedItems.fold(0, (sum, e) => sum + (int.tryParse(e['quantity'] ?? '0') ?? 0))}',
                          style:
                              const TextStyle(fontSize: 13, fontFamily: 'Bold'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Multiple Photos Capture
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _hasDamage ? 'Photos of Damaged Boxes' : 'Photo of Empty Truck',
              style: const TextStyle(fontSize: 14, fontFamily: 'Medium'),
            ),
            const SizedBox(height: 8),
            // Photo Grid
            if (_damagePhotos.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_damagePhotos.length, (index) {
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.lightGrey),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _damagePhotos[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _damagePhotos.removeAt(index);
                              if (index < _damagePhotoUrls.length) {
                                _damagePhotoUrls.removeAt(index);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      // Upload indicator
                      if (index >= _damagePhotoUrls.length)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            const SizedBox(height: 12),
            // Add Photo Button
            OutlinedButton.icon(
              onPressed: () {
                _takePhoto(
                  (file) {
                    _damagePhotos.add(file);
                  },
                  _hasDamage ? 'Damaged Boxes' : 'Empty Truck',
                  onRemove: (file) {
                    _damagePhotos.remove(file);
                  },
                );
              },
              icon: const Icon(Icons.add_a_photo),
              label: Text(
                  _damagePhotos.isEmpty ? 'Take Photo' : 'Add More Photos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                side: const BorderSide(color: AppColors.primaryRed),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Continue Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () async {
              if (_damagePhotos.isEmpty) {
                UIHelpers.showInfoToast('Please take at least one photo.');
                return;
              }
              if (_hasDamage && _damagedItems.isEmpty) {
                UIHelpers.showInfoToast(
                    'Please add at least one damaged item.');
                return;
              }

              // Ensure all damage photos are uploaded
              if (_damagePhotoUrls.length < _damagePhotos.length) {
                UIHelpers.showInfoToast('Please wait for photos to upload.');
                return;
              }

              // Save damaged items to Firestore
              await _bookingService.updateBookingStatusWithDetails(
                bookingId: widget.request.id,
                status: 'damage_reported',
                picklistItems: _picklistItems,
                deliveryPhotos: {
                  if (_hasDamage) 'damaged_items': _damagedItems,
                  'damage_photos': _damagePhotoUrls,
                  'has_damage': _hasDamage,
                },
              );

              setState(() {
                _currentStep = DeliveryStep.receiving;
                _receivingSubStep = ReceivingSubStep.receiverName;
                _receiverIdPhotoConfirmed = false;
              });

              _saveDeliveryState();
              UIHelpers.showSuccessToast(
                  'Damage report saved. Proceed to receiver confirmation.');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Continue to Receiving',
                style: TextStyle(
                    fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildReceivingView() {
    final totalDemurrageCard = Column(
      children: [
        _buildTotalDemurrageHoursCard(),
        const SizedBox(height: 16),
      ],
    );

    switch (_receivingSubStep) {
      case ReceivingSubStep.receiverName:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            totalDemurrageCard,
            const Text('Receiver Name',
                style: TextStyle(fontSize: 18, fontFamily: 'Bold')),
            const SizedBox(height: 8),
            const Text(
              'Type the name exactly as it appears on the ID presented',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _receiverNameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Receiver name (as on ID)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _receiverNameController.text.trim().isEmpty
                    ? null
                    : () {
                        _logActivity('receiving_next:receiver_name');
                        setState(() {
                          _receivingSubStep = ReceivingSubStep.receiverIdPhoto;
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Next',
                    style: TextStyle(
                        fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
              ),
            ),
          ],
        );

      case ReceivingSubStep.receiverIdPhoto:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            totalDemurrageCard,
            const Text('Receiver Valid ID',
                style: TextStyle(fontSize: 18, fontFamily: 'Bold')),
            const SizedBox(height: 16),
            _buildPhotoStep(
              'Take a picture of receiver ID',
              _idPhoto,
              (file) => _idPhoto = file,
              photoType: 'Receiver ID',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _receiverIdPhotoConfirmed,
                  onChanged: (v) {
                    setState(() {
                      _receiverIdPhotoConfirmed = v ?? false;
                    });
                  },
                  activeColor: AppColors.success,
                ),
                const Expanded(
                  child: Text(
                    'Photo is clear and readable',
                    style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_idPhotoUrl == null || !_receiverIdPhotoConfirmed)
                    ? null
                    : () {
                        _logActivity('receiving_next:receiver_id_photo');
                        setState(() {
                          _receivingSubStep = ReceivingSubStep.received;
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Next',
                    style: TextStyle(
                        fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
              ),
            ),
          ],
        );

      case ReceivingSubStep.received:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            totalDemurrageCard,
            const Text('Confirm Receipt',
                style: TextStyle(fontSize: 18, fontFamily: 'Bold')),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Receiver has confirmed receipt of all goods. Tap RECEIVED to proceed to signature capture.',
                      style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Medium',
                          color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  _logActivity('receiving:received');
                  // Unfocus any text fields before moving to signature
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _receivingSubStep = ReceivingSubStep.signature;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('RECEIVED',
                    style: TextStyle(
                        fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
              ),
            ),
          ],
        );

      case ReceivingSubStep.signature:
        // Get current Philippine Time (UTC+8)
        final nowPHT = DateTime.now().toUtc().add(const Duration(hours: 8));
        final formattedDateTime =
            '${nowPHT.month.toString().padLeft(2, '0')}/${nowPHT.day.toString().padLeft(2, '0')}/${nowPHT.year} ${nowPHT.hour.toString().padLeft(2, '0')}:${nowPHT.minute.toString().padLeft(2, '0')}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and Time Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      color: AppColors.primaryBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date & Time (PHT)',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Medium',
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          formattedDateTime,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Receiver Name Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: AppColors.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Receiver Name (as on ID)',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Medium',
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _receiverNameController.text,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text('Digital Signature',
                style: TextStyle(fontSize: 16, fontFamily: 'Bold')),
            const SizedBox(height: 4),
            const Text(
              'Ask receiver to sign below',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),

            // Smaller Signature Box (fixed height, not expanded)
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.lightGrey),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RepaintBoundary(
                  key: _signatureKey,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        _signaturePoints.add(details.localPosition);
                        _isSignatureEmpty = false;
                      });
                    },
                    onPanEnd: (details) => _signaturePoints.add(null),
                    child: CustomPaint(
                      painter: SignaturePainter(points: _signaturePoints),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _signaturePoints.clear();
                      _isSignatureEmpty = true;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
                if (_isSignatureEmpty)
                  const Text(
                    'Signature required',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          color: AppColors.success, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Signed',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontFamily: 'Medium',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSignatureEmpty ? null : _completeDelivery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Delivery Complete',
                    style: TextStyle(
                        fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildCompletedView() {
    String formatHours(Duration d) {
      final hours = d.inSeconds / 3600.0;
      return '${hours.toStringAsFixed(2)} hrs';
    }

    final totalDemurrage = _loadingDuration + _unloadingDuration;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.success),
          const SizedBox(height: 24),
          const Text(
            'Delivery Completed!',
            style: TextStyle(
                fontSize: 24, fontFamily: 'Bold', color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          const Text('All details have been submitted.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 40),
          _buildSummaryRow('Base Fare', 'Hidden'),
          _buildSummaryRow(
              'Loading Demurrage Hours', formatHours(_loadingDuration)),
          _buildSummaryRow(
              'Destination Demurrage Hours', formatHours(_unloadingDuration)),
          const Divider(height: 32),
          _buildSummaryRow(
              'Total Demurrage Hours', formatHours(totalDemurrage)),
          _buildSummaryRow('Total Earnings', 'Hidden', isTotal: true),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context), // Go back to Home
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Back to Home',
                  style: TextStyle(
                      fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Components ---

  Widget _buildDemurrageTimerCard(String title, Duration duration, double fee) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String timerText =
        '${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Bold', color: AppColors.warning)),
              const Icon(Icons.timer, color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 12),
          Text(timerText,
              style: const TextStyle(
                  fontSize: 32,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          // Text('Current Fee: P${fee.toStringAsFixed(2)}',
          //     style: const TextStyle(
          //         fontSize: 14, color: AppColors.textSecondary)),
          // const SizedBox(height: 4),
          // const Text('Fees apply every 4 hours (25% of fare)',
          //     style: TextStyle(fontSize: 10, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildPhotoStep(String label, File? image, Function(File) onPicked,
      {bool isId = false, required String photoType}) {
    return GestureDetector(
      onTap: () => _takePhoto(onPicked, photoType),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lightGrey),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                image: image != null
                    ? DecorationImage(
                        image: FileImage(image), fit: BoxFit.cover)
                    : null,
              ),
              child: image == null
                  ? const Icon(Icons.camera_alt, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontFamily: 'Bold', fontSize: 14)),
                  Text(image != null ? 'Photo taken' : 'Tap to take photo',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (image != null)
              const Icon(Icons.check_circle, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: AppColors.primaryBlue))),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isTotal ? 18 : 14,
                  fontFamily: isTotal ? 'Bold' : 'Regular',
                  color: isTotal
                      ? AppColors.textPrimary
                      : AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: isTotal ? 20 : 14,
                  fontFamily: 'Bold',
                  color: isTotal ? AppColors.success : AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPicklistSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Picklist',
                  style: TextStyle(fontSize: 16, fontFamily: 'Bold')),
              const Spacer(),
              IconButton(
                onPressed: _addPicklistItem,
                icon: const Icon(Icons.add_circle, color: AppColors.primaryRed),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_picklistItems.isEmpty)
            const Text(
              'No items added yet.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else
            Column(
              children: List.generate(_picklistItems.length, (i) {
                final item = (_picklistItems[i]['item'] ?? '').toString();
                final qty = (_picklistItems[i]['quantity'] ?? '').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                              fontSize: 13, fontFamily: 'Medium'),
                        ),
                      ),
                      Text(
                        qty,
                        style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          _logActivity('picklist:remove');
                          setState(() {
                            _picklistItems.removeAt(i);
                          });
                          await _persistPicklistItems();
                        },
                        icon:
                            const Icon(Icons.close, color: AppColors.textHint),
                      ),
                    ],
                  ),
                );
              }),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _addPicklistItem,
              icon: const Icon(Icons.add),
              label: const Text('Add More Items'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceInvoiceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  color: AppColors.primaryRed, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Service Invoice (POD)',
                    style: TextStyle(fontSize: 16, fontFamily: 'Bold')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workflow:',
                  style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Bold',
                      color: AppColors.primaryBlue),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Go to Documentation Dept / POD Counter\n'
                  '2. Report loading is complete\n'
                  '3. Submit the picklist\n'
                  '4. POD will issue printed Service Invoice\n'
                  '5. Take photo of the Service Invoice',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_serviceInvoicePhotos.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _serviceInvoicePhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _serviceInvoicePhotos[i],
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            )
          else
            const Text(
              'Take a photo of the Service Invoice issued by POD department.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _takeServiceInvoicePhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_a_photo, size: 18),
              label: Text(
                _serviceInvoicePhotos.isEmpty
                    ? 'Take Service Invoice Photo'
                    : 'Take More Photos',
                style: const TextStyle(fontSize: 14, fontFamily: 'Medium'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Open chat screen with customer
  Future<void> _openChatWithCustomer() async {
    final riderId = _riderAuthService.currentRider?.riderId ?? '';
    final riderName = _riderAuthService.currentRider?.name ?? 'Driver';

    if (riderId.isEmpty) {
      UIHelpers.showErrorToast('Driver information not available');
      return;
    }

    // Get booking data to fetch customerId
    final bookingData = await _getBookingDoc(widget.request.id);
    final customerId = (bookingData?['customerId'] as String?) ?? '';

    if (customerId.isEmpty) {
      UIHelpers.showErrorToast('Customer information not available');
      return;
    }

    // Get or create chat room
    final chatRoom = await _chatService.getOrCreateChatRoom(
      bookingId: widget.request.id,
      customerId: customerId,
      customerName: widget.request.customerName,
      driverId: riderId,
      driverName: riderName,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatRoomId: chatRoom.chatRoomId,
            currentUserId: riderId,
            currentUserName: riderName,
            currentUserType: 'driver',
            otherUserName: widget.request.customerName,
            otherUserPhone: widget.request.customerPhone,
          ),
        ),
      );
    }
  }

  /// Call customer using url_launcher
  Future<void> _callCustomer() async {
    print(widget.request);
    final customerPhone = widget.request.customerPhone;
    if (customerPhone.isEmpty) {
      UIHelpers.showErrorToast('Customer phone number not available');
      return;
    }

    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: customerPhone);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          UIHelpers.showErrorToast('Could not launch phone call');
        }
      }
    } catch (e) {
      if (mounted) {
        UIHelpers.showErrorToast('Error making phone call: $e');
      }
    }
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
