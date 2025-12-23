import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId; // Can be customer userId or rider riderId
  final String userType; // 'customer' or 'rider'
  final String type; // 'booking', 'payment', 'system', 'rating'
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
}
