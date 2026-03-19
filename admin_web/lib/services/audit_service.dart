import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class AdminAuditService {
  static final _col = FirebaseFirestore.instance.collection(
    AdminConstants.colAdminAuditLogs,
  );

  static Future<void> log({
    required String action,
    required String entityType,
    required String entityId,
    String? reason,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    await _col.add({
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'reason': reason ?? '',
      'before': before ?? {},
      'after': after ?? {},
      'performedBy': AdminConstants.adminUsername,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
