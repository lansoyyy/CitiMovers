import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/promo_banner_model.dart';

class PromoBannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static PromoBannerService? _instance;

  PromoBannerService._();

  static PromoBannerService get instance {
    _instance ??= PromoBannerService._();
    return _instance!;
  }

  // Collection reference
  CollectionReference get _collection => _firestore.collection('promo_banners');

  // Get all active promo banners
  Stream<List<PromoBanner>> getActivePromoBanners() {
    final now = DateTime.now();
    return _collection
        .where('isActive', isEqualTo: true)
        .where('startDate', isLessThanOrEqualTo: now)
        .where('endDate', isGreaterThan: now)
        .orderBy('displayOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PromoBanner.fromFirestore(doc))
            .toList());
  }

  // Get all promo banners (including inactive)
  Stream<List<PromoBanner>> getAllPromoBanners() {
    return _collection.orderBy('displayOrder').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => PromoBanner.fromFirestore(doc)).toList());
  }

  // Get promo banner by ID
  Future<PromoBanner?> getPromoBannerById(String bannerId) async {
    final doc = await _collection.doc(bannerId).get();
    if (doc.exists) {
      return PromoBanner.fromFirestore(doc);
    }
    return null;
  }

  // Add new promo banner
  Future<String?> addPromoBanner(PromoBanner banner) async {
    try {
      final docRef = await _collection.add(banner.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error adding promo banner: $e');
      return null;
    }
  }

  // Update promo banner
  Future<bool> updatePromoBanner(PromoBanner banner) async {
    try {
      await _collection.doc(banner.id).update(banner.toFirestore());
      return true;
    } catch (e) {
      print('Error updating promo banner: $e');
      return false;
    }
  }

  // Delete promo banner
  Future<bool> deletePromoBanner(String bannerId) async {
    try {
      await _collection.doc(bannerId).delete();
      return true;
    } catch (e) {
      print('Error deleting promo banner: $e');
      return false;
    }
  }

  // Toggle promo banner active status
  Future<bool> togglePromoBannerStatus(String bannerId, bool isActive) async {
    try {
      await _collection.doc(bannerId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error toggling promo banner status: $e');
      return false;
    }
  }
}
