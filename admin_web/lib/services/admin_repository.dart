import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class AdminRepository {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Timestamp normalization ─────────────────────────────────────────────
  static DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ─── Users ───────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamUsers({String? searchQuery}) {
    var query = _db
        .collection(AdminConstants.colUsers)
        .orderBy('createdAt', descending: true)
        .limit(200);
    return query.snapshots();
  }

  static Future<DocumentSnapshot> getUser(String userId) =>
      _db.collection(AdminConstants.colUsers).doc(userId).get();

  static Future<void> updateUser(String userId, Map<String, dynamic> data) =>
      _db.collection(AdminConstants.colUsers).doc(userId).update(data);

  // ─── Riders ──────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamRiders({String? statusFilter}) {
    var ref = _db.collection(AdminConstants.colRiders);
    Query query = statusFilter != null && statusFilter.isNotEmpty
        ? ref.where('accountStatus', isEqualTo: statusFilter)
        : ref;
    return query.orderBy('createdAt', descending: true).limit(200).snapshots();
  }

  static Future<DocumentSnapshot> getRider(String riderId) =>
      _db.collection(AdminConstants.colRiders).doc(riderId).get();

  static Future<void> updateRider(String riderId, Map<String, dynamic> data) =>
      _db.collection(AdminConstants.colRiders).doc(riderId).update(data);

  // ─── Bookings ─────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamBookings({
    String? statusFilter,
    int limit = 100,
  }) {
    Query query = _db.collection(AdminConstants.colBookings);
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  static Future<DocumentSnapshot> getBooking(String bookingId) =>
      _db.collection(AdminConstants.colBookings).doc(bookingId).get();

  static Future<void> updateBooking(
          String bookingId, Map<String, dynamic> data) =>
      _db.collection(AdminConstants.colBookings).doc(bookingId).update(data);

  // ─── Wallet transactions ──────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamWalletTransactions(String userId) =>
      _db
          .collection(AdminConstants.colWalletTransactions)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();

  // ─── Payments ─────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamPayments({int limit = 100}) =>
      _db
          .collection(AdminConstants.colPayments)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots();

  // ─── Notifications ────────────────────────────────────────────────────────
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'admin_broadcast',
  }) =>
      _db.collection(AdminConstants.colNotifications).add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

  // ─── Promo Banners ────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamPromoBanners() =>
      _db.collection(AdminConstants.colPromoBanners)
          .orderBy('createdAt', descending: true)
          .snapshots();

  static Future<void> upsertBanner(
          String? id, Map<String, dynamic> data) async {
    if (id != null) {
      await _db
          .collection(AdminConstants.colPromoBanners)
          .doc(id)
          .update(data);
    } else {
      await _db.collection(AdminConstants.colPromoBanners).add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─── Audit Logs ───────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamAuditLogs({int limit = 100}) =>
      _db
          .collection(AdminConstants.colAdminAuditLogs)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots();

  // ─── Dashboard aggregates ─────────────────────────────────────────────────
  static Future<Map<String, int>> getBookingStatusCounts() async {
    final snap =
        await _db.collection(AdminConstants.colBookings).get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final status = (doc.data()['status'] as String?) ?? 'unknown';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  static Future<int> countPendingRiderApprovals() async {
    final snap = await _db
        .collection(AdminConstants.colRiders)
        .where('accountStatus', isEqualTo: 'pending')
        .count()
        .get();
    return snap.count ?? 0;
  }

  static Future<int> countUsers() async {
    final snap =
        await _db.collection(AdminConstants.colUsers).count().get();
    return snap.count ?? 0;
  }
}
