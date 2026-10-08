import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_constants.dart';
import '../utils/contact_parsing.dart';
import 'admin_repository.dart';
import 'audit_service.dart';

/// Data access for subcontractor partners, their declared units, and the
/// trip-level partner report snapshot.
class AdminPartnerRepository {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String statusActive = 'active';
  static const String statusInactive = 'inactive';

  // ─── small coercion helpers ───────────────────────────────────────────────

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  // ─── normalization ────────────────────────────────────────────────────────

  static Map<String, dynamic> normalizePartnerData(
    String partnerId,
    Map<String, dynamic> raw,
  ) {
    final status = _asString(raw['status'], fallback: statusActive);
    return {
      ...raw,
      'id': partnerId,
      'partnerId': partnerId,
      'name': _asString(raw['name'], fallback: 'Unnamed Partner'),
      'contactPerson': _asString(raw['contactPerson']),
      'phone': _asString(raw['phone']),
      'email': _asString(raw['email']),
      'address': _asString(raw['address']),
      'notes': _asString(raw['notes']),
      'status': status == statusInactive ? statusInactive : statusActive,
      'reportEmailEnabled': raw['reportEmailEnabled'] == true,
      'reportEmails': ContactParsing.parseEmailRecipients(raw['reportEmails']),
      'reportSmsEnabled': raw['reportSmsEnabled'] == true,
      'reportPhones': ContactParsing.parsePhoneNumbers(raw['reportPhones']),
      'createdAt': AdminRepository.parseTimestamp(raw['createdAt']),
      'updatedAt': AdminRepository.parseTimestamp(raw['updatedAt']),
    };
  }

  // ─── partners ─────────────────────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> streamPartners() {
    return _db
        .collection(AdminConstants.colPartners)
        .snapshots()
        .map((snapshot) {
          final partners = snapshot.docs
              .map((doc) => normalizePartnerData(doc.id, _asMap(doc.data())))
              .toList();
          partners.sort(
            (a, b) => (a['name'] ?? '')
                .toString()
                .toLowerCase()
                .compareTo((b['name'] ?? '').toString().toLowerCase()),
          );
          return partners;
        });
  }

  static Future<Map<String, dynamic>?> getNormalizedPartner(
    String partnerId,
  ) async {
    final doc = await _db
        .collection(AdminConstants.colPartners)
        .doc(partnerId)
        .get();
    if (!doc.exists) return null;
    return normalizePartnerData(partnerId, _asMap(doc.data()));
  }

  static Stream<Map<String, dynamic>?> streamPartner(String partnerId) {
    return _db
        .collection(AdminConstants.colPartners)
        .doc(partnerId)
        .snapshots()
        .map((doc) => doc.exists
            ? normalizePartnerData(partnerId, _asMap(doc.data()))
            : null);
  }

  static Map<String, dynamic> _buildPartnerPayload({
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
    required bool reportEmailEnabled,
    required List<String> reportEmails,
    required bool reportSmsEnabled,
    required List<String> reportPhones,
  }) {
    return {
      'name': name.trim(),
      'contactPerson': contactPerson?.trim() ?? '',
      'phone': ContactParsing.normalizePhone(phone) ?? phone?.trim() ?? '',
      'email': email?.trim() ?? '',
      'address': address?.trim() ?? '',
      'notes': notes?.trim() ?? '',
      'reportEmailEnabled': reportEmailEnabled,
      'reportEmails': ContactParsing.parseEmailRecipients(reportEmails),
      'reportSmsEnabled': reportSmsEnabled,
      'reportPhones': ContactParsing.parsePhoneNumbers(reportPhones),
    };
  }

  static Future<String> createPartner({
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool reportEmailEnabled = false,
    List<String> reportEmails = const [],
    bool reportSmsEnabled = false,
    List<String> reportPhones = const [],
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('Partner name is required.');
    }

    final ref = _db.collection(AdminConstants.colPartners).doc();
    final payload = _buildPartnerPayload(
      name: trimmedName,
      contactPerson: contactPerson,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      reportEmailEnabled: reportEmailEnabled,
      reportEmails: reportEmails,
      reportSmsEnabled: reportSmsEnabled,
      reportPhones: reportPhones,
    );

    await ref.set({
      ...payload,
      'partnerId': ref.id,
      'status': statusActive,
      'createdBy': AdminConstants.adminUsername,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AdminAuditService.log(
      action: AdminConstants.auditCreatePartner,
      entityType: 'partner',
      entityId: ref.id,
      reason: 'Created partner "$trimmedName"',
      after: payload,
    );
    return ref.id;
  }

  static Future<void> savePartner({
    required String partnerId,
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
    required bool reportEmailEnabled,
    required List<String> reportEmails,
    required bool reportSmsEnabled,
    required List<String> reportPhones,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('Partner name is required.');
    }
    if (reportEmailEnabled &&
        ContactParsing.parseEmailRecipients(reportEmails).isEmpty) {
      throw StateError(
          'Add at least one valid email recipient or untick Email reports.');
    }

    final ref = _db.collection(AdminConstants.colPartners).doc(partnerId);
    final beforeSnap = await ref.get();
    if (!beforeSnap.exists) {
      throw StateError('Partner not found.');
    }
    final before = normalizePartnerData(partnerId, _asMap(beforeSnap.data()));

    final payload = _buildPartnerPayload(
      name: trimmedName,
      contactPerson: contactPerson,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      reportEmailEnabled: reportEmailEnabled,
      reportEmails: reportEmails,
      reportSmsEnabled: reportSmsEnabled,
      reportPhones: reportPhones,
    );

    await ref.set({
      ...payload,
      'updatedBy': AdminConstants.adminUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AdminAuditService.log(
      action: AdminConstants.auditUpdatePartner,
      entityType: 'partner',
      entityId: partnerId,
      reason: 'Updated partner "$trimmedName"',
      before: {
        'name': before['name'],
        'reportEmailEnabled': before['reportEmailEnabled'],
        'reportEmails': before['reportEmails'],
        'reportSmsEnabled': before['reportSmsEnabled'],
        'reportPhones': before['reportPhones'],
      },
      after: payload,
    );
  }

  static Future<void> setPartnerStatus({
    required String partnerId,
    required String status,
  }) async {
    final resolvedStatus =
        status == statusInactive ? statusInactive : statusActive;
    final ref = _db.collection(AdminConstants.colPartners).doc(partnerId);
    final beforeSnap = await ref.get();
    if (!beforeSnap.exists) {
      throw StateError('Partner not found.');
    }

    await ref.set({
      'status': resolvedStatus,
      'updatedBy': AdminConstants.adminUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AdminAuditService.log(
      action: AdminConstants.auditPartnerStatus,
      entityType: 'partner',
      entityId: partnerId,
      reason: 'Status set to $resolvedStatus',
      before: {'status': _asMap(beforeSnap.data())['status']},
      after: {'status': resolvedStatus},
    );
  }

  // ─── declared units (riders) ──────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> streamUnitsForPartner(
    String partnerId,
  ) {
    return _db
        .collection(AdminConstants.colRiders)
        .where('partnerId', isEqualTo: partnerId)
        .snapshots()
        .map((snapshot) {
          final units = snapshot.docs
              .map((doc) => AdminRepository.normalizeRiderData(
                    doc.id,
                    _asMap(doc.data()),
                  ))
              .toList();
          units.sort(
            (a, b) => (a['name'] ?? '')
                .toString()
                .toLowerCase()
                .compareTo((b['name'] ?? '').toString().toLowerCase()),
          );
          return units;
        });
  }

  /// Attaches a registered rider (unit) to [partnerId].
  static Future<void> assignRiderToPartner({
    required String riderId,
    required String partnerId,
  }) async {
    final riderRef = _db.collection(AdminConstants.colRiders).doc(riderId);
    final partnerSnap = await _db
        .collection(AdminConstants.colPartners)
        .doc(partnerId)
        .get();
    if (!partnerSnap.exists) {
      throw StateError('Partner not found.');
    }
    final partner =
        normalizePartnerData(partnerId, _asMap(partnerSnap.data()));

    final riderSnap = await riderRef.get();
    if (!riderSnap.exists) {
      throw StateError('Rider not found.');
    }
    final before = _asMap(riderSnap.data());

    await riderRef.set({
      'partnerId': partnerId,
      'partnerName': partner['name'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AdminAuditService.log(
      action: AdminConstants.auditAssignPartnerUnit,
      entityType: 'rider',
      entityId: riderId,
      reason: 'Unit assigned to partner "${partner['name']}"',
      before: {
        'partnerId': before['partnerId'] ?? '',
        'partnerName': before['partnerName'] ?? '',
      },
      after: {
        'partnerId': partnerId,
        'partnerName': partner['name'],
      },
    );
  }

  /// Detaches a rider (unit) from its partner.
  static Future<void> removeRiderFromPartner({required String riderId}) async {
    final riderRef = _db.collection(AdminConstants.colRiders).doc(riderId);
    final riderSnap = await riderRef.get();
    if (!riderSnap.exists) {
      throw StateError('Rider not found.');
    }
    final before = _asMap(riderSnap.data());

    await riderRef.set({
      'partnerId': FieldValue.delete(),
      'partnerName': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AdminAuditService.log(
      action: AdminConstants.auditRemovePartnerUnit,
      entityType: 'rider',
      entityId: riderId,
      reason: 'Unit removed from partner "${before['partnerName'] ?? ''}"',
      before: {
        'partnerId': before['partnerId'] ?? '',
        'partnerName': before['partnerName'] ?? '',
      },
    );
  }

  // ─── partner trips ────────────────────────────────────────────────────────

  /// Trips stamped with this partner (live + completed), newest first.
  static Stream<List<Map<String, dynamic>>> streamPartnerTrips(
    String partnerId, {
    int limit = 200,
  }) {
    return _db
        .collection(AdminConstants.colBookings)
        .where('partnerId', isEqualTo: partnerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdminRepository.normalizeBookingData(
                  doc.id,
                  _asMap(doc.data()),
                ))
            .toList());
  }
}
