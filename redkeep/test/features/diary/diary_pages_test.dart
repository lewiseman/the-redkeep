import 'dart:ui' show SemanticsAction, SemanticsActionEvent;
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/application/diary_editor_controller.dart';
import 'package:redkeep/features/diary/presentation/diary_scene.dart';
import 'package:redkeep/features/diary/presentation/diary_calendar_page.dart';
import 'package:redkeep/features/diary/presentation/diary_writing_prompt.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';

import '../../support/controlled_diary_repository.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';

const id = '11111111111111111111111111111111';
final date = CivilDate(2026, 11, 2);
final address = (date: date, id: id);

void main() {
  late AppDatabase db;
  late ControlledDiaryRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ControlledDiaryRepository(
      DriftDiaryRepository(db, clock: () => DateTime.utc(2026, 11, 2)),
    );
  });
  tearDown(() => db.close());
  void diaryTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
  Finder liveText(String text) => find.descendant(
    of: find.byKey(const ValueKey('diary-live-content')),
    matching: find.text(text),
  );
  Future<void> tap(WidgetTester tester, String label) async {
    if (label == 'Write an entry') {
      await tester.ensureVisible(find.byType(DiaryWritingPrompt).hitTestable());
      await tester.tap(find.byType(DiaryWritingPrompt).hitTestable());
      await tester.pumpAndSettle();
      return;
    }
    if (label == 'Previous day' || label == 'Next day') {
      final scene = tester.widget<DiaryScene>(find.byType(DiaryScene).last);
      scene.onDateChanged(
        DateTime(
          scene.day.date.year,
          scene.day.date.month,
          scene.day.date.day + (label == 'Previous day' ? -1 : 1),
        ),
      );
      await tester.pumpAndSettle();
      return;
    }
    if (label == 'Name this day') {
      await tester.ensureVisible(
        find.byKey(const ValueKey('diary-day-title')).hitTestable(),
      );
      await tester.tap(
        find.byKey(const ValueKey('diary-day-title')).hitTestable(),
      );
      await tester.pumpAndSettle();
      return;
    }
    if (label == 'Calendar for this month') {
      await tester.tap(find.byKey(const ValueKey('diary-date-control')).last);
      await tester.pumpAndSettle();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final control = find.text(label);
    if (control.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        control,
        160,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    expect(control.hitTestable(), findsOneWidget);
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  Future<DiaryDay> storedDay(WidgetTester tester) async =>
      (await tester.runAsync(() => repo.watchDay(date).first))!;

  Future<void> seed({
    String body = 'Exact writing 👩🏽‍💻 中文 e\u0301',
    String key = id,
    CivilDate? day,
  }) async {
    await repo.save(
      id: key,
      date: day ?? date,
      text: DiaryText(title: 'Synthetic entry', body: body),
      expectedRevision: 0,
    );
  }

  diaryTest(
    'diary title and body fonts apply to day, reader and editor without changing writing',
    (tester) async {
      await seed(body: 'Exact writing stays unchanged');
      final appearance = FakeAppearanceRepository(
        const AppearancePreferences(
          fontFamily: 'Lora',
          diaryTitleFontFamily: 'Poppins',
          diaryBodyFontFamily: 'Caveat',
        ),
      );
      addTearDown(appearance.close);
      final router = await pumpApp(
        tester,
        initialLocation: diaryEntryLocation(date, id),
        diary: repo,
        repository: appearance,
      );
      expect(
        tester
            .widget<Text>(find.text('Synthetic entry').first)
            .style!
            .fontFamily,
        'Poppins',
      );
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .style!
            .fontFamily,
        'Caveat',
      );
      router.go(diaryEntryLocation(date, id, edit: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('diary-title')))
            .style!
            .fontFamily,
        'Poppins',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('diary-body')))
            .style!
            .fontFamily,
        'Caveat',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('diary-body')))
            .controller!
            .text,
        'Exact writing stays unchanged',
      );
      router.go(diaryDayLocation(date));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.text('Synthetic entry').first)
            .style!
            .fontFamily,
        'Poppins',
      );
      expect(
        tester
            .widget<Text>(liveText('Exact writing stays unchanged'))
            .style!
            .fontFamily,
        'Caveat',
      );
    },
  );

  diaryTest(
    'empty day → durable create → committed read/edit → confirmed delete and unavailable old route',
    (tester) async {
      final router = await pumpApp(
        tester,
        initialLocation: diaryDayLocation(date),
        diary: repo,
        diaryId: () => id,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('diary-live-content')),
          matching: find.byType(DiaryWritingPrompt),
        ),
        findsOneWidget,
      );
      await tap(tester, 'Write an entry');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryEntryLocation(date, id, edit: true),
      );
      await tester.enterText(
        find.byKey(const ValueKey('diary-title')),
        'My day',
      );
      await tester.enterText(
        find.byKey(const ValueKey('diary-body')),
        'Hello 👩🏽‍💻\nHabari • 中文',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Save entry');
      expect(find.text('Saved revision 1 on this device.'), findsOneWidget);
      await tap(tester, 'Read committed entry');
      expect(find.text('Hello 👩🏽‍💻\nHabari • 中文'), findsOneWidget);
      await tap(tester, 'Edit entry');
      await tester.enterText(
        find.byKey(const ValueKey('diary-body')),
        'Revised writing',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Save entry');
      expect(find.text('Saved revision 2 on this device.'), findsOneWidget);
      await tap(tester, 'Read committed entry');
      await tap(tester, 'Delete entry');
      await tap(tester, 'Keep entry');
      expect((await repo.openDocument(id)).available, isTrue);
      await tap(tester, 'Delete entry');
      await tap(tester, 'Delete committed entry');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(date),
      );
      expect((await repo.openDocument(id)).entry!.text.body, '');
      router.go(diaryEntryLocation(date, id));
      await tester.pumpAndSettle();
      expect(find.text('Entry unavailable'), findsOneWidget);
      expect(find.text('Revised writing'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  diaryTest(
    'card title opens its own page, saves and clears without changing entries',
    (tester) async {
      await seed();
      final original = (await repo.openDocument(id)).entry!;
      final router = await pumpApp(
        tester,
        initialLocation: diaryDayLocation(date),
        diary: repo,
      );
      await tap(tester, 'Name this day');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryTitleLocation(date),
      );
      expect(find.byType(Dialog), findsNothing);
      await tester.enterText(find.byType(TextField), 'A day to remember');
      await tap(tester, 'Save title');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(date),
      );
      expect(liveText('A day to remember'), findsOneWidget);
      expect((await storedDay(tester)).heading, 'A day to remember');

      await tap(tester, 'Name this day');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'A day to remember',
      );
      await tester.enterText(find.byType(TextField), '');
      await tap(tester, 'Save title');
      expect((await storedDay(tester)).heading, '');
      expect(find.byType(DiaryTitlePrompt).hitTestable(), findsOneWidget);
      final unchanged = (await repo.openDocument(id)).entry!;
      expect(unchanged.revision, original.revision);
      expect(unchanged.text.title, original.text.title);
      expect(unchanged.text.body, original.text.body);
    },
  );

  diaryTest(
    'title editor protects unsaved changes and keeps the draft after a stale save',
    (tester) async {
      final router = await pumpApp(
        tester,
        initialLocation: diaryDayLocation(date),
        diary: repo,
      );
      await tap(tester, 'Name this day');
      await tester.enterText(find.byType(TextField), 'Draft title');
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Keep writing');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryTitleLocation(date),
      );
      await repo.renameDay(await storedDay(tester), 'Newer title');
      await tester.pumpAndSettle();
      await tap(tester, 'Save title');
      expect(
        find.text('Title could not be saved. Reopen the day and retry.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Draft title',
      );
      expect((await storedDay(tester)).heading, 'Newer title');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Discard');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(date),
      );
      expect(liveText('Newer title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  diaryTest(
    'selected calendar month, date steps and heading survive entry visits',
    (tester) async {
      final leap = CivilDate(2024, 2, 29);
      final router = await pumpApp(
        tester,
        initialLocation: diaryCalendarLocation(leap),
        diary: repo,
      );
      expect(find.text('February'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(
          ValueKey('calendar-day-${DateTime(2024, 2, 29).toIso8601String()}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey('calendar-day-${DateTime(2024, 2, 29).toIso8601String()}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(leap),
      );
      await tap(tester, 'Next day');
      expect(
        router.routeInformationProvider.value.uri.path,
        '/diary/2024-03-01',
      );
      await tap(tester, 'Previous day');
      await tap(tester, 'Name this day');
      await tester.enterText(find.byType(TextField), 'Leap day notebook');
      await tap(tester, 'Save title');
      expect(liveText('Leap day notebook'), findsOneWidget);
      await tap(tester, 'Calendar for this month');
      expect(find.byType(DiaryCalendarPage), findsOneWidget);
      expect(find.text('February'), findsOneWidget);
      await tap(tester, 'Today');
      await tester.ensureVisible(
        find.byKey(
          ValueKey('calendar-day-${DateTime(2026, 11, 2).toIso8601String()}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey('calendar-day-${DateTime(2026, 11, 2).toIso8601String()}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(date),
      );
      expect(tester.takeException(), isNull);
    },
  );

  diaryTest(
    'calendar dates expose full labels and an accessible activation action',
    (tester) async {
      final handle = tester.ensureSemantics();

      final router = await pumpApp(
        tester,
        initialLocation: diaryCalendarLocation(CivilDate(2024, 2, 29)),
        diary: repo,
      );
      final control = find.byKey(
        ValueKey('calendar-day-${DateTime(2024, 2, 29).toIso8601String()}'),
      );
      await tester.ensureVisible(control);
      final node = tester.getSemantics(control);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          viewId: tester.view.viewId,
          nodeId: node.id,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/diary/2024-02-29',
      );
      handle.dispose();
    },
  );

  diaryTest('save failure retains buffer; retry waits for storage', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: diaryDayLocation(date),
      diary: repo,
      diaryId: () => id,
    );
    await tap(tester, 'Write an entry');
    await tester.enterText(
      find.byKey(const ValueKey('diary-body')),
      'Retain this buffer',
    );
    await tester.pumpAndSettle();
    repo.failCommit = true;
    await tap(tester, 'Save entry');
    expect(find.textContaining('Save failed.'), findsOneWidget);
    expect((await repo.openDocument(id)).entry, isNull);
    repo.failCommit = false;
    repo.commitGate = Completer<void>();
    final saving = tester
        .container()
        .read(diaryEditorProvider(address).notifier)
        .save();
    await tester.pump();
    expect(find.text('Saving…'), findsNWidgets(2));
    repo.commitGate!.complete();
    await saving;
    await tester.pumpAndSettle();
    expect(find.text('Saved revision 1 on this device.'), findsOneWidget);
    expect(
      (await repo.openDocument(id)).entry!.text.body,
      'Retain this buffer',
    );
  });

  diaryTest(
    'unsaved edits are discarded explicitly and absent after restart; wrong dates hide source',
    (tester) async {
      await seed();
      final router = await pumpApp(
        tester,
        initialLocation: diaryEntryLocation(date, id, edit: true),
        diary: repo,
      );
      await tester.enterText(
        find.byKey(const ValueKey('diary-body')),
        'Recovered writing',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tap(tester, 'Keep writing');
      await tester.pumpWidget(const SizedBox());
      await pumpApp(
        tester,
        initialLocation: diaryEntryLocation(date, id, edit: true),
        diary: repo,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('diary-body')))
            .controller!
            .text,
        'Exact writing 👩🏽‍💻 中文 e\u0301',
      );
      await tap(tester, 'Discard changes');
      await tap(tester, 'Discard');
      expect((await repo.openDocument(id)).entry!.revision, 1);
      // Use the new scope's router, never the disposed one.
      expect(router, isNotNull);
      await tester.pumpWidget(const SizedBox());
      final next = await pumpApp(
        tester,
        initialLocation: diaryEntryLocation(date.shift(1)!, id),
        diary: repo,
      );
      expect(find.text('Entry unavailable'), findsOneWidget);
      expect(find.text('Exact writing 👩🏽‍💻 中文 e\u0301'), findsNothing);
      next.go(diaryEntryLocation(date.shift(1)!, id, edit: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('Editor unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  diaryTest(
    'search crosses days, opens selected day and excludes deleted text',
    (tester) async {
      await seed(body: 'lake 工作');
      await seed(body: 'Other day lake', key: '2' * 32, day: date.shift(1));
      final router = await pumpApp(
        tester,
        initialLocation: '/diary/search',
        diary: repo,
      );
      await tester.enterText(find.byType(TextField), 'lake 工作');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('diary-search-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Nov 2, 2026'), findsOneWidget);
      expect(find.text(date.shift(1)!.key), findsNothing);
      await tap(tester, 'Synthetic entry');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(date),
      );
      await repo.deleteEntry(id, 1);
      router.go('/diary/search');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '工作');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('diary-search-submit')));
      await tester.pumpAndSettle();
      expect(find.text('No moments found yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final simple in [false, true]) {
      diaryTest(
        'calendar/day/reader/editor/dialogs: 320px 3x safe areas keyboard $theme simple=$simple',
        (tester) async {
          await seed();
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = FakeViewPadding(top: 24, bottom: 16);
          tester.view.viewInsets = FakeViewPadding(bottom: 180);
          tester.platformDispatcher.textScaleFactorTestValue = 3;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(
                disableAnimations: simple,
                reduceMotion: simple,
              );
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final appearance = FakeAppearanceRepository(
            AppearancePreferences(theme: theme, simplerEffects: simple),
          );
          addTearDown(appearance.close);
          final router = await pumpApp(
            tester,
            initialLocation: '/diary',
            diary: repo,
            repository: appearance,
          );
          expect(
            find.byKey(const ValueKey('diary-active-paper')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          router.go(diaryDayLocation(date));
          await tester.pumpAndSettle();
          await tap(tester, 'Name this day');
          await tester.enterText(find.byType(TextField), 'Large text heading');
          await tap(tester, 'Save title');
          expect(liveText('Large text heading'), findsOneWidget);
          expect(tester.takeException(), isNull);
          router.go(diaryEntryLocation(date, id));
          await tester.pumpAndSettle();
          await tap(tester, 'Delete entry');
          await tap(tester, 'Keep entry');
          router.go(diaryEntryLocation(date, id, edit: true));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('diary-body')),
            'Large text diary',
          );
          await tester.pumpAndSettle();
          await tap(tester, 'Save entry');
          expect(find.text('Saved revision 2 on this device.'), findsOneWidget);
          await tap(tester, 'Discard changes');
          await tap(tester, 'Keep writing');
          router.go('/diary/search');
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(TextField),
            160,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(find.byType(TextField), 'Large');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  diaryTest(
    'long complete writing opens unchanged for focused reading and editing',
    (tester) async {
      final body = List.filled(5000, 'Unicode 👩🏽‍💻 e\u0301 中文\n').join();
      await seed(body: body);
      final router = await pumpApp(
        tester,
        initialLocation: diaryEntryLocation(date, id),
        diary: repo,
      );
      expect(find.text(body), findsOneWidget);
      router.go(diaryEntryLocation(date, id, edit: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('diary-body')))
            .controller!
            .text,
        body,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
