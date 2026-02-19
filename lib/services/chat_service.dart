import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

/// Chat Service - handles real-time messaging between customer and driver
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get or create chat room for a booking
  Future<ChatRoomModel> getOrCreateChatRoom({
    required String bookingId,
    required String customerId,
    required String customerName,
    required String driverId,
    required String driverName,
  }) async {
    final chatRoomId = ChatRoomModel.generateChatRoomId(bookingId);
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);

    final doc = await chatRoomRef.get();

    if (doc.exists && doc.data() != null) {
      return ChatRoomModel.fromMap(doc.data()!);
    }

    // Create new chat room
    final now = DateTime.now();
    final chatRoom = ChatRoomModel(
      chatRoomId: chatRoomId,
      bookingId: bookingId,
      customerId: customerId,
      customerName: customerName,
      driverId: driverId,
      driverName: driverName,
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );

    await chatRoomRef.set(chatRoom.toMap());
    return chatRoom;
  }

  /// Get chat room by ID
  Future<ChatRoomModel?> getChatRoom(String chatRoomId) async {
    final doc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
    if (doc.exists && doc.data() != null) {
      return ChatRoomModel.fromMap(doc.data()!);
    }
    return null;
  }

  /// Get chat room by booking ID
  Future<ChatRoomModel?> getChatRoomByBookingId(String bookingId) async {
    final chatRoomId = ChatRoomModel.generateChatRoomId(bookingId);
    return getChatRoom(chatRoomId);
  }

  /// Stream chat room updates
  Stream<ChatRoomModel?> streamChatRoom(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return ChatRoomModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  /// Send a message
  Future<bool> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String senderType,
    required String message,
  }) async {
    try {
      final now = DateTime.now();
      final messageId =
          '${now.millisecondsSinceEpoch}_${senderId.substring(0, 8)}';

      final chatMessage = ChatMessageModel(
        messageId: messageId,
        chatRoomId: chatRoomId,
        senderId: senderId,
        senderName: senderName,
        senderType: senderType,
        message: message,
        createdAt: now,
        isRead: false,
      );

      // Add message to messages subcollection
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set(chatMessage.toMap());

      // Update chat room with last message
      final updateData = <String, dynamic>{
        'lastMessage': message,
        'lastMessageAt': now.toIso8601String(),
        'lastMessageSenderId': senderId,
        'updatedAt': now.toIso8601String(),
      };

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .update(updateData);

      // Increment unread count for the other party (separate update)
      if (senderType == 'customer') {
        await _firestore.collection('chatRooms').doc(chatRoomId).update({
          'unreadByDriver': FieldValue.increment(1),
        });
      } else {
        await _firestore.collection('chatRooms').doc(chatRoomId).update({
          'unreadByCustomer': FieldValue.increment(1),
        });
      }

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Stream messages for a chat room
  Stream<List<ChatMessageModel>> streamMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(100) // Limit to last 100 messages
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessageModel.fromMap(doc.data()))
          .toList();
    });
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId, String userType) async {
    try {
      // Reset unread count for the user type
      final updateData = userType == 'customer'
          ? {'unreadByCustomer': 0}
          : {'unreadByDriver': 0};

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .update(updateData);

      // Mark all messages from the other party as read
      final messagesRef = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages');

      final senderType = userType == 'customer' ? 'driver' : 'customer';

      final unreadMessages = await messagesRef
          .where('senderType', isEqualTo: senderType)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  /// Deactivate chat room after delivery completion
  Future<void> deactivateChatRoom(String chatRoomId) async {
    try {
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error deactivating chat room: $e');
    }
  }

  /// Get unread message count for a user
  Future<int> getUnreadCount(String chatRoomId, String userType) async {
    try {
      final doc =
          await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return userType == 'customer'
            ? (data['unreadByCustomer'] as int?) ?? 0
            : (data['unreadByDriver'] as int?) ?? 0;
      }
    } catch (e) {
      print('Error getting unread count: $e');
    }
    return 0;
  }

  /// Stream unread count for a user across all their chat rooms
  Stream<int> streamTotalUnreadCount(String userId, String userType) {
    final field = userType == 'customer' ? 'customerId' : 'driverId';
    final unreadField =
        userType == 'customer' ? 'unreadByCustomer' : 'unreadByDriver';

    return _firestore
        .collection('chatRooms')
        .where(field, isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        total += (doc.data()[unreadField] as int?) ?? 0;
      }
      return total;
    });
  }
}
