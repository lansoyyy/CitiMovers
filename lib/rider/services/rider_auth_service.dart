import 'package:flutter/material.dart';
import '../../rider/models/rider_model.dart';

/// Authentication service for CitiMovers Riders
/// Handles rider registration, login, and session management
class RiderAuthService {
  static final RiderAuthService _instance = RiderAuthService._internal();
  factory RiderAuthService() => _instance;
  RiderAuthService._internal();

  // Current rider (in-memory for now, will be replaced with Firebase)
  RiderModel? _currentRider;

  RiderModel? get currentRider => _currentRider;
  bool get isLoggedIn => _currentRider != null;

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber) async {
    try {
      // TODO: Implement Firebase phone authentication
      // For now, simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // Simulate success
      debugPrint('OTP sent to rider: $phoneNumber');
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
        debugPrint('OTP verified for rider: $phoneNumber');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return false;
    }
  }

  /// Register new rider
  Future<RiderModel?> registerRider({
    required String name,
    required String phoneNumber,
    String? email,
    required String vehicleType,
    String? vehiclePlateNumber,
    String? vehicleModel,
    String? vehicleColor,
  }) async {
    try {
      // TODO: Implement Firebase rider creation
      await Future.delayed(const Duration(seconds: 2));

      final now = DateTime.now();
      final rider = RiderModel(
        riderId: 'rider_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        phoneNumber: phoneNumber,
        email: email,
        vehicleType: vehicleType,
        vehiclePlateNumber: vehiclePlateNumber,
        vehicleModel: vehicleModel,
        vehicleColor: vehicleColor,
        status: 'pending', // pending, approved, active, inactive
        isOnline: false,
        rating: 0.0,
        totalDeliveries: 0,
        totalEarnings: 0.0,
        createdAt: now,
        updatedAt: now,
      );

      _currentRider = rider;
      debugPrint('Rider registered: ${rider.name}');
      return rider;
    } catch (e) {
      debugPrint('Error registering rider: $e');
      return null;
    }
  }

  /// Login existing rider
  Future<RiderModel?> loginRider(String phoneNumber) async {
    try {
      // TODO: Implement Firebase rider login
      await Future.delayed(const Duration(seconds: 2));

      // Simulate fetching rider from database
      final now = DateTime.now();
      final rider = RiderModel(
        riderId: 'rider_existing',
        name: 'John Driver',
        phoneNumber: phoneNumber,
        email: 'john.driver@example.com',
        vehicleType: 'Motorcycle',
        vehiclePlateNumber: 'ABC 1234',
        status: 'active',
        isOnline: false,
        rating: 4.8,
        totalDeliveries: 150,
        totalEarnings: 25000.0,
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      );

      _currentRider = rider;
      debugPrint('Rider logged in: ${rider.name}');
      return rider;
    } catch (e) {
      debugPrint('Error logging in rider: $e');
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

  /// Logout rider
  Future<void> logout() async {
    _currentRider = null;
    debugPrint('Rider logged out');
  }

  /// Get current rider
  Future<RiderModel?> getCurrentRider() async {
    try {
      // TODO: Implement Firebase rider fetch
      // For now, return the in-memory rider
      await Future.delayed(const Duration(milliseconds: 500));
      return _currentRider;
    } catch (e) {
      debugPrint('Error getting current rider: $e');
      return null;
    }
  }

  /// Update rider profile
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? photoUrl,
    String? vehicleType,
    String? vehiclePlateNumber,
  }) async {
    try {
      if (_currentRider == null) return false;

      // TODO: Implement Firebase profile update
      await Future.delayed(const Duration(seconds: 1));

      _currentRider = _currentRider!.copyWith(
        name: name,
        email: email,
        photoUrl: photoUrl,
        vehicleType: vehicleType,
        vehiclePlateNumber: vehiclePlateNumber,
        updatedAt: DateTime.now(),
      );

      debugPrint('Rider profile updated');
      return true;
    } catch (e) {
      debugPrint('Error updating rider profile: $e');
      return false;
    }
  }

  /// Toggle rider online status
  Future<bool> toggleOnlineStatus() async {
    try {
      if (_currentRider == null) return false;

      // TODO: Implement Firebase status update
      await Future.delayed(const Duration(milliseconds: 500));

      _currentRider = _currentRider!.copyWith(
        isOnline: !_currentRider!.isOnline,
        updatedAt: DateTime.now(),
      );

      debugPrint('Rider online status: ${_currentRider!.isOnline}');
      return true;
    } catch (e) {
      debugPrint('Error toggling online status: $e');
      return false;
    }
  }

  /// Update rider location
  Future<bool> updateLocation(double latitude, double longitude) async {
    try {
      if (_currentRider == null) return false;

      // TODO: Implement Firebase location update
      await Future.delayed(const Duration(milliseconds: 200));

      _currentRider = _currentRider!.copyWith(
        currentLatitude: latitude,
        currentLongitude: longitude,
        updatedAt: DateTime.now(),
      );

      debugPrint('Rider location updated: $latitude, $longitude');
      return true;
    } catch (e) {
      debugPrint('Error updating location: $e');
      return false;
    }
  }

  /// Request account deletion
  Future<bool> requestAccountDeletion() async {
    try {
      // TODO: Implement account deletion request
      await Future.delayed(const Duration(seconds: 1));

      debugPrint('Rider account deletion requested');
      return true;
    } catch (e) {
      debugPrint('Error requesting account deletion: $e');
      return false;
    }
  }
}
