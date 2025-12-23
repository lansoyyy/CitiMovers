import 'package:cloud_firestore/cloud_firestore.dart';

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

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
