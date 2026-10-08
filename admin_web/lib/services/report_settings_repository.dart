import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_constants.dart';
import '../utils/contact_parsing.dart';
import 'admin_repository.dart';
import 'audit_service.dart';

/// Reads/writes the delivery-report settings document consumed by the
/// `sendCompletionReport` Cloud Function.
///
/// Changing recipients here takes effect immediately for the next completed
/// booking — no rider app update is ever required.
class ReportSettingsRepository {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String colAppConfig = AdminConstants.colAppConfig;
  static const String docReportSettings = 'report_settings';

  /// Internal fallback matching the Cloud Function default.
  static const List<String> defaultRecipients = ['excel_gesite@yahoo.com'];

  static DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(colAppConfig).doc(docReportSettings);

  static Map<String, dynamic> normalizeReportSettings(
    Map<String, dynamic> raw,
  ) {
    final rawRecipients = raw['recipients'];
    final recipients = ContactParsing.parseEmailRecipients(rawRecipients);
    return {
      'enabled': raw['enabled'] != false,
      'recipients': recipients.isEmpty ? defaultRecipients : recipients,
      'updatedBy': (raw['updatedBy'] ?? '').toString(),
      'updatedAt': AdminRepository.parseTimestamp(raw['updatedAt']),
    };
  }

  static Stream<Map<String, dynamic>> streamReportSettings() {
    return _doc.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return {
          'enabled': true,
          'recipients': defaultRecipients,
          'updatedBy': '',
          'updatedAt': null,
        };
      }
      return normalizeReportSettings(
        snapshot.data() ?? <String, dynamic>{},
      );
    });
  }

  static Future<Map<String, dynamic>> getReportSettings() async {
    final snapshot = await _doc.get();
    if (!snapshot.exists) {
      return {
        'enabled': true,
        'recipients': defaultRecipients,
        'updatedBy': '',
        'updatedAt': null,
      };
    }
    return normalizeReportSettings(
      snapshot.data() ?? <String, dynamic>{},
    );
  }

  static Future<void> saveReportSettings({
    required bool enabled,
    required List<String> recipients,
  }) async {
    final parsed = ContactParsing.parseEmailRecipients(recipients);
    final resolved = parsed.isEmpty ? defaultRecipients : parsed;

    final before = await getReportSettings();

    await _doc.set({
      'enabled': enabled,
      'recipients': resolved,
      'updatedBy': AdminConstants.adminUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AdminAuditService.log(
      action: AdminConstants.auditUpdateReportSettings,
      entityType: 'app_config',
      entityId: docReportSettings,
      reason: enabled
          ? 'Delivery report recipients updated'
          : 'Delivery report emails disabled',
      before: {
        'enabled': before['enabled'],
        'recipients': before['recipients'],
      },
      after: {
        'enabled': enabled,
        'recipients': resolved,
      },
    );
  }
}
