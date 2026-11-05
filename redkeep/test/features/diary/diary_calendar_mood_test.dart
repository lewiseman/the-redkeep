import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_day_details.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';
import '../../support/diary_reader.dart';

Finder _day(DiaryPeriod date) =>
    find.byKey(ValueKey('calendar-day-${date.calendarDate.toIso8601String()}'));

Finder _emoji(DiaryPeriod date, DiaryMood mood) =>
    find.descendant(of: _day(date), matching: find.text(mood.emoji));

void main() {
  late AppDatabase db;
  late DriftDiaryRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 2));
  });
  tearDown(() => db.close());

  void moodTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });

  moodTest('calendar shows saved moods and reacts to changes and clearing', (
    tester,
  ) async {
    for (final mood in DiaryMood.values) {
      await repo.saveDay(
        DiaryDay(date: DiaryPeriod(2026, 10, 12 + mood.index), mood: mood),
      );
    }
    final entryOnly = DiaryPeriod(2026, 10, 18);
    await repo.save(
      id: '11111111111111111111111111111111',
      date: entryOnly,
      text: const DiaryText(body: 'A day without a mood.'),
      expectedRevision: 0,
    );
    final date = DiaryPeriod(2026, 10, 12);
    await pumpApp(
      tester,
      initialLocation: diaryCalendarLocation(date),
      diary: repo,
      database: db,
    );

    for (final mood in DiaryMood.values) {
      final moodDate = DiaryPeriod(2026, 10, 12 + mood.index);
      expect(_emoji(moodDate, mood), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find
            .descendant(of: _day(moodDate), matching: find.byType(Semantics))
            .first,
      );
      expect(semantics.properties.label, contains('${mood.label} mood'));
    }
    for (final noMood in [DiaryPeriod(2026, 10, 17), entryOnly]) {
      for (final mood in DiaryMood.values) {
        expect(_emoji(noMood, mood), findsNothing);
      }
    }

    await repo.saveDay(DiaryDay(date: date, mood: DiaryMood.low, revision: 1));
    await tester.pumpAndSettle();
    expect(_emoji(date, DiaryMood.happy), findsNothing);
    expect(_emoji(date, DiaryMood.low), findsOneWidget);

    await repo.saveDay(DiaryDay(date: date, revision: 2));
    await tester.pumpAndSettle();
    expect(_emoji(date, DiaryMood.low), findsNothing);

    await repo.saveDay(DiaryDay(date: date, mood: DiaryMood.calm, revision: 3));
    await tester.pumpAndSettle();
    expect(_emoji(date, DiaryMood.calm), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  moodTest('mood opens its day at 320px and 3x text with reduced effects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final appearance = FakeAppearanceRepository(
      const AppearancePreferences(reduceMotion: true, simplerEffects: true),
    );
    addTearDown(appearance.close);
    final date = DiaryPeriod(2026, 10, 12);
    await repo.saveDay(DiaryDay(date: date, mood: DiaryMood.calm));
    final router = await pumpApp(
      tester,
      initialLocation: diaryCalendarLocation(date),
      diary: repo,
      database: db,
      repository: appearance,
    );
    await tester.ensureVisible(_day(date));
    await tester.pumpAndSettle();
    expect(_emoji(date, DiaryMood.calm).hitTestable(), findsOneWidget);
    await tester.tap(_emoji(date, DiaryMood.calm));
    await tester.pumpAndSettle();
    expectDiaryDay(tester, router, date);
    expect(tester.takeException(), isNull);
  });
}
