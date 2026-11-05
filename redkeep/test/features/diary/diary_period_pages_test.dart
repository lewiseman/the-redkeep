import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/presentation/diary_scene.dart';
import 'package:redkeep/features/diary/presentation/diary_calendar.dart';
import 'package:redkeep/features/diary/presentation/diary_writing_prompt.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';
import '../../support/warm_diary_faces.dart';

final _today = DiaryPeriod(2026, 11, 2);
final _periods = [
  DiaryPeriod.week(_today.start),
  DiaryPeriod.month(2026, 11),
  DiaryPeriod.year(2026),
];

DiaryPeriod _selected(WidgetTester tester) =>
    tester.widget<DiaryScene>(find.byType(DiaryScene).last).day.date;

Future<void> _tap(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final period in _periods) {
    testWidgets(
      'calendar opens an empty ${period.kind.name}; saved title marks it and clearing hides it',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final repo = DriftDiaryRepository(
          db,
          clock: () => DateTime(2026, 11, 2),
        );
        try {
          final router = await pumpApp(
            tester,
            database: db,
            diary: repo,
            initialLocation: diaryCalendarLocation(_today),
          );
          final button = find
              .byKey(ValueKey('calendar-period-${period.key}'))
              .first;
          await _tap(tester, button);
          expect(_selected(tester), period);
          expect(
            router.routeInformationProvider.value.uri.path,
            diaryDayLocation(period),
          );
          expect(await repo.watchSavedPeriods().first, isEmpty);
          final title = find
              .byKey(const ValueKey('diary-day-title'))
              .hitTestable();
          await _tap(tester, title);
          await tester.enterText(
            find.byKey(const ValueKey('diary-day-title-field')),
            'My ${period.kind.name}',
          );
          await _tap(tester, find.text('Save ${period.kind.name}'));
          expect(await repo.watchSavedPeriods().first, contains(period));
          await _tap(tester, find.byKey(const ValueKey('diary-date-control')));
          final savedButton = find
              .byKey(ValueKey('calendar-period-${period.key}'))
              .first;
          await tester.ensureVisible(savedButton);
          expect(
            find.descendant(
              of: savedButton,
              matching: find.text('Open ${period.kind.name}'),
            ),
            findsOneWidget,
          );
          await repo.saveDay(DiaryDay(date: period, revision: 1));
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: savedButton,
              matching: find.text('Add ${period.kind.name}'),
            ),
            findsOneWidget,
          );
          expect(await repo.watchSavedPeriods().first, isEmpty);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await db.close();
        }
      },
    );
  }

  testWidgets(
    'weekly writing uses the normal editor; search and swipes reopen the weekly page',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 2));
      final week = _periods.first;
      try {
        final router = await pumpApp(
          tester,
          database: db,
          diary: repo,
          diaryId: () => 'a' * 32,
          initialLocation: diaryDayLocation(week),
        );
        await _tap(tester, find.byType(DiaryWritingPrompt).hitTestable());
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('diary-body')),
          'The garden grew this week 🌿',
        );
        await _tap(tester, find.text('Save entry'));
        await _tap(tester, find.text('Read committed entry'));
        expect((await repo.openDocument('a' * 32)).entry!.date, week);
        await _tap(tester, find.text('Return to week'));
        expect(_selected(tester), week);
        router.go(diaryDayLocation(_today));
        await tester.pumpAndSettle();
        final nested = tester.state<NestedScrollViewState>(
          find.byType(NestedScrollView),
        );
        nested.outerController.jumpTo(0);
        nested.innerController.jumpTo(0);
        await tester.pumpAndSettle();
        await warmDiaryFaces(tester);
        expect(
          tester.widget<DiaryScene>(find.byType(DiaryScene)).previous.date,
          week,
        );
        await tester.drag(find.byType(DiaryCalendar), const Offset(150, 0));
        await tester.pumpAndSettle();
        expect(_selected(tester), week);
        await tester.drag(find.byType(DiaryCalendar), const Offset(-150, 0));
        await tester.pumpAndSettle();
        expect(_selected(tester), _today);
        router.go('/diary/search');
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('diary-search-input')),
          'garden',
        );
        await _tap(tester, find.byKey(const ValueKey('diary-search-submit')));
        await _tap(tester, find.byKey(const ValueKey('diary-search-match-0')));
        expect(_selected(tester), week);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      }
    },
  );

  testWidgets(
    'an unsaved special page leaves no extra page in normal browsing',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 2));
      try {
        await pumpApp(
          tester,
          database: db,
          diary: repo,
          initialLocation: diaryDayLocation(_periods.first),
        );
        await tester.drag(
          find.byKey(const ValueKey('diary-active-paper')),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();
        expect(_selected(tester), _today);
        await tester.drag(
          find.byKey(const ValueKey('diary-active-paper')),
          const Offset(300, 0),
        );
        await tester.pumpAndSettle();
        expect(_selected(tester), _today.shift(-1));
        expect(await repo.watchSavedPeriods().first, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      }
    },
  );

  testWidgets(
    'a turn freezes the special neighbor until cancellation, then applies saved-page changes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 2));
      final week = _periods.first;
      try {
        await repo.saveDay(DiaryDay(date: week, heading: 'This week'));
        await pumpApp(
          tester,
          database: db,
          diary: repo,
          initialLocation: diaryDayLocation(_today),
        );
        await warmDiaryFaces(tester);
        DiaryScene scene() =>
            tester.widget<DiaryScene>(find.byType(DiaryScene));
        expect(scene().previous.date, week);
        final paper = find.byKey(const ValueKey('diary-active-paper'));
        final gesture = await tester.startGesture(tester.getRect(paper).center);
        await gesture.moveBy(const Offset(24, 0));
        await gesture.moveBy(const Offset(90, 0));
        await tester.pump();
        expect(scene().busy, isTrue);
        await repo.saveDay(DiaryDay(date: week, revision: 1));
        await tester.pump();
        expect(scene().previous.date, week);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(scene().day.date, _today);
        expect(scene().previous.date, _today.shift(-1));
        expect(await repo.watchSavedPeriods().first, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      }
    },
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final simple in [false, true]) {
      testWidgets(
        'period calendar and reader fit narrow screens and large text: $theme simple=$simple',
        (tester) async {
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 3;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(
                disableAnimations: simple,
                reduceMotion: simple,
              );
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final db = AppDatabase(NativeDatabase.memory());
          final repo = DriftDiaryRepository(
            db,
            clock: () => DateTime(2026, 11, 2),
          );
          final appearance = FakeAppearanceRepository(
            AppearancePreferences(theme: theme, simplerEffects: simple),
          );
          try {
            for (final period in _periods) {
              await repo.saveDay(
                DiaryDay(date: period, heading: 'A full ${period.kind.name}'),
              );
            }
            final router = await pumpApp(
              tester,
              database: db,
              diary: repo,
              repository: appearance,
              initialLocation: diaryCalendarLocation(_today),
            );
            await _tap(
              tester,
              find
                  .byKey(ValueKey('calendar-period-${_periods.first.key}'))
                  .first,
            );
            expect(_selected(tester), _periods.first);
            for (final period in _periods) {
              router.go(diaryDayLocation(period));
              await tester.pumpAndSettle();
              expect(_selected(tester), period);
            }
          } finally {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            await db.close();
            await appearance.close();
          }
        },
      );
    }
  }
}
