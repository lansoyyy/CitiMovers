import 'package:admin_web/utils/partner_stamp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PartnerStamp.resolveBookingPartnerStamp', () {
    test('stamps id, name and recipients for an active partner', () {
      final stamp = PartnerStamp.resolveBookingPartnerStamp(
        partnerId: 'partner-1',
        partnerRaw: {
          'name': 'ABC Trucking',
          'status': 'active',
          'reportEmailEnabled': true,
          'reportEmails': ['pod@abc.com', 'ops@abc.com'],
          'reportSmsEnabled': true,
          'reportPhones': ['09171234567'],
        },
      );

      expect(stamp['partnerId'], 'partner-1');
      expect(stamp['partnerName'], 'ABC Trucking');
      expect(stamp['partnerReportEmails'], ['pod@abc.com', 'ops@abc.com']);
      expect(stamp['partnerReportPhones'], ['+639171234567']);
    });

    test('gates each channel on its enable flag', () {
      final stamp = PartnerStamp.resolveBookingPartnerStamp(
        partnerId: 'partner-1',
        partnerRaw: {
          'name': 'ABC Trucking',
          'status': 'active',
          'reportEmailEnabled': false,
          'reportEmails': ['pod@abc.com'],
          'reportSmsEnabled': false,
          'reportPhones': ['09171234567'],
        },
      );

      expect(stamp['partnerReportEmails'], isEmpty);
      expect(stamp['partnerReportPhones'], isEmpty);
    });

    test('parses raw recipient strings when needed', () {
      final stamp = PartnerStamp.resolveBookingPartnerStamp(
        partnerId: 'partner-1',
        partnerRaw: {
          'name': 'ABC Trucking',
          'status': 'active',
          'reportEmailEnabled': true,
          'reportEmails': 'a@x.com, b@y.com',
        },
      );

      expect(stamp['partnerReportEmails'], ['a@x.com', 'b@y.com']);
    });

    test('clears the stamp when the rider has no partner', () {
      final stamp = PartnerStamp.resolveBookingPartnerStamp(
        partnerId: '',
        partnerRaw: null,
      );

      expect(stamp['partnerId'], isA<FieldValue>());
      expect(stamp['partnerName'], isA<FieldValue>());
      expect(stamp['partnerReportEmails'], isA<FieldValue>());
      expect(stamp['partnerReportPhones'], isA<FieldValue>());
    });

    test('clears the stamp for an inactive partner', () {
      final stamp = PartnerStamp.resolveBookingPartnerStamp(
        partnerId: 'partner-1',
        partnerRaw: {'name': 'ABC Trucking', 'status': 'inactive'},
      );

      expect(stamp['partnerId'], isA<FieldValue>());
      expect(stamp['partnerName'], isA<FieldValue>());
    });

    test('treats a missing status as active for legacy partner docs', () {
      final stamp = PartnerStamp.resolveBookingPartnerStamp(
        partnerId: 'partner-1',
        partnerRaw: {'name': 'ABC Trucking'},
      );

      expect(stamp['partnerId'], 'partner-1');
      expect(stamp['partnerName'], 'ABC Trucking');
    });
  });
}
