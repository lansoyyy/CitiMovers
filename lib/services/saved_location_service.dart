import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/saved_location_model.dart';

class SavedLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static SavedLocationService? _instance;

  SavedLocationService._();

  static SavedLocationService get instance {
    _instance ??= SavedLocationService._();
    return _instance!;
  }

  // Collection reference
  CollectionReference get _collection =>
      _firestore.collection('saved_locations');

  // Get all saved locations for a user
  Stream<List<SavedLocation>> getUserSavedLocations(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedLocation.fromFirestore(doc))
            .toList());
  }

  // Get saved location by ID
  Future<SavedLocation?> getSavedLocationById(String locationId) async {
    try {
      final doc = await _collection.doc(locationId).get();
      if (doc.exists) {
        return SavedLocation.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint(
          'SavedLocationService: Error getting saved location by ID: $e');
      return null;
    }
  }

  // Add new saved location
  Future<String?> addSavedLocation(SavedLocation location) async {
    try {
      final docRef = await _collection.add(location.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('SavedLocationService: Error adding saved location: $e');
      return null;
    }
  }

  // Update saved location
  Future<bool> updateSavedLocation(SavedLocation location) async {
    try {
      await _collection.doc(location.id).update(location.toFirestore());
      return true;
    } catch (e) {
      debugPrint('SavedLocationService: Error updating saved location: $e');
      return false;
    }
  }

  // Delete saved location
  Future<bool> deleteSavedLocation(String locationId) async {
    try {
      await _collection.doc(locationId).delete();
      return true;
    } catch (e) {
      debugPrint('SavedLocationService: Error deleting saved location: $e');
      return false;
    }
  }

  // Get saved locations by type
  Stream<List<SavedLocation>> getLocationsByType(String userId, String type) {
    return _collection
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedLocation.fromFirestore(doc))
            .toList());
  }
}
