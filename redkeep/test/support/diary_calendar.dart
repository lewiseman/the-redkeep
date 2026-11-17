import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/presentation/diary_calendar_overview.dart';

final calendarZoomDial = find.byKey(const ValueKey('calendar-zoom-dial'));

/// The lens the calendar has settled on, as its zoom dial reports it.
String? calendarLens(WidgetTester tester) =>
    tester.widget<Semantics>(calendarZoomDial).properties.value;

/// Steps the calendar's zoom dial until it settles on [kind]'s lens.
Future<void> zoomCalendarTo(WidgetTester tester, DiaryPeriodKind kind) async {
  final label = DiaryCalendarLens.of(kind).label;
  for (var step = 0; step < DiaryCalendarLens.values.length; step++) {
    if (calendarLens(tester) == label) return;
    await tester.ensureVisible(calendarZoomDial);
    await tester.pumpAndSettle();
    await tester.tap(calendarZoomDial);
    await tester.pumpAndSettle();
  }
  expect(calendarLens(tester), label);
}

/// Two fingers about [center], spreading apart ([apart] > 1) to zoom in or
/// pinching together to zoom out.
Future<void> pinchCalendar(
  WidgetTester tester,
  Offset center, {
  required double apart,
}) async {
  const start = 40.0;
  final first = await tester.startGesture(center - const Offset(start, 0));
  final second = await tester.startGesture(center + const Offset(start, 0));
  await tester.pump();
  const steps = 8;
  for (var i = 1; i <= steps; i++) {
    final reach = start * (1 + (apart - 1) * i / steps);
    await first.moveTo(center - Offset(reach, 0));
    await second.moveTo(center + Offset(reach, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await first.up();
  await second.up();
  await tester.pumpAndSettle();
}
