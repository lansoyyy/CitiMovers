import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WalletTransaction {
  final String id;
  final String userId;
  final String type; // 'top_up', 'payment', 'refund', 'earning'
  final double amount;
  final double previousBalance;
  final double newBalance;
  final String description;
  final String? referenceId; // booking ID, payment ID, etc.
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.previousBalance,
    required this.newBalance,
    required this.description,
    this.referenceId,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      previousBalance: (map['previousBalance'] as num?)?.toDouble() ?? 0.0,
      newBalance: (map['newBalance'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] ?? '',
      referenceId: map['referenceId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'amount': amount,
      'previousBalance': previousBalance,
      'newBalance': newBalance,
      'description': description,
      'referenceId': referenceId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get wallet transactions for a user
  Stream<List<WalletTransaction>> getWalletTransactions(String userId) {
    return _firestore
        .collection('wallet_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransaction.fromMap(doc.data()))
            .toList());
  }

  /// Add funds to user wallet
  Future<bool> topUpWallet({
    required String userId,
    required double amount,
    required String description,
    String? referenceId,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      final userSnapshot = await userDoc.get();

      if (!userSnapshot.exists) {
        return false;
      }

      final userData = userSnapshot.data()!;
      final currentBalance =
          (userData['walletBalance'] as num?)?.toDouble() ?? 0.0;
      final newBalance = currentBalance + amount;

      // Create transaction record
      final walletTransaction = WalletTransaction(
        id: _firestore.collection('wallet_transactions').doc().id,
        userId: userId,
        type: 'top_up',
        amount: amount,
        previousBalance: currentBalance,
        newBalance: newBalance,
        description: description,
        referenceId: referenceId,
        createdAt: DateTime.now(),
      );

      // Run transaction to ensure atomicity
      await _firestore.runTransaction((firestoreTransaction) async {
        // Update user wallet balance
        firestoreTransaction.update(userDoc, {
          'walletBalance': newBalance,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // Add transaction record
        firestoreTransaction.set(
          _firestore
              .collection('wallet_transactions')
              .doc(walletTransaction.id),
          walletTransaction.toMap(),
        );
      });

      return true;
    } catch (e) {
      debugPrint('WalletService: Error topping up wallet: $e');
      return false;
    }
  }

  /// Deduct funds from user wallet (for payments)
  Future<bool> deductFromWallet({
    required String userId,
    required double amount,
    required String description,
    String? referenceId,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      final userSnapshot = await userDoc.get();

      if (!userSnapshot.exists) {
        return false;
      }

      final userData = userSnapshot.data()!;
      final currentBalance =
          (userData['walletBalance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < amount) {
        return false; // Insufficient funds
      }

      final newBalance = currentBalance - amount;

      // Create transaction record
      final walletTransaction = WalletTransaction(
        id: _firestore.collection('wallet_transactions').doc().id,
        userId: userId,
        type: 'payment',
        amount: -amount, // Negative for deduction
        previousBalance: currentBalance,
        newBalance: newBalance,
        description: description,
        referenceId: referenceId,
        createdAt: DateTime.now(),
      );

      // Run transaction to ensure atomicity
      await _firestore.runTransaction((firestoreTransaction) async {
        // Update user wallet balance
        firestoreTransaction.update(userDoc, {
          'walletBalance': newBalance,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // Add transaction record
        firestoreTransaction.set(
          _firestore
              .collection('wallet_transactions')
              .doc(walletTransaction.id),
          walletTransaction.toMap(),
        );
      });

      return true;
    } catch (e) {
      debugPrint('WalletService: Error deducting from wallet: $e');
      return false;
    }
  }

  /// Add earnings to rider wallet
  Future<bool> addEarnings({
    required String riderId,
    required double amount,
    required String description,
    String? referenceId,
  }) async {
    try {
      final riderDoc = _firestore.collection('riders').doc(riderId);
      final riderSnapshot = await riderDoc.get();

      if (!riderSnapshot.exists) {
        return false;
      }

      final riderData = riderSnapshot.data()!;
      final currentEarnings =
          (riderData['totalEarnings'] as num?)?.toDouble() ?? 0.0;
      final newEarnings = currentEarnings + amount;

      // Create transaction record
      final walletTransaction = WalletTransaction(
        id: _firestore.collection('wallet_transactions').doc().id,
        userId: riderId,
        type: 'earning',
        amount: amount,
        previousBalance: currentEarnings,
        newBalance: newEarnings,
        description: description,
        referenceId: referenceId,
        createdAt: DateTime.now(),
      );

      // Run transaction to ensure atomicity
      await _firestore.runTransaction((firestoreTransaction) async {
        // Update rider total earnings
        firestoreTransaction.update(riderDoc, {
          'totalEarnings': newEarnings,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // Add transaction record
        firestoreTransaction.set(
          _firestore
              .collection('wallet_transactions')
              .doc(walletTransaction.id),
          walletTransaction.toMap(),
        );
      });

      return true;
    } catch (e) {
      debugPrint('WalletService: Error adding earnings: $e');
      return false;
    }
  }

  /// Get current wallet balance for a user
  Future<double> getWalletBalance(String userId) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      final userSnapshot = await userDoc.get();

      if (!userSnapshot.exists) {
        return 0.0;
      }

      final userData = userSnapshot.data()!;
      return (userData['walletBalance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('WalletService: Error getting wallet balance: $e');
      return 0.0;
    }
  }

  /// Get total earnings for a rider
  Future<double> getRiderEarnings(String riderId) async {
    try {
      final riderDoc = _firestore.collection('riders').doc(riderId);
      final riderSnapshot = await riderDoc.get();

      if (!riderSnapshot.exists) {
        return 0.0;
      }

      final riderData = riderSnapshot.data()!;
      return (riderData['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('WalletService: Error getting rider earnings: $e');
      return 0.0;
    }
  }
}
