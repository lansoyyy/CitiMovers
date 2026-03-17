import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';
import 'booking_status_service.dart';
import '../models/location_model.dart';
import '../models/vehicle_model.dart';
import '../utils/app_constants.dart';

/// Booking Service for CitiMovers
/// Handles booking creation, updates, and management with Firebase Firestore
class BookingService {
  // Singleton pattern
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  static const String _bookingsCollection = 'bookings';

  static const Duration _autoContinueActiveStaleThreshold = Duration(hours: 72);
  static const Duration _autoContinuePendingStaleThreshold =
      Duration(hours: 24);
  static const Duration _scheduledAutoContinueLeadWindow =
      Duration(minutes: 30);

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

      final booking = BookingModel(
        bookingId: bookingId,
        customerId: customerId,
        driverId: null, // Will be set when rider accepts
        pickupLocation: pickupLocation,
        dropoffLocation: dropoffLocation,
        vehicle: vehicle,
        bookingType: bookingType,
        scheduledDateTime: scheduledDateTime,
        distance: distance,
        estimatedFare: estimatedFare,
        finalFare: estimatedFare, // Initially same as estimated
        status: initialStatus,
        paymentMethod: enforcedPaymentMethod,
        notes: notes,
        createdAt: now,
        completedAt: null,
        cancellationReason: null,
      );

      // Use Firestore transaction to ensure atomic creation of booking and delivery request
      final bookingRef =
          _firestore.collection(_bookingsCollection).doc(bookingId);
      final deliveryRequestRef =
          _firestore.collection('delivery_requests').doc(bookingId);
      final userRef = _firestore.collection('users').doc(customerId);
      final walletTxnRef = _firestore.collection('wallet_transactions').doc();

      await _firestore.runTransaction((transaction) async {
        // Check if booking already exists
        final bookingSnapshot = await transaction.get(bookingRef);
        if (bookingSnapshot.exists) {
          throw Exception('Booking already exists: $bookingId');
        }

        // Validate wallet balance (no minimum requirement - removed since no payment gateway)
        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) {
          throw Exception('Customer not found: $customerId');
        }

        final userData = userSnap.data();
        final currentBalance =
            (userData?['walletBalance'] as num?)?.toDouble() ?? 0.0;

        if (currentBalance < estimatedFare) {
          throw Exception('Insufficient wallet balance for this booking');
        }

        final newBalance = currentBalance - estimatedFare;

        // Create booking document
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
          'paymentHeldAt': now.millisecondsSinceEpoch,
          'paymentCapturedAmount': estimatedFare,
          'paymentCapturedFromBalance': currentBalance,
          'paymentCapturedToBalance': newBalance,
          // Payment is ON HOLD — deducted from wallet now, but only finalised
          // once delivery is completed. If the customer cancels, the held
          // amount is captured as a cancellation fee (not refunded).
          'paymentStatus': 'held',
        });

        // Deduct from wallet (hold)
        transaction.update(userRef, {
          'walletBalance': newBalance,
          'updatedAt': now.toIso8601String(),
        });

        // Wallet transaction record
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

        // Create delivery request document
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
        status == BookingStatusService.STATUS_UNLOADING_COMPLETE;
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
      final updateData = {
        'status': status,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (driverId != null) {
        updateData['driverId'] = driverId;
      }

      await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .update(updateData);
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
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'completed',
        'finalFare': finalFare,
        'completedAt': completedAt.millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      debugPrint('Error completing booking: $e');
      return false;
    }
  }

  /// Cancel booking by customer — the held fare is captured as a cancellation
  /// fee and is NOT refunded to the customer's wallet.
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

      // Only cancel if still cancellable (pending or accepted)
      if (currentStatus != 'pending' && currentStatus != 'accepted') {
        debugPrint('Cannot cancel booking with status: $currentStatus');
        return false;
      }

      final capturedAmount =
          (bookingData['paymentCapturedAmount'] as num?)?.toDouble() ??
              (bookingData['estimatedFare'] as num?)?.toDouble() ??
              0.0;

      // Capture the held amount as a cancellation fee — no wallet refund.
      await bookingRef.update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'updatedAt': now.millisecondsSinceEpoch,
        'cancelledAt': now.millisecondsSinceEpoch,
        'paymentStatus': 'captured',
        'paymentCapturedAt': now.millisecondsSinceEpoch,
      });

      debugPrint(
          'Booking $bookingId cancelled by customer — '
          'P$capturedAmount held amount captured as cancellation fee.');
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
      final capturedAmount =
          (bookingData['paymentCapturedAmount'] as num?)?.toDouble() ??
              (bookingData['estimatedFare'] as num?)?.toDouble() ??
              0.0;

      final userRef = _firestore.collection('users').doc(customerId);
      final walletTxnRef = _firestore.collection('wallet_transactions').doc();

      await _firestore.runTransaction((txn) async {
        txn.update(bookingRef, {
          'status': 'cancelled_by_rider',
          'cancellationReason': reason,
          'updatedAt': now.millisecondsSinceEpoch,
          'cancelledAt': now.millisecondsSinceEpoch,
          'paymentStatus': 'refunded',
        });

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

      debugPrint(
          'Booking $bookingId cancelled by rider $riderId — '
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

      // Update booking with review reference
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'reviewId': reviewData['reviewId'],
        'rating': rating,
        'tipAmount': tipAmount,
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
    List<Map<String, dynamic>>? picklistItems,
    Map<String, dynamic>? deliveryPhotos,
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
      }

      if (loadingCompletedAt != null) {
        updateData['loadingCompletedAt'] =
            loadingCompletedAt.millisecondsSinceEpoch;
      }

      if (unloadingStartedAt != null) {
        updateData['unloadingStartedAt'] =
            unloadingStartedAt.millisecondsSinceEpoch;
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

      // Finalise payment when delivery is completed
      if (status == 'completed') {
        updateData['paymentStatus'] = 'captured';
        updateData['paymentCapturedAt'] =
            DateTime.now().millisecondsSinceEpoch;
      }

      await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .update(updateData);

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
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      final bookingRef =
          _firestore.collection(_bookingsCollection).doc(bookingId);
      final acceptedRequestRef =
          _firestore.collection('delivery_requests').doc(bookingId);

      late Map<String, dynamic> bookingData;

      final accepted = await _firestore.runTransaction<bool>((txn) async {
        final snap = await txn.get(bookingRef);
        if (!snap.exists) return false;

        final data = snap.data() as Map<String, dynamic>;
        bookingData = data;

        final currentStatus = data['status'] as String?;
        final currentDriverId = data['driverId'] as String?;

        if (currentStatus != 'pending' || currentDriverId != null) {
          return false;
        }

        txn.update(bookingRef, {
          'driverId': riderId,
          'status': 'accepted',
          'acceptedAt': nowMs,
          'updatedAt': nowMs,
        });

        txn.set(
          acceptedRequestRef,
          {
            'requestId': bookingId,
            'bookingId': bookingId,
            'customerId': data['customerId'],
            'riderId': riderId,
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

        return true;
      });

      if (!accepted) return false;

      final customerId = bookingData['customerId'] as String?;
      final customerName = bookingData['customerName'] as String?;
      final riderName = bookingData['driverName'] as String?;
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
