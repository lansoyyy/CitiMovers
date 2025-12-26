import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId; // Can be customer userId or rider riderId
  final String userType; // 'customer' or 'rider'
  final String
      type; // 'booking', 'payment', 'system', 'rating', 'delivery_request', 'review', 'tip', 'demurrage'
  final String title;
  final String message;
  final String? referenceId; // booking ID, payment ID, etc.
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.userType,
    required this.type,
    required this.title,
    required this.message,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userType: map['userType'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      referenceId: map['referenceId'],
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userType': userType,
      'type': type,
      'title': title,
      'message': message,
      'referenceId': referenceId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get notifications stream for a user
  Stream<List<NotificationModel>> getUserNotifications(
      String userId, String userType) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('userType', isEqualTo: userType)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data()))
            .toList());
  }

  /// Get unread notifications count for a user
  Stream<int> getUnreadNotificationsCount(String userId, String userType) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('userType', isEqualTo: userType)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Create a new notification
  Future<bool> createNotification({
    required String userId,
    required String userType,
    required String type,
    required String title,
    required String message,
    String? referenceId,
  }) async {
    try {
      final notification = NotificationModel(
        id: _firestore.collection('notifications').doc().id,
        userId: userId,
        userType: userType,
        type: type,
        title: title,
        message: message,
        referenceId: referenceId,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mark all notifications as read for a user
  Future<bool> markAllAsRead(String userId, String userType) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('userType', isEqualTo: userType)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        await doc.reference.update({'isRead': true});
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all notifications for a user
  Future<bool> clearAllNotifications(String userId, String userType) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('userType', isEqualTo: userType)
          .get();

      for (final doc in notifications.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create booking notification for customer
  Future<bool> createBookingNotificationForCustomer({
    required String customerId,
    required String bookingId,
    required String status,
    required String message,
  }) async {
    String title;
    switch (status) {
      case 'confirmed':
        title = 'Booking Confirmed';
        break;
      case 'picked_up':
        title = 'Rider On The Way';
        break;
      case 'in_transit':
        title = 'Delivery In Progress';
        break;
      case 'delivered':
        title = 'Delivery Completed';
        break;
      case 'cancelled':
        title = 'Booking Cancelled';
        break;
      default:
        title = 'Booking Update';
    }

    return createNotification(
      userId: customerId,
      userType: 'customer',
      type: 'booking',
      title: title,
      message: message,
      referenceId: bookingId,
    );
  }

  /// Create booking notification for rider
  Future<bool> createBookingNotificationForRider({
    required String riderId,
    required String bookingId,
    required String status,
    required String message,
  }) async {
    String title;
    switch (status) {
      case 'assigned':
        title = 'New Booking Assigned';
        break;
      case 'picked_up':
        title = 'Package Picked Up';
        break;
      case 'delivered':
        title = 'Delivery Completed';
        break;
      case 'cancelled':
        title = 'Booking Cancelled';
        break;
      default:
        title = 'Booking Update';
    }

    return createNotification(
      userId: riderId,
      userType: 'rider',
      type: 'booking',
      title: title,
      message: message,
      referenceId: bookingId,
    );
  }

  /// Create payment notification
  Future<bool> createPaymentNotification({
    required String userId,
    required String userType,
    required String paymentType, // 'top_up', 'payment', 'earning'
    required String message,
    String? referenceId,
  }) async {
    String title;
    switch (paymentType) {
      case 'top_up':
        title = 'Wallet Top-up Successful';
        break;
      case 'payment':
        title = 'Payment Processed';
        break;
      case 'earning':
        title = 'Earning Added';
        break;
      default:
        title = 'Payment Update';
    }

    return createNotification(
      userId: userId,
      userType: userType,
      type: 'payment',
      title: title,
      message: message,
      referenceId: referenceId,
    );
  }

  /// Create system notification
  Future<bool> createSystemNotification({
    required String userId,
    required String userType,
    required String title,
    required String message,
  }) async {
    return createNotification(
      userId: userId,
      userType: userType,
      type: 'system',
      title: title,
      message: message,
    );
  }

  /// Create rating notification
  Future<bool> createRatingNotification({
    required String riderId,
    required String bookingId,
    required String message,
  }) async {
    return createNotification(
      userId: riderId,
      userType: 'rider',
      type: 'rating',
      title: 'New Rating Received',
      message: message,
      referenceId: bookingId,
    );
  }

  /// Create comprehensive booking status notification
  /// This handles all booking status updates for both customers and riders
  Future<bool> createBookingStatusNotification({
    required String bookingId,
    required String status,
    String? customerId,
    String? riderId,
    String? customerName,
    String? riderName,
    double? fare,
  }) async {
    String title;
    String customerMessage;
    String? riderMessage;

    switch (status) {
      case 'pending':
        title = 'Booking Created';
        customerMessage =
            'Your booking request has been submitted and is waiting for a rider.';
        riderMessage = null; // No rider assigned yet
        break;
      case 'accepted':
        title = 'Booking Accepted';
        customerMessage =
            'Great news! ${riderName ?? 'A rider'} has accepted your booking.';
        riderMessage = 'You have accepted the booking request.';
        break;
      case 'arrived_at_pickup':
        title = 'Rider Arrived at Pickup';
        customerMessage =
            '${riderName ?? 'Your rider'} has arrived at the pickup location.';
        riderMessage = 'You have arrived at the pickup location.';
        break;
      case 'loading_complete':
        title = 'Loading Complete';
        customerMessage =
            'Your package has been loaded and the rider is now in transit.';
        riderMessage =
            'Loading complete. You are now in transit to the delivery location.';
        break;
      case 'in_transit':
        title = 'Delivery In Transit';
        customerMessage =
            '${riderName ?? 'Your rider'} is now on the way to the delivery location.';
        riderMessage = 'You are now in transit to the delivery location.';
        break;
      case 'arrived_at_dropoff':
        title = 'Rider Arrived at Drop-off';
        customerMessage =
            '${riderName ?? 'Your rider'} has arrived at the delivery location.';
        riderMessage = 'You have arrived at the delivery location.';
        break;
      case 'unloading_complete':
        title = 'Unloading Complete';
        customerMessage = 'Your package has been unloaded at the destination.';
        riderMessage = 'Unloading complete. Package has been delivered.';
        break;
      case 'completed':
        title = 'Delivery Completed';
        customerMessage =
            'Your delivery has been completed successfully! Please rate your rider.';
        riderMessage =
            'Delivery completed! You earned P${fare?.toStringAsFixed(0) ?? '0'} for this delivery.';
        break;
      case 'cancelled':
        title = 'Booking Cancelled';
        customerMessage = 'Your booking has been cancelled.';
        riderMessage = 'The booking has been cancelled.';
        break;
      case 'cancelled_by_rider':
        title = 'Booking Cancelled by Rider';
        customerMessage =
            'The rider has cancelled your booking. We apologize for the inconvenience.';
        riderMessage = 'You have cancelled this booking.';
        break;
      case 'rejected':
        title = 'Booking Rejected';
        customerMessage =
            'Your booking request was rejected by a rider. We are finding another rider for you.';
        riderMessage = 'You have rejected this booking request.';
        break;
      default:
        title = 'Booking Update';
        customerMessage = 'Your booking status has been updated.';
        riderMessage = 'Booking status has been updated.';
    }

    // Create notification for customer
    if (customerId != null && customerMessage != null) {
      await createNotification(
        userId: customerId,
        userType: 'customer',
        type: 'booking',
        title: title,
        message: customerMessage,
        referenceId: bookingId,
      );
    }

    // Create notification for rider
    if (riderId != null && riderMessage != null) {
      await createNotification(
        userId: riderId,
        userType: 'rider',
        type: 'booking',
        title: title,
        message: riderMessage,
        referenceId: bookingId,
      );
    }

    return true;
  }

  /// Create delivery request notification for rider
  /// When a new booking is available for the rider
  Future<bool> createDeliveryRequestNotification({
    required String riderId,
    required String bookingId,
    required String vehicleType,
    required String pickupLocation,
    required String dropoffLocation,
    required double fare,
  }) async {
    return createNotification(
      userId: riderId,
      userType: 'rider',
      type: 'delivery_request',
      title: 'New Delivery Request',
      message:
          'A $vehicleType delivery from $pickupLocation to $dropoffLocation is available. Earnings: P${fare.toStringAsFixed(0)}',
      referenceId: bookingId,
    );
  }

  /// Create review notification for rider
  /// When a customer submits a review and rating
  Future<bool> createReviewNotification({
    required String riderId,
    required String bookingId,
    required String customerName,
    required double rating,
    String? review,
    double? tipAmount,
  }) async {
    String message;
    if (review != null && review.isNotEmpty) {
      message = '$customerName rated you $rating.0 stars: "$review"';
      if (tipAmount != null && tipAmount > 0) {
        message += ' + P${tipAmount.toStringAsFixed(0)} tip!';
      }
    } else {
      message = '$customerName rated you $rating.0 stars';
      if (tipAmount != null && tipAmount > 0) {
        message += ' and gave you a P${tipAmount.toStringAsFixed(0)} tip!';
      }
    }

    return createNotification(
      userId: riderId,
      userType: 'rider',
      type: 'review',
      title: 'New Review Received',
      message: message,
      referenceId: bookingId,
    );
  }

  /// Create tip notification for rider
  /// When a customer gives a tip to the rider
  Future<bool> createTipNotification({
    required String riderId,
    required String bookingId,
    required String customerName,
    required double tipAmount,
  }) async {
    return createNotification(
      userId: riderId,
      userType: 'rider',
      type: 'tip',
      title: 'Tip Received',
      message: '$customerName gave you a P${tipAmount.toStringAsFixed(0)} tip!',
      referenceId: bookingId,
    );
  }

  /// Create demurrage notification for customer
  /// When demurrage fees are applied
  Future<bool> createDemurrageNotification({
    required String customerId,
    required String bookingId,
    required double loadingDemurrageFee,
    required double unloadingDemurrageFee,
    required double totalDemurrageFee,
  }) async {
    String message;
    if (loadingDemurrageFee > 0 && unloadingDemurrageFee > 0) {
      message =
          'Demurrage fees applied: P${loadingDemurrageFee.toStringAsFixed(0)} for loading and P${unloadingDemurrageFee.toStringAsFixed(0)} for unloading. Total: P${totalDemurrageFee.toStringAsFixed(0)}';
    } else if (loadingDemurrageFee > 0) {
      message =
          'Loading demurrage fee applied: P${loadingDemurrageFee.toStringAsFixed(0)}';
    } else if (unloadingDemurrageFee > 0) {
      message =
          'Unloading demurrage fee applied: P${unloadingDemurrageFee.toStringAsFixed(0)}';
    } else {
      message = 'No demurrage fees applied for this delivery.';
    }

    return createNotification(
      userId: customerId,
      userType: 'customer',
      type: 'demurrage',
      title: 'Demurrage Fee Applied',
      message: message,
      referenceId: bookingId,
    );
  }
}
