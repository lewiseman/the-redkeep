import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_day_details.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/presentation/diary_calendar_overview.dart';

import '../../support/pump_app.dart';
import '../../support/diary_reader.dart';

final _today = DiaryPeriod(2026, 11, 2);

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _day(DiaryPeriod date) =>
    _key('calendar-day-${date.calendarDate.toIso8601String()}');

void main() {
  late AppDatabase db;
  late DriftDiaryRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 2));
  });
  tearDown(() => db.close());

  Future<void> writeDay(DiaryPeriod date, String id) => repo.save(
    id: id,
    date: date,
    text: const DiaryText(body: 'Something happened.'),
    expectedRevision: 0,
  );

  void lensTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });

  test('moods arrive in one stream and follow edits', () async {
    final moods = repo.watchMoods();
    expect(await moods.first, isEmpty);
    await repo.saveDay(DiaryDay(date: _today, mood: DiaryMood.calm));
    await repo.saveDay(DiaryDay(date: DiaryPeriod(2026, 11, 1), heading: 'x'));
    expect(await repo.watchMoods().first, {_today: DiaryMood.calm});
    expect(await repo.watchHeadings().first, {DiaryPeriod(2026, 11, 1): 'x'});
  });

  lensTest('the lens follows the page that opened the calendar', (
    tester,
  ) async {
    await writeDay(
      DiaryPeriod(2026, 10, 5),
      '11111111111111111111111111111111',
    );
    await writeDay(
      DiaryPeriod(2026, 10, 6),
      '22222222222222222222222222222222',
    );
    final month = DiaryPeriod.month(2026, 10);
    final router = await pumpApp(
      tester,
      initialLocation: diaryCalendarLocation(month),
      diary: repo,
      database: db,
    );
    final lens = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('calendar-lens-month')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(lens.properties.selected, isTrue);
    final october = tester.widget<Semantics>(
      _key('calendar-month-tile-${month.key}'),
    );
    expect(october.properties.label, contains('Add month'));
    expect(october.properties.label, contains('2 days written'));
    final december = tester.widget<Semantics>(
      _key('calendar-month-tile-${DiaryPeriod.month(2026, 12).key}'),
    );
    expect(december.properties.label, startsWith('Not started'));
    await tester.ensureVisible(_key('calendar-period-${month.key}'));
    await tester.pumpAndSettle();
    await tester.tap(_key('calendar-period-${month.key}'));
    await tester.pumpAndSettle();
    expectDiaryDay(tester, router, month);
    expect(tester.takeException(), isNull);
  });

  lensTest('week lens turns rows into whole-week targets', (tester) async {
    await writeDay(_today, '11111111111111111111111111111111');
    final week = DiaryPeriod.week(_today.start);
    final router = await pumpApp(
      tester,
      initialLocation: diaryCalendarLocation(_today),
      diary: repo,
      database: db,
    );
    expect(_day(_today).hitTestable(), findsOneWidget);
    await tester.tap(_key('calendar-lens-week'));
    await tester.pumpAndSettle();
    final band = _key('calendar-period-${week.key}').first;
    final semantics = tester.widget<Semantics>(
      find.ancestor(of: band, matching: find.byType(Semantics)).first,
    );
    expect(semantics.properties.label, contains('Add week'));
    expect(semantics.properties.label, contains('1 day written'));
    await tester.tap(band);
    await tester.pumpAndSettle();
    expectDiaryDay(tester, router, week);
    expect(tester.takeException(), isNull);
  });

  test('ISO week numbers follow the Thursday rule', () {
    expect(isoWeekNumber(DateTime(2026, 11, 2)), 45);
    expect(isoWeekNumber(DateTime(2025, 12, 29)), 1);
    expect(isoWeekNumber(DateTime(2020, 12, 28)), 53);
  });

  lensTest('a week spanning two months appears once, with its title', (
    tester,
  ) async {
    // Sep 28 – Oct 4 2026: its Thursday is Oct 1, so it belongs to October.
    final split = DiaryPeriod.week(DiaryPeriod(2026, 9, 28).start);
    await repo.saveDay(DiaryDay(date: split, heading: 'Moving week'));
    await writeDay(
      DiaryPeriod(2026, 9, 29),
      '11111111111111111111111111111111',
    );
    await pumpApp(
      tester,
      initialLocation: diaryCalendarLocation(split),
      diary: repo,
      database: db,
    );
    final card = _key('calendar-period-${split.key}');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Moving week')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Open week')),
      findsOneWidget,
    );
    final label = tester
        .widget<Semantics>(
          find.ancestor(of: card, matching: find.byType(Semantics)).first,
        )
        .properties
        .label;
    expect(label, contains('Week 40'));
    expect(label, contains('1 day written'));
    expect(label, contains('titled Moving week'));
    // The current week is listed even before its Thursday arrives.
    final current = DiaryPeriod.week(_today.start);
    await tester.tap(find.byKey(const ValueKey('calendar-year-tab-2026')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-year-tab-2026')));
    await tester.pumpAndSettle();
    expect(_key('calendar-period-${current.key}'), findsOneWidget);
    expect(find.text('WEEK 45 · THIS WEEK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  lensTest('year lens totals the year and adds its page', (tester) async {
    await writeDay(_today, '11111111111111111111111111111111');
    await repo.saveDay(
      DiaryDay(date: DiaryPeriod.month(2026, 10), heading: 'October'),
    );
    final year = DiaryPeriod.year(2026);
    final router = await pumpApp(
      tester,
      initialLocation: diaryCalendarLocation(_today),
      diary: repo,
      database: db,
    );
    await tester.tap(_key('calendar-lens-year'));
    await tester.pumpAndSettle();
    expect(find.text('day written'), findsOneWidget);
    expect(find.text('month written'), findsOneWidget);
    expect(find.text('weeks written'), findsOneWidget);
    final button = _key('calendar-period-${year.key}');
    expect(
      find.descendant(of: button, matching: find.text('Add year')),
      findsOneWidget,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expectDiaryDay(tester, router, year);
    expect(tester.takeException(), isNull);
  });

  lensTest('every lens fits 320px with 3x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await writeDay(_today, '11111111111111111111111111111111');
    await pumpApp(
      tester,
      initialLocation: diaryCalendarLocation(_today),
      diary: repo,
      database: db,
    );
    for (final lens in ['week', 'month', 'year', 'day']) {
      final tab = _key('calendar-lens-$lens');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: lens);
    }
  });
}
