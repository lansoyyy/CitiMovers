import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Authentication service for CitiMovers
/// Handles user registration, login, and session management
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Current user (in-memory for now, will be replaced with Firebase)
  UserModel? _currentUser;
  
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber) async {
    try {
      // TODO: Implement Firebase phone authentication
      // For now, simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate success
      debugPrint('OTP sent to: $phoneNumber');
      return true;
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      return false;
    }
  }

  /// Verify OTP code
  Future<bool> verifyOTP(String phoneNumber, String otpCode) async {
    try {
      // TODO: Implement Firebase OTP verification
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate verification (accept any 6-digit code for now)
      if (otpCode.length == 6) {
        debugPrint('OTP verified for: $phoneNumber');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
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
      // TODO: Implement Firebase user creation
      await Future.delayed(const Duration(seconds: 2));
      
      final now = DateTime.now();
      final user = UserModel(
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        phoneNumber: phoneNumber,
        email: email,
        userType: 'customer',
        createdAt: now,
        updatedAt: now,
      );
      
      _currentUser = user;
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
      // TODO: Implement Firebase user login
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate fetching user from database
      final now = DateTime.now();
      final user = UserModel(
        userId: 'user_existing',
        name: 'John Doe',
        phoneNumber: phoneNumber,
        email: 'john@example.com',
        userType: 'customer',
        walletBalance: 500.0,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      );
      
      _currentUser = user;
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
      // TODO: Implement Firebase phone check
      await Future.delayed(const Duration(seconds: 1));
      
      // Simulate check (for demo, phone starting with +639 is registered)
      return phoneNumber.startsWith('+639');
    } catch (e) {
      debugPrint('Error checking phone: $e');
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _currentUser = null;
    debugPrint('User logged out');
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? photoUrl,
  }) async {
    try {
      if (_currentUser == null) return false;
      
      // TODO: Implement Firebase profile update
      await Future.delayed(const Duration(seconds: 1));
      
      _currentUser = _currentUser!.copyWith(
        name: name,
        email: email,
        photoUrl: photoUrl,
        updatedAt: DateTime.now(),
      );
      
      debugPrint('Profile updated');
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }
}
