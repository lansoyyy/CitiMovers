import 'package:cloud_firestore/cloud_firestore.dart';

/// A support ticket submitted by a customer, rider, or created by admin on behalf of a caller.
class SupportTicketModel {
  final String ticketId;
  final String ticketNumber; // e.g. TICKET#00001
  final String subject;
  final String description;
  final String category; // 'app' | 'logistics'
  final String status; // 'open' | 'pending' | 'escalated' | 'resolved'
  final String submittedBy; // userId / riderId / 'admin'
  final String submittedByType; // 'customer' | 'rider' | 'admin'
  final String submittedByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNotes;
  final bool isEscalated;
  final String? escalationRemarks;
  final DateTime? escalatedAt;
  final String? closedBy;

  const SupportTicketModel({
    required this.ticketId,
    required this.ticketNumber,
    required this.subject,
    required this.description,
    required this.category,
    required this.status,
    required this.submittedBy,
    required this.submittedByType,
    required this.submittedByName,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
    this.isEscalated = false,
    this.escalationRemarks,
    this.escalatedAt,
    this.closedBy,
  });

  bool get isResolved => status == 'resolved';
  bool get isOpen => status == 'open' || status == 'pending';

  factory SupportTicketModel.fromMap(String id, Map<String, dynamic> data) {
    return SupportTicketModel(
      ticketId: id,
      ticketNumber: (data['ticketNumber'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? 'app').toString(),
      status: (data['status'] ?? 'open').toString(),
      submittedBy: (data['submittedBy'] ?? '').toString(),
      submittedByType: (data['submittedByType'] ?? 'customer').toString(),
      submittedByName: (data['submittedByName'] ?? '').toString(),
      createdAt: _parseTs(data['createdAt']),
      updatedAt: _parseTs(data['updatedAt']),
      lastMessageAt: data['lastMessageAt'] != null
          ? _parseTs(data['lastMessageAt'])
          : null,
      resolvedAt:
          data['resolvedAt'] != null ? _parseTs(data['resolvedAt']) : null,
      resolvedBy: data['resolvedBy'] as String?,
      resolutionNotes: data['resolutionNotes'] as String?,
      isEscalated: (data['isEscalated'] as bool?) ?? false,
      escalationRemarks: data['escalationRemarks'] as String?,
      escalatedAt:
          data['escalatedAt'] != null ? _parseTs(data['escalatedAt']) : null,
      closedBy: data['closedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketNumber': ticketNumber,
      'subject': subject,
      'description': description,
      'category': category,
      'status': status,
      'submittedBy': submittedBy,
      'submittedByType': submittedByType,
      'submittedByName': submittedByName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolvedBy': resolvedBy,
      'resolutionNotes': resolutionNotes,
      'isEscalated': isEscalated,
      'escalationRemarks': escalationRemarks,
      'escalatedAt': escalatedAt?.toIso8601String(),
      'closedBy': closedBy,
    };
  }

  static DateTime _parseTs(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }
}

/// A single message in a support ticket thread.
class SupportTicketMessageModel {
  final String messageId;
  final String ticketId;
  final String body;
  final String senderId;
  final String senderType; // 'customer' | 'rider' | 'admin'
  final String senderName;
  final DateTime createdAt;

  const SupportTicketMessageModel({
    required this.messageId,
    required this.ticketId,
    required this.body,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.createdAt,
  });

  bool get isAdmin => senderType == 'admin';

  factory SupportTicketMessageModel.fromMap(
      String id, String ticketId, Map<String, dynamic> data) {
    return SupportTicketMessageModel(
      messageId: id,
      ticketId: ticketId,
      body: (data['body'] ?? '').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      senderType: (data['senderType'] ?? 'customer').toString(),
      senderName: (data['senderName'] ?? '').toString(),
      createdAt: SupportTicketModel._parseTs(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'body': body,
      'senderId': senderId,
      'senderType': senderType,
      'senderName': senderName,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
