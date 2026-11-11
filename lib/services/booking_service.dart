import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../utils/app_constants.dart';
import 'notification_service.dart';
import 'booking_status_service.dart';
import 'booking_finance_service.dart';
import 'trip_number_service.dart';
import 'customer_profile_helper.dart';
import 'rate_config_service.dart';
import '../models/location_model.dart';
import '../models/vehicle_model.dart';
import '../utils/partner_stamp.dart';
import '../utils/rider_booking_capacity.dart';

/// Booking Service for CitiMovers
/// Handles booking creation, updates, and management with Firebase Firestore
class BookingService {
  // Singleton pattern
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final TripNumberService _tripNumberService = TripNumberService();
  static const String _bookingsCollection = 'bookings';

  static const Map<String, String> additionalChargeTypeLabels = {
    'toll': 'Toll fee',
    'parking': 'Parking fee',
    'passway': 'Passway fee',
    'extra_helper': 'Extra helper / Mano fee',
    'other': 'Other charge',
  };

  static const Duration _autoContinueActiveStaleThreshold = Duration(hours: 72);
  static const Duration _autoContinuePendingStaleThreshold =
      Duration(hours: 24);
  static const Duration _scheduledAutoContinueLeadWindow =
      Duration(minutes: 30);

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double calculateFinalFare({
    required double lockedFare,
    double loadingDemurrageFee = 0.0,
    double unloadingDemurrageFee = 0.0,
    double additionalChargesTotal = 0.0,
    double tipAmount = 0.0,
  }) {
    return BookingFinanceService.resolveGrossAmount(
      estimatedFare: lockedFare,
      loadingDemurrageFee: loadingDemurrageFee,
      unloadingDemurrageFee: unloadingDemurrageFee,
      additionalChargesTotal: additionalChargesTotal,
      tipAmount: tipAmount,
    );
  }

  BookingFinanceBreakdown _buildFinanceBreakdown(
    Map<String, dynamic>? bookingData, {
    double? estimatedFare,
    double? loadingDemurrageFee,
    double? unloadingDemurrageFee,
    double? additionalChargesTotal,
    double? tipAmount,
    double? persistedFinalFare,
  }) {
    return BookingFinanceService.calculate(
      estimatedFare:
          estimatedFare ?? _readDouble(bookingData?['estimatedFare']),
      loadingDemurrageFee: loadingDemurrageFee ??
          _readDouble(bookingData?['loadingDemurrageFee']),
      unloadingDemurrageFee: unloadingDemurrageFee ??
          _readDouble(bookingData?['unloadingDemurrageFee']),
      additionalChargesTotal: additionalChargesTotal ??
          _readDouble(bookingData?['additionalChargesTotal']),
      tipAmount: tipAmount ?? _readDouble(bookingData?['tipAmount']),
      persistedFinalFare:
          persistedFinalFare ?? _readDouble(bookingData?['finalFare']),
    );
  }

  double _calculateResolvedFinalFare(
    Map<String, dynamic>? bookingData, {
    double? loadingDemurrageFee,
    double? unloadingDemurrageFee,
    double? additionalChargesTotal,
    double? tipAmount,
  }) {
    final lockedFare = _readDouble(bookingData?['estimatedFare']);
    final resolvedLoadingDemurrage =
        loadingDemurrageFee ?? _readDouble(bookingData?['loadingDemurrageFee']);
    final resolvedUnloadingDemurrage = unloadingDemurrageFee ??
        _readDouble(bookingData?['unloadingDemurrageFee']);
    final resolvedAdditionalCharges = additionalChargesTotal ??
        _readDouble(bookingData?['additionalChargesTotal']);
    final resolvedTip = tipAmount ?? _readDouble(bookingData?['tipAmount']);
    return BookingFinanceService.resolveGrossAmount(
      estimatedFare: lockedFare,
      loadingDemurrageFee: resolvedLoadingDemurrage,
      unloadingDemurrageFee: resolvedUnloadingDemurrage,
      additionalChargesTotal: resolvedAdditionalCharges,
      tipAmount: resolvedTip,
      persistedFinalFare: _readDouble(bookingData?['finalFare']),
    );
  }

  /// Create a new booking
  /// Uses Firestore transaction to ensure atomic creation of booking and delivery request
  Future<BookingModel?> createBooking({
    required String customerId,
    String? customerName,
    String? customerPhone,
    required LocationModel pickupLocation,
    required LocationModel dropoffLocation,
    required VehicleModel vehicle,
    required String bookingType,
    DateTime? scheduledDateTime,
    required double distance,
    required double estimatedFare,
    int? estimatedDurationMinutes,
    required String paymentMethod,
    String? notes,
    String? reportRecipients,
  }) async {
    try {
      final now = DateTime.now();
      final bookingId = _firestore.collection(_bookingsCollection).doc().id;

      const enforcedPaymentMethod = 'Wallet';
      const initialStatus = 'pending';

      if (paymentMethod != enforcedPaymentMethod) {
        debugPrint(
            'Payment method "$paymentMethod" requested but payments are currently enforced to "$enforcedPaymentMethod".');
      }

      final initialFinance = BookingFinanceService.calculate(
        estimatedFare: estimatedFare,
        persistedFinalFare: estimatedFare,
      );
      late BookingModel booking;

      // Use Firestore transaction to ensure atomic creation of booking and delivery request
      final bookingRef =
          _firestore.collection(_bookingsCollection).doc(bookingId);
      final deliveryRequestRef =
          _firestore.collection('delivery_requests').doc(bookingId);
      final userRef = _firestore.collection('users').doc(customerId);
      final walletTxnRef = _firestore.collection('wallet_transactions').doc();
      // Trip tickets are based on the booking transaction date, not the
      // scheduled service date, so daily sequences match what was booked today.
      final tripCounterDate = now;

      await _firestore.runTransaction((transaction) async {
        final tripAllocation = await _tripNumberService.allocateTripNumber(
          transaction: transaction,
          firestore: _firestore,
          date: tripCounterDate,
        );

        final bookingSnapshot = await transaction.get(bookingRef);
        if (bookingSnapshot.exists) {
          throw Exception('Booking already exists: $bookingId');
        }

        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) {
          throw Exception('Customer not found: $customerId');
        }

        final userData = userSnap.data() ?? {};
        final customerAccountType =
            CustomerProfileHelper.resolveAccountTypeFromMap(userData);
        final isContractCustomer = customerAccountType ==
            AppConstants.customerAccountTypeWarehouseContract;
        final billingType = isContractCustomer
            ? AppConstants.billingTypeContract30Day
            : AppConstants.billingTypeWallet;
        final paymentMethodValue =
            isContractCustomer ? 'Contract' : enforcedPaymentMethod;
        final paymentStatusValue =
            isContractCustomer ? 'contract_pending' : 'held';

        booking = BookingModel(
          bookingId: bookingId,
          tripNumber: tripAllocation.tripNumber,
          tripDateKey: tripAllocation.dateKey,
          tripSequence: tripAllocation.sequence,
          customerId: customerId,
          driverId: null,
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          vehicle: vehicle,
          bookingType: bookingType,
          scheduledDateTime: scheduledDateTime,
          distance: distance,
          estimatedFare: estimatedFare,
          finalFare: initialFinance.grossAmount,
          grossAmount: initialFinance.grossAmount,
          partnerNetRate: initialFinance.partnerNetRate,
          partnerNetAmount: initialFinance.partnerNetAmount,
          adminFeeRate: initialFinance.adminFeeRate,
          adminFeeAmount: initialFinance.adminFeeAmount,
          vatRate: initialFinance.vatRate,
          vatAmount: initialFinance.vatAmount,
          adminNetAmount: initialFinance.adminNetAmount,
          status: initialStatus,
          paymentMethod: paymentMethodValue,
          notes: notes,
          createdAt: now,
          completedAt: null,
          cancellationReason: null,
        );

        if (!isContractCustomer) {
          final currentBalance =
              (userData['walletBalance'] as num?)?.toDouble() ?? 0.0;

          if (currentBalance < estimatedFare) {
            throw Exception('Insufficient wallet balance for this booking');
          }

          final newBalance = currentBalance - estimatedFare;

          transaction.set(bookingRef, {
            ...booking.toMap(),
            if (customerName != null && customerName.trim().isNotEmpty)
              'customerName': customerName.trim(),
            if (customerPhone != null && customerPhone.trim().isNotEmpty)
              'customerPhone': customerPhone.trim(),
            if (estimatedDurationMinutes != null)
              'estimatedDuration': estimatedDurationMinutes,
            if (reportRecipients != null && reportRecipients.trim().isNotEmpty)
              'reportRecipients': reportRecipients.trim(),
            'userId': customerId,
            'riderId': null,
            'customerAccountType': customerAccountType,
            'billingType': billingType,
            'issueNotesCount': 0,
            'issueStatus': '',
            'reconciliationStatus': '',
            'paymentHeldAt': now.millisecondsSinceEpoch,
            'paymentCapturedAmount': estimatedFare,
            'paymentCapturedFromBalance': currentBalance,
            'paymentCapturedToBalance': newBalance,
            'paymentStatus': paymentStatusValue,
          });

          transaction.update(userRef, {
            'walletBalance': newBalance,
            'updatedAt': now.toIso8601String(),
          });

          transaction.set(walletTxnRef, {
            'id': walletTxnRef.id,
            'userId': customerId,
            'type': 'payment_hold',
            'amount': -estimatedFare,
            'previousBalance': currentBalance,
            'newBalance': newBalance,
            'description': 'Booking payment (on hold — captured on completion)',
            'referenceId': bookingId,
            'createdAt': Timestamp.fromDate(now),
          });
        } else {
          transaction.set(bookingRef, {
            ...booking.toMap(),
            if (customerName != null && customerName.trim().isNotEmpty)
              'customerName': customerName.trim(),
            if (customerPhone != null && customerPhone.trim().isNotEmpty)
              'customerPhone': customerPhone.trim(),
            if (estimatedDurationMinutes != null)
              'estimatedDuration': estimatedDurationMinutes,
            if (reportRecipients != null && reportRecipients.trim().isNotEmpty)
              'reportRecipients': reportRecipients.trim(),
            'userId': customerId,
            'riderId': null,
            'customerAccountType': customerAccountType,
            'billingType': billingType,
            'issueNotesCount': 0,
            'issueStatus': '',
            'reconciliationStatus': '',
            'paymentStatus': paymentStatusValue,
          });
        }

        transaction.set(deliveryRequestRef, {
          'requestId': bookingId,
          'bookingId': bookingId,
          'customerId': customerId,
          'riderId': null,
          'status': 'pending',
          'vehicleType': vehicle.name,
          'pickupLocation': {
            'address': pickupLocation.address,
            'latitude': pickupLocation.latitude,
            'longitude': pickupLocation.longitude,
          },
          'dropoffLocation': {
            'address': dropoffLocation.address,
            'latitude': dropoffLocation.latitude,
            'longitude': dropoffLocation.longitude,
          },
          'distance': distance,
          'estimatedFare': estimatedFare,
          'createdAt': now.millisecondsSinceEpoch,
          'respondedAt': null,
        });
      });

      debugPrint('Booking created successfully with transaction: $bookingId');
      return booking;
    } catch (e) {
      debugPrint('Error creating booking: $e');
      return null;
    }
  }

  static Future<double> resolveBookingFare({
    required double distanceKm,
    required String vehicleType,
  }) async {
    await RateConfigService.instance.ensureLoaded();
    return RateConfigService.instance.calculateCodFare(
      distanceKm: distanceKm,
      vehicleType: vehicleType,
    );
  }

  /// Get bookings for a specific customer
  Stream<List<BookingModel>> getCustomerBookings(String customerId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap({
                ...doc.data(),
                'bookingId': doc.id,
              }))
          .toList();
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bookings;
    });
  }

  /// Get bookings for a specific rider
  Stream<List<BookingModel>> getRiderBookings(String riderId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('driverId', isEqualTo: riderId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap({
                ...doc.data(),
                'bookingId': doc.id,
              }))
          .toList();
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bookings;
    });
  }

  bool _isPendingStatusForAutoContinue(String rawStatus) {
    final status = BookingStatusService.normalizeStatus(rawStatus);
    return status == BookingStatusService.STATUS_PENDING ||
        status == BookingStatusService.STATUS_AWAITING_PAYMENT ||
        status == BookingStatusService.STATUS_PAYMENT_LOCKED;
  }

  bool _isActiveStatusForAutoContinue(String rawStatus) {
    final status = BookingStatusService.normalizeStatus(rawStatus);
    return status == BookingStatusService.STATUS_ACCEPTED ||
        status == BookingStatusService.STATUS_ARRIVED_PICKUP ||
        status == BookingStatusService.STATUS_LOADING ||
        status == BookingStatusService.STATUS_LOADING_COMPLETE ||
        status == BookingStatusService.STATUS_IN_TRANSIT ||
        status == BookingStatusService.STATUS_ARRIVED_DROPOFF ||
        status == BookingStatusService.STATUS_UNLOADING ||
        status == BookingStatusService.STATUS_UNLOADING_COMPLETE ||
        status == BookingStatusService.STATUS_DAMAGE_REPORTED ||
        status == BookingStatusService.STATUS_RECEIVING;
  }

  DateTime _lastActivityAt(BookingModel booking) {
    return booking.updatedAt ??
        booking.unloadingCompletedAt ??
        booking.unloadingStartedAt ??
        booking.loadingCompletedAt ??
        booking.loadingStartedAt ??
        booking.acceptedAt ??
        booking.createdAt;
  }

  List<BookingModel> _sortMostRecent(List<BookingModel> bookings) {
    final sorted = [...bookings];
    sorted.sort((a, b) => _lastActivityAt(b).compareTo(_lastActivityAt(a)));
    return sorted;
  }

  String _assignedRiderIdFromData(Map<String, dynamic>? bookingData) {
    return ((bookingData?['driverId'] ?? bookingData?['riderId']) as String?)
            ?.trim() ??
        '';
  }

  Future<List<Map<String, dynamic>>> _loadLiveBookingsForRider(
    String riderId,
  ) async {
    final trimmedRiderId = riderId.trim();
    if (trimmedRiderId.isEmpty) return const <Map<String, dynamic>>[];

    final snapshots = await Future.wait([
      _firestore
          .collection(_bookingsCollection)
          .where('driverId', isEqualTo: trimmedRiderId)
          .get(),
      _firestore
          .collection(_bookingsCollection)
          .where('riderId', isEqualTo: trimmedRiderId)
          .get(),
    ]);

    final bookingsById = <String, Map<String, dynamic>>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (_assignedRiderIdFromData(data) != trimmedRiderId) continue;

        final rawStatus = (data['status'] ?? '').toString();
        if (!BookingStatusService.isAssignedRiderLiveStatus(rawStatus)) {
          continue;
        }

        bookingsById[doc.id] = {
          ...data,
          'bookingId': doc.id,
        };
      }
    }

    return bookingsById.values.toList();
  }

  /// Returns the reason the rider cannot accept the booking, or `null` when
  /// the rider still has capacity (max 1 scheduled + 1 realtime pickup).
  Future<String?> getBookingCapacityConflict({
    required String bookingId,
    required String riderId,
  }) async {
    final bookingDoc =
        await _firestore.collection(_bookingsCollection).doc(bookingId).get();
    if (!bookingDoc.exists) return 'Booking not found.';

    final liveBookings = await _loadLiveBookingsForRider(riderId);
    return RiderBookingCapacity.conflictMessage(
      candidateBookingType: bookingDoc.data()?['bookingType'],
      liveBookings: liveBookings,
      excludingBookingId: bookingId,
      referenceBuilder: (booking) => (booking['tripNumber'] ??
              booking['bookingId'] ??
              booking['id'] ??
              '')
          .toString(),
    );
  }

  Future<void> _syncRiderActiveBookingPointer({
    required String bookingId,
    required String riderId,
    required String status,
  }) async {
    final resolvedRiderId = riderId.trim();
    if (resolvedRiderId.isEmpty) return;

    try {
      final riderRef = _firestore.collection('riders').doc(resolvedRiderId);
      final normalizedStatus = BookingStatusService.normalizeStatus(status);

      // Keep the legacy pointer and the two capacity slots aligned with the
      // rider's real live assignments. This also migrates riders that only
      // have the old `activeBookingId` field.
      final liveBookings = await _loadLiveBookingsForRider(resolvedRiderId);
      Map<String, dynamic>? scheduledBooking;
      Map<String, dynamic>? realtimeBooking;
      for (final booking in liveBookings) {
        if (RiderBookingCapacity.isScheduled(booking['bookingType'])) {
          scheduledBooking ??= booking;
        } else {
          realtimeBooking ??= booking;
        }
      }

      final primaryBooking = liveBookings.isEmpty ? null : liveBookings.first;
      final primaryBookingId = primaryBooking == null
          ? ''
          : RiderBookingCapacity.bookingId(primaryBooking);
      final scheduledBookingId = scheduledBooking == null
          ? ''
          : RiderBookingCapacity.bookingId(scheduledBooking);
      final realtimeBookingId = realtimeBooking == null
          ? ''
          : RiderBookingCapacity.bookingId(realtimeBooking);

      await riderRef.set({
        'activeScheduledBookingId': scheduledBookingId.isEmpty
            ? FieldValue.delete()
            : scheduledBookingId,
        'activeRealtimeBookingId': realtimeBookingId.isEmpty
            ? FieldValue.delete()
            : realtimeBookingId,
        'activeBookingId':
            primaryBookingId.isEmpty ? FieldValue.delete() : primaryBookingId,
        'activeBookingStatus': primaryBookingId.isEmpty
            ? FieldValue.delete()
            : (primaryBooking?['status'] ?? normalizedStatus),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (e) {
      // Capacity sync must never fail the delivery action that triggered it.
      debugPrint('Error syncing rider booking capacity: $e');
    }
  }

  static List<Map<String, dynamic>> _additionalChargesFrom(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    final charges = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map) {
        charges.add(item.map((key, v) => MapEntry(key.toString(), v)));
      }
    }
    return charges;
  }

  static double _additionalChargesTotal(
    List<Map<String, dynamic>> charges,
  ) {
    return charges.fold<double>(
      0.0,
      (total, charge) => total + ((charge['amount'] as num?)?.toDouble() ?? 0.0),
    );
  }

  Future<bool> addAdditionalCharge({
    required String bookingId,
    required String type,
    required double amount,
    String? notes,
    String? addedByRole,
    String? addedById,
  }) async {
    if (amount <= 0) return false;
    final normalizedType = additionalChargeTypeLabels.containsKey(type)
        ? type
        : 'other';
    final now = DateTime.now();
    final bookingRef =
        _firestore.collection(_bookingsCollection).doc(bookingId);

    try {
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(bookingRef);
        if (!snap.exists) {
          throw StateError('Booking not found.');
        }
        final data = snap.data()!;
        final status = BookingStatusService.normalizeStatus(
          (data['status'] ?? '').toString(),
        );
        if (BookingStatusService.isFinalStatus(status)) {
          throw StateError(
            'Additional charges can no longer be changed after completion.',
          );
        }

        final charges = _additionalChargesFrom(data['additionalCharges']);
        charges.add({
          'id': '${now.microsecondsSinceEpoch}',
          'type': normalizedType,
          'label': additionalChargeTypeLabels[normalizedType],
          'amount': amount,
          'notes': (notes ?? '').trim(),
          'addedByRole': (addedByRole ?? 'rider').trim(),
          'addedById': (addedById ?? '').trim(),
          'addedAt': now.millisecondsSinceEpoch,
        });

        txn.update(bookingRef, {
          'additionalCharges': charges,
          'additionalChargesTotal': _additionalChargesTotal(charges),
          'additionalChargesUpdatedAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
        });
      });
      return true;
    } catch (e) {
      debugPrint('Error adding additional charge: $e');
      return false;
    }
  }

  Future<bool> removeAdditionalCharge({
    required String bookingId,
    required String chargeId,
    String? removedByRole,
    String? removedById,
  }) async {
    final now = DateTime.now();
    final bookingRef =
        _firestore.collection(_bookingsCollection).doc(bookingId);

    try {
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(bookingRef);
        if (!snap.exists) {
          throw StateError('Booking not found.');
        }
        final data = snap.data()!;
        final status = BookingStatusService.normalizeStatus(
          (data['status'] ?? '').toString(),
        );
        if (BookingStatusService.isFinalStatus(status)) {
          throw StateError(
            'Additional charges can no longer be changed after completion.',
          );
        }

        final charges = _additionalChargesFrom(data['additionalCharges']);
        charges.removeWhere((charge) => charge['id']?.toString() == chargeId);

        txn.update(bookingRef, {
          'additionalCharges': charges,
          'additionalChargesTotal': _additionalChargesTotal(charges),
          'additionalChargesUpdatedAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
          'additionalChargesRemovedByRole': (removedByRole ?? 'rider').trim(),
          'additionalChargesRemovedById': (removedById ?? '').trim(),
        });
      });
      return true;
    } catch (e) {
      debugPrint('Error removing additional charge: $e');
      return false;
    }
  }

  /// Guard for auto-continue navigation.
  ///
  /// - Prevents resuming stale bookings.
  /// - Avoids auto-resuming scheduled trips that are not near their start time.
  bool isBookingEligibleForAutoContinue(BookingModel booking, {DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    final normalizedStatus =
        BookingStatusService.normalizeStatus(booking.status);

    if (!_isPendingStatusForAutoContinue(normalizedStatus) &&
        !_isActiveStatusForAutoContinue(normalizedStatus)) {
      return false;
    }

    // Do not auto-resume scheduled bookings too early.
    if (booking.bookingType == 'scheduled' &&
        booking.scheduledDateTime != null) {
      final shouldResumeBy =
          booking.scheduledDateTime!.subtract(_scheduledAutoContinueLeadWindow);
      if (resolvedNow.isBefore(shouldResumeBy)) {
        return false;
      }
    }

    final age = resolvedNow.difference(_lastActivityAt(booking));
    if (_isPendingStatusForAutoContinue(normalizedStatus)) {
      return age <= _autoContinuePendingStaleThreshold;
    }

    return age <= _autoContinueActiveStaleThreshold;
  }

  /// Active (already accepted/in-progress) bookings for customer.
  Stream<List<BookingModel>> getActiveUserBookings(String customerId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap({
                ...doc.data(),
                'bookingId': doc.id,
              }))
          .where((booking) {
        final normalized = BookingStatusService.normalizeStatus(booking.status);
        return _isActiveStatusForAutoContinue(normalized) &&
            isBookingEligibleForAutoContinue(booking);
      }).toList();
      return _sortMostRecent(bookings);
    });
  }

  /// Pending/searching bookings for customer.
  Stream<List<BookingModel>> getPendingUserBookings(String customerId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap({
                ...doc.data(),
                'bookingId': doc.id,
              }))
          .where((booking) {
        final normalized = BookingStatusService.normalizeStatus(booking.status);
        return _isPendingStatusForAutoContinue(normalized) &&
            isBookingEligibleForAutoContinue(booking);
      }).toList();
      return _sortMostRecent(bookings);
    });
  }

  /// Pending or in-progress bookings that are still eligible for quick resume.
  Stream<List<BookingModel>> getAutoContinueEligibleUserBookings(
    String customerId,
  ) {
    return _firestore
        .collection(_bookingsCollection)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap({
                ...doc.data(),
                'bookingId': doc.id,
              }))
          .where((booking) {
        final normalized = BookingStatusService.normalizeStatus(booking.status);
        final isLive = _isPendingStatusForAutoContinue(normalized) ||
            _isActiveStatusForAutoContinue(normalized);
        return isLive && isBookingEligibleForAutoContinue(booking);
      }).toList();
      return _sortMostRecent(bookings);
    });
  }

  /// Active bookings for driver.
  Stream<List<BookingModel>> getActiveDriverBookings(String driverId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap({
                ...doc.data(),
                'bookingId': doc.id,
              }))
          .where((booking) {
        final normalized = BookingStatusService.normalizeStatus(booking.status);
        return _isActiveStatusForAutoContinue(normalized) &&
            isBookingEligibleForAutoContinue(booking);
      }).toList();
      return _sortMostRecent(bookings);
    });
  }

  Future<BookingModel?> getMostRecentActiveUserBooking(
      String customerId) async {
    final bookings = await getActiveUserBookings(customerId).first;
    if (bookings.isEmpty) return null;
    return bookings.first;
  }

  Future<BookingModel?> getMostRecentPendingUserBooking(
      String customerId) async {
    final bookings = await getPendingUserBookings(customerId).first;
    if (bookings.isEmpty) return null;
    return bookings.first;
  }

  Future<BookingModel?> getMostRecentActiveDriverBooking(
      String driverId) async {
    final bookings = await getActiveDriverBookings(driverId).first;
    if (bookings.isEmpty) return null;
    return bookings.first;
  }

  /// Get booking by ID
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      final doc =
          await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      if (doc.exists) {
        return BookingModel.fromMap({
          ...doc.data()!,
          'bookingId': doc.id,
        });
      }
      return null;
    } catch (e) {
      debugPrint('Error getting booking: $e');
      return null;
    }
  }

  /// Update booking status
  Future<bool> updateBookingStatus(String bookingId, String status,
      {String? driverId}) async {
    try {
      final bookingRef =
          _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) return false;

      final bookingData = bookingDoc.data();
      final resolvedDriverId =
          driverId?.trim() ?? _assignedRiderIdFromData(bookingData);
      final updateData = {
        'status': status,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (driverId != null) {
        updateData['driverId'] = driverId;
      }

      await bookingRef.update(updateData);

      if (resolvedDriverId.isNotEmpty) {
        await _syncRiderActiveBookingPointer(
          bookingId: bookingId,
          riderId: resolvedDriverId,
          status: status,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      return false;
    }
  }

  /// Update booking with final fare and completion details
  Future<bool> completeBooking({
    required String bookingId,
    required double finalFare,
    required DateTime completedAt,
  }) async {
    try {
      final bookingDoc =
          await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      final bookingData = bookingDoc.data();
      final riderId = _assignedRiderIdFromData(bookingData);
      final resolvedFinalFare = _calculateResolvedFinalFare(bookingData);
      final appliedFinalFare =
          resolvedFinalFare > finalFare ? resolvedFinalFare : finalFare;
      final financeBreakdown = _buildFinanceBreakdown(
        bookingData,
        persistedFinalFare: appliedFinalFare,
      );

      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'completed',
        'finalFare': appliedFinalFare,
        ...financeBreakdown.toMap(),
        'completedAt': completedAt.millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (riderId.isNotEmpty) {
        await _syncRiderActiveBookingPointer(
          bookingId: bookingId,
          riderId: riderId,
          status: BookingStatusService.STATUS_COMPLETED,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error completing booking: $e');
      return false;
    }
  }

  /// Cancel booking by customer and fully refund the held amount to the
  /// customer's wallet.
  Future<bool> cancelBooking(String bookingId, String reason) async {
    try {
      final now = DateTime.now();

      // Fetch booking
      final bookingRef =
          _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) return false;

      final bookingData = bookingSnap.data()!;
      final currentStatus = bookingData['status'] as String?;
      final customerId = (bookingData['customerId'] as String?)?.trim() ?? '';
      final riderId =
          ((bookingData['driverId'] ?? bookingData['riderId']) as String?)
                  ?.trim() ??
              '';
      final riderRef = riderId.isNotEmpty
          ? _firestore.collection('riders').doc(riderId)
          : null;

      // Only cancel if still in a customer-cancellable state.
      if (currentStatus == null ||
          !BookingStatusService.canBeCancelled(currentStatus)) {
        debugPrint('Cannot cancel booking with status: $currentStatus');
        return false;
      }

      final refundAmount =
          (bookingData['paymentCapturedAmount'] as num?)?.toDouble() ??
              (bookingData['estimatedFare'] as num?)?.toDouble() ??
              0.0;
      final userRef = _firestore.collection('users').doc(customerId);
      final deliveryRequestRef =
          _firestore.collection('delivery_requests').doc(bookingId);
      final walletTxnRef = _firestore.collection('wallet_transactions').doc();

      await _firestore.runTransaction((txn) async {
        final userSnap = customerId.isNotEmpty ? await txn.get(userRef) : null;
        final previousBalance =
            (userSnap?.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final newBalance = previousBalance + refundAmount;

        txn.update(bookingRef, {
          'status': BookingStatusService.STATUS_CANCELLED_BY_CUSTOMER,
          'cancellationReason': reason,
          'updatedAt': now.millisecondsSinceEpoch,
          'cancelledAt': now.millisecondsSinceEpoch,
          'paymentStatus': 'refunded',
          'paymentRefundedAt': now.millisecondsSinceEpoch,
          'paymentRefundedAmount': refundAmount,
          'refundedAmount': refundAmount,
          'refundedAt': now.millisecondsSinceEpoch,
          'reconciliationStatus': 'refunded',
        });

        txn.set(
            deliveryRequestRef,
            {
              'bookingId': bookingId,
              'status': 'cancelled',
              'cancellationReason': reason,
              'updatedAt': now.millisecondsSinceEpoch,
            },
            SetOptions(merge: true));

        if (riderRef != null) {
          final riderSnap = await txn.get(riderRef);
          final activeBookingId =
              (riderSnap.data()?['activeBookingId'] as String?)?.trim() ?? '';
          if (activeBookingId == bookingId) {
            txn.set(
                riderRef,
                {
                  'activeBookingId': FieldValue.delete(),
                  'activeBookingStatus': FieldValue.delete(),
                  'updatedAt': now.millisecondsSinceEpoch,
                },
                SetOptions(merge: true));
          }
        }

        if (customerId.isNotEmpty && refundAmount > 0) {
          txn.update(userRef, {
            'walletBalance': newBalance,
            'updatedAt': now.toIso8601String(),
          });

          txn.set(walletTxnRef, {
            'id': walletTxnRef.id,
            'userId': customerId,
            'type': 'refund',
            'amount': refundAmount,
            'previousBalance': previousBalance,
            'newBalance': newBalance,
            'description': 'Booking refund — cancelled by customer',
            'referenceId': bookingId,
            'createdAt': Timestamp.fromDate(now),
          });
        }
      });

      if (riderId.isNotEmpty) {
        await _syncRiderActiveBookingPointer(
          bookingId: bookingId,
          riderId: riderId,
          status: BookingStatusService.STATUS_CANCELLED_BY_CUSTOMER,
        );
      }

      if (customerId.isNotEmpty) {
        await _notificationService.createBookingStatusNotification(
          bookingId: bookingId,
          status: BookingStatusService.STATUS_CANCELLED_BY_CUSTOMER,
          customerId: customerId,
          riderId: riderId.isNotEmpty ? riderId : null,
        );
        await _notificationService.createPaymentNotification(
          userId: customerId,
          userType: 'customer',
          paymentType: 'refund',
          message:
              'Your booking payment hold of P${refundAmount.toStringAsFixed(2)} has been refunded to your wallet.',
          referenceId: bookingId,
        );
      }

      debugPrint('Booking $bookingId cancelled by customer — '
          'P$refundAmount refunded to customer wallet.');
      return true;
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      return false;
    }
  }

  /// Cancel booking by rider — the held fare is refunded to the customer's
  /// wallet because the cancellation was not the customer's fault.
  Future<bool> cancelBookingByRider(
      String bookingId, String riderId, String reason) async {
    try {
      final now = DateTime.now();

      final bookingRef =
          _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) return false;

      final bookingData = bookingSnap.data()!;
      final customerId = bookingData['customerId'] as String?;
      final riderName = bookingData['driverName'] as String?;
      final assignedRiderId = _assignedRiderIdFromData(bookingData);
      final currentStatus = (bookingData['status'] ?? '').toString();
      final capturedAmount =
          (bookingData['paymentCapturedAmount'] as num?)?.toDouble() ??
              (bookingData['estimatedFare'] as num?)?.toDouble() ??
              0.0;

      if (assignedRiderId.isNotEmpty && assignedRiderId != riderId) {
        throw StateError('Only the assigned rider can cancel this booking.');
      }

      if (!BookingStatusService.isAssignedRiderLiveStatus(currentStatus)) {
        debugPrint('Cannot cancel rider booking with status: $currentStatus');
        return false;
      }

      final userRef = _firestore.collection('users').doc(customerId);
      final deliveryRequestRef =
          _firestore.collection('delivery_requests').doc(bookingId);
      final walletTxnRef = _firestore.collection('wallet_transactions').doc();
      final riderRef = _firestore.collection('riders').doc(riderId);

      await _firestore.runTransaction((txn) async {
        txn.update(bookingRef, {
          'status': 'cancelled_by_rider',
          'cancellationReason': reason,
          'updatedAt': now.millisecondsSinceEpoch,
          'cancelledAt': now.millisecondsSinceEpoch,
          'paymentStatus': 'refunded',
        });

        txn.set(
            deliveryRequestRef,
            {
              'bookingId': bookingId,
              'status': 'cancelled',
              'cancellationReason': reason,
              'updatedAt': now.millisecondsSinceEpoch,
            },
            SetOptions(merge: true));

        final riderSnap = await txn.get(riderRef);
        final activeBookingId =
            (riderSnap.data()?['activeBookingId'] as String?)?.trim() ?? '';
        if (activeBookingId == bookingId) {
          txn.set(
              riderRef,
              {
                'activeBookingId': FieldValue.delete(),
                'activeBookingStatus': FieldValue.delete(),
                'updatedAt': now.millisecondsSinceEpoch,
              },
              SetOptions(merge: true));
        }

        if (customerId != null && customerId.isNotEmpty && capturedAmount > 0) {
          final userSnap = await txn.get(userRef);
          final currentBalance =
              (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
          final newBalance = currentBalance + capturedAmount;

          txn.update(userRef, {
            'walletBalance': newBalance,
            'updatedAt': now.toIso8601String(),
          });

          txn.set(walletTxnRef, {
            'id': walletTxnRef.id,
            'userId': customerId,
            'type': 'refund',
            'amount': capturedAmount,
            'previousBalance': currentBalance,
            'newBalance': newBalance,
            'description': 'Booking refund — cancelled by rider',
            'referenceId': bookingId,
            'createdAt': Timestamp.fromDate(now),
          });
        }
      });

      await _syncRiderActiveBookingPointer(
        bookingId: bookingId,
        riderId: riderId,
        status: BookingStatusService.STATUS_CANCELLED_BY_RIDER,
      );

      await _notificationService.createBookingStatusNotification(
        bookingId: bookingId,
        status: BookingStatusService.STATUS_CANCELLED_BY_RIDER,
        customerId: customerId,
        riderId: riderId,
        riderName: riderName,
      );
      if (customerId != null && customerId.isNotEmpty && capturedAmount > 0) {
        await _notificationService.createPaymentNotification(
          userId: customerId,
          userType: 'customer',
          paymentType: 'refund',
          message:
              'Your booking payment hold of P${capturedAmount.toStringAsFixed(2)} has been refunded to your wallet.',
          referenceId: bookingId,
        );
      }

      debugPrint('Booking $bookingId cancelled by rider $riderId — '
          'P$capturedAmount refunded to customer.');
      return true;
    } catch (e) {
      debugPrint('Error cancelling booking by rider: $e');
      return false;
    }
  }

  /// Get available bookings for riders (pending bookings)
  Stream<List<BookingModel>> getAvailableBookings() {
    return _firestore
        .collection(_bookingsCollection)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap({
                ...doc.data(),
                'bookingId': doc.id,
              }))
          .toList();
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bookings;
    });
  }

  /// Get booking statistics for customer
  Future<Map<String, int>> getCustomerBookingStats(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('customerId', isEqualTo: customerId)
          .get();

      final bookings =
          snapshot.docs.map((doc) => BookingModel.fromMap(doc.data())).toList();

      final stats = <String, int>{
        'total': bookings.length,
        'completed': bookings.where((b) => b.status == 'completed').length,
        'cancelled': bookings.where((b) => b.status == 'cancelled').length,
        'pending': bookings.where((b) => b.status == 'pending').length,
        'in_progress': bookings.where((b) => b.status == 'in_progress').length,
      };

      return stats;
    } catch (e) {
      debugPrint('Error getting booking stats: $e');
      return {};
    }
  }

  /// Get booking statistics for rider
  Future<Map<String, int>> getRiderBookingStats(String riderId) async {
    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('driverId', isEqualTo: riderId)
          .get();

      final bookings =
          snapshot.docs.map((doc) => BookingModel.fromMap(doc.data())).toList();

      final stats = <String, int>{
        'total': bookings.length,
        'completed': bookings.where((b) => b.status == 'completed').length,
        'cancelled': bookings.where((b) => b.status == 'cancelled').length,
        'in_progress': bookings.where((b) => b.status == 'in_progress').length,
      };

      return stats;
    } catch (e) {
      debugPrint('Error getting rider booking stats: $e');
      return {};
    }
  }

  /// Submit review for a completed booking
  Future<bool> submitReview({
    required String bookingId,
    required String customerId,
    required String riderId,
    required double rating,
    String? review,
    double? tipAmount,
    List<String>? tipReasons,
  }) async {
    try {
      final now = DateTime.now();

      // Get booking details for notification
      final bookingDoc =
          await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      final bookingData = bookingDoc.data();
      final customerName = bookingData?['customerName'] as String?;

      // Create review document
      final reviewData = {
        'reviewId': _firestore.collection('reviews').doc().id,
        'bookingId': bookingId,
        'customerId': customerId,
        'riderId': riderId,
        'rating': rating,
        'review': review,
        'tipAmount': tipAmount,
        'tipReasons': tipReasons,
        'createdAt': now.millisecondsSinceEpoch,
      };

      await _firestore.collection('reviews').add(reviewData);

      final financeBreakdown = _buildFinanceBreakdown(
        bookingData,
        tipAmount: tipAmount ?? 0.0,
      );

      // Update booking with review reference
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'reviewId': reviewData['reviewId'],
        'rating': rating,
        'tipAmount': tipAmount,
        'finalFare': financeBreakdown.grossAmount,
        ...financeBreakdown.toMap(),
        'reviewedAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      // Update rider's rating and total deliveries
      final riderDoc = await _firestore.collection('riders').doc(riderId).get();
      if (riderDoc.exists) {
        final riderData = riderDoc.data()!;
        final currentRating = (riderData['rating'] as num?)?.toDouble() ?? 0.0;
        final totalDeliveries = (riderData['totalDeliveries'] as int?) ?? 0;
        final totalEarnings =
            (riderData['totalEarnings'] as num?)?.toDouble() ?? 0.0;

        // Calculate new average rating
        final newRating = ((currentRating * totalDeliveries) + rating) /
            (totalDeliveries + 1);

        await _firestore.collection('riders').doc(riderId).update({
          'rating': newRating,
          'totalDeliveries': totalDeliveries + 1,
          'totalEarnings': totalEarnings + (tipAmount ?? 0.0),
          'updatedAt': now.millisecondsSinceEpoch,
        });
      }

      // Send notification to rider
      await _notificationService.createReviewNotification(
        riderId: riderId,
        bookingId: bookingId,
        customerName: customerName ?? 'Customer',
        rating: rating,
        review: review,
        tipAmount: tipAmount,
      );

      // Send tip notification if tip was given
      if (tipAmount != null && tipAmount > 0) {
        await _notificationService.createTipNotification(
          riderId: riderId,
          bookingId: bookingId,
          customerName: customerName ?? 'Customer',
          tipAmount: tipAmount,
        );
      }

      debugPrint('Review submitted for booking: $bookingId');
      return true;
    } catch (e) {
      debugPrint('Error submitting review: $e');
      return false;
    }
  }

  /// Enhanced update booking status with demurrage tracking
  Future<bool> updateBookingStatusWithDetails({
    required String bookingId,
    required String status,
    String? driverId,
    DateTime? loadingStartedAt,
    DateTime? loadingCompletedAt,
    DateTime? unloadingStartedAt,
    DateTime? unloadingCompletedAt,
    DateTime? completedAt,
    String? receiverName,
    double? loadingDemurrageFee,
    double? unloadingDemurrageFee,
    int? loadingDemurrageSeconds,
    int? destinationDemurrageSeconds,
    int? totalDemurrageSeconds,
    DateTime? loadingDocsReceivedAt,
    String? loadingDemurrageStartSource,
    DateTime? arrivalAtPickupAt,
    List<Map<String, dynamic>>? picklistItems,
    Map<String, dynamic>? deliveryPhotos,
    String? deliveryProgressStep,
    String? receivingSubStep,
    bool? receiverIdPhotoConfirmed,
  }) async {
    try {
      // Get booking details for notification and delivery photos merge
      final bookingDoc =
          await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      final bookingData = bookingDoc.data();
      final customerId = bookingData?['customerId'] as String?;

      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (driverId != null) {
        updateData['driverId'] = driverId;
      }

      if (loadingStartedAt != null) {
        updateData['loadingStartedAt'] =
            loadingStartedAt.millisecondsSinceEpoch;
        // Keep the admin timeline timestamp in sync with the demurrage start.
        // With a call time the demurrage start can precede the physical
        // arrival, so the explicit actual arrival wins when provided.
        if (status == 'arrived_at_pickup') {
          updateData['arrivedAtPickupAt'] =
              (arrivalAtPickupAt ?? loadingStartedAt).millisecondsSinceEpoch;
        }
      }

      if (loadingCompletedAt != null) {
        updateData['loadingCompletedAt'] =
            loadingCompletedAt.millisecondsSinceEpoch;
        // Loading complete marks the start of transit — nothing in the app
        // writes an explicit inTransitAt click, so derive it here so the
        // admin timeline has a timestamp for the In Transit step.
        if (status == 'loading_complete') {
          updateData['inTransitAt'] = loadingCompletedAt.millisecondsSinceEpoch;
        }
      }

      if (unloadingStartedAt != null) {
        updateData['unloadingStartedAt'] =
            unloadingStartedAt.millisecondsSinceEpoch;
        // Keep the admin timeline timestamp in sync with the demurrage start.
        if (status == 'arrived_at_dropoff') {
          updateData['arrivedAtDropoffAt'] = unloadingStartedAt.millisecondsSinceEpoch;
        }
      }

      if (unloadingCompletedAt != null) {
        updateData['unloadingCompletedAt'] =
            unloadingCompletedAt.millisecondsSinceEpoch;
      }

      if (completedAt != null) {
        updateData['completedAt'] = completedAt.millisecondsSinceEpoch;
      }

      if (receiverName != null) {
        updateData['receiverName'] = receiverName;
      }

      if (deliveryProgressStep != null && deliveryProgressStep.isNotEmpty) {
        updateData['deliveryProgressStep'] = deliveryProgressStep;
      }

      if (receivingSubStep != null && receivingSubStep.isNotEmpty) {
        updateData['receivingSubStep'] = receivingSubStep;
      }

      if (receiverIdPhotoConfirmed != null) {
        updateData['receiverIdPhotoConfirmed'] = receiverIdPhotoConfirmed;
      }

      if (loadingDemurrageFee != null) {
        updateData['loadingDemurrageFee'] = loadingDemurrageFee;
      }

      if (unloadingDemurrageFee != null) {
        updateData['unloadingDemurrageFee'] = unloadingDemurrageFee;
      }

      if (loadingDemurrageSeconds != null) {
        updateData['loadingDemurrageSeconds'] = loadingDemurrageSeconds;
      }

      if (destinationDemurrageSeconds != null) {
        updateData['destinationDemurrageSeconds'] = destinationDemurrageSeconds;
      }

      if (totalDemurrageSeconds != null) {
        updateData['totalDemurrageSeconds'] = totalDemurrageSeconds;
      }

      if (loadingDocsReceivedAt != null) {
        updateData['loadingDocsReceivedAt'] =
            loadingDocsReceivedAt.millisecondsSinceEpoch;
      }

      if (loadingDemurrageStartSource != null &&
          loadingDemurrageStartSource.isNotEmpty) {
        updateData['loadingDemurrageStartSource'] = loadingDemurrageStartSource;
      }

      if (picklistItems != null) {
        updateData['picklistItems'] = picklistItems;
      }

      if (deliveryPhotos != null) {
        final existingRaw = bookingData?['deliveryPhotos'];
        final existing = (existingRaw is Map)
            ? existingRaw.map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : <String, dynamic>{};

        final merged = <String, dynamic>{...existing};
        for (final entry in deliveryPhotos.entries) {
          final stage = entry.key;
          final value = entry.value;
          if (value is Map) {
            merged[stage] = value;
          } else if (value is String) {
            final trimmed = value.trim();
            final isPhotoUrl =
                trimmed.startsWith('http://') || trimmed.startsWith('https://');

            // Keep plain metadata strings (remarks, timestamps, etc.) as-is.
            // Only wrap actual photo URLs in the expected photo object format.
            if (isPhotoUrl) {
              merged[stage] = {
                'url': trimmed,
                'uploadedAt': DateTime.now().millisecondsSinceEpoch,
              };
            } else {
              merged[stage] = trimmed;
            }
          } else {
            merged[stage] = value;
          }
        }

        updateData['deliveryPhotos'] = merged;
      }

      final resolvedLoadingDemurrage = loadingDemurrageFee ??
          _readDouble(bookingData?['loadingDemurrageFee']);
      final resolvedUnloadingDemurrage = unloadingDemurrageFee ??
          _readDouble(bookingData?['unloadingDemurrageFee']);
      final totalDemurrageFee =
          resolvedLoadingDemurrage + resolvedUnloadingDemurrage;
      final resolvedRiderId =
          driverId?.trim() ?? _assignedRiderIdFromData(bookingData);

      if (loadingDemurrageFee != null || unloadingDemurrageFee != null) {
        updateData['totalDemurrageFee'] = totalDemurrageFee;
        final financeBreakdown = _buildFinanceBreakdown(
          bookingData,
          loadingDemurrageFee: resolvedLoadingDemurrage,
          unloadingDemurrageFee: resolvedUnloadingDemurrage,
        );
        updateData['finalFare'] = financeBreakdown.grossAmount;
        updateData.addAll(financeBreakdown.toMap());
      }

      // Finalise payment when delivery is completed
      if (status == 'completed') {
        final financeBreakdown = _buildFinanceBreakdown(
          bookingData,
          loadingDemurrageFee: resolvedLoadingDemurrage,
          unloadingDemurrageFee: resolvedUnloadingDemurrage,
        );
        updateData['finalFare'] = financeBreakdown.grossAmount;
        updateData.addAll(financeBreakdown.toMap());
        updateData['totalDemurrageFee'] = totalDemurrageFee;
        final isContractBooking =
            (bookingData?['paymentMethod'] ?? '').toString() == 'Contract';
        if (!isContractBooking) {
          updateData['paymentStatus'] = 'captured';
          updateData['paymentCapturedAt'] =
              DateTime.now().millisecondsSinceEpoch;
        }
      }

      await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .update(updateData);

      if (resolvedRiderId.isNotEmpty) {
        await _syncRiderActiveBookingPointer(
          bookingId: bookingId,
          riderId: resolvedRiderId,
          status: status,
        );
      }

      // Send notifications based on status
      final hasDemurrageFees = (loadingDemurrageFee ?? 0.0) > 0.0 ||
          (unloadingDemurrageFee ?? 0.0) > 0.0;
      if (hasDemurrageFees &&
          (status == 'loading_complete' || status == 'unloading_complete')) {
        await _notificationService.createDemurrageNotification(
          customerId: customerId!,
          bookingId: bookingId,
          loadingDemurrageFee: loadingDemurrageFee ?? 0.0,
          unloadingDemurrageFee: unloadingDemurrageFee ?? 0.0,
          totalDemurrageFee:
              (loadingDemurrageFee ?? 0.0) + (unloadingDemurrageFee ?? 0.0),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      return false;
    }
  }

  /// Accept delivery request (for rider)
  Future<bool> acceptDeliveryRequest({
    required String bookingId,
    required String riderId,
  }) async {
    try {
      final capacityConflict = await getBookingCapacityConflict(
        bookingId: bookingId,
        riderId: riderId,
      );
      if (capacityConflict != null) {
        debugPrint(capacityConflict);
        return false;
      }

      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      final bookingRef =
          _firestore.collection(_bookingsCollection).doc(bookingId);
      final acceptedRequestRef =
          _firestore.collection('delivery_requests').doc(bookingId);
      final riderRef = _firestore.collection('riders').doc(riderId);

      late Map<String, dynamic> bookingData;
      late String riderName;

      final accepted = await _firestore.runTransaction<bool>((txn) async {
        final snap = await txn.get(bookingRef);
        if (!snap.exists) return false;

        final riderSnap = await txn.get(riderRef);
        if (!riderSnap.exists) return false;

        final data = snap.data() as Map<String, dynamic>;
        bookingData = data;
        final riderData = riderSnap.data() as Map<String, dynamic>;
        riderName =
            (riderData['name'] ?? riderData['fullName'] ?? 'Driver').toString();

        final currentStatus = data['status'] as String?;
        final currentDriverId = data['driverId'] as String?;
        final canAccept = currentStatus == 'pending' ||
            currentStatus == 'awaiting_payment' ||
            currentStatus == 'payment_locked';

        if (!canAccept || currentDriverId != null) {
          return false;
        }

        final candidateType =
            RiderBookingCapacity.normalizeType(data['bookingType']);
        var scheduledBookingId =
            (riderData['activeScheduledBookingId'] as String?)?.trim() ?? '';
        var realtimeBookingId =
            (riderData['activeRealtimeBookingId'] as String?)?.trim() ?? '';

        // Ignore stale slots whose booking is already completed, cancelled,
        // or reassigned so they cannot permanently block the rider.
        Future<bool> isSlotStillLive(String slotBookingId) async {
          if (slotBookingId.isEmpty || slotBookingId == bookingId) return true;
          final slotSnap = await txn.get(
            _firestore.collection(_bookingsCollection).doc(slotBookingId),
          );
          if (!slotSnap.exists) return false;
          final slotData = slotSnap.data();
          if (_assignedRiderIdFromData(slotData) != riderId.trim()) {
            return false;
          }
          return BookingStatusService.isAssignedRiderLiveStatus(
            (slotData?['status'] ?? '').toString(),
          );
        }

        if (!await isSlotStillLive(scheduledBookingId)) {
          scheduledBookingId = '';
        }
        if (!await isSlotStillLive(realtimeBookingId)) {
          realtimeBookingId = '';
        }

        // Fall back to the legacy pointer when a rider still has a single
        // pre-capacity booking that was never written to a slot field.
        final legacyActiveBookingId =
            (riderData['activeBookingId'] as String?)?.trim() ?? '';
        if (scheduledBookingId.isEmpty &&
            realtimeBookingId.isEmpty &&
            legacyActiveBookingId.isNotEmpty &&
            legacyActiveBookingId != bookingId) {
          final legacySnap = await txn.get(
            _firestore.collection(_bookingsCollection).doc(legacyActiveBookingId),
          );
          if (legacySnap.exists) {
            final legacyData = legacySnap.data()!;
            final legacyStatus = (legacyData['status'] ?? '').toString();
            if (BookingStatusService.isAssignedRiderLiveStatus(legacyStatus)) {
              if (RiderBookingCapacity.isScheduled(
                legacyData['bookingType'],
              )) {
                scheduledBookingId = legacyActiveBookingId;
              } else {
                realtimeBookingId = legacyActiveBookingId;
              }
            }
          }
        }

        final slotConflict = RiderBookingCapacity.slotConflictMessage(
          candidateBookingType: data['bookingType'],
          scheduledBookingId: scheduledBookingId,
          realtimeBookingId: realtimeBookingId,
          candidateBookingId: bookingId,
        );
        if (slotConflict != null) {
          debugPrint(slotConflict);
          return false;
        }

        if (candidateType == RiderBookingCapacity.scheduledType) {
          scheduledBookingId = bookingId;
        } else {
          realtimeBookingId = bookingId;
        }

        // Resolve the unit's partner (if any) before any writes so the
        // booking carries a self-contained partner report snapshot.
        final riderPartnerId =
            (riderData['partnerId'] as String?)?.trim() ?? '';
        DocumentSnapshot<Map<String, dynamic>>? partnerSnap;
        if (riderPartnerId.isNotEmpty) {
          partnerSnap = await txn.get(
            _firestore.collection('partners').doc(riderPartnerId),
          );
        }
        final partnerStamp = PartnerStamp.resolveBookingPartnerStamp(
          partnerId: riderPartnerId,
          partnerRaw: partnerSnap != null && partnerSnap.exists
              ? partnerSnap.data()
              : null,
        );

        txn.update(bookingRef, {
          'driverId': riderId,
          'riderId': riderId,
          'driverName': riderName,
          'riderName': riderName,
          'status': 'accepted',
          'acceptedAt': nowMs,
          'updatedAt': nowMs,
          ...partnerStamp,
        });

        txn.set(
          acceptedRequestRef,
          {
            'requestId': bookingId,
            'bookingId': bookingId,
            'customerId': data['customerId'],
            'riderId': riderId,
            'riderName': riderName,
            'status': 'accepted',
            'acceptedAt': nowMs,
            'respondedAt': nowMs,
            'updatedAt': nowMs,
            'vehicleType': (data['vehicle'] is Map)
                ? (data['vehicle']['name'] ?? data['vehicle']['type'])
                : null,
            'pickupLocation': data['pickupLocation'],
            'dropoffLocation': data['dropoffLocation'],
            'distance': data['distance'],
            'estimatedFare': data['estimatedFare'],
          },
          SetOptions(merge: true),
        );

        txn.set(
            riderRef,
            {
              'activeBookingId': bookingId,
              'activeBookingStatus': BookingStatusService.STATUS_ACCEPTED,
              'activeScheduledBookingId': scheduledBookingId.isEmpty
                  ? FieldValue.delete()
                  : scheduledBookingId,
              'activeRealtimeBookingId': realtimeBookingId.isEmpty
                  ? FieldValue.delete()
                  : realtimeBookingId,
              'updatedAt': nowMs,
            },
            SetOptions(merge: true));

        return true;
      });

      if (!accepted) return false;

      final customerId = bookingData['customerId'] as String?;
      final customerName = bookingData['customerName'] as String?;
      final fare = (bookingData['estimatedFare'] as num?)?.toDouble() ?? 0.0;

      // Send notification to customer
      await _notificationService.createBookingStatusNotification(
        bookingId: bookingId,
        status: 'accepted',
        customerId: customerId,
        riderId: riderId,
        customerName: customerName,
        riderName: riderName,
        fare: fare,
      );

      debugPrint(
          'Delivery request accepted for booking: $bookingId by rider: $riderId');
      return true;
    } catch (e) {
      debugPrint('Error accepting delivery request: $e');
      return false;
    }
  }

  /// Reject delivery request (for rider)
  Future<bool> rejectDeliveryRequest({
    required String bookingId,
    required String riderId,
    String? reason,
  }) async {
    try {
      final now = DateTime.now();

      // Get booking details for notification
      final bookingDoc =
          await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      final bookingData = bookingDoc.data();
      final customerId = bookingData?['customerId'] as String?;
      final customerName = bookingData?['customerName'] as String?;
      final riderName = bookingData?['driverName'] as String?;

      await _firestore.collection('delivery_requests').doc(bookingId).set(
        {
          'requestId': bookingId,
          'bookingId': bookingId,
          'customerId': customerId,
          'riderId': riderId,
          'status': 'rejected',
          'reason': reason,
          'rejectedAt': now.millisecondsSinceEpoch,
          'respondedAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
          'pickupLocation': bookingData?['pickupLocation'],
          'dropoffLocation': bookingData?['dropoffLocation'],
          'distance': bookingData?['distance'],
          'estimatedFare': bookingData?['estimatedFare'],
        },
        SetOptions(merge: true),
      );

      // Send notification to customer
      await _notificationService.createBookingStatusNotification(
        bookingId: bookingId,
        status: 'rejected',
        customerId: customerId,
        riderId: riderId,
        customerName: customerName,
        riderName: riderName,
      );

      debugPrint(
          'Delivery request rejected for booking: $bookingId by rider: $riderId');
      return true;
    } catch (e) {
      debugPrint('Error rejecting delivery request: $e');
      return false;
    }
  }

  /// Add delivery photo to booking
  Future<bool> addDeliveryPhoto({
    required String bookingId,
    required String
        stage, // 'start_loading', 'finish_loading', 'start_unloading', 'finish_unloading', 'receiver_id'
    required String photoUrl,
  }) async {
    try {
      final bookingRef =
          _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingDoc = await bookingRef.get();

      if (!bookingDoc.exists) {
        debugPrint('Booking not found: $bookingId');
        return false;
      }

      Map<String, dynamic> existingPhotos = Map<String, dynamic>.from(
          bookingDoc.data()?['deliveryPhotos'] as Map? ?? {});

      existingPhotos[stage] = {
        'url': photoUrl,
        'uploadedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await bookingRef.update({
        'deliveryPhotos': existingPhotos,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint('Delivery photo added for booking: $bookingId, stage: $stage');
      return true;
    } catch (e) {
      debugPrint('Error adding delivery photo: $e');
      return false;
    }
  }

  Future<bool> addCustomerDeliveryPhoto({
    required String bookingId,
    required String photoUrl,
    String? uploadedBy,
  }) async {
    final trimmedUrl = photoUrl.trim();
    if (trimmedUrl.isEmpty) return false;
    final bookingRef =
        _firestore.collection(_bookingsCollection).doc(bookingId);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    try {
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(bookingRef);
        if (!snap.exists) {
          throw StateError('Booking not found.');
        }
        final data = snap.data()!;
        final existing = (data['customerDeliveryPhotos'] is List)
            ? (data['customerDeliveryPhotos'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
        existing.add({
          'url': trimmedUrl,
          'uploadedAt': nowMs,
          'uploadedBy': (uploadedBy ?? '').trim(),
        });
        txn.update(bookingRef, {
          'customerDeliveryPhotos': existing,
          'updatedAt': nowMs,
        });
      });
      return true;
    } catch (e) {
      debugPrint('Error adding customer delivery photo: $e');
      return false;
    }
  }

  /// Get all delivery photos for a booking
  Future<Map<String, dynamic>?> getDeliveryPhotos(String bookingId) async {
    try {
      final bookingDoc =
          await _firestore.collection(_bookingsCollection).doc(bookingId).get();

      if (!bookingDoc.exists) {
        return null;
      }

      return bookingDoc.data()?['deliveryPhotos'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting delivery photos: $e');
      return null;
    }
  }

  /// Get available delivery requests for riders
  Stream<List<Map<String, dynamic>>> getAvailableDeliveryRequests() {
    int _parseCreatedAtMs(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is Timestamp) return value.millisecondsSinceEpoch;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        return parsed?.millisecondsSinceEpoch ?? 0;
      }
      if (value is num) return value.toInt();
      return 0;
    }

    return _firestore
        .collection(_bookingsCollection)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => {
                'bookingId': doc.id,
                ...doc.data(),
              })
          .toList();
      list.sort((a, b) {
        final aMs = _parseCreatedAtMs(a['createdAt']);
        final bMs = _parseCreatedAtMs(b['createdAt']);
        return bMs.compareTo(aMs);
      });
      return list;
    });
  }

  /// Get delivery requests for a specific rider
  Stream<List<Map<String, dynamic>>> getRiderDeliveryRequests(String riderId) {
    int _parseCreatedAtMs(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is Timestamp) return value.millisecondsSinceEpoch;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        return parsed?.millisecondsSinceEpoch ?? 0;
      }
      if (value is num) return value.toInt();
      return 0;
    }

    return _firestore
        .collection('delivery_requests')
        .where('riderId', isEqualTo: riderId)
        .snapshots()
        .map((snapshot) {
      int sortKey(Map<String, dynamic> m) {
        return _parseCreatedAtMs(m['updatedAt']) != 0
            ? _parseCreatedAtMs(m['updatedAt'])
            : (_parseCreatedAtMs(m['respondedAt']) != 0
                ? _parseCreatedAtMs(m['respondedAt'])
                : _parseCreatedAtMs(m['createdAt']));
      }

      final byBookingId = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final raw = doc.data();
        final normalized = <String, dynamic>{
          ...raw,
          'requestId': raw['requestId'] ?? doc.id,
          'bookingId': raw['bookingId'] ?? doc.id,
        };

        final bookingId = (normalized['bookingId'] ?? '').toString();
        if (bookingId.isEmpty) continue;

        final existing = byBookingId[bookingId];
        if (existing == null || sortKey(normalized) > sortKey(existing)) {
          byBookingId[bookingId] = normalized;
        }
      }

      final list = byBookingId.values.toList();
      list.sort((a, b) => sortKey(b).compareTo(sortKey(a)));
      return list;
    });
  }
}
