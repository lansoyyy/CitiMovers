import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat Room Model - represents a conversation between customer and driver
class ChatRoomModel {
  final String chatRoomId;
  final String bookingId;
  final String customerId;
  final String customerName;
  final String driverId;
  final String driverName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final int unreadByCustomer;
  final int unreadByDriver;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive; // Chat is active only during delivery

  ChatRoomModel({
    required this.chatRoomId,
    required this.bookingId,
    required this.customerId,
    required this.customerName,
    required this.driverId,
    required this.driverName,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.unreadByCustomer = 0,
    this.unreadByDriver = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory ChatRoomModel.fromMap(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value) {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return ChatRoomModel(
      chatRoomId: (json['chatRoomId'] ?? '').toString(),
      bookingId: (json['bookingId'] ?? '').toString(),
      customerId: (json['customerId'] ?? '').toString(),
      customerName: (json['customerName'] ?? '').toString(),
      driverId: (json['driverId'] ?? '').toString(),
      driverName: (json['driverName'] ?? '').toString(),
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? parseDateTime(json['lastMessageAt'])
          : null,
      lastMessageSenderId: json['lastMessageSenderId'] as String?,
      unreadByCustomer: (json['unreadByCustomer'] as int?) ?? 0,
      unreadByDriver: (json['unreadByDriver'] as int?) ?? 0,
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatRoomId': chatRoomId,
      'bookingId': bookingId,
      'customerId': customerId,
      'customerName': customerName,
      'driverId': driverId,
      'driverName': driverName,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadByCustomer': unreadByCustomer,
      'unreadByDriver': unreadByDriver,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Generate chat room ID from booking ID
  static String generateChatRoomId(String bookingId) {
    return 'chat_$bookingId';
  }
}

/// Chat Message Model - individual messages in a chat room
class ChatMessageModel {
  final String messageId;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final String senderType; // 'customer' or 'driver'
  final String message;
  final DateTime createdAt;
  final bool isRead;

  ChatMessageModel({
    required this.messageId,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value) {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return ChatMessageModel(
      messageId: (json['messageId'] ?? '').toString(),
      chatRoomId: (json['chatRoomId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
      senderType: (json['senderType'] ?? 'customer').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: parseDateTime(json['createdAt']),
      isRead: (json['isRead'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderType': senderType,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }
}
