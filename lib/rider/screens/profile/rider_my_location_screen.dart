import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:citimovers/rider/services/rider_auth_service.dart';
import 'package:citimovers/rider/services/rider_foreground_location_service.dart';
import 'package:citimovers/utils/app_colors.dart';
import 'package:citimovers/widgets/map_marker_icon_factory.dart';
import 'package:citimovers/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class RiderMyLocationScreen extends StatefulWidget {
  const RiderMyLocationScreen({super.key});

  @override
  State<RiderMyLocationScreen> createState() => _RiderMyLocationScreenState();
}

class _RiderMyLocationScreenState extends State<RiderMyLocationScreen> {
  final RiderAuthService _authService = RiderAuthService();
  final RiderForegroundLocationService _locationService =
      RiderForegroundLocationService.instance;

  GoogleMapController? _mapController;
  String? _riderId;
  bool _isLoadingRider = true;
  BitmapDescriptor? _unitMarkerIcon;

  @override
  void initState() {
    super.initState();
    _locationService.stateNotifier.addListener(_handleLocationChanged);
    _initializeRider();
    _loadUnitMarkerIcon();
  }

  Future<void> _loadUnitMarkerIcon() async {
    final icon = await MapMarkerIconFactory.vehicleIcon(AppColors.success);
    if (!mounted) return;
    setState(() => _unitMarkerIcon = icon);
  }

  Future<void> _initializeRider() async {
    final rider =
        _authService.currentRider ?? await _authService.getCurrentRider();
    if (!mounted) return;

    setState(() {
      _riderId = rider?.riderId;
      _isLoadingRider = false;
    });

    if (rider != null) {
      await _locationService.startTracking(riderId: rider.riderId);
    }
  }

  void _handleLocationChanged() {
    final position = _locationService.currentState.position;
    if (_mapController != null && position != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 16.2),
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _locationService.stateNotifier.removeListener(_handleLocationChanged);
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _handleLocationAction(
    RiderForegroundLocationStatus status,
  ) async {
    if (status == RiderForegroundLocationStatus.permissionDenied) {
      await Geolocator.openAppSettings();
      return;
    }

    if (status == RiderForegroundLocationStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    await _locationService.refreshNow();
  }

  String _statusLabel(RiderForegroundLocationStatus status) {
    switch (status) {
      case RiderForegroundLocationStatus.active:
        return 'Live';
      case RiderForegroundLocationStatus.locating:
        return 'Locating';
      case RiderForegroundLocationStatus.paused:
        return 'Paused';
      case RiderForegroundLocationStatus.permissionDenied:
        return 'Permission Needed';
      case RiderForegroundLocationStatus.serviceDisabled:
        return 'GPS Off';
      case RiderForegroundLocationStatus.error:
        return 'Needs Refresh';
      case RiderForegroundLocationStatus.idle:
        return 'Idle';
    }
  }

  Color _statusColor(RiderForegroundLocationStatus status) {
    switch (status) {
      case RiderForegroundLocationStatus.active:
        return AppColors.success;
      case RiderForegroundLocationStatus.locating:
        return AppColors.primaryBlue;
      case RiderForegroundLocationStatus.paused:
        return AppColors.warning;
      case RiderForegroundLocationStatus.permissionDenied:
      case RiderForegroundLocationStatus.serviceDisabled:
      case RiderForegroundLocationStatus.error:
        return AppColors.error;
      case RiderForegroundLocationStatus.idle:
        return AppColors.textSecondary;
    }
  }

  String _formatLastPing(DateTime? updatedAt) {
    if (updatedAt == null) return 'Waiting for first GPS ping';
    return 'Last GPS ping ${DateFormat('MMM d, hh:mm a').format(updatedAt.toLocal())}';
  }

  LatLng? _positionFromDoc(Map<String, dynamic>? data) {
    if (data == null) return null;

    final currentLocation = _asMap(data['currentLocation']);
    final latitude = _asDouble(currentLocation['latitude']) ??
        _asDouble(data['currentLatitude']) ??
        _asDouble(data['latitude']);
    final longitude = _asDouble(currentLocation['longitude']) ??
        _asDouble(data['currentLongitude']) ??
        _asDouble(data['longitude']);

    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  String? _addressFromDoc(Map<String, dynamic>? data) {
    if (data == null) return null;

    final currentLocation = _asMap(data['currentLocation']);
    final candidates = [
      currentLocation['address'],
      currentLocation['label'],
      data['currentAddress'],
      data['address'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return null;
  }

  DateTime? _updatedAtFromDoc(Map<String, dynamic>? data) {
    if (data == null) return null;

    final currentLocation = _asMap(data['currentLocation']);
    return _parseTimestamp(currentLocation['updatedAt']) ??
        _parseTimestamp(data['lastActive']) ??
        _parseTimestamp(data['updatedAt']);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Location',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoadingRider
          ? Center(
              child: UIHelpers.loadingThreeBounce(
                color: AppColors.primaryRed,
                size: 18,
              ),
            )
          : _riderId == null
              ? const Center(
                  child: Text(
                    'Unable to load the logged-in rider.',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Medium',
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('riders')
                      .doc(_riderId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final locationState = _locationService.currentState;
                    final position =
                        locationState.position ?? _positionFromDoc(data);
                    final address =
                        (locationState.address?.trim().isNotEmpty ?? false)
                            ? locationState.address!.trim()
                            : (_addressFromDoc(data) ??
                                'Locating current address...');
                    final updatedAt =
                        locationState.updatedAt ?? _updatedAtFromDoc(data);
                    final isOnline = data?['isOnline'] == true;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontFamily: 'Bold',
                                          color: AppColors.textPrimary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _statusColor(locationState.status)
                                                .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _statusLabel(locationState.status),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Bold',
                                          color: _statusColor(
                                              locationState.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _formatLastPing(updatedAt),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Medium',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isOnline
                                      ? 'Unit status: Online and visible for dispatch.'
                                      : 'Unit status: Logged in. Turn online on the home screen when ready for dispatch.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Regular',
                                    color: isOnline
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                if ((locationState.message ?? '')
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    locationState.message!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'Medium',
                                      color: AppColors.error,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _handleLocationAction(
                                          locationState.status,
                                        ),
                                        icon: Icon(
                                          locationState.status ==
                                                      RiderForegroundLocationStatus
                                                          .permissionDenied ||
                                                  locationState.status ==
                                                      RiderForegroundLocationStatus
                                                          .serviceDisabled
                                              ? Icons.settings_outlined
                                              : Icons.refresh,
                                        ),
                                        label: Text(
                                          locationState.status ==
                                                  RiderForegroundLocationStatus
                                                      .permissionDenied
                                              ? 'App Settings'
                                              : locationState.status ==
                                                      RiderForegroundLocationStatus
                                                          .serviceDisabled
                                                  ? 'Location Settings'
                                                  : 'Refresh Location',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              AppColors.primaryBlue,
                                          side: const BorderSide(
                                            color: AppColors.primaryBlue,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: position == null
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                          'Waiting for the first GPS fix from this unit.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Medium',
                                            color: AppColors.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    )
                                  : GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: position,
                                        zoom: 16.2,
                                      ),
                                      onMapCreated: (controller) {
                                        _mapController = controller;
                                      },
                                      myLocationEnabled: true,
                                      myLocationButtonEnabled: true,
                                      compassEnabled: true,
                                      zoomControlsEnabled: false,
                                      mapToolbarEnabled: false,
                                      markers: {
                                        Marker(
                                          markerId:
                                              const MarkerId('unit-location'),
                                          position: position,
                                          infoWindow: InfoWindow(
                                            title: 'My Location',
                                            snippet: address,
                                          ),
                                          icon: _unitMarkerIcon ??
                                              BitmapDescriptor.defaultMarker,
                                        ),
                                      },
                                    ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
