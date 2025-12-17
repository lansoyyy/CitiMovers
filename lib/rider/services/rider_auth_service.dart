import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import '../../services/otp_service.dart';
import '../models/rider_model.dart';

/// Authentication service for CitiMovers Riders
/// Handles rider registration, login, and session management
class RiderAuthService {
  static final RiderAuthService _instance = RiderAuthService._internal();
  factory RiderAuthService() => _instance;
  RiderAuthService._internal() {
    _loadRiderFromStorage();
  }

  final GetStorage _storage = GetStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  // Current rider (in-memory for now, will be replaced with Firebase)
  RiderModel? _currentRider;

  RiderModel? get currentRider => _currentRider;
  bool get isLoggedIn => _currentRider != null;

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

  Future<QuerySnapshot<Map<String, dynamic>>> _findRiderByPhone(
    String phoneNumber,
  ) {
    final variants = _phoneNumberVariants(phoneNumber);

    final query = variants.length == 1
        ? _firestore
            .collection('riders')
            .where('phoneNumber', isEqualTo: variants.first)
        : _firestore
            .collection('riders')
            .where('phoneNumber', whereIn: variants);

    return query.limit(1).get();
  }

  void _loadRiderFromStorage() {
    try {
      final stored = _storage.read('riderData');
      if (stored is Map) {
        final data = Map<String, dynamic>.from(stored);
        _currentRider = RiderModel.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error loading rider from storage: $e');
    }
  }

  Future<void> _saveRiderToStorage(RiderModel rider) async {
    await _storage.write('riderData', rider.toJson());
  }

  Future<void> _clearRiderFromStorage() async {
    await _storage.remove('riderData');
  }

  static const Map<String, String> _documentNameToKey = {
    "Driver's License": 'drivers_license',
    'Vehicle Registration (OR/CR)': 'vehicle_registration',
    'NBI Clearance': 'nbi_clearance',
    'Insurance': 'insurance',
  };

  static const Set<String> _requiredDocumentKeys = {
    'drivers_license',
    'vehicle_registration',
    'nbi_clearance',
  };

  Future<Map<String, dynamic>> _uploadRiderDocuments({
    required String riderId,
    required Map<String, String?> documentImagePaths,
  }) async {
    final now = DateTime.now();
    final documents = <String, dynamic>{};

    for (final entry in documentImagePaths.entries) {
      final documentName = entry.key;
      final path = entry.value;
      if (path == null || path.isEmpty) continue;

      final documentKey = _documentNameToKey[documentName] ??
          documentName
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'^_+|_+$'), '');

      try {
        final file = File(path);
        final ext = file.path.split('.').last.toLowerCase();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final objectName = '${documentKey}_$timestamp.$ext';

        final ref = _firebaseStorage
            .ref()
            .child('rider_documents')
            .child(riderId)
            .child(objectName);

        final uploadTask = await ref.putFile(file);
        final url = await uploadTask.ref.getDownloadURL();

        documents[documentKey] = {
          'name': documentName,
          'url': url,
          'status': 'pending',
          'uploadedAt': now.toIso8601String(),
        };
      } catch (e) {
        if (_requiredDocumentKeys.contains(documentKey)) {
          rethrow;
        }
      }
    }

    return documents;
  }

  Future<bool> uploadRiderDocuments(
      Map<String, String?> documentImagePaths) async {
    try {
      final rider = _currentRider;
      if (rider == null) return false;

      if (documentImagePaths.isEmpty) return true;

      final uploaded = await _uploadRiderDocuments(
        riderId: rider.riderId,
        documentImagePaths: documentImagePaths,
      );

      if (uploaded.isEmpty) return true;

      final docRef = _firestore.collection('riders').doc(rider.riderId);
      final snap = await docRef.get();
      final existing = (snap.data()?['documents'] as Map?)
              ?.map((key, value) => MapEntry(key.toString(), value)) ??
          <String, dynamic>{};

      final mergedDocuments = <String, dynamic>{
        ...existing,
        ...uploaded,
      };

      await docRef.set(
        {
          'documents': mergedDocuments,
          'documentsUpdatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );

      return true;
    } catch (e) {
      debugPrint('Error uploading rider documents: $e');
      return false;
    }
  }

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber) async {
    try {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
      final success = await OtpService.sendOtp(normalizedPhoneNumber);
      if (success) {
        debugPrint('OTP sent to rider: $normalizedPhoneNumber');
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
        debugPrint('OTP verified for rider: $normalizedPhoneNumber');
      }
      return success;
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
    Map<String, String?>? documentImagePaths,
  }) async {
    try {
      final now = DateTime.now();
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);

      final existingSnapshot = await _findRiderByPhone(normalizedPhoneNumber);
      if (existingSnapshot.docs.isNotEmpty) {
        final doc = existingSnapshot.docs.first;
        final data = Map<String, dynamic>.from(doc.data());
        data['riderId'] = doc.id;

        final rider = RiderModel.fromJson({
          ...data,
          'riderId': doc.id,
          'name': name,
          'phoneNumber': normalizedPhoneNumber,
          'email': email,
          'vehicleType': vehicleType,
          'vehiclePlateNumber': vehiclePlateNumber,
          'vehicleModel': vehicleModel,
          'vehicleColor': vehicleColor,
          'updatedAt': now.toIso8601String(),
        });

        await doc.reference.set(rider.toJson(), SetOptions(merge: true));

        if (documentImagePaths != null && documentImagePaths.isNotEmpty) {
          final docs = await _uploadRiderDocuments(
            riderId: doc.id,
            documentImagePaths: documentImagePaths,
          );

          final existingDocuments = (data['documents'] as Map?)
                  ?.map((key, value) => MapEntry(key.toString(), value)) ??
              <String, dynamic>{};

          final mergedDocuments = <String, dynamic>{
            ...existingDocuments,
            ...docs,
          };

          await doc.reference.set(
            {
              'documents': mergedDocuments,
              'documentsUpdatedAt': now.toIso8601String(),
            },
            SetOptions(merge: true),
          );
        }

        _currentRider = rider;
        await _saveRiderToStorage(rider);
        debugPrint('Rider registered: ${rider.name}');
        return rider;
      }

      final docRef = _firestore.collection('riders').doc();
      final rider = RiderModel(
        riderId: docRef.id,
        name: name,
        phoneNumber: normalizedPhoneNumber,
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

      await docRef.set(rider.toJson());

      if (documentImagePaths != null && documentImagePaths.isNotEmpty) {
        final docs = await _uploadRiderDocuments(
          riderId: docRef.id,
          documentImagePaths: documentImagePaths,
        );

        await docRef.set(
          {
            'documents': docs,
            'documentsUpdatedAt': now.toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }

      _currentRider = rider;
      await _saveRiderToStorage(rider);
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
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
      final snapshot = await _findRiderByPhone(normalizedPhoneNumber);

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = Map<String, dynamic>.from(doc.data());
      data['riderId'] = doc.id;

      final rider = RiderModel.fromJson(data);

      _currentRider = rider;
      await _saveRiderToStorage(rider);
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
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
      final snapshot = await _findRiderByPhone(normalizedPhoneNumber);
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking phone: $e');
      return false;
    }
  }

  /// Logout rider
  Future<void> logout() async {
    _currentRider = null;
    await _clearRiderFromStorage();
    debugPrint('Rider logged out');
  }

  /// Get current rider
  Future<RiderModel?> getCurrentRider() async {
    try {
      if (_currentRider != null) return _currentRider;

      _loadRiderFromStorage();
      if (_currentRider != null) return _currentRider;

      final stored = _storage.read('riderData');
      if (stored is! Map) return null;

      final data = Map<String, dynamic>.from(stored);
      final phoneNumber = data['phoneNumber'] as String?;
      if (phoneNumber == null || phoneNumber.isEmpty) return null;

      return await loginRider(phoneNumber);
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

      final updatedRider = _currentRider!.copyWith(
        name: name,
        email: email,
        photoUrl: photoUrl,
        vehicleType: vehicleType,
        vehiclePlateNumber: vehiclePlateNumber,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('riders')
          .doc(updatedRider.riderId)
          .set(updatedRider.toJson(), SetOptions(merge: true));

      _currentRider = updatedRider;
      await _saveRiderToStorage(updatedRider);

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

      final updatedRider = _currentRider!.copyWith(
        isOnline: !_currentRider!.isOnline,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('riders').doc(updatedRider.riderId).set({
        'isOnline': updatedRider.isOnline,
        'updatedAt': updatedRider.updatedAt.toIso8601String()
      }, SetOptions(merge: true));

      _currentRider = updatedRider;
      await _saveRiderToStorage(updatedRider);

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

      final updatedRider = _currentRider!.copyWith(
        currentLatitude: latitude,
        currentLongitude: longitude,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('riders').doc(updatedRider.riderId).set(
        {
          'currentLatitude': latitude,
          'currentLongitude': longitude,
          'updatedAt': updatedRider.updatedAt.toIso8601String(),
        },
        SetOptions(merge: true),
      );

      _currentRider = updatedRider;
      await _saveRiderToStorage(updatedRider);

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
