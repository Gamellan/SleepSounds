// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sleep_sounds/main.dart';

Future<void> _ensureVisibleText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isNotEmpty) {
    return;
  }

  final scrollable = find.byType(ListView);
  for (var i = 0; i < 8; i++) {
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

void main() {
  testWidgets('Sleep sounds renders core tracks', (WidgetTester tester) async {
    await tester.pumpWidget(const SleepSoundsApp());

    expect(find.text('Sleep Sounds'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Presets'), findsOneWidget);
    expect(find.text('Sleep Timer'), findsOneWidget);
    expect(find.text('Aurora'), findsOneWidget);
    expect(find.text('Sunset'), findsOneWidget);
    expect(find.text('Forest Night'), findsOneWidget);
    expect(find.text('Baby'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.text('Meditation'), findsOneWidget);

    await _ensureVisibleText(tester, 'Rain');
    expect(find.text('Rain'), findsOneWidget);

    await _ensureVisibleText(tester, 'Ocean');
    expect(find.text('Ocean'), findsOneWidget);

    await _ensureVisibleText(tester, 'Forest');
    expect(find.text('Forest'), findsOneWidget);

    await _ensureVisibleText(tester, 'Fan');
    expect(find.text('Fan'), findsOneWidget);

    await _ensureVisibleText(tester, 'White Noise');
    expect(find.text('White Noise'), findsOneWidget);
  });
}
