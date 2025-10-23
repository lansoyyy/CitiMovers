import '../models/booking_model.dart';
import '../models/location_model.dart';
import '../models/vehicle_model.dart';

/// Booking Service for CitiMovers
/// Handles booking creation, updates, and management
/// Ready for Firebase Firestore integration
class BookingService {
  // Singleton pattern
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  // Mock bookings storage
  final List<BookingModel> _bookings = [];

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
      // TODO: Save to Firestore
      // final docRef = await FirebaseFirestore.instance
      //     .collection('bookings')
      //     .add(booking.toMap());

      // Mock implementation
      await Future.delayed(const Duration(seconds: 1));

      final booking = BookingModel(
        bookingId: 'booking_${DateTime.now().millisecondsSinceEpoch}',
        customerId: customerId,
        pickupLocation: pickupLocation,
        dropoffLocation: dropoffLocation,
        vehicle: vehicle,
        bookingType: bookingType,
        scheduledDateTime: scheduledDateTime,
        distance: distance,
        estimatedFare: estimatedFare,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: DateTime.now(),
      );

      _bookings.add(booking);
      print('Booking created: ${booking.bookingId}');
      return booking;
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  /// Get all bookings for a customer
  Future<List<BookingModel>> getCustomerBookings(String customerId) async {
    try {
      // TODO: Fetch from Firestore
      // final snapshot = await FirebaseFirestore.instance
      //     .collection('bookings')
      //     .where('customerId', isEqualTo: customerId)
      //     .orderBy('createdAt', descending: true)
      //     .get();

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));

      return _bookings
          .where((booking) => booking.customerId == customerId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Error getting customer bookings: $e');
      return [];
    }
  }

  /// Get active bookings for a customer
  Future<List<BookingModel>> getActiveBookings(String customerId) async {
    try {
      final allBookings = await getCustomerBookings(customerId);
      return allBookings.where((booking) => booking.isActive).toList();
    } catch (e) {
      print('Error getting active bookings: $e');
      return [];
    }
  }

  /// Get booking by ID
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      // TODO: Fetch from Firestore
      // final doc = await FirebaseFirestore.instance
      //     .collection('bookings')
      //     .doc(bookingId)
      //     .get();

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 300));

      return _bookings.firstWhere(
        (booking) => booking.bookingId == bookingId,
        orElse: () => throw Exception('Booking not found'),
      );
    } catch (e) {
      print('Error getting booking: $e');
      return null;
    }
  }

  /// Update booking status
  Future<bool> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      // TODO: Update in Firestore
      // await FirebaseFirestore.instance
      //     .collection('bookings')
      //     .doc(bookingId)
      //     .update({'status': newStatus});

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));

      final index = _bookings.indexWhere((b) => b.bookingId == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(status: newStatus);
        print('Booking status updated: $bookingId -> $newStatus');
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  /// Cancel a booking
  Future<bool> cancelBooking(String bookingId, String reason) async {
    try {
      // TODO: Update in Firestore
      // await FirebaseFirestore.instance
      //     .collection('bookings')
      //     .doc(bookingId)
      //     .update({
      //       'status': 'cancelled',
      //       'cancellationReason': reason,
      //     });

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));

      final index = _bookings.indexWhere((b) => b.bookingId == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(
          status: 'cancelled',
          cancellationReason: reason,
        );
        print('Booking cancelled: $bookingId');
        return true;
      }
      return false;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  /// Assign driver to booking
  Future<bool> assignDriver(String bookingId, String driverId) async {
    try {
      // TODO: Update in Firestore
      // await FirebaseFirestore.instance
      //     .collection('bookings')
      //     .doc(bookingId)
      //     .update({
      //       'driverId': driverId,
      //       'status': 'accepted',
      //     });

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));

      final index = _bookings.indexWhere((b) => b.bookingId == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(
          driverId: driverId,
          status: 'accepted',
        );
        print('Driver assigned to booking: $bookingId');
        return true;
      }
      return false;
    } catch (e) {
      print('Error assigning driver: $e');
      return false;
    }
  }

  /// Complete a booking
  Future<bool> completeBooking(String bookingId, double finalFare) async {
    try {
      // TODO: Update in Firestore
      // await FirebaseFirestore.instance
      //     .collection('bookings')
      //     .doc(bookingId)
      //     .update({
      //       'status': 'completed',
      //       'finalFare': finalFare,
      //       'completedAt': FieldValue.serverTimestamp(),
      //     });

      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 500));

      final index = _bookings.indexWhere((b) => b.bookingId == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(
          status: 'completed',
          finalFare: finalFare,
          completedAt: DateTime.now(),
        );
        print('Booking completed: $bookingId');
        return true;
      }
      return false;
    } catch (e) {
      print('Error completing booking: $e');
      return false;
    }
  }

  /// Get booking statistics for a customer
  Future<Map<String, dynamic>> getBookingStats(String customerId) async {
    try {
      final bookings = await getCustomerBookings(customerId);

      final completed = bookings.where((b) => b.status == 'completed').length;
      final cancelled = bookings.where((b) => b.status == 'cancelled').length;
      final active = bookings.where((b) => b.isActive).length;

      final totalSpent = bookings
          .where((b) => b.status == 'completed' && b.finalFare != null)
          .fold<double>(0, (sum, b) => sum + b.finalFare!);

      return {
        'total': bookings.length,
        'completed': completed,
        'cancelled': cancelled,
        'active': active,
        'totalSpent': totalSpent,
      };
    } catch (e) {
      print('Error getting booking stats: $e');
      return {};
    }
  }
}
