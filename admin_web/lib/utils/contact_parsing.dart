/// Pure helpers for parsing and normalizing partner contact details.
///
/// Kept dependency-free so both the admin UI and repository layers (and unit
/// tests) share exactly one implementation.
class ContactParsing {
  ContactParsing._();

  /// Splits on commas, semicolons, tabs and newlines — "comma then space for
  /// additional email" produces separate entries.
  static final RegExp _separatorPattern = RegExp(r'[,;\n\r\t]+');

  /// Minimal email sanity check matching the sending path: an `@` with no
  /// whitespace on either side.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+$');

  /// Parses a raw string (or list) of email addresses into a clean,
  /// de-duplicated recipient list.
  ///
  /// Invalid entries (missing `@`, containing spaces) are dropped.
  static List<String> parseEmailRecipients(dynamic raw) {
    final candidates = <String>[];
    if (raw == null) return candidates;

    if (raw is List) {
      for (final value in raw) {
        candidates.addAll(parseEmailRecipients(value));
      }
    } else {
      for (final part in raw.toString().split(_separatorPattern)) {
        candidates.add(part);
      }
    }

    final seen = <String>{};
    final result = <String>[];
    for (final candidate in candidates) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty) continue;
      if (!_emailPattern.hasMatch(trimmed)) continue;
      if (!seen.add(trimmed.toLowerCase())) continue;
      result.add(trimmed);
    }
    return result;
  }

  /// Normalizes a Philippine mobile number to the system's canonical `+63…`
  /// form, matching the rider app and the rider profile editor.
  ///
  /// Accepts `+639XXXXXXXXX`, `09XXXXXXXXX`, `9XXXXXXXXX`, `63XXXXXXXXXX`,
  /// and variants with spaces/dashes/parentheses. Returns null unless the
  /// remaining characters are digits (with an optional leading `+`).
  static String? normalizePhone(dynamic raw) {
    if (raw == null) return null;
    var digits = raw.toString().trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.isEmpty) return null;

    final hasPlus = digits.startsWith('+');
    final bare = hasPlus ? digits.substring(1) : digits;
    if (bare.isEmpty || !RegExp(r'^\d+$').hasMatch(bare)) return null;
    if (hasPlus) return digits;

    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.startsWith('63') && digits.length == 12) return '+$digits';
    return '+63$digits';
  }

  /// Parses phone numbers into a clean, de-duplicated `+63…` list.
  static List<String> parsePhoneNumbers(dynamic raw) {
    final candidates = <String>[];
    if (raw == null) return candidates;

    if (raw is List) {
      for (final value in raw) {
        candidates.addAll(parsePhoneNumbers(value));
      }
    } else {
      for (final part in raw.toString().split(_separatorPattern)) {
        candidates.add(part);
      }
    }

    final seen = <String>{};
    final result = <String>[];
    for (final candidate in candidates) {
      final normalized = normalizePhone(candidate);
      if (normalized == null) continue;
      if (!seen.add(normalized)) continue;
      result.add(normalized);
    }
    return result;
  }

  /// True when the value looks like a usable email address.
  static bool isValidEmail(String value) =>
      _emailPattern.hasMatch(value.trim());
}
