import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citimovers/main.dart';

void main() {
  testWidgets('CitiMovers app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CitiMoversApp());

    // Verify that splash screen shows app name
    expect(find.text('CitiMovers'), findsOneWidget);
  });
}
