import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rider_settings_model.dart';

/// Service for managing Rider Settings in Firestore
class RiderSettingsService {
  static RiderSettingsService? _instance;
  static RiderSettingsService get instance {
    _instance ??= RiderSettingsService._internal();
    return _instance!;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'rider_settings';

  RiderSettingsService._internal();

  /// Get rider settings by rider ID
  Future<RiderSettingsModel?> getRiderSettings(String riderId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(riderId).get();

      if (doc.exists && doc.data() != null) {
        return RiderSettingsModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get rider settings: $e');
    }
  }

  /// Stream of rider settings
  Stream<RiderSettingsModel?> riderSettingsStream(String riderId) {
    return _firestore
        .collection(_collection)
        .doc(riderId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return RiderSettingsModel.fromMap(snapshot.data()!);
      }
      return null;
    });
  }

  /// Save or update rider settings
  Future<bool> saveRiderSettings(RiderSettingsModel settings) async {
    try {
      await _firestore.collection(_collection).doc(settings.riderId).set(
          settings.copyWith(updatedAt: DateTime.now()).toMap(),
          SetOptions(merge: true));
      return true;
    } catch (e) {
      throw Exception('Failed to save rider settings: $e');
    }
  }

  /// Update a single setting
  Future<bool> updateSetting(
      String riderId, String field, dynamic value) async {
    try {
      await _firestore.collection(_collection).doc(riderId).update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      throw Exception('Failed to update setting: $e');
    }
  }

  /// Delete rider settings
  Future<bool> deleteRiderSettings(String riderId) async {
    try {
      await _firestore.collection(_collection).doc(riderId).delete();
      return true;
    } catch (e) {
      throw Exception('Failed to delete rider settings: $e');
    }
  }

  /// Initialize default settings for a new rider
  Future<RiderSettingsModel> initializeDefaultSettings(String riderId) async {
    final defaultSettings = RiderSettingsModel(riderId: riderId);
    await saveRiderSettings(defaultSettings);
    return defaultSettings;
  }
}
