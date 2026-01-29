import 'package:flutter/foundation.dart';

/// Booking Status Service for CitiMovers
/// Centralizes booking status logic and provides valid state transitions
class BookingStatusService {
  // Private constructor to prevent instantiation
  BookingStatusService._();

  // Singleton pattern
  static final BookingStatusService _instance = BookingStatusService._();
  factory BookingStatusService() => _instance;

  // Valid booking states
  static const String STATUS_PENDING = 'pending';
  static const String STATUS_AWAITING_PAYMENT = 'awaiting_payment';
  static const String STATUS_PAYMENT_LOCKED = 'payment_locked';
  static const String STATUS_ACCEPTED = 'accepted';
  static const String STATUS_ARRIVED_PICKUP = 'arrived_at_pickup';
  static const String STATUS_LOADING = 'loading';
  static const String STATUS_LOADING_COMPLETE = 'loading_complete';
  static const String STATUS_IN_TRANSIT = 'in_transit';
  static const String STATUS_ARRIVED_DROPOFF = 'arrived_at_dropoff';
  static const String STATUS_UNLOADING = 'unloading';
  static const String STATUS_UNLOADING_COMPLETE = 'unloading_complete';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_CANCELLED = 'cancelled';
  static const String STATUS_CANCELLED_BY_RIDER = 'cancelled_by_rider';
  static const String STATUS_CANCELLED_BY_CUSTOMER = 'cancelled_by_customer';

  // All valid status values
  static const List<String> ALL_STATUSES = [
    STATUS_PENDING,
    STATUS_AWAITING_PAYMENT,
    STATUS_PAYMENT_LOCKED,
    STATUS_ACCEPTED,
    STATUS_ARRIVED_PICKUP,
    STATUS_LOADING,
    STATUS_LOADING_COMPLETE,
    STATUS_IN_TRANSIT,
    STATUS_ARRIVED_DROPOFF,
    STATUS_UNLOADING,
    STATUS_UNLOADING_COMPLETE,
    STATUS_COMPLETED,
    STATUS_CANCELLED,
    STATUS_CANCELLED_BY_RIDER,
    STATUS_CANCELLED_BY_CUSTOMER,
  ];

  // Status categories
  static const List<String> PENDING_STATUSES = [
    STATUS_PENDING,
    STATUS_AWAITING_PAYMENT,
    STATUS_PAYMENT_LOCKED,
  ];

  static const List<String> ACTIVE_STATUSES = [
    STATUS_ACCEPTED,
    STATUS_ARRIVED_PICKUP,
    STATUS_LOADING,
    STATUS_LOADING_COMPLETE,
    STATUS_IN_TRANSIT,
    STATUS_ARRIVED_DROPOFF,
    STATUS_UNLOADING,
    STATUS_UNLOADING_COMPLETE,
  ];

  static const List<String> COMPLETED_STATUSES = [
    STATUS_COMPLETED,
  ];

  static const List<String> CANCELLED_STATUSES = [
    STATUS_CANCELLED,
    STATUS_CANCELLED_BY_RIDER,
    STATUS_CANCELLED_BY_CUSTOMER,
  ];

  // Valid state transitions (from -> to)
  static const Map<String, List<String>> VALID_TRANSITIONS = {
    STATUS_PENDING: [
      STATUS_AWAITING_PAYMENT,
      STATUS_CANCELLED,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_AWAITING_PAYMENT: [
      STATUS_PAYMENT_LOCKED,
      STATUS_CANCELLED,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_PAYMENT_LOCKED: [
      STATUS_ACCEPTED,
      STATUS_CANCELLED,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_ACCEPTED: [
      STATUS_ARRIVED_PICKUP,
      STATUS_CANCELLED_BY_RIDER,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_ARRIVED_PICKUP: [
      STATUS_LOADING,
      STATUS_CANCELLED_BY_RIDER,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_LOADING: [
      STATUS_LOADING_COMPLETE,
      STATUS_CANCELLED_BY_RIDER,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_LOADING_COMPLETE: [
      STATUS_IN_TRANSIT,
      STATUS_CANCELLED_BY_RIDER,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_IN_TRANSIT: [
      STATUS_ARRIVED_DROPOFF,
      STATUS_CANCELLED_BY_RIDER,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_ARRIVED_DROPOFF: [
      STATUS_UNLOADING,
      STATUS_CANCELLED_BY_RIDER,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_UNLOADING: [
      STATUS_UNLOADING_COMPLETE,
      STATUS_CANCELLED_BY_RIDER,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_UNLOADING_COMPLETE: [
      STATUS_COMPLETED,
      STATUS_CANCELLED_BY_RIDER,
      STATUS_CANCELLED_BY_CUSTOMER
    ],
    STATUS_COMPLETED: [], // Final state, no transitions allowed
    STATUS_CANCELLED: [], // Final state, no transitions allowed
    STATUS_CANCELLED_BY_RIDER: [], // Final state, no transitions allowed
    STATUS_CANCELLED_BY_CUSTOMER: [], // Final state, no transitions allowed
  };

  /// Check if a status is valid
  static bool isValidStatus(String status) {
    return ALL_STATUSES.contains(status);
  }

  /// Check if a status is pending
  static bool isPending(String status) {
    return PENDING_STATUSES.contains(status);
  }

  /// Check if a status is active
  static bool isActive(String status) {
    return ACTIVE_STATUSES.contains(status);
  }

  /// Check if a status is completed
  static bool isCompleted(String status) {
    return COMPLETED_STATUSES.contains(status);
  }

  /// Check if a status is cancelled
  static bool isCancelled(String status) {
    return CANCELLED_STATUSES.contains(status);
  }

  /// Check if a status is final (no further transitions allowed)
  static bool isFinalStatus(String status) {
    return COMPLETED_STATUSES.contains(status) ||
        CANCELLED_STATUSES.contains(status);
  }

  /// Check if a transition is valid
  static bool isValidTransition(String fromStatus, String toStatus) {
    final validTargets = VALID_TRANSITIONS[fromStatus];
    return validTargets != null && validTargets.contains(toStatus);
  }

  /// Get display text for a status
  static String getStatusDisplayText(String status) {
    switch (status) {
      case STATUS_PENDING:
        return 'Waiting for Driver';
      case STATUS_AWAITING_PAYMENT:
        return 'Waiting for Payment';
      case STATUS_PAYMENT_LOCKED:
        return 'Payment Processing';
      case STATUS_ACCEPTED:
        return 'Driver Assigned';
      case STATUS_ARRIVED_PICKUP:
        return 'Arrived at Pickup';
      case STATUS_LOADING:
        return 'Loading';
      case STATUS_LOADING_COMPLETE:
        return 'Loading Complete';
      case STATUS_IN_TRANSIT:
        return 'In Transit';
      case STATUS_ARRIVED_DROPOFF:
        return 'Arrived at Drop-off';
      case STATUS_UNLOADING:
        return 'Unloading';
      case STATUS_UNLOADING_COMPLETE:
        return 'Unloading Complete';
      case STATUS_COMPLETED:
        return 'Completed';
      case STATUS_CANCELLED:
        return 'Cancelled';
      case STATUS_CANCELLED_BY_RIDER:
        return 'Cancelled by Rider';
      case STATUS_CANCELLED_BY_CUSTOMER:
        return 'Cancelled by Customer';
      default:
        return status;
    }
  }

  /// Get color code for a status
  static int getStatusColor(String status) {
    switch (status) {
      case STATUS_PENDING:
      case STATUS_AWAITING_PAYMENT:
      case STATUS_PAYMENT_LOCKED:
        return 0xFFFFA52A; // Orange
      case STATUS_ACCEPTED:
      case STATUS_ARRIVED_PICKUP:
      case STATUS_LOADING:
      case STATUS_LOADING_COMPLETE:
      case STATUS_IN_TRANSIT:
      case STATUS_ARRIVED_DROPOFF:
      case STATUS_UNLOADING:
      case STATUS_UNLOADING_COMPLETE:
        return 0xFF4CAF50; // Green
      case STATUS_COMPLETED:
        return 0xFF2196F3; // Dark Green
      case STATUS_CANCELLED:
      case STATUS_CANCELLED_BY_RIDER:
      case STATUS_CANCELLED_BY_CUSTOMER:
        return 0xFFF44336; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// Check if a booking can be cancelled
  static bool canBeCancelled(String status) {
    return isPending(status) || status == STATUS_ACCEPTED;
  }

  /// Check if a booking can be modified
  static bool canBeModified(String status) {
    return isPending(status);
  }

  /// Check if a booking can be rated
  static bool canBeRated(String status) {
    return status == STATUS_COMPLETED;
  }

  /// Get next possible statuses for a given status
  static List<String> getNextPossibleStatuses(String status) {
    final validTargets = VALID_TRANSITIONS[status];
    return validTargets ?? [];
  }

  /// Get status category
  static String getStatusCategory(String status) {
    if (isPending(status)) {
      return 'pending';
    } else if (isActive(status)) {
      return 'active';
    } else if (isCompleted(status)) {
      return 'completed';
    } else if (isCancelled(status)) {
      return 'cancelled';
    }
    return 'unknown';
  }

  /// Log status transition for debugging
  static void logStatusTransition(
    String bookingId,
    String fromStatus,
    String toStatus,
  ) {
    if (!isValidTransition(fromStatus, toStatus)) {
      debugPrint(
        'BookingStatusService: INVALID transition for booking $bookingId: $fromStatus -> $toStatus',
      );
    } else {
      debugPrint(
        'BookingStatusService: Valid transition for booking $bookingId: $fromStatus -> $toStatus',
      );
    }
  }

  /// Validate booking status data
  static String? validateBookingStatusData(Map<String, dynamic> data) {
    final status = data['status'] as String?;

    if (status == null || status.isEmpty) {
      return 'Booking status is required';
    }

    if (!isValidStatus(status)) {
      return 'Invalid booking status: $status';
    }

    // Validate related timestamps based on status
    final timestamps = [
      'createdAt',
      'acceptedAt',
      'loadingStartedAt',
      'loadingCompletedAt',
      'unloadingStartedAt',
      'unloadingCompletedAt',
      'completedAt',
      'cancelledAt',
    ];

    for (final timestamp in timestamps) {
      if (data.containsKey(timestamp)) {
        final value = data[timestamp];
        if (value != null && value is! int && value is! DateTime) {
          return 'Invalid timestamp format for $timestamp';
        }
      }
    }

    return null;
  }

  /// Normalize booking status (handles legacy status values)
  static String normalizeStatus(String status) {
    // Map legacy status values to current standard
    switch (status) {
      case 'awaiting_payment':
      case 'payment_pending':
        return STATUS_AWAITING_PAYMENT;
      case 'driver_assigned':
        return STATUS_ACCEPTED;
      case 'driver_arrived':
        return STATUS_ARRIVED_PICKUP;
      case 'loading_started':
        return STATUS_LOADING;
      case 'loading_finished':
        return STATUS_LOADING_COMPLETE;
      case 'transit':
      case 'on_the_way':
      case 'in_progress':
        return STATUS_IN_TRANSIT;
      case 'driver_arrived_destination':
        return STATUS_ARRIVED_DROPOFF;
      case 'unloading_started':
        return STATUS_UNLOADING;
      case 'unloading_finished':
        return STATUS_UNLOADING_COMPLETE;
      case 'delivered':
        return STATUS_COMPLETED;
      case 'rider_cancelled':
        return STATUS_CANCELLED_BY_RIDER;
      case 'customer_cancelled':
        return STATUS_CANCELLED_BY_CUSTOMER;
      default:
        return status; // Already normalized
    }
  }

  /// Get status description with context
  static String getStatusDescription(String status,
      {Map<String, dynamic>? context}) {
    final displayText = getStatusDisplayText(status);

    switch (status) {
      case STATUS_PENDING:
        return 'Your booking is $displayText. Waiting for a driver to accept.';
      case STATUS_AWAITING_PAYMENT:
        return 'Please complete your payment to proceed.';
      case STATUS_PAYMENT_LOCKED:
        return 'Payment is being processed. Please wait...';
      case STATUS_ACCEPTED:
        final driverName = context?['driverName'] as String? ?? 'your driver';
        return '$driverName has accepted your booking and is on the way.';
      case STATUS_ARRIVED_PICKUP:
        return 'Driver has arrived at the pickup location.';
      case STATUS_LOADING:
        return 'Driver is loading your items.';
      case STATUS_LOADING_COMPLETE:
        return 'Loading is complete. Driver is now in transit.';
      case STATUS_IN_TRANSIT:
        return 'Your items are being delivered.';
      case STATUS_ARRIVED_DROPOFF:
        return 'Driver has arrived at the drop-off location.';
      case STATUS_UNLOADING:
        return 'Driver is unloading your items.';
      case STATUS_UNLOADING_COMPLETE:
        return 'Unloading is complete. Please receive your items.';
      case STATUS_COMPLETED:
        return 'Delivery completed! Thank you for using CitiMovers.';
      case STATUS_CANCELLED:
        return 'Booking has been cancelled.';
      case STATUS_CANCELLED_BY_RIDER:
        return 'Driver has cancelled this booking.';
      case STATUS_CANCELLED_BY_CUSTOMER:
        return 'You have cancelled this booking.';
      default:
        return displayText;
    }
  }
}
