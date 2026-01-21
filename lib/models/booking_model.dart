import 'location_model.dart';
import 'vehicle_model.dart';

/// Booking Model for CitiMovers
/// Represents a delivery booking
class BookingModel {
  final String? bookingId;
  final String customerId;
  final String? driverId;
  final LocationModel pickupLocation;
  final LocationModel dropoffLocation;
  final VehicleModel vehicle;
  final String bookingType; // 'now' or 'scheduled'
  final DateTime? scheduledDateTime;
  final double distance;
  final double estimatedFare;
  final double? finalFare;
  final String
      status; // 'pending', 'accepted', 'in_progress', 'completed', 'cancelled'
  final String paymentMethod; // 'Gcash', 'Maya', 'Debit Card', 'Credit Card'
  final String? notes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? cancellationReason;

  BookingModel({
    this.bookingId,
    required this.customerId,
    this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.vehicle,
    required this.bookingType,
    this.scheduledDateTime,
    required this.distance,
    required this.estimatedFare,
    this.finalFare,
    this.status = 'pending',
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.completedAt,
    this.cancellationReason,
  });

  /// Create BookingModel from Firestore document
  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      bookingId: map['bookingId'] as String?,
      customerId: map['customerId'] as String,
      driverId: map['driverId'] as String?,
      pickupLocation:
          LocationModel.fromMap(map['pickupLocation'] as Map<String, dynamic>),
      dropoffLocation:
          LocationModel.fromMap(map['dropoffLocation'] as Map<String, dynamic>),
      vehicle: VehicleModel.fromMap(map['vehicle'] as Map<String, dynamic>),
      bookingType: map['bookingType'] as String,
      scheduledDateTime: map['scheduledDateTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['scheduledDateTime'] as int)
          : null,
      distance: (map['distance'] as num).toDouble(),
      estimatedFare: (map['estimatedFare'] as num).toDouble(),
      finalFare: map['finalFare'] != null
          ? (map['finalFare'] as num).toDouble()
          : null,
      status: map['status'] as String,
      paymentMethod: map['paymentMethod'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      cancellationReason: map['cancellationReason'] as String?,
    );
  }

  /// Convert BookingModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'customerId': customerId,
      'driverId': driverId,
      'pickupLocation': pickupLocation.toMap(),
      'dropoffLocation': dropoffLocation.toMap(),
      'vehicle': vehicle.toMap(),
      'bookingType': bookingType,
      'scheduledDateTime': scheduledDateTime?.millisecondsSinceEpoch,
      'distance': distance,
      'estimatedFare': estimatedFare,
      'finalFare': finalFare,
      'status': status,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'cancellationReason': cancellationReason,
    };
  }

  /// Create a copy with updated fields
  BookingModel copyWith({
    String? bookingId,
    String? customerId,
    String? driverId,
    LocationModel? pickupLocation,
    LocationModel? dropoffLocation,
    VehicleModel? vehicle,
    String? bookingType,
    DateTime? scheduledDateTime,
    double? distance,
    double? estimatedFare,
    double? finalFare,
    String? status,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? completedAt,
    String? cancellationReason,
  }) {
    return BookingModel(
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      vehicle: vehicle ?? this.vehicle,
      bookingType: bookingType ?? this.bookingType,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      distance: distance ?? this.distance,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      finalFare: finalFare ?? this.finalFare,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case 'awaiting_payment':
        return 'Awaiting Payment';
      case 'pending':
        return 'Waiting for Driver';
      case 'accepted':
        return 'Driver Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Check if booking can be cancelled
  bool get canBeCancelled {
    return status == 'awaiting_payment' ||
        status == 'pending' ||
        status == 'accepted';
  }

  /// Check if booking is active
  bool get isActive {
    return status == 'awaiting_payment' ||
        status == 'pending' ||
        status == 'accepted' ||
        status == 'in_progress';
  }

  @override
  String toString() {
    return 'BookingModel(id: $bookingId, status: $status, vehicle: ${vehicle.type})';
  }
}
