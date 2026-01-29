import 'package:flutter/material.dart';

/// Model class for Rider Notifications in CitiMovers
class RiderNotificationModel {
  final String id;
  final String title;
  final String message;
  final String time;
  final RiderNotificationType type;
  final IconData icon;
  final Color color;
  bool isUnread;
  final String? bookingId;
  final String? customerId;
  final String? customerName;
  final String? pickupAddress;
  final String? deliveryAddress;
  final double? amount;
  final Map<String, dynamic>? metadata;

  RiderNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    required this.icon,
    required this.color,
    this.isUnread = false,
    this.bookingId,
    this.customerId,
    this.customerName,
    this.pickupAddress,
    this.deliveryAddress,
    this.amount,
    this.metadata,
  });

  // CopyWith method for immutable updates
  RiderNotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? time,
    RiderNotificationType? type,
    IconData? icon,
    Color? color,
    bool? isUnread,
    String? bookingId,
    String? customerId,
    String? customerName,
    String? pickupAddress,
    String? deliveryAddress,
    double? amount,
    Map<String, dynamic>? metadata,
  }) {
    return RiderNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      time: time ?? this.time,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isUnread: isUnread ?? this.isUnread,
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      amount: amount ?? this.amount,
      metadata: metadata ?? this.metadata,
    );
  }

  // Convert to Map (standardized naming)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'time': time,
      'type': type.toString(),
      'icon': icon.codePoint,
      'color': color.value,
      'isUnread': isUnread,
      'bookingId': bookingId,
      'customerId': customerId,
      'customerName': customerName,
      'pickupAddress': pickupAddress,
      'deliveryAddress': deliveryAddress,
      'amount': amount,
      'metadata': metadata,
    };
  }

  // Create from Map (standardized naming)
  factory RiderNotificationModel.fromMap(Map<String, dynamic> map) {
    return RiderNotificationModel(
      id: map['id'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      time: map['time'] as String,
      type: RiderNotificationType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => RiderNotificationType.systemAlert,
      ),
      icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
      color: Color(map['color'] as int),
      isUnread: map['isUnread'] as bool,
      bookingId: map['bookingId'] as String?,
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      pickupAddress: map['pickupAddress'] as String?,
      deliveryAddress: map['deliveryAddress'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  // Backward compatibility: toJson (alias for toMap)
  Map<String, dynamic> toJson() => toMap();

  // Backward compatibility: fromJson (alias for fromMap)
  factory RiderNotificationModel.fromJson(Map<String, dynamic> json) =>
      RiderNotificationModel.fromMap(json);

  @override
  String toString() {
    return 'RiderNotificationModel(id: $id, title: $title, type: $type, isUnread: $isUnread)';
  }
}

/// Enum for different types of rider notifications
enum RiderNotificationType {
  newBooking,
  bookingAccepted,
  bookingCancelled,
  pickupConfirmed,
  deliveryCompleted,
  paymentReceived,
  earningUpdate,
  ratingReceived,
  systemAlert,
  maintenance,
  promotion,
  emergency,
}

/// Extension to get notification type properties
extension RiderNotificationTypeExtension on RiderNotificationType {
  String get displayName {
    switch (this) {
      case RiderNotificationType.newBooking:
        return 'New Booking';
      case RiderNotificationType.bookingAccepted:
        return 'Booking Accepted';
      case RiderNotificationType.bookingCancelled:
        return 'Booking Cancelled';
      case RiderNotificationType.pickupConfirmed:
        return 'Pickup Confirmed';
      case RiderNotificationType.deliveryCompleted:
        return 'Delivery Completed';
      case RiderNotificationType.paymentReceived:
        return 'Payment Received';
      case RiderNotificationType.earningUpdate:
        return 'Earning Update';
      case RiderNotificationType.ratingReceived:
        return 'Rating Received';
      case RiderNotificationType.systemAlert:
        return 'System Alert';
      case RiderNotificationType.maintenance:
        return 'Maintenance';
      case RiderNotificationType.promotion:
        return 'Promotion';
      case RiderNotificationType.emergency:
        return 'Emergency';
    }
  }

  IconData get defaultIcon {
    switch (this) {
      case RiderNotificationType.newBooking:
        return Icons.add_task_outlined;
      case RiderNotificationType.bookingAccepted:
        return Icons.check_circle_outline;
      case RiderNotificationType.bookingCancelled:
        return Icons.cancel_outlined;
      case RiderNotificationType.pickupConfirmed:
        return Icons.inventory_2_outlined;
      case RiderNotificationType.deliveryCompleted:
        return Icons.task_alt_outlined;
      case RiderNotificationType.paymentReceived:
        return Icons.payments_outlined;
      case RiderNotificationType.earningUpdate:
        return Icons.trending_up_outlined;
      case RiderNotificationType.ratingReceived:
        return Icons.star_outline;
      case RiderNotificationType.systemAlert:
        return Icons.notifications_active_outlined;
      case RiderNotificationType.maintenance:
        return Icons.build_outlined;
      case RiderNotificationType.promotion:
        return Icons.local_offer_outlined;
      case RiderNotificationType.emergency:
        return Icons.warning_amber_outlined;
    }
  }

  Color get defaultColor {
    switch (this) {
      case RiderNotificationType.newBooking:
        return const Color(0xFF4CAF50); // Green
      case RiderNotificationType.bookingAccepted:
        return const Color(0xFF2196F3); // Blue
      case RiderNotificationType.bookingCancelled:
        return const Color(0xFFF44336); // Red
      case RiderNotificationType.pickupConfirmed:
        return const Color(0xFF9C27B0); // Purple
      case RiderNotificationType.deliveryCompleted:
        return const Color(0xFF4CAF50); // Green
      case RiderNotificationType.paymentReceived:
        return const Color(0xFF009688); // Teal
      case RiderNotificationType.earningUpdate:
        return const Color(0xFFFF9800); // Orange
      case RiderNotificationType.ratingReceived:
        return const Color(0xFFFFC107); // Amber
      case RiderNotificationType.systemAlert:
        return const Color(0xFF607D8B); // Blue Grey
      case RiderNotificationType.maintenance:
        return const Color(0xFF795548); // Brown
      case RiderNotificationType.promotion:
        return const Color(0xFFE91E63); // Pink
      case RiderNotificationType.emergency:
        return const Color(0xFFD32F2F); // Dark Red
    }
  }
}
