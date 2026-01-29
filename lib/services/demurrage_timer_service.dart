import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Demurrage Timer Service for CitiMovers
/// Manages demurrage timer lifecycle with proper cleanup and persistence
class DemurrageTimerService {
  // Singleton pattern
  static final DemurrageTimerService _instance =
      DemurrageTimerService._internal();
  factory DemurrageTimerService() => _instance;
  DemurrageTimerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Timer instances
  Timer? _loadingTimer;
  Timer? _unloadingTimer;

  // Timer state
  Duration _loadingDuration = Duration.zero;
  Duration _unloadingDuration = Duration.zero;
  DateTime? _loadingStartTime;
  DateTime? _unloadingStartTime;
  double _baseFare = 0.0;

  // Stream controllers for real-time updates
  final StreamController<Duration> _loadingDurationController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _unloadingDurationController =
      StreamController<Duration>.broadcast();
  final StreamController<double> _loadingFeeController =
      StreamController<double>.broadcast();
  final StreamController<double> _unloadingFeeController =
      StreamController<double>.broadcast();

  // Getters for streams
  Stream<Duration> get loadingDurationStream =>
      _loadingDurationController.stream;
  Stream<Duration> get unloadingDurationStream =>
      _unloadingDurationController.stream;
  Stream<double> get loadingFeeStream => _loadingFeeController.stream;
  Stream<double> get unloadingFeeStream => _unloadingFeeController.stream;

  // Getters for current state
  Duration get loadingDuration => _loadingDuration;
  Duration get unloadingDuration => _unloadingDuration;
  double get loadingDemurrageFee =>
      _calculateDemurrageFee(_loadingDuration, _baseFare);
  double get unloadingDemurrageFee =>
      _calculateDemurrageFee(_unloadingDuration, _baseFare);

  /// Initialize demurrage timer for a booking
  Future<void> initializeTimer({
    required String bookingId,
    required double baseFare,
    required String stage, // 'loading' or 'unloading'
  }) async {
    try {
      _baseFare = baseFare;

      // Load persisted timer state from Firestore
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        debugPrint('DemurrageTimerService: Booking not found');
        return;
      }

      final data = bookingDoc.data()!;
      final loadingStartTime = data['loadingStartTime'];
      final unloadingStartTime = data['unloadingStartTime'];

      if (stage == 'loading' && loadingStartTime != null) {
        // Resume loading timer
        _loadingStartTime = (loadingStartTime as Timestamp).toDate();
        _loadingDuration = DateTime.now().difference(_loadingStartTime!);
        _startLoadingTimer();
      } else if (stage == 'unloading' && unloadingStartTime != null) {
        // Resume unloading timer
        _unloadingStartTime = (unloadingStartTime as Timestamp).toDate();
        _unloadingDuration = DateTime.now().difference(_unloadingStartTime!);
        _startUnloadingTimer();
      }
    } catch (e) {
      debugPrint('DemurrageTimerService: Error initializing timer: $e');
    }
  }

  /// Start loading demurrage timer
  void startLoadingTimer({
    required String bookingId,
    required double baseFare,
  }) {
    try {
      _baseFare = baseFare;
      _loadingStartTime = DateTime.now();
      _loadingDuration = Duration.zero;

      // Persist start time to Firestore
      _firestore.collection('bookings').doc(bookingId).update({
        'loadingStartTime': FieldValue.serverTimestamp(),
      });

      _startLoadingTimer();
      debugPrint(
          'DemurrageTimerService: Loading timer started for booking $bookingId');
    } catch (e) {
      debugPrint('DemurrageTimerService: Error starting loading timer: $e');
    }
  }

  /// Start unloading demurrage timer
  void startUnloadingTimer({
    required String bookingId,
    required double baseFare,
  }) {
    try {
      _baseFare = baseFare;
      _unloadingStartTime = DateTime.now();
      _unloadingDuration = Duration.zero;

      // Persist start time to Firestore
      _firestore.collection('bookings').doc(bookingId).update({
        'unloadingStartTime': FieldValue.serverTimestamp(),
      });

      _startUnloadingTimer();
      debugPrint(
          'DemurrageTimerService: Unloading timer started for booking $bookingId');
    } catch (e) {
      debugPrint('DemurrageTimerService: Error starting unloading timer: $e');
    }
  }

  /// Pause loading demurrage timer
  Future<void> pauseLoadingTimer(String bookingId) async {
    try {
      _stopLoadingTimer();

      // Persist current duration to Firestore
      await _firestore.collection('bookings').doc(bookingId).update({
        'loadingDuration': _loadingDuration.inSeconds,
        'loadingStartTime': null,
      });

      debugPrint(
          'DemurrageTimerService: Loading timer paused for booking $bookingId');
    } catch (e) {
      debugPrint('DemurrageTimerService: Error pausing loading timer: $e');
    }
  }

  /// Pause unloading demurrage timer
  Future<void> pauseUnloadingTimer(String bookingId) async {
    try {
      _stopUnloadingTimer();

      // Persist current duration to Firestore
      await _firestore.collection('bookings').doc(bookingId).update({
        'unloadingDuration': _unloadingDuration.inSeconds,
        'unloadingStartTime': null,
      });

      debugPrint(
          'DemurrageTimerService: Unloading timer paused for booking $bookingId');
    } catch (e) {
      debugPrint('DemurrageTimerService: Error pausing unloading timer: $e');
    }
  }

  /// Stop loading demurrage timer and finalize fee
  Future<void> stopLoadingTimer({
    required String bookingId,
    required double? finalFare,
  }) async {
    try {
      _stopLoadingTimer();

      final fee = _calculateDemurrageFee(_loadingDuration, _baseFare);

      // Persist final fee to Firestore
      await _firestore.collection('bookings').doc(bookingId).update({
        'loadingDemurrageFee': fee,
        'loadingDuration': _loadingDuration.inSeconds,
        'loadingStartTime': null,
      });

      _loadingFeeController.add(fee);
      debugPrint(
          'DemurrageTimerService: Loading timer stopped for booking $bookingId, fee: $fee');
    } catch (e) {
      debugPrint('DemurrageTimerService: Error stopping loading timer: $e');
    }
  }

  /// Stop unloading demurrage timer and finalize fee
  Future<void> stopUnloadingTimer({
    required String bookingId,
    required double? finalFare,
  }) async {
    try {
      _stopUnloadingTimer();

      final fee = _calculateDemurrageFee(_unloadingDuration, _baseFare);

      // Persist final fee to Firestore
      await _firestore.collection('bookings').doc(bookingId).update({
        'unloadingDemurrageFee': fee,
        'unloadingDuration': _unloadingDuration.inSeconds,
        'unloadingStartTime': null,
      });

      _unloadingFeeController.add(fee);
      debugPrint(
          'DemurrageTimerService: Unloading timer stopped for booking $bookingId, fee: $fee');
    } catch (e) {
      debugPrint('DemurrageTimerService: Error stopping unloading timer: $e');
    }
  }

  /// Cancel all timers (call when disposing)
  void cancelAllTimers() {
    _stopLoadingTimer();
    _stopUnloadingTimer();
    debugPrint('DemurrageTimerService: All timers cancelled');
  }

  /// Reset timer state
  void reset() {
    _loadingDuration = Duration.zero;
    _unloadingDuration = Duration.zero;
    _loadingStartTime = null;
    _unloadingStartTime = null;
    _baseFare = 0.0;
    debugPrint('DemurrageTimerService: Timer state reset');
  }

  /// Get demurrage fee for a booking
  Future<Map<String, double>> getDemurrageFees(String bookingId) async {
    try {
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        return {'loading': 0.0, 'unloading': 0.0};
      }

      final data = bookingDoc.data()!;
      final loadingFee =
          (data['loadingDemurrageFee'] as num?)?.toDouble() ?? 0.0;
      final unloadingFee =
          (data['unloadingDemurrageFee'] as num?)?.toDouble() ?? 0.0;

      return {'loading': loadingFee, 'unloading': unloadingFee};
    } catch (e) {
      debugPrint('DemurrageTimerService: Error getting demurrage fees: $e');
      return {'loading': 0.0, 'unloading': 0.0};
    }
  }

  /// Check if loading timer is active
  bool get isLoadingTimerActive => _loadingTimer?.isActive ?? false;

  /// Check if unloading timer is active
  bool get isUnloadingTimerActive => _unloadingTimer?.isActive ?? false;

  // Private methods

  void _startLoadingTimer() {
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        _loadingDuration += const Duration(seconds: 1);
        _loadingDurationController.add(_loadingDuration);

        // Update fee every second
        final fee = _calculateDemurrageFee(_loadingDuration, _baseFare);
        _loadingFeeController.add(fee);
      },
    );
  }

  void _startUnloadingTimer() {
    _unloadingTimer?.cancel();
    _unloadingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        _unloadingDuration += const Duration(seconds: 1);
        _unloadingDurationController.add(_unloadingDuration);

        // Update fee every second
        final fee = _calculateDemurrageFee(_unloadingDuration, _baseFare);
        _unloadingFeeController.add(fee);
      },
    );
  }

  void _stopLoadingTimer() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
  }

  void _stopUnloadingTimer() {
    _unloadingTimer?.cancel();
    _unloadingTimer = null;
  }

  /// Calculate demurrage fee based on duration and base fare
  /// 25% of fare for every 4-hour block
  double _calculateDemurrageFee(Duration duration, double baseFare) {
    final hours = duration.inHours;
    final blocks = hours ~/ 4; // Integer division for 4-hour blocks

    if (blocks <= 0) {
      return 0.0;
    }

    return blocks * 0.25 * baseFare;
  }

  /// Dispose resources
  void dispose() {
    cancelAllTimers();
    _loadingDurationController.close();
    _unloadingDurationController.close();
    _loadingFeeController.close();
    _unloadingFeeController.close();
    debugPrint('DemurrageTimerService: Disposed');
  }
}
