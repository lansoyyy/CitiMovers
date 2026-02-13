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

import 'package:citimovers/config/integrations_config.dart';
import 'package:citimovers/services/emailjs_service.dart';
import 'package:citimovers/services/gps_map_camera_service.dart';

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

  @override
  void initState() {
    super.initState();
    // Geocode addresses to get coordinates
    _geocodeAddresses();

    // Start location tracking
    _startLocationTracking();
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
    super.dispose();
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

    // Animate map camera to follow driver
    _activeMapController?.animateCamera(
      CameraUpdate.newLatLng(newLatLng),
    );
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

  // Actual coordinates from geocoding
  LatLng? _pickupCoordinates;
  LatLng? _dropoffCoordinates;

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
    } catch (e) {
      debugPrint('Error geocoding addresses: $e');
      // Fallback to Manila coordinates if geocoding fails
      setState(() {
        _pickupCoordinates = const LatLng(14.5995, 120.9842);
        _dropoffCoordinates = const LatLng(14.5995, 120.9842);
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
                        onPressed: () =>
                            Navigator.pop(context, {'confirmed': false}),
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
                          GestureDetector(
                            onTap: () async {
                              await _takeGpsArrivalPhoto();
                              setDialogState(() {});
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
                                        image:
                                            FileImage(_warehouseArrivalPhoto!),
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
                                  await _takeGpsArrivalPhoto();
                                  setDialogState(() {});
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
                          onPressed: () =>
                              Navigator.pop(context, {'confirmed': false}),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _warehouseArrivalPhoto != null
                              ? () {
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

  /// Take GPS photo at warehouse arrival
  Future<void> _takeGpsArrivalPhoto() async {
    try {
      _logActivity('take_gps_photo:warehouse_arrival');

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current location
      final locationData = await _gpsCameraService.getCurrentLocationData();

      // Close loading
      Navigator.pop(context);

      // Take photo
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) return;

      // Show processing
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Add GPS watermark
      final File originalFile = File(image.path);
      final File watermarkedFile = await _gpsCameraService.addGpsWatermark(
        originalFile,
        locationData,
      );

      setState(() {
        _warehouseArrivalPhoto = watermarkedFile;
      });

      // Upload to Firebase
      final photoUrl = await _storageService.uploadDeliveryPhoto(
        watermarkedFile,
        widget.request.id,
        'Warehouse Arrival GPS',
      );

      if (photoUrl != null) {
        setState(() {
          _warehouseArrivalPhotoUrl = photoUrl;
        });

        // Add to booking document
        await _bookingService.addDeliveryPhoto(
          bookingId: widget.request.id,
          stage: 'warehouse_arrival',
          photoUrl: photoUrl,
        );

        UIHelpers.showSuccessToast('GPS photo captured and uploaded!');
      } else {
        UIHelpers.showErrorToast('Failed to upload GPS photo');
      }

      // Close processing
      Navigator.pop(context);
    } catch (e) {
      // Close any open dialogs
      Navigator.of(context).popUntil((route) => route is! DialogRoute);

      debugPrint('Error taking GPS photo: $e');
      UIHelpers.showErrorToast('Error taking GPS photo: $e');
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

  Future<void> _takePhoto(Function(File) onPicked, String photoType) async {
    _logActivity('take_photo:$photoType');
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final file = File(image.path);
      setState(() {
        onPicked(file);
      });

      // Upload photo to Firebase Storage
      final photoUrl = await _storageService.uploadDeliveryPhoto(
        file,
        widget.request.id,
        photoType,
      );

      if (photoUrl != null) {
        // Store the URL based on photo type
        if (photoType == 'Start Loading') {
          setState(() {
            _startLoadingPhotoUrl = photoUrl;
          });
          _startLoadingPhotoProcess();
        } else if (photoType == 'Finished Loading') {
          setState(() {
            _finishLoadingPhotoUrl = photoUrl;
          });
          _finishLoadingPhotoProcess();
        } else if (photoType == 'Start Unloading') {
          setState(() {
            _startUnloadingPhotoUrl = photoUrl;
          });
          _startUnloadingPhotoProcess();
        } else if (photoType == 'Finished Unloading') {
          setState(() {
            _finishUnloadingPhotoUrl = photoUrl;
          });
          _finishUnloadingPhotoProcess();
        } else if (photoType == 'Receiver ID') {
          setState(() {
            _idPhotoUrl = photoUrl;
          });
        }

        // Add photo URL to booking document
        await _bookingService.addDeliveryPhoto(
          bookingId: widget.request.id,
          stage: photoType.toLowerCase().replaceAll(' ', '_'),
          photoUrl: photoUrl,
        );

        UIHelpers.showSuccessToast('$photoType photo captured and uploaded!');
      } else {
        UIHelpers.showErrorToast('Failed to upload $photoType photo');
      }
    }
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

    final url = await _storageService.uploadDeliveryPhoto(
      file,
      widget.request.id,
      stage,
    );

    if (url == null) {
      UIHelpers.showErrorToast('Failed to upload Service Invoice photo');
      return;
    }

    setState(() {
      _serviceInvoicePhotoUrls.add(url);
    });

    await _bookingService.addDeliveryPhoto(
      bookingId: widget.request.id,
      stage: stage,
      photoUrl: url,
    );

    UIHelpers.showSuccessToast('Service Invoice photo captured and uploaded!');
  }

  void _finishLoading() async {
    _logActivity('finish_loading');
    if (_startLoadingPhoto == null || _finishLoadingPhoto == null) {
      UIHelpers.showInfoToast('Please take both photos to finish loading.');
      return;
    }

    // Ensure photos are uploaded
    if (_startLoadingPhotoUrl == null || _finishLoadingPhotoUrl == null) {
      UIHelpers.showInfoToast('Please wait for photos to upload.');
      return;
    }

    // Require Service Invoice photo after finish loading
    if (_serviceInvoicePhotos.isEmpty) {
      UIHelpers.showInfoToast(
          'Please take a photo of the Service Invoice issued by the POD department.');
      return;
    }

    _loadingTimer?.cancel();
    _loadingDemurrageFee = 0.0;

    // Update booking status in Firestore with demurrage data
    await _bookingService.updateBookingStatusWithDetails(
      bookingId: widget.request.id,
      status: 'loading_complete',
      loadingCompletedAt: DateTime.now(),
      loadingDemurrageFee: _loadingDemurrageFee,
      loadingDemurrageSeconds: _loadingDuration.inSeconds,
      picklistItems: _picklistItems,
      deliveryPhotos: {
        'start_loading': _startLoadingPhotoUrl,
        'finish_loading': _finishLoadingPhotoUrl,
      },
    );

    setState(() {
      _currentStep = DeliveryStep.delivering;
      _loadingSubStep = null;
    });
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
                        onPressed: () =>
                            Navigator.pop(context, {'confirmed': false}),
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
                          GestureDetector(
                            onTap: () async {
                              await _takeGpsDestinationPhoto();
                              setDialogState(() {});
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

                          if (_destinationArrivalPhoto != null) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton.icon(
                                onPressed: () async {
                                  await _takeGpsDestinationPhoto();
                                  setDialogState(() {});
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
                          onPressed: () =>
                              Navigator.pop(context, {'confirmed': false}),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _destinationArrivalPhoto != null
                              ? () {
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

  /// Take GPS photo at destination arrival
  Future<void> _takeGpsDestinationPhoto() async {
    try {
      _logActivity('take_gps_photo:destination_arrival');

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current location
      final locationData = await _gpsCameraService.getCurrentLocationData();

      // Close loading
      Navigator.pop(context);

      // Take photo
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) return;

      // Show processing
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Add GPS watermark
      final File originalFile = File(image.path);
      final File watermarkedFile = await _gpsCameraService.addGpsWatermark(
        originalFile,
        locationData,
      );

      setState(() {
        _destinationArrivalPhoto = watermarkedFile;
      });

      // Upload to Firebase
      final photoUrl = await _storageService.uploadDeliveryPhoto(
        watermarkedFile,
        widget.request.id,
        'Destination Arrival GPS',
      );

      if (photoUrl != null) {
        setState(() {
          _destinationArrivalPhotoUrl = photoUrl;
        });

        // Add to booking document
        await _bookingService.addDeliveryPhoto(
          bookingId: widget.request.id,
          stage: 'destination_arrival',
          photoUrl: photoUrl,
        );

        UIHelpers.showSuccessToast('GPS photo captured and uploaded!');
      } else {
        UIHelpers.showErrorToast('Failed to upload GPS photo');
      }

      // Close processing
      Navigator.pop(context);
    } catch (e) {
      // Close any open dialogs
      Navigator.of(context).popUntil((route) => route is! DialogRoute);

      debugPrint('Error taking GPS photo: $e');
      UIHelpers.showErrorToast('Error taking GPS photo: $e');
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

    // Ensure photos are uploaded
    if (_startUnloadingPhotoUrl == null || _finishUnloadingPhotoUrl == null) {
      UIHelpers.showInfoToast('Please wait for photos to upload.');
      return;
    }

    _unloadingDemurrageFee = 0.0;

    // Update booking status in Firestore with demurrage data
    await _bookingService.updateBookingStatusWithDetails(
      bookingId: widget.request.id,
      status: 'unloading_complete',
      unloadingCompletedAt: DateTime.now(),
      unloadingDemurrageFee: _unloadingDemurrageFee,
      picklistItems: _picklistItems,
      deliveryPhotos: {
        'start_unloading': _startUnloadingPhotoUrl,
        'finish_unloading': _finishUnloadingPhotoUrl,
      },
    );

    setState(() {
      _currentStep = DeliveryStep.receiving;
      _unloadingSubStep = null;
      _receivingSubStep = ReceivingSubStep.receiverName;
      _receiverIdPhotoConfirmed = false;
    });
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

    // Ensure ID photo is uploaded
    if (_idPhotoUrl == null) {
      UIHelpers.showInfoToast('Please wait for ID photo to upload.');
      return;
    }

    final signatureUrl = await _captureAndUploadSignature();
    if (signatureUrl == null) {
      UIHelpers.showInfoToast('Please wait for signature to upload.');
      return;
    }

    // Capture Philippine Time (UTC+8) timestamp for receiver signature
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final receivedAt = now;

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
        'receiver_signature': signatureUrl,
        'receiver_signature_timestamp': receivedAt.toIso8601String(),
        'received_at_pht': receivedAt.toIso8601String(),
      },
    );

    setState(() {
      _currentStep = DeliveryStep.completed;
    });

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

  String _formatMilitaryTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('HH:mm').format(dateTime);
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
      final customerName =
          (customerData?['name'] as String?) ?? widget.request.customerName;

      final driverName = (riderData?['name'] as String?) ??
          _riderAuthService.currentRider?.name;
      final driverPhone = (riderData?['phoneNumber'] as String?) ??
          _riderAuthService.currentRider?.phoneNumber ??
          widget.request.customerPhone;

      final driverEmail = (riderData?['email'] as String?) ?? '';

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

      final rdd = scheduledAt ?? createdAt ?? now;
      final rddStr = DateFormat('yyyyMMdd').format(rdd);
      final subject =
          '${vehicleType.isNotEmpty ? vehicleType : 'TYPE'}_${plate.isNotEmpty ? plate : 'PLATE'}_${rddStr}_Citimovers';

      final templateParams = <String, dynamic>{
        'sender': IntegrationsConfig.reportSenderEmail,
        'receiver_name': receiverName,
        'type': vehicleType,
        'plate': plate,
        'driver_name': driverName ?? '',
        'driver_phone': driverPhone,
        'pickup_address': pickupAddress,
        'destination_address': destinationAddress,
        'fo_number': '',
        'trip_number': widget.request.id,
        'rdd': rddStr,
        'pickup_arrival_time': _formatMilitaryTime(pickupArrival),
        'pickup_loading_start_time': _formatMilitaryTime(startLoadingAt),
        'pickup_loading_finish_time':
            _formatMilitaryTime(finishLoadingAt ?? loadingFinish),
        'dropoff_arrival_time': _formatMilitaryTime(destArrival),
        'dropoff_unloading_start_time': _formatMilitaryTime(startUnloadingAt),
        'dropoff_unloading_finish_time':
            _formatMilitaryTime(finishUnloadingAt ?? unloadingFinish),
        'received_date_time': DateFormat('MMM dd, yyyy HH:mm')
            .format(DateTime.now().toUtc().add(const Duration(hours: 8))),
        'received_timestamp_pht': DateFormat('yyyy-MM-dd HH:mm:ss')
            .format(DateTime.now().toUtc().add(const Duration(hours: 8))),
        'loading_photo_url': startLoadingUrl ?? '',
        'unloading_photo_url': finishUnloadingUrl ?? '',
        'receiver_id_photo_url': receiverIdUrl ?? '',
        'receiver_signature_url': receiverSignatureUrl ?? '',
        'service_invoice_urls': invoiceUrls.join('\n'),
        'picklist_items': formatPicklist(
            (picklistFromBooking is List && picklistFromBooking.isNotEmpty)
                ? picklistFromBooking
                : _picklistItems),
        // Additional photos
        'start_loading_photo_url': startLoadingUrl ?? '',
        'finish_loading_photo_url': finishLoadingUrl ?? '',
        'start_unloading_photo_url': startUnloadingUrl ?? '',
        'finish_unloading_photo_url': finishUnloadingUrl ?? '',
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
        await EmailJsService.instance.sendTemplateEmail(
          toEmail: to,
          subject: subject,
          templateParams: templateParams,
        );

        await Future.delayed(const Duration(milliseconds: 1100));
      }
    } catch (e) {
      debugPrint('Error sending completion emails: $e');
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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath =
          '${Directory.systemTemp.path}/receiver_signature_${widget.request.id}_$timestamp.png';
      final file = File(tempPath);
      await file.writeAsBytes(bytes);

      final url = await _storageService.uploadDeliveryPhoto(
        file,
        widget.request.id,
        'Receiver Signature',
      );

      if (url == null) {
        return null;
      }

      await _bookingService.addDeliveryPhoto(
        bookingId: widget.request.id,
        stage: 'receiver_signature',
        photoUrl: url,
      );

      return url;
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
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressHeader(),
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
                if (_pickupCoordinates != null && _dropoffCoordinates != null)
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: [
                      _pickupCoordinates!,
                      if (_currentDriverLocation != null)
                        _currentDriverLocation!,
                      _dropoffCoordinates!,
                    ],
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
