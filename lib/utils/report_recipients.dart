/// Pure helpers for assembling delivery-completion report recipients.
class ReportRecipients {
  ReportRecipients._();

  /// Partner report emails stamped on the booking at assignment time.
  ///
  /// Entries are validated (`@`) and de-duplicated case-insensitively so a
  /// partner address that matches the customer/driver/report recipient list
  /// is only emailed once.
  static List<String> partnerEmailsFromBooking(
    Map<String, dynamic>? bookingData,
  ) {
    final raw = bookingData?['partnerReportEmails'];
    if (raw is! List) return const [];

    final seen = <String>{};
    final result = <String>[];
    for (final value in raw) {
      final email = value.toString().trim();
      if (email.isEmpty || !email.contains('@')) continue;
      if (seen.add(email.toLowerCase())) result.add(email);
    }
    return result;
  }

  /// Partner report phone numbers stamped on the booking (reserved for the
  /// future SMS channel — stored now, not sent yet).
  static List<String> partnerPhonesFromBooking(
    Map<String, dynamic>? bookingData,
  ) {
    final raw = bookingData?['partnerReportPhones'];
    if (raw is! List) return const [];

    final seen = <String>{};
    final result = <String>[];
    for (final value in raw) {
      final phone = value.toString().trim();
      if (phone.isEmpty) continue;
      if (seen.add(phone)) result.add(phone);
    }
    return result;
  }
}
