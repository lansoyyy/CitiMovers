import 'package:admin_web/services/report_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportSettingsRepository.normalizeReportSettings', () {
    test('defaults to enabled with the fallback recipient', () {
      final settings = ReportSettingsRepository.normalizeReportSettings(
        const {},
      );

      expect(settings['enabled'], isTrue);
      expect(
        settings['recipients'],
        ReportSettingsRepository.defaultRecipients,
      );
    });

    test('parses and de-duplicates recipient lists', () {
      final settings = ReportSettingsRepository.normalizeReportSettings({
        'recipients': [
          'excel_gesite@yahoo.com',
          'Excel_Gesite@yahoo.com',
          'billing@citimovers.net',
        ],
      });

      expect(settings['recipients'], [
        'excel_gesite@yahoo.com',
        'billing@citimovers.net',
      ]);
    });

    test('parses comma-separated recipient strings', () {
      final settings = ReportSettingsRepository.normalizeReportSettings({
        'recipients': 'a@x.com, b@y.com',
      });

      expect(settings['recipients'], ['a@x.com', 'b@y.com']);
    });

    test('falls back to the default when all recipients are invalid', () {
      final settings = ReportSettingsRepository.normalizeReportSettings({
        'recipients': ['not-an-email'],
      });

      expect(
        settings['recipients'],
        ReportSettingsRepository.defaultRecipients,
      );
    });

    test('honors an explicit disable', () {
      final settings = ReportSettingsRepository.normalizeReportSettings({
        'enabled': false,
        'recipients': ['excel_gesite@yahoo.com'],
      });

      expect(settings['enabled'], isFalse);
    });
  });
}
