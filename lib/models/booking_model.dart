import 'package:cloud_firestore/cloud_firestore.dart';

import 'location_model.dart';
import 'vehicle_model.dart';

/// Booking Model for CitiMovers
/// Represents a delivery booking
class BookingModel {
  final String? bookingId;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String? driverId;
  final LocationModel pickupLocation;
  final LocationModel dropoffLocation;
  final VehicleModel vehicle;
  final String bookingType; // 'now' or 'scheduled'
  final DateTime? scheduledDateTime;
  final int? estimatedDuration;
  final double distance;
  final double estimatedFare;
  final double? finalFare;
  final String
      status; // 'pending', 'accepted', 'in_progress', 'completed', 'cancelled'
  final String paymentMethod; // 'Gcash', 'Maya', 'Debit Card', 'Credit Card'
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? loadingStartedAt;
  final DateTime? loadingCompletedAt;
  final DateTime? unloadingStartedAt;
  final DateTime? unloadingCompletedAt;
  final double? loadingDemurrageFee;
  final double? unloadingDemurrageFee;
  final Map<String, dynamic>? deliveryPhotos;
  final String? receiverName;
  final List<dynamic>? picklistItems;
  final DateTime? completedAt;
  final String? cancellationReason;

  BookingModel({
    this.bookingId,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.vehicle,
    required this.bookingType,
    this.scheduledDateTime,
    this.estimatedDuration,
    required this.distance,
    required this.estimatedFare,
    this.finalFare,
    this.status = 'pending',
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.loadingStartedAt,
    this.loadingCompletedAt,
    this.unloadingStartedAt,
    this.unloadingCompletedAt,
    this.loadingDemurrageFee,
    this.unloadingDemurrageFee,
    this.deliveryPhotos,
    this.receiverName,
    this.picklistItems,
    this.completedAt,
    this.cancellationReason,
  });

  static DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _parseMap(dynamic value) {
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
    }
    return null;
  }

  static int? _parseFirestoreInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Create BookingModel from Firestore document
  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      bookingId: map['bookingId'] as String?,
      customerId: map['customerId'] as String,
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      driverId: map['driverId'] as String?,
      pickupLocation:
          LocationModel.fromMap(map['pickupLocation'] as Map<String, dynamic>),
      dropoffLocation:
          LocationModel.fromMap(map['dropoffLocation'] as Map<String, dynamic>),
      vehicle: VehicleModel.fromMap(map['vehicle'] as Map<String, dynamic>),
      bookingType: map['bookingType'] as String,
      scheduledDateTime: _parseFirestoreDate(map['scheduledDateTime']),
      estimatedDuration: _parseFirestoreInt(map['estimatedDuration']),
      distance: (map['distance'] as num).toDouble(),
      estimatedFare: (map['estimatedFare'] as num).toDouble(),
      finalFare: map['finalFare'] != null
          ? (map['finalFare'] as num).toDouble()
          : null,
      status: map['status'] as String,
      paymentMethod: map['paymentMethod'] as String,
      notes: map['notes'] as String?,
      createdAt: _parseFirestoreDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseFirestoreDate(map['updatedAt']),
      acceptedAt: _parseFirestoreDate(map['acceptedAt']),
      loadingStartedAt: _parseFirestoreDate(map['loadingStartedAt']),
      loadingCompletedAt: _parseFirestoreDate(map['loadingCompletedAt']),
      unloadingStartedAt: _parseFirestoreDate(map['unloadingStartedAt']),
      unloadingCompletedAt: _parseFirestoreDate(map['unloadingCompletedAt']),
      loadingDemurrageFee: (map['loadingDemurrageFee'] as num?)?.toDouble(),
      unloadingDemurrageFee: (map['unloadingDemurrageFee'] as num?)?.toDouble(),
      deliveryPhotos: _parseMap(map['deliveryPhotos']),
      receiverName: map['receiverName'] as String?,
      picklistItems: map['picklistItems'] as List<dynamic>?,
      completedAt: _parseFirestoreDate(map['completedAt']),
      cancellationReason: map['cancellationReason'] as String?,
    );
  }

  /// Convert BookingModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'driverId': driverId,
      'pickupLocation': pickupLocation.toMap(),
      'dropoffLocation': dropoffLocation.toMap(),
      'vehicle': vehicle.toMap(),
      'bookingType': bookingType,
      'scheduledDateTime': scheduledDateTime?.millisecondsSinceEpoch,
      'estimatedDuration': estimatedDuration,
      'distance': distance,
      'estimatedFare': estimatedFare,
      'finalFare': finalFare,
      'status': status,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'acceptedAt': acceptedAt?.millisecondsSinceEpoch,
      'loadingStartedAt': loadingStartedAt?.millisecondsSinceEpoch,
      'loadingCompletedAt': loadingCompletedAt?.millisecondsSinceEpoch,
      'unloadingStartedAt': unloadingStartedAt?.millisecondsSinceEpoch,
      'unloadingCompletedAt': unloadingCompletedAt?.millisecondsSinceEpoch,
      'loadingDemurrageFee': loadingDemurrageFee,
      'unloadingDemurrageFee': unloadingDemurrageFee,
      'deliveryPhotos': deliveryPhotos,
      'receiverName': receiverName,
      'picklistItems': picklistItems,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'cancellationReason': cancellationReason,
    };
  }

  /// Create a copy with updated fields
  BookingModel copyWith({
    String? bookingId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? driverId,
    LocationModel? pickupLocation,
    LocationModel? dropoffLocation,
    VehicleModel? vehicle,
    String? bookingType,
    DateTime? scheduledDateTime,
    int? estimatedDuration,
    double? distance,
    double? estimatedFare,
    double? finalFare,
    String? status,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    DateTime? loadingStartedAt,
    DateTime? loadingCompletedAt,
    DateTime? unloadingStartedAt,
    DateTime? unloadingCompletedAt,
    double? loadingDemurrageFee,
    double? unloadingDemurrageFee,
    Map<String, dynamic>? deliveryPhotos,
    String? receiverName,
    List<dynamic>? picklistItems,
    DateTime? completedAt,
    String? cancellationReason,
  }) {
    return BookingModel(
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      driverId: driverId ?? this.driverId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      vehicle: vehicle ?? this.vehicle,
      bookingType: bookingType ?? this.bookingType,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      distance: distance ?? this.distance,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      finalFare: finalFare ?? this.finalFare,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      loadingStartedAt: loadingStartedAt ?? this.loadingStartedAt,
      loadingCompletedAt: loadingCompletedAt ?? this.loadingCompletedAt,
      unloadingStartedAt: unloadingStartedAt ?? this.unloadingStartedAt,
      unloadingCompletedAt: unloadingCompletedAt ?? this.unloadingCompletedAt,
      loadingDemurrageFee: loadingDemurrageFee ?? this.loadingDemurrageFee,
      unloadingDemurrageFee:
          unloadingDemurrageFee ?? this.unloadingDemurrageFee,
      deliveryPhotos: deliveryPhotos ?? this.deliveryPhotos,
      receiverName: receiverName ?? this.receiverName,
      picklistItems: picklistItems ?? this.picklistItems,
      completedAt: completedAt ?? this.completedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case 'pending':
        return 'Waiting for Driver';
      case 'accepted':
        return 'Driver Assigned';
      case 'arrived_at_pickup':
        return 'Arrived at Pickup';
      case 'loading_complete':
        return 'Loading Complete';
      case 'in_transit':
      case 'in_progress':
        return 'In Transit';
      case 'arrived_at_dropoff':
        return 'Arrived at Drop-off';
      case 'unloading_complete':
        return 'Unloading Complete';
      case 'completed':
      case 'delivered':
        return 'Completed';
      case 'cancelled':
      case 'cancelled_by_rider':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Check if booking can be cancelled
  bool get canBeCancelled {
    return status == 'pending' || status == 'accepted';
  }

  /// Check if booking is active
  bool get isActive {
    return status == 'pending' ||
        status == 'accepted' ||
        status == 'arrived_at_pickup' ||
        status == 'loading_complete' ||
        status == 'in_transit' ||
        status == 'in_progress' ||
        status == 'arrived_at_dropoff' ||
        status == 'unloading_complete';
  }

  @override
  String toString() {
    return 'BookingModel(id: $bookingId, status: $status, vehicle: ${vehicle.type})';
  }
}
