import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Finder chapterPosition(int chapter) => find.byWidgetPredicate(
  (w) =>
      w is Semantics &&
      w.key == const ValueKey('onboarding-chapter-position') &&
      w.properties.label == 'Chapter $chapter of 5',
);

Future<void> navigateChapter(WidgetTester tester, int direction) async {
  await tester.sendKeyEvent(
    direction > 0
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft,
  );
  await tester.pumpAndSettle();
}

Future<void> reopenOnboardingBook(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}
