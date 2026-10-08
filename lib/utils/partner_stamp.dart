import 'package:cloud_firestore/cloud_firestore.dart';

/// Builds the partner snapshot merged onto a booking when a rider/unit is
/// assigned or self-accepts a delivery request.
///
/// Mirrors the admin panel's stamp logic. The snapshot keeps the booking
/// self-contained: the completion report routing needs no extra queries and
/// stays accurate even if the partner configuration changes later.
class PartnerStamp {
  PartnerStamp._();

  static const String activeStatus = 'active';

  static Map<String, dynamic> resolveBookingPartnerStamp({
    required String? partnerId,
    required Map<String, dynamic>? partnerRaw,
  }) {
    final resolvedId = partnerId?.trim() ?? '';
    final status = (partnerRaw?['status'] ?? '').toString().trim();
    final hasActivePartner = resolvedId.isNotEmpty &&
        partnerRaw != null &&
        (status.isEmpty || status == activeStatus);

    if (!hasActivePartner) {
      return {
        'partnerId': FieldValue.delete(),
        'partnerName': FieldValue.delete(),
        'partnerReportEmails': FieldValue.delete(),
        'partnerReportPhones': FieldValue.delete(),
      };
    }

    return {
      'partnerId': resolvedId,
      'partnerName': (partnerRaw['name'] ?? '').toString().trim(),
      'partnerReportEmails': _emailList(
        partnerRaw['reportEmails'],
        enabled: partnerRaw['reportEmailEnabled'] == true,
      ),
      'partnerReportPhones': _stringList(
        partnerRaw['reportPhones'],
        enabled: partnerRaw['reportSmsEnabled'] == true,
      ),
    };
  }

  static List<String> _emailList(dynamic raw, {required bool enabled}) {
    if (!enabled || raw is! List) return const [];
    final seen = <String>{};
    final result = <String>[];
    for (final value in raw) {
      final email = value.toString().trim();
      if (email.isEmpty || !email.contains('@')) continue;
      if (seen.add(email.toLowerCase())) result.add(email);
    }
    return result;
  }

  static List<String> _stringList(dynamic raw, {required bool enabled}) {
    if (!enabled || raw is! List) return const [];
    final seen = <String>{};
    final result = <String>[];
    for (final value in raw) {
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      if (seen.add(text)) result.add(text);
    }
    return result;
  }
}
