import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/integrations_config.dart';
import '../models/payment_transaction_model.dart';
import 'dragonpay_service.dart';
import 'dragonpay_status_service.dart';

class PaymentMethod {
  final String id;
  final String userId;
  final String type; // 'bank', 'gcash', 'paymaya'
  final String name;
  final String accountNumber;
  final String accountName;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PaymentMethod({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    required this.accountNumber,
    required this.accountName,
    required this.isDefault,
    required this.createdAt,
    this.updatedAt,
  });

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      name: map['name'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      accountName: map['accountName'] ?? '',
      isDefault: map['isDefault'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'name': name,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.delete(),
    };
  }
}

class DragonpayInitiationResult {
  final PaymentTransactionModel transaction;
  final String paymentUrl;

  DragonpayInitiationResult({
    required this.transaction,
    required this.paymentUrl,
  });
}

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Set<String> _finalStatuses = <String>{
    'success',
    'failed',
    'cancelled',
    'refunded',
    'chargeback',
    'voided',
  };

  static bool _isFinal(String status) => _finalStatuses.contains(status);

  Future<PaymentTransactionModel?> getActiveTransactionForBooking(
    String bookingId,
  ) async {
    try {
      final snap = await _firestore
          .collection('payment_transactions')
          .where('bookingId', isEqualTo: bookingId)
          .where('status', whereIn: ['pending', 'in_progress'])
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return PaymentTransactionModel.fromMap(snap.docs.first.data());
    } catch (_) {
      return null;
    }
  }

  Future<String?> getStoredPaymentUrl(String transactionId) async {
    try {
      final docRef =
          _firestore.collection('payment_transactions').doc(transactionId);
      final snap = await docRef.get();
      final data = snap.data();
      final metadata = data?['metadata'];
      if (metadata is Map) {
        final url = metadata['paymentUrl'];
        if (url is String && url.isNotEmpty) return url;
      }

      // Fallback: regenerate paymentUrl from stored transaction data
      if (data == null) return null;
      final amount = (data['amount'] as num?)?.toDouble();
      final currency =
          (data['currency'] as String?) ?? IntegrationsConfig.dragonpayCurrency;
      final description = (data['description'] as String?) ?? '';
      String? customerEmail;
      if (metadata is Map) {
        final value = metadata['customerEmail'];
        if (value is String && value.isNotEmpty) {
          customerEmail = value;
        }
      }

      if (amount == null || description.isEmpty || customerEmail == null) {
        return null;
      }

      final regenerated = DragonpayService.instance.createPaymentUrl(
        txnId: transactionId,
        amount: amount,
        description: description,
        customerEmail: customerEmail,
        currency: currency,
      );

      await docRef.set(
        {
          'metadata': {
            'paymentUrl': regenerated,
          },
        },
        SetOptions(merge: true),
      );

      return regenerated;
    } catch (_) {
      return null;
    }
  }

  Future<DragonpayInitiationResult?> initiateOrResumeDragonpayBookingPayment({
    required String bookingId,
    required String userId,
    required double amount,
    required String description,
    required String customerEmail,
    required String paymentMethod,
  }) async {
    final active = await getActiveTransactionForBooking(bookingId);
    if (active != null) {
      final url = await getStoredPaymentUrl(active.transactionId);
      if (url != null && url.isNotEmpty) {
        return DragonpayInitiationResult(transaction: active, paymentUrl: url);
      }
    }

    return initiateDragonpayBookingPayment(
      bookingId: bookingId,
      userId: userId,
      amount: amount,
      description: description,
      customerEmail: customerEmail,
      paymentMethod: paymentMethod,
    );
  }

  Future<DragonpayInitiationResult?> initiateDragonpayBookingPayment({
    required String bookingId,
    required String userId,
    required double amount,
    required String description,
    required String customerEmail,
    required String paymentMethod,
  }) async {
    try {
      if (bookingId.isNotEmpty) {
        final bookingSnap =
            await _firestore.collection('bookings').doc(bookingId).get();
        final bookingData = bookingSnap.data();
        final status = (bookingData?['status'] ?? '').toString();
        if (status == 'cancelled' || status == 'completed') {
          return null;
        }
      }

      final active = await getActiveTransactionForBooking(bookingId);
      if (active != null) {
        final url = await getStoredPaymentUrl(active.transactionId);
        if (url != null && url.isNotEmpty) {
          return DragonpayInitiationResult(
              transaction: active, paymentUrl: url);
        }
      }

      final docRef = _firestore.collection('payment_transactions').doc();
      final transactionId = docRef.id;

      final txn = PaymentTransactionModel(
        transactionId: transactionId,
        bookingId: bookingId,
        userId: userId,
        amount: amount,
        currency: IntegrationsConfig.dragonpayCurrency,
        paymentMethod: paymentMethod,
        status: 'pending',
        createdAt: DateTime.now(),
        description: description,
        metadata: {
          'gateway': 'dragonpay',
          'customerEmail': customerEmail,
        },
      );

      await docRef.set(txn.toMap());

      // Lock booking and persist expected payment snapshot
      if (bookingId.isNotEmpty) {
        await _firestore.collection('bookings').doc(bookingId).set(
          {
            'paymentStatus': 'pending',
            'paymentTransactionId': transactionId,
            'paymentLocked': true,
            'paymentLockedAt': Timestamp.now(),
            'paymentExpectedAmount': amount,
            'paymentCurrency': IntegrationsConfig.dragonpayCurrency,
          },
          SetOptions(merge: true),
        );
      }

      final paymentUrl = DragonpayService.instance.createPaymentUrl(
        txnId: transactionId,
        amount: amount,
        description: description,
        customerEmail: customerEmail,
      );

      await docRef.update({
        'metadata.paymentUrl': paymentUrl,
      });

      return DragonpayInitiationResult(
        transaction: txn,
        paymentUrl: paymentUrl,
      );
    } catch (e) {
      return null;
    }
  }

  String _mapDragonpayStatusToLocal(String? dpStatus) {
    switch (dpStatus) {
      case 'S':
        return 'success';
      case 'F':
        return 'failed';
      case 'P':
        return 'pending';
      case 'R':
        return 'refunded';
      case 'K':
        return 'chargeback';
      case 'V':
        return 'voided';
      case 'A':
        return 'authorized';
      case 'G':
        return 'in_progress';
      case 'U':
      default:
        return 'unknown';
    }
  }

  Future<PaymentTransactionModel?> refreshDragonpayTransactionStatus({
    required String transactionId,
  }) async {
    try {
      final docRef =
          _firestore.collection('payment_transactions').doc(transactionId);
      final snap = await docRef.get();
      final data = snap.data();
      if (data == null) return null;

      final current = PaymentTransactionModel.fromMap(data);
      if (_isFinal(current.status)) return current;

      final statusResult =
          await DragonpayStatusService.instance.getStatus(txnId: transactionId);
      if (statusResult == null) return current;

      final newStatus = _mapDragonpayStatusToLocal(statusResult.status);

      final expectedAmount = current.amount;
      final expectedCurrency = current.currency;
      final returnedAmount = statusResult.amount;
      final returnedCurrency = statusResult.currency;
      final amountMismatch = returnedAmount != null &&
          (returnedAmount - expectedAmount).abs() > 0.009;
      final currencyMismatch = returnedCurrency != null &&
          returnedCurrency.toUpperCase() != expectedCurrency.toUpperCase();

      await _firestore.runTransaction((tx) async {
        final latestSnap = await tx.get(docRef);
        final latestData = latestSnap.data();
        if (latestData == null) return;
        final latest = PaymentTransactionModel.fromMap(latestData);
        if (_isFinal(latest.status)) return;

        final update = <String, dynamic>{
          'status': amountMismatch || currencyMismatch ? 'failed' : newStatus,
          'updatedAt': Timestamp.now(),
          'metadata.lastCheckedAt': Timestamp.now(),
          'metadata.dpStatus': statusResult.status,
          'metadata.dpRefNo': statusResult.refNo,
          'metadata.dpProcId': statusResult.procId,
          'metadata.dpProcMsg': statusResult.procMsg,
          if (returnedAmount != null) 'metadata.dpAmount': returnedAmount,
          if (returnedCurrency != null) 'metadata.dpCurrency': returnedCurrency,
          if (amountMismatch) 'metadata.amountMismatch': true,
          if (currencyMismatch) 'metadata.currencyMismatch': true,
        };

        final finalStatus = update['status'] as String;
        if (_isFinal(finalStatus)) {
          update['completedAt'] = Timestamp.now();
        }

        tx.update(docRef, update);

        final bookingId = latest.bookingId;
        if (bookingId.isEmpty) return;

        final bookingRef = _firestore.collection('bookings').doc(bookingId);

        if (finalStatus == 'success') {
          tx.set(
            bookingRef,
            {
              'paymentStatus': 'paid',
              'paymentTransactionId': transactionId,
              'paidAt': Timestamp.now(),
              'paymentLocked': false,
              'status': 'pending',
            },
            SetOptions(merge: true),
          );
        } else if (_isFinal(finalStatus)) {
          tx.set(
            bookingRef,
            {
              'paymentStatus': finalStatus,
              'paymentLocked': false,
              'paymentTransactionId': transactionId,
            },
            SetOptions(merge: true),
          );
        }
      });

      final updated = await docRef.get();
      final updatedData = updated.data();
      if (updatedData == null) return null;
      return PaymentTransactionModel.fromMap(updatedData);
    } catch (_) {
      return null;
    }
  }

  Future<void> reconcilePendingTransactionsForUser(String userId) async {
    try {
      final snap = await _firestore
          .collection('payment_transactions')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['pending', 'in_progress', 'unknown'])
          .limit(10)
          .get();

      for (final doc in snap.docs) {
        final transactionId = (doc.data()['transactionId'] ?? '').toString();
        if (transactionId.isEmpty) continue;
        await refreshDragonpayTransactionStatus(transactionId: transactionId);
      }
    } catch (_) {
      return;
    }
  }

  /// Get payment methods for a user (customer or rider)
  Stream<List<PaymentMethod>> getPaymentMethods(String userId) {
    return _firestore
        .collection('payment_methods')
        .where('userId', isEqualTo: userId)
        .orderBy('isDefault', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentMethod.fromMap(doc.data()))
            .toList());
  }

  /// Add a new payment method
  Future<bool> addPaymentMethod({
    required String userId,
    required String type,
    required String name,
    required String accountNumber,
    required String accountName,
    bool isDefault = false,
  }) async {
    try {
      // If setting as default, unset other default methods
      if (isDefault) {
        await _unsetDefaultPaymentMethods(userId);
      }

      final paymentMethod = PaymentMethod(
        id: _firestore.collection('payment_methods').doc().id,
        userId: userId,
        type: type,
        name: name,
        accountNumber: accountNumber,
        accountName: accountName,
        isDefault: isDefault,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('payment_methods')
          .doc(paymentMethod.id)
          .set(paymentMethod.toMap());

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update payment method
  Future<bool> updatePaymentMethod({
    required String id,
    String? name,
    String? accountNumber,
    String? accountName,
    bool? isDefault,
  }) async {
    try {
      final docRef = _firestore.collection('payment_methods').doc(id);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        return false;
      }

      final currentData = docSnapshot.data()!;
      final userId = currentData['userId'] as String;

      // If setting as default, unset other default methods
      if (isDefault == true) {
        await _unsetDefaultPaymentMethods(userId);
      }

      final updateData = <String, dynamic>{
        'updatedAt': DateTime.now(),
      };

      if (name != null) updateData['name'] = name;
      if (accountNumber != null) updateData['accountNumber'] = accountNumber;
      if (accountName != null) updateData['accountName'] = accountName;
      if (isDefault != null) updateData['isDefault'] = isDefault;

      await docRef.update(updateData);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Set payment method as default
  Future<bool> setDefaultPaymentMethod(String id) async {
    try {
      final docRef = _firestore.collection('payment_methods').doc(id);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        return false;
      }

      final currentData = docSnapshot.data()!;
      final userId = currentData['userId'] as String;

      // Unset other default methods
      await _unsetDefaultPaymentMethods(userId);

      // Set this as default
      await docRef.update({
        'isDefault': true,
        'updatedAt': DateTime.now(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete payment method
  Future<bool> deletePaymentMethod(String id) async {
    try {
      final docRef = _firestore.collection('payment_methods').doc(id);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        return false;
      }

      final currentData = docSnapshot.data()!;
      final isDefault = currentData['isDefault'] as bool;

      // Don't allow deletion of default payment method if there are other methods
      if (isDefault) {
        final otherMethods = await _firestore
            .collection('payment_methods')
            .where('userId', isEqualTo: currentData['userId'])
            .where('id', isNotEqualTo: id)
            .get();

        if (otherMethods.docs.isNotEmpty) {
          return false; // Cannot delete default if other methods exist
        }
      }

      await docRef.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get default payment method for a user
  Future<PaymentMethod?> getDefaultPaymentMethod(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('payment_methods')
          .where('userId', isEqualTo: userId)
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return PaymentMethod.fromMap(snapshot.docs.first.data());
    } catch (e) {
      return null;
    }
  }

  /// Unset all default payment methods for a user
  Future<void> _unsetDefaultPaymentMethods(String userId) async {
    final snapshot = await _firestore
        .collection('payment_methods')
        .where('userId', isEqualTo: userId)
        .where('isDefault', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isDefault': false,
        'updatedAt': DateTime.now(),
      });
    }

    await batch.commit();
  }
}
