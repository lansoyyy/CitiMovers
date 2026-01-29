import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/driver_model.dart';

/// Driver Service for managing driver-related operations
class DriverService {
  static DriverService? _instance;
  static DriverService get instance {
    _instance ??= DriverService._internal();
    return _instance!;
  }

  DriverService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'drivers';

  /// Get driver by ID
  Future<DriverModel?> getDriverById(String driverId) async {
    try {
      final docSnapshot =
          await _firestore.collection(_collection).doc(driverId).get();
      if (docSnapshot.exists) {
        return DriverModel.fromMap(docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('DriverService: Error fetching driver: $e');
      return null;
    }
  }

  /// Get driver stream by ID
  Stream<DriverModel?> getDriverStream(String driverId) {
    return _firestore
        .collection(_collection)
        .doc(driverId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return DriverModel.fromMap(snapshot.data()!);
      }
      return null;
    });
  }

  /// Get all available drivers
  Stream<List<DriverModel>> getAvailableDrivers() {
    return _firestore
        .collection(_collection)
        .where('isAvailable', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DriverModel.fromMap(doc.data()))
          .toList();
    });
  }

  /// Get all drivers
  Stream<List<DriverModel>> getAllDrivers() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => DriverModel.fromMap(doc.data()))
          .toList();
    });
  }

  /// Update driver availability
  Future<bool> updateDriverAvailability(
      String driverId, bool isAvailable) async {
    try {
      await _firestore.collection(_collection).doc(driverId).update({
        'isAvailable': isAvailable,
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      debugPrint('DriverService: Error updating driver availability: $e');
      return false;
    }
  }

  /// Update driver location (for tracking)
  Future<bool> updateDriverLocation(
      String driverId, double latitude, double longitude) async {
    try {
      await _firestore.collection(_collection).doc(driverId).update({
        'currentLocation': {
          'latitude': latitude,
          'longitude': longitude,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      debugPrint('DriverService: Error updating driver location: $e');
      return false;
    }
  }

  /// Update driver rating
  Future<bool> updateDriverRating(String driverId, double newRating) async {
    try {
      // Get current driver data
      final docSnapshot =
          await _firestore.collection(_collection).doc(driverId).get();
      if (!docSnapshot.exists) return false;

      final currentData = docSnapshot.data()!;
      final currentRating = (currentData['rating'] as num?)?.toDouble() ?? 0.0;
      final totalDeliveries = currentData['totalDeliveries'] as int? ?? 0;

      // Calculate new average rating
      final newAverageRating = ((currentRating * totalDeliveries) + newRating) /
          (totalDeliveries + 1);

      await _firestore.collection(_collection).doc(driverId).update({
        'rating': newAverageRating,
        'totalDeliveries': totalDeliveries + 1,
      });
      return true;
    } catch (e) {
      debugPrint('DriverService: Error updating driver rating: $e');
      return false;
    }
  }

  /// Search drivers by name or vehicle plate
  Stream<List<DriverModel>> searchDrivers(String query) {
    return _firestore
        .collection(_collection)
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final drivers =
          snapshot.docs.map((doc) => DriverModel.fromMap(doc.data())).toList();
      return drivers.where((driver) {
        return driver.name.toLowerCase().contains(query.toLowerCase()) ||
            driver.vehiclePlateNumber
                .toLowerCase()
                .contains(query.toLowerCase());
      }).toList();
    });
  }
}
