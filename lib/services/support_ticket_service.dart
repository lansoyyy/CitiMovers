import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/support_ticket_model.dart';

/// Handles support ticket creation and retrieval for customer and rider mobile apps.
class SupportTicketService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Auto-increment ticket number ──────────────────────────────────────────

  /// Atomically increments meta/ticket_counter and returns the next padded
  /// ticket number string, e.g. "TICKET#00001".
  Future<String> _getNextTicketNumber() async {
    final counterRef = _db.collection('meta').doc('ticket_counter');
    int nextCount = 1;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      if (snap.exists) {
        nextCount = ((snap.data()?['count'] as int?) ?? 0) + 1;
        tx.update(counterRef, {'count': nextCount});
      } else {
        nextCount = 1;
        tx.set(counterRef, {'count': 1});
      }
    });

    return 'TICKET#${nextCount.toString().padLeft(5, '0')}';
  }

  // ─── Create ticket ──────────────────────────────────────────────────────────

  /// Creates a new support ticket for a customer or rider.
  ///
  /// [submitterType] should be either `'customer'` or `'rider'`.
  Future<SupportTicketModel?> createTicket({
    required String submitterId,
    required String submitterName,
    required String submitterType,
    required String subject,
    required String description,
    required String category,
  }) async {
    try {
      final ticketNumber = await _getNextTicketNumber();
      final now = DateTime.now();
      final docRef = _db.collection('support_tickets').doc();

      final ticket = SupportTicketModel(
        ticketId: docRef.id,
        ticketNumber: ticketNumber,
        subject: subject,
        description: description,
        category: category,
        status: 'open',
        submittedBy: submitterId,
        submittedByType: submitterType,
        submittedByName: submitterName,
        createdAt: now,
        updatedAt: now,
        isEscalated: false,
      );

      await docRef.set(ticket.toMap());

      // Post the initial description as the first message in the thread.
      await _addMessage(
        ticketId: docRef.id,
        senderId: submitterId,
        senderType: submitterType,
        senderName: submitterName,
        body: description,
      );

      return ticket.copyWith(ticketId: docRef.id);
    } catch (_) {
      return null;
    }
  }

  // ─── Stream tickets for a user ──────────────────────────────────────────────

  Stream<List<SupportTicketModel>> streamUserTickets(String userId) {
    return _db
        .collection('support_tickets')
        .where('submittedBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SupportTicketModel.fromMap(d.id, d.data()))
            .toList());
  }

  // ─── Stream messages ────────────────────────────────────────────────────────

  Stream<List<SupportTicketMessageModel>> streamTicketMessages(
      String ticketId) {
    return _db
        .collection('support_tickets')
        .doc(ticketId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                SupportTicketMessageModel.fromMap(d.id, ticketId, d.data()))
            .toList());
  }

  // ─── Add a reply message ────────────────────────────────────────────────────

  Future<bool> addMessage({
    required String ticketId,
    required String senderId,
    required String senderType,
    required String senderName,
    required String body,
  }) async {
    try {
      await _addMessage(
        ticketId: ticketId,
        senderId: senderId,
        senderType: senderType,
        senderName: senderName,
        body: body,
      );
      // Update parent doc's lastMessageAt + status→pending (awaiting admin reply)
      await _db.collection('support_tickets').doc(ticketId).update({
        'lastMessageAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _addMessage({
    required String ticketId,
    required String senderId,
    required String senderType,
    required String senderName,
    required String body,
  }) async {
    final now = DateTime.now();
    final msgRef = _db
        .collection('support_tickets')
        .doc(ticketId)
        .collection('messages')
        .doc();

    final msg = SupportTicketMessageModel(
      messageId: msgRef.id,
      ticketId: ticketId,
      body: body,
      senderId: senderId,
      senderType: senderType,
      senderName: senderName,
      createdAt: now,
    );

    await msgRef.set(msg.toMap());
  }
}

// Extension so createTicket can return a copy with a resolved ticketId.
extension _CopyWith on SupportTicketModel {
  SupportTicketModel copyWith({String? ticketId}) {
    return SupportTicketModel(
      ticketId: ticketId ?? this.ticketId,
      ticketNumber: ticketNumber,
      subject: subject,
      description: description,
      category: category,
      status: status,
      submittedBy: submittedBy,
      submittedByType: submittedByType,
      submittedByName: submittedByName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessageAt: lastMessageAt,
      resolvedAt: resolvedAt,
      resolvedBy: resolvedBy,
      resolutionNotes: resolutionNotes,
      isEscalated: isEscalated,
      escalationRemarks: escalationRemarks,
      escalatedAt: escalatedAt,
      closedBy: closedBy,
    );
  }
}
