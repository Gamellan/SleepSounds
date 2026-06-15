// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sleep_sounds/main.dart';

void main() {
  testWidgets('Sleep sounds renders core tracks', (WidgetTester tester) async {
    await tester.pumpWidget(const SleepSoundsApp());

    expect(find.text('Sleep Sounds'), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget);
    expect(find.text('Ocean'), findsOneWidget);
    expect(find.text('Forest'), findsOneWidget);
    expect(find.text('Fan'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('White Noise'), findsOneWidget);
  });
}
