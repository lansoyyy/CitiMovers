import 'package:citimovers/utils/report_recipients.dart';
import 'package:citimovers/utils/partner_stamp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportRecipients.partnerEmailsFromBooking', () {
    test('returns validated, de-duplicated partner emails', () {
      final emails = ReportRecipients.partnerEmailsFromBooking({
        'partnerReportEmails': [
          'pod@abc.com',
          'OPS@abc.com',
          'ops@abc.com',
          'not-an-email',
          '  spaced@abc.com  ',
        ],
      });

      expect(emails, ['pod@abc.com', 'OPS@abc.com', 'spaced@abc.com']);
    });

    test('handles missing or malformed fields', () {
      expect(ReportRecipients.partnerEmailsFromBooking(null), isEmpty);
      expect(ReportRecipients.partnerEmailsFromBooking(const {}), isEmpty);
      expect(
        ReportRecipients.partnerEmailsFromBooking({
          'partnerReportEmails': 'not-a-list',
        }),
        isEmpty,
      );
    });
  });

  group('ReportRecipients.partnerPhonesFromBooking', () {
    test('returns trimmed, de-duplicated numbers', () {
      final phones = ReportRecipients.partnerPhonesFromBooking({
        'partnerReportPhones': ['09171234567', ' 09171234567 ', ''],
      });

      expect(phones, ['09171234567']);
    });

    test('handles missing fields', () {
      expect(ReportRecipients.partnerPhonesFromBooking(null), isEmpty);
      expect(
        ReportRecipients.partnerPhonesFromBooking(const {}),
        isEmpty,
      );
    });
  });

  group('PartnerStamp.resolveBookingPartnerStamp', () {
    test('stamps active partner data onto a self-accepted booking', () {
      final stamp = PartnerStamp.resolveBookingPartnerStamp(
        partnerId: 'partner-1',
        partnerRaw: {
          'name': 'ABC Trucking',
          'status': 'active',
          'reportEmailEnabled': true,
          'reportEmails': ['pod@abc.com'],
          'reportSmsEnabled': true,
          'reportPhones': ['09171234567'],
        },
      );

      expect(stamp['partnerId'], 'partner-1');
      expect(stamp['partnerName'], 'ABC Trucking');
      expect(stamp['partnerReportEmails'], ['pod@abc.com']);
      expect(stamp['partnerReportPhones'], ['09171234567']);
    });

    test('clears the stamp for independent units and inactive partners', () {
      final noPartner = PartnerStamp.resolveBookingPartnerStamp(
        partnerId: null,
        partnerRaw: null,
      );
      expect(noPartner.values.every((value) => value is FieldValue), isTrue);

      final inactive = PartnerStamp.resolveBookingPartnerStamp(
        partnerId: 'partner-1',
        partnerRaw: {'name': 'ABC', 'status': 'inactive'},
      );
      expect(inactive.values.every((value) => value is FieldValue), isTrue);
    });
  });
}
