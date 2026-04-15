import 'package:admin_web/services/csv_export_service.dart';
import 'package:admin_web/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SectionHeader lays out inside an unbounded row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                SectionHeader(title: 'Booking Details'),
                SizedBox(width: 12),
                Text('status'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Booking Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('AdminCsvExportService escapes CSV values for Excel', () {
    final csv = AdminCsvExportService.buildCsv(
      headers: const ['Trip Ticket', 'Reason'],
      rows: const [
        ['2026-0415-00001', 'Customer said "late", reschedule'],
      ],
    );

    expect(csv, contains('"Trip Ticket","Reason"'));
    expect(csv, contains('"Customer said ""late"", reschedule"'));
  });
}
