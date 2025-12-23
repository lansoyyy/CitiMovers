import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
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
        status:
            'pending', // pending, accepted, in_progress, completed, cancelled
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
}
