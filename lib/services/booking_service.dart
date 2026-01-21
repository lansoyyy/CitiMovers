import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';
import '../models/location_model.dart';
import '../models/vehicle_model.dart';

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

  /// Create a new booking
  Future<BookingModel?> createBooking({
    required String customerId,
    required LocationModel pickupLocation,
    required LocationModel dropoffLocation,
    required VehicleModel vehicle,
    required String bookingType,
    DateTime? scheduledDateTime,
    required double distance,
    required double estimatedFare,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final bookingId = _firestore.collection(_bookingsCollection).doc().id;

      final initialStatus =
          paymentMethod == 'Dragonpay' ? 'awaiting_payment' : 'pending';

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
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: now,
        completedAt: null,
        cancellationReason: null,
      );

      await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .set(booking.toMap());

      // Create delivery request record for rider assignment
      await _firestore.collection('delivery_requests').add({
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
        'createdAt': now.toIso8601String(),
        'respondedAt': null,
      });

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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromMap(doc.data()))
            .toList());
  }

  /// Get bookings for a specific rider
  Stream<List<BookingModel>> getRiderBookings(String riderId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('driverId', isEqualTo: riderId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromMap(doc.data()))
            .toList());
  }

  /// Get booking by ID
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      final doc =
          await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      if (doc.exists) {
        return BookingModel.fromMap(doc.data()!);
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
        'completedAt': completedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error completing booking: $e');
      return false;
    }
  }

  /// Cancel booking
  Future<bool> cancelBooking(String bookingId, String reason) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
      });
      return true;
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      return false;
    }
  }

  /// Get available bookings for riders (pending bookings)
  Stream<List<BookingModel>> getAvailableBookings() {
    return _firestore
        .collection(_bookingsCollection)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromMap(doc.data()))
            .toList());
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
      final fare = (bookingData?['estimatedFare'] as num?)?.toDouble() ?? 0.0;

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
        'createdAt': now.toIso8601String(),
      };

      await _firestore.collection('reviews').add(reviewData);

      // Update booking with review reference
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'reviewId': reviewData['reviewId'],
        'rating': rating,
        'tipAmount': tipAmount,
        'reviewedAt': now.toIso8601String(),
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
          'updatedAt': now.toIso8601String(),
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
    Map<String, dynamic>? deliveryPhotos,
  }) async {
    try {
      // Get booking details for notification
      final bookingDoc =
          await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      final bookingData = bookingDoc.data();
      final customerId = bookingData?['customerId'] as String?;
      final riderId = bookingData?['driverId'] as String?;
      final customerName = bookingData?['customerName'] as String?;
      final riderName = bookingData?['driverName'] as String?;
      final fare = (bookingData?['estimatedFare'] as num?)?.toDouble() ?? 0.0;

      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (driverId != null) {
        updateData['driverId'] = driverId;
      }

      if (loadingStartedAt != null) {
        updateData['loadingStartedAt'] = loadingStartedAt.toIso8601String();
      }

      if (loadingCompletedAt != null) {
        updateData['loadingCompletedAt'] = loadingCompletedAt.toIso8601String();
      }

      if (unloadingStartedAt != null) {
        updateData['unloadingStartedAt'] = unloadingStartedAt.toIso8601String();
      }

      if (unloadingCompletedAt != null) {
        updateData['unloadingCompletedAt'] =
            unloadingCompletedAt.toIso8601String();
      }

      if (completedAt != null) {
        updateData['completedAt'] = completedAt.toIso8601String();
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
            merged[stage] = {
              'url': value,
              'uploadedAt': DateTime.now().toIso8601String(),
            };
          } else {
            merged[stage] = value;
          }
        }

        updateData['deliveryPhotos'] = merged;
      }

      await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .update(updateData);

      // Send notifications based on status
      if (status == 'loading_complete' || status == 'unloading_complete') {
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

      // Get booking details for notification
      final bookingDoc =
          await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      final bookingData = bookingDoc.data();
      final customerId = bookingData?['customerId'] as String?;
      final customerName = bookingData?['customerName'] as String?;
      final riderName = bookingData?['driverName'] as String?;
      final fare = (bookingData?['estimatedFare'] as num?)?.toDouble() ?? 0.0;

      // Update booking with rider assignment
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'driverId': riderId,
        'status': 'accepted',
        'acceptedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      // Create delivery request record
      await _firestore.collection('delivery_requests').add({
        'requestId': _firestore.collection('delivery_requests').doc().id,
        'bookingId': bookingId,
        'riderId': riderId,
        'status': 'accepted',
        'acceptedAt': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });

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

      // Create delivery request record with rejected status
      await _firestore.collection('delivery_requests').add({
        'requestId': _firestore.collection('delivery_requests').doc().id,
        'bookingId': bookingId,
        'riderId': riderId,
        'status': 'rejected',
        'reason': reason,
        'rejectedAt': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });

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
        'uploadedAt': DateTime.now().toIso8601String(),
      };

      await bookingRef.update({
        'deliveryPhotos': existingPhotos,
        'updatedAt': DateTime.now().toIso8601String(),
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
    return _firestore
        .collection(_bookingsCollection)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'bookingId': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  /// Get delivery requests for a specific rider
  Stream<List<Map<String, dynamic>>> getRiderDeliveryRequests(String riderId) {
    return _firestore
        .collection('delivery_requests')
        .where('riderId', isEqualTo: riderId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
