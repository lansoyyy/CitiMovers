import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import '../models/user_model.dart';
import 'otp_service.dart';

/// Authentication service for CitiMovers
/// Handles user registration, login, and session management
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _loadUserFromStorage();
  }

  final GetStorage _storage = GetStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user (in-memory for now, will be replaced with Firebase)
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn {
    if (_currentUser != null) return true;
    final userId = _storage.read('userId') as String?;
    final phoneNumber = _storage.read('userPhoneNumber') as String?;
    return userId != null &&
        userId.isNotEmpty &&
        phoneNumber != null &&
        phoneNumber.isNotEmpty;
  }

  String _toIsoString(dynamic value, DateTime fallback) {
    if (value is String && value.isNotEmpty) return value;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    return fallback.toIso8601String();
  }

  String _normalizePhoneNumber(String phoneNumber) {
    String normalizedPhoneNumber = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');

    if (!normalizedPhoneNumber.startsWith('+')) {
      if (normalizedPhoneNumber.startsWith('0')) {
        normalizedPhoneNumber = normalizedPhoneNumber.substring(1);
      }
      normalizedPhoneNumber = '+63$normalizedPhoneNumber';
    }

    return normalizedPhoneNumber;
  }

  List<String> _phoneNumberVariants(String phoneNumber) {
    final raw = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');
    final normalized = _normalizePhoneNumber(phoneNumber);
    if (raw == normalized) return [normalized];
    return [raw, normalized];
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _findUserByPhone(
    String phoneNumber,
  ) {
    final variants = _phoneNumberVariants(phoneNumber);

    final query = variants.length == 1
        ? _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: variants.first)
        : _firestore
            .collection('users')
            .where('phoneNumber', whereIn: variants);

    return query.limit(1).get();
  }

  DocumentReference<Map<String, dynamic>> _userDocByPhone(
    String phoneNumber,
  ) {
    final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
    return _firestore.collection('users').doc(normalizedPhoneNumber);
  }

  void _loadUserFromStorage() {
    try {
      final userId = _storage.read('userId') as String?;
      final phoneNumber = _storage.read('userPhoneNumber') as String?;

      if (userId != null &&
          userId.isNotEmpty &&
          phoneNumber != null &&
          phoneNumber.isNotEmpty) {
        return;
      }

      final legacyPhone = phoneNumber;
      if ((userId == null || userId.isEmpty) &&
          legacyPhone != null &&
          legacyPhone.isNotEmpty) {
        final normalized = _normalizePhoneNumber(legacyPhone);
        _storage.write('userId', normalized);
        _storage.write('userPhoneNumber', normalized);
      }
    } catch (e) {
      debugPrint('Error loading user from storage: $e');
    }
  }

  Future<void> _saveUserToStorage(UserModel user) async {
    await _storage.write('userId', user.userId);
    await _storage.write('userPhoneNumber', user.phoneNumber);
  }

  Future<void> _clearUserFromStorage() async {
    await _storage.remove('userId');
    await _storage.remove('userPhoneNumber');

    await _storage.remove('userName');
    await _storage.remove('userEmail');
    await _storage.remove('userCreatedAt');
    await _storage.remove('userUpdatedAt');
    await _storage.remove('userWalletBalance');
    await _storage.remove('userFavoriteLocations');
  }

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber) async {
    try {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
      final success = await OtpService.sendOtp(normalizedPhoneNumber);
      if (success) {
        debugPrint('OTP sent to: $normalizedPhoneNumber');
      }
      return success;
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      return false;
    }
  }

  /// Verify OTP code
  Future<bool> verifyOTP(String phoneNumber, String otpCode) async {
    try {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
      final success =
          await OtpService.verifyOtp(normalizedPhoneNumber, otpCode);
      if (success) {
        debugPrint('OTP verified for: $normalizedPhoneNumber');
      }
      return success;
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return false;
    }
  }

  /// Send email verification code
  Future<bool> sendEmailVerificationCode(String email) async {
    try {
      // TODO: Implement Firebase email verification
      // For now, simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // Simulate success
      debugPrint('Email verification code sent to: $email');
      return true;
    } catch (e) {
      debugPrint('Error sending email verification code: $e');
      return false;
    }
  }

  /// Verify email code
  Future<bool> verifyEmailCode(String email, String code) async {
    try {
      // TODO: Implement Firebase email code verification
      await Future.delayed(const Duration(seconds: 2));

      // Simulate verification (accept any 6-digit code for now)
      if (code.length == 6) {
        debugPrint('Email code verified for: $email');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying email code: $e');
      return false;
    }
  }

  /// Register new user
  Future<UserModel?> registerUser({
    required String name,
    required String phoneNumber,
    String? email,
  }) async {
    try {
      final now = DateTime.now();

      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);

      final userDocRef = _userDocByPhone(normalizedPhoneNumber);
      final userDoc = await userDocRef.get();

      Map<String, dynamic>? existingData;
      if (userDoc.exists) {
        existingData = userDoc.data();
      } else {
        final existingSnapshot = await _findUserByPhone(normalizedPhoneNumber);
        if (existingSnapshot.docs.isNotEmpty) {
          existingData = existingSnapshot.docs.first.data();
        }
      }

      final createdAtIso = _toIsoString(existingData?['createdAt'], now);

      final user = UserModel(
        userId: normalizedPhoneNumber,
        name: name,
        phoneNumber: normalizedPhoneNumber,
        email: email,
        userType: (existingData?['userType'] ?? 'customer').toString(),
        walletBalance: switch (existingData?['walletBalance']) {
          num v => v.toDouble(),
          String v => double.tryParse(v) ?? 0.0,
          _ => 0.0,
        },
        favoriteLocations: (existingData?['favoriteLocations'] is List)
            ? List<String>.from(existingData?['favoriteLocations'] as List)
            : const [],
        createdAt: DateTime.tryParse(createdAtIso) ?? now,
        updatedAt: now,
      );

      await userDocRef.set(
        {
          ...?existingData,
          ...user.toMap(),
          'userId': normalizedPhoneNumber,
          'phoneNumber': normalizedPhoneNumber,
          'updatedAt': now.toIso8601String(),
          'createdAt': createdAtIso,
        },
        SetOptions(merge: true),
      );

      _currentUser = user;
      await _saveUserToStorage(user);
      debugPrint('User registered: ${user.name}');
      return user;
    } catch (e) {
      debugPrint('Error registering user: $e');
      return null;
    }
  }

  /// Login existing user
  Future<UserModel?> loginUser(String phoneNumber) async {
    try {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
      final now = DateTime.now();

      final userDocRef = _userDocByPhone(normalizedPhoneNumber);
      final docSnap = await userDocRef.get();

      Map<String, dynamic>? data;
      if (docSnap.exists) {
        data = docSnap.data();
      } else {
        final snapshot = await _findUserByPhone(normalizedPhoneNumber);
        if (snapshot.docs.isEmpty) return null;
        data = Map<String, dynamic>.from(snapshot.docs.first.data());
      }

      data ??= <String, dynamic>{};
      data['userId'] = normalizedPhoneNumber;
      data['phoneNumber'] = normalizedPhoneNumber;
      data['createdAt'] = _toIsoString(data['createdAt'], now);
      data['updatedAt'] = _toIsoString(data['updatedAt'], now);

      await userDocRef.set(
        {
          ...data,
          'userId': normalizedPhoneNumber,
          'phoneNumber': normalizedPhoneNumber,
          'updatedAt': now.toIso8601String(),
        },
        SetOptions(merge: true),
      );

      final user = UserModel.fromMap(data);

      _currentUser = user;
      await _saveUserToStorage(user);
      debugPrint('User logged in: ${user.name}');
      return user;
    } catch (e) {
      debugPrint('Error logging in: $e');
      return null;
    }
  }

  /// Check if phone number is registered
  Future<bool> isPhoneRegistered(String phoneNumber) async {
    try {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);

      final doc = await _userDocByPhone(normalizedPhoneNumber).get();
      if (doc.exists) return true;

      final snapshot = await _findUserByPhone(normalizedPhoneNumber);
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking phone: $e');
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _currentUser = null;
    await _clearUserFromStorage();
    debugPrint('User logged out');
  }

  /// Get current user
  Future<UserModel?> getCurrentUser() async {
    try {
      if (_currentUser != null) return _currentUser;

      _loadUserFromStorage();
      if (_currentUser != null) return _currentUser;

      final storedPhoneNumber = _storage.read('userPhoneNumber') as String?;
      if (storedPhoneNumber == null || storedPhoneNumber.isEmpty) {
        return null;
      }

      return await loginUser(storedPhoneNumber);
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    try {
      if (_currentUser == null) return false;

      final normalizedPhone = phoneNumber != null
          ? _normalizePhoneNumber(phoneNumber)
          : _currentUser!.phoneNumber;

      final updatedUser = _currentUser!.copyWith(
        name: name,
        phoneNumber: normalizedPhone,
        photoUrl: photoUrl,
        updatedAt: DateTime.now(),
      );

      if (phoneNumber != null && phoneNumber != _currentUser!.phoneNumber) {
        await _firestore.collection('users').doc(_currentUser!.userId).delete();

        await _firestore
            .collection('users')
            .doc(normalizedPhone)
            .set(updatedUser.toMap(), SetOptions(merge: true));

        await _saveUserToStorage(updatedUser);
      } else {
        await _firestore
            .collection('users')
            .doc(updatedUser.userId)
            .set(updatedUser.toMap(), SetOptions(merge: true));
      }

      _currentUser = updatedUser;
      await _saveUserToStorage(updatedUser);
      debugPrint('Profile updated');
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // TODO: Implement Firebase password change
      await Future.delayed(const Duration(seconds: 1));

      debugPrint('Password changed successfully');
      return true;
    } catch (e) {
      debugPrint('Error changing password: $e');
      return false;
    }
  }

  /// Request account deletion
  Future<bool> requestAccountDeletion() async {
    try {
      // TODO: Implement account deletion request
      await Future.delayed(const Duration(seconds: 1));

      debugPrint('Account deletion requested');
      return true;
    } catch (e) {
      debugPrint('Error requesting account deletion: $e');
      return false;
    }
  }
}
