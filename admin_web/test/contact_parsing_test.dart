import 'package:admin_web/utils/contact_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContactParsing.parseEmailRecipients', () {
    test('splits comma-separated addresses from a single input', () {
      final emails = ContactParsing.parseEmailRecipients(
        'pod@company.com, ops@company.com, admin@company.com',
      );

      expect(emails, [
        'pod@company.com',
        'ops@company.com',
        'admin@company.com',
      ]);
    });

    test('splits lists and nested strings, trims and de-duplicates', () {
      final emails = ContactParsing.parseEmailRecipients([
        'A@x.com , b@y.com',
        ['a@x.com', '  c@z.com  '],
        'b@y.com; d@w.com',
      ]);

      expect(emails, ['A@x.com', 'b@y.com', 'c@z.com', 'd@w.com']);
    });

    test('drops invalid entries', () {
      final emails = ContactParsing.parseEmailRecipients(
        'not-an-email, ok@mail.com, spaces in@mail.com, @nouser.com',
      );

      expect(emails, ['ok@mail.com']);
    });

    test('returns empty for null and blank input', () {
      expect(ContactParsing.parseEmailRecipients(null), isEmpty);
      expect(ContactParsing.parseEmailRecipients('   '), isEmpty);
    });
  });

  group('ContactParsing.normalizePhone', () {
    test('normalizes local mobile formats to +63', () {
      expect(ContactParsing.normalizePhone('09859784897'), '+639859784897');
      expect(ContactParsing.normalizePhone('9859784897'), '+639859784897');
      expect(ContactParsing.normalizePhone('639859784897'), '+639859784897');
      expect(ContactParsing.normalizePhone('+639859784897'), '+639859784897');
    });

    test('strips spaces, dashes and parentheses', () {
      expect(
        ContactParsing.normalizePhone('+63 (985) 978-4897'),
        '+639859784897',
      );
      expect(
        ContactParsing.normalizePhone('0985 978 4897'),
        '+639859784897',
      );
    });

    test('returns null for empty or digit-free input', () {
      expect(ContactParsing.normalizePhone(null), isNull);
      expect(ContactParsing.normalizePhone(''), isNull);
      expect(ContactParsing.normalizePhone('abc'), isNull);
    });
  });

  group('ContactParsing.parsePhoneNumbers', () {
    test('normalizes, trims and de-duplicates numbers', () {
      final phones = ContactParsing.parsePhoneNumbers(
        '09859784897, +63 985 978 4897, 09171234567',
      );

      expect(phones, ['+639859784897', '+639171234567']);
    });

    test('handles list input and drops blanks', () {
      final phones = ContactParsing.parsePhoneNumbers([
        '',
        '  ',
        '09171234567',
      ]);

      expect(phones, ['+639171234567']);
    });
  });

  group('ContactParsing.isValidEmail', () {
    test('accepts common addresses and rejects malformed ones', () {
      expect(ContactParsing.isValidEmail('pod@company.com'), isTrue);
      expect(ContactParsing.isValidEmail('no-at-sign.com'), isFalse);
      expect(ContactParsing.isValidEmail('has space@mail.com'), isFalse);
    });
  });
}
