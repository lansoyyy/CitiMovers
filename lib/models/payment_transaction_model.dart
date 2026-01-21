import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentTransactionModel {
  final String transactionId;
  final String bookingId;
  final String userId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? dragonpayTxnId;
  final String? description;
  final Map<String, dynamic>? metadata;

  PaymentTransactionModel({
    required this.transactionId,
    required this.bookingId,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.dragonpayTxnId,
    this.description,
    this.metadata,
  });

  factory PaymentTransactionModel.fromMap(Map<String, dynamic> map) {
    return PaymentTransactionModel(
      transactionId: (map['transactionId'] ?? '').toString(),
      bookingId: (map['bookingId'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] ?? 'PHP').toString(),
      paymentMethod: (map['paymentMethod'] ?? '').toString(),
      status: (map['status'] ?? 'pending').toString(),
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] is int)
              ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
              : DateTime.now(),
      completedAt: (map['completedAt'] is Timestamp)
          ? (map['completedAt'] as Timestamp).toDate()
          : (map['completedAt'] is int)
              ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
              : null,
      dragonpayTxnId: map['dragonpayTxnId'] as String?,
      description: map['description'] as String?,
      metadata: map['metadata'] is Map
          ? (map['metadata'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'bookingId': bookingId,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (dragonpayTxnId != null) 'dragonpayTxnId': dragonpayTxnId,
      if (description != null) 'description': description,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
