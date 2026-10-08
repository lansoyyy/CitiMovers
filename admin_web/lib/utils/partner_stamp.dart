import 'package:cloud_firestore/cloud_firestore.dart';

import 'contact_parsing.dart';

/// Builds the partner snapshot merged onto a booking when a rider/unit is
/// assigned.
///
/// Kept free of repository imports so both the admin repository and the
/// partner repository can share it without a dependency cycle.
class PartnerStamp {
  PartnerStamp._();

  static const String activeStatus = 'active';

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }

  static String _asString(dynamic value) => value?.toString().trim() ?? '';

  /// Returns the partner report snapshot to merge into the booking document.
  ///
  /// Pass the rider's `partnerId` plus the partner document data (read inside
  /// the assignment transaction). When the unit is not attached to an active
  /// partner, the cleared stamp is returned — this also handles reassignment
  /// off a partner unit.
  static Map<String, dynamic> resolveBookingPartnerStamp({
    required String? partnerId,
    required Map<String, dynamic>? partnerRaw,
  }) {
    final resolvedId = partnerId?.trim() ?? '';
    final raw = partnerRaw == null ? null : _asMap(partnerRaw);
    final status = _asString(raw?['status']);
    final hasActivePartner = resolvedId.isNotEmpty &&
        raw != null &&
        (status.isEmpty || status == activeStatus);

    if (!hasActivePartner) {
      return {
        'partnerId': FieldValue.delete(),
        'partnerName': FieldValue.delete(),
        'partnerReportEmails': FieldValue.delete(),
        'partnerReportPhones': FieldValue.delete(),
      };
    }

    final emailEnabled = raw['reportEmailEnabled'] == true;
    final smsEnabled = raw['reportSmsEnabled'] == true;
    return {
      'partnerId': resolvedId,
      'partnerName': _asString(raw['name']),
      'partnerReportEmails': emailEnabled
          ? ContactParsing.parseEmailRecipients(raw['reportEmails'])
          : <String>[],
      'partnerReportPhones': smsEnabled
          ? ContactParsing.parsePhoneNumbers(raw['reportPhones'])
          : <String>[],
    };
  }
}
