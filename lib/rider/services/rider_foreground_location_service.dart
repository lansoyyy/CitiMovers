import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:citimovers/rider/services/rider_location_service.dart';
import 'package:citimovers/services/location_service.dart';
import 'package:citimovers/services/maps_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RiderForegroundLocationStatus {
  idle,
  locating,
  active,
  paused,
  permissionDenied,
  serviceDisabled,
  error,
}

class RiderForegroundLocationState {
  final RiderForegroundLocationStatus status;
  final String? riderId;
  final LatLng? position;
  final String? address;
  final DateTime? updatedAt;
  final String? message;
  final bool isTracking;

  const RiderForegroundLocationState({
    required this.status,
    this.riderId,
    this.position,
    this.address,
    this.updatedAt,
    this.message,
    required this.isTracking,
  });

  static const RiderForegroundLocationState initial =
      RiderForegroundLocationState(
    status: RiderForegroundLocationStatus.idle,
    isTracking: false,
  );

  RiderForegroundLocationState copyWith({
    RiderForegroundLocationStatus? status,
    String? riderId,
    bool clearRiderId = false,
    LatLng? position,
    bool clearPosition = false,
    String? address,
    bool clearAddress = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    String? message,
    bool clearMessage = false,
    bool? isTracking,
  }) {
    return RiderForegroundLocationState(
      status: status ?? this.status,
      riderId: clearRiderId ? null : (riderId ?? this.riderId),
      position: clearPosition ? null : (position ?? this.position),
      address: clearAddress ? null : (address ?? this.address),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      message: clearMessage ? null : (message ?? this.message),
      isTracking: isTracking ?? this.isTracking,
    );
  }
}

class RiderForegroundLocationService {
  RiderForegroundLocationService._();

  static final RiderForegroundLocationService instance =
      RiderForegroundLocationService._();

  static const Duration _defaultInterval = Duration(seconds: 12);
  static const Duration _addressRefreshInterval = Duration(seconds: 15);
  static const double _addressRefreshDistanceMeters = 100;

  final ValueNotifier<RiderForegroundLocationState> stateNotifier =
      ValueNotifier<RiderForegroundLocationState>(
    RiderForegroundLocationState.initial,
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final MapsService _mapsService = MapsService();
  final RiderLocationService _riderLocationService = RiderLocationService();

  Timer? _trackingTimer;
  String? _activeRiderId;
  Duration _trackingInterval = _defaultInterval;
  DateTime? _lastAddressUpdate;
  LatLng? _lastTrackedPosition;
  bool _isPaused = false;
  bool _isUpdating = false;

  RiderForegroundLocationState get currentState => stateNotifier.value;

  Future<void> startTracking({
    required String riderId,
    Duration interval = _defaultInterval,
  }) async {
    final switchedRider = _activeRiderId != riderId;
    _activeRiderId = riderId;
    _trackingInterval = interval;
    _isPaused = false;

    if (switchedRider) {
      _lastAddressUpdate = null;
      _lastTrackedPosition = null;
    }

    _trackingTimer?.cancel();
    stateNotifier.value = currentState.copyWith(
      status: currentState.position == null
          ? RiderForegroundLocationStatus.locating
          : RiderForegroundLocationStatus.active,
      riderId: riderId,
      isTracking: true,
      clearMessage: true,
    );

    await refreshNow();

    if (_activeRiderId != riderId || _isPaused) {
      return;
    }

    _trackingTimer = Timer.periodic(_trackingInterval, (_) {
      refreshNow();
    });
  }

  Future<void> refreshNow() async {
    final riderId = _activeRiderId;
    if (riderId == null || _isPaused || _isUpdating) {
      return;
    }

    _isUpdating = true;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        stateNotifier.value = currentState.copyWith(
          status: RiderForegroundLocationStatus.serviceDisabled,
          message: 'Location services are turned off.',
          isTracking: false,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        stateNotifier.value = currentState.copyWith(
          status: RiderForegroundLocationStatus.permissionDenied,
          message: permission == LocationPermission.deniedForever
              ? 'Location permission is permanently denied.'
              : 'Location permission is required to update your unit position.',
          isTracking: false,
        );
        return;
      }

      stateNotifier.value = currentState.copyWith(
        status: currentState.position == null
            ? RiderForegroundLocationStatus.locating
            : currentState.status,
        riderId: riderId,
        isTracking: true,
        clearMessage: true,
      );

      final location =
          await _locationService.getCurrentLocation(requestPermission: false);
      if (location == null) {
        stateNotifier.value = currentState.copyWith(
          status: RiderForegroundLocationStatus.error,
          message: 'Unable to get the current GPS location.',
          isTracking: false,
        );
        return;
      }

      final nextPosition = LatLng(location.latitude, location.longitude);
      final now = DateTime.now();
      final shouldRefreshAddress = _lastAddressUpdate == null ||
          now.difference(_lastAddressUpdate!) >= _addressRefreshInterval ||
          (_lastTrackedPosition != null &&
              _distanceMeters(_lastTrackedPosition!, nextPosition) >=
                  _addressRefreshDistanceMeters);

      String resolvedAddress = location.address;
      if (shouldRefreshAddress) {
        final addressModel = await _mapsService.getAddressFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (addressModel?.address != null &&
            addressModel!.address.trim().isNotEmpty) {
          resolvedAddress = addressModel.address.trim();
          _lastAddressUpdate = now;
        }
      }

      await _firestore.collection('riders').doc(riderId).set(
        {
          'currentLatitude': location.latitude,
          'currentLongitude': location.longitude,
          'updatedAt': now.toIso8601String(),
          if (resolvedAddress.isNotEmpty) 'currentAddress': resolvedAddress,
        },
        SetOptions(merge: true),
      );

      await _riderLocationService.updateRiderLocation(
        riderId: riderId,
        latitude: location.latitude,
        longitude: location.longitude,
        address: resolvedAddress,
      );

      _lastTrackedPosition = nextPosition;
      stateNotifier.value = currentState.copyWith(
        status: RiderForegroundLocationStatus.active,
        riderId: riderId,
        position: nextPosition,
        address: resolvedAddress,
        updatedAt: now,
        isTracking: true,
        clearMessage: true,
      );
    } catch (e) {
      debugPrint('RiderForegroundLocationService: $e');
      stateNotifier.value = currentState.copyWith(
        status: RiderForegroundLocationStatus.error,
        message: 'Unable to refresh unit location right now.',
        isTracking: false,
      );
    } finally {
      _isUpdating = false;
    }
  }

  void pauseTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _isPaused = true;
    if (_activeRiderId == null) {
      return;
    }

    stateNotifier.value = currentState.copyWith(
      status: RiderForegroundLocationStatus.paused,
      isTracking: false,
      clearMessage: true,
    );
  }

  Future<void> resumeTracking({Duration? interval}) async {
    final riderId = _activeRiderId;
    if (riderId == null) {
      return;
    }

    await startTracking(
      riderId: riderId,
      interval: interval ?? _trackingInterval,
    );
  }

  void stopTracking({bool clearLocation = false}) {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _isPaused = false;
    _isUpdating = false;
    _activeRiderId = null;
    _lastAddressUpdate = null;
    _lastTrackedPosition = null;

    stateNotifier.value = clearLocation
        ? RiderForegroundLocationState.initial
        : currentState.copyWith(
            status: RiderForegroundLocationStatus.idle,
            isTracking: false,
            clearRiderId: true,
            clearMessage: true,
          );
  }

  double _distanceMeters(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }
}
