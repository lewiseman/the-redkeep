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
import 'package:redkeep/features/diary/presentation/diary_artwork.dart';
import 'package:redkeep/features/diary/presentation/diary_day_details_widgets.dart';
import 'package:redkeep/features/diary/presentation/diary_day_page.dart';
import 'package:redkeep/features/diary/presentation/diary_edit_page.dart';
import 'package:redkeep/features/diary/presentation/diary_paper_stamp.dart';
import 'package:redkeep/features/diary/presentation/diary_title_page.dart';
import 'package:redkeep/features/diary/presentation/photos/diary_ink_action.dart';
import 'package:redkeep/features/diary/presentation/diary_writing_paper.dart';
import 'package:redkeep/features/diary/presentation/diary_entry_page.dart';
import 'package:redkeep/features/diary/presentation/diary_widgets.dart';
import 'package:redkeep/features/diary/presentation/diary_writing_prompt.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_day_details.dart';

import '../../support/controlled_diary_repository.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';

const id = '11111111111111111111111111111111';
final date = DiaryPeriod(2026, 11, 2);
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
        scene.day.date.shift(label == 'Previous day' ? -1 : 1)!,
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

  Future<void> pickMood(WidgetTester tester, String name) async {
    final mood = find.byKey(ValueKey('diary-day-mood-$name'));
    await tester.ensureVisible(mood);
    await tester.pumpAndSettle();
    await tester.tap(mood);
    await tester.pumpAndSettle();
  }

  bool? moodSelected(WidgetTester tester, String name) => tester
      .widget<DiaryInkAction>(
        find.descendant(
          of: find.byKey(ValueKey('diary-day-mood-$name')),
          matching: find.byType(DiaryInkAction),
        ),
      )
      .selected;

  Future<void> removeTheme(WidgetTester tester, String theme) async {
    final remove = find.byKey(ValueKey('diary-day-theme-remove-$theme'));
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
  }

  Future<DiaryDay> storedDay(WidgetTester tester) async =>
      (await tester.runAsync(() => repo.watchDay(date).first))!;

  Future<void> seed({
    String body = 'Exact writing 👩🏽‍💻 中文 e\u0301',
    String key = id,
    DiaryPeriod? day,
  }) async {
    await repo.save(
      id: key,
      date: day ?? date,
      text: DiaryText(body: body),
      expectedRevision: 0,
    );
  }

  diaryTest(
    'only the day has a title; entry readers and editors use the body font',
    (tester) async {
      await seed(body: 'Exact writing stays unchanged');
      await repo.renameDay(DiaryDay(date: date), 'A quiet day');
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
      expect(find.text('Untitled entry'), findsNothing);
      expect(find.text('A quiet day'), findsNothing);
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .style!
            .fontFamily,
        'Caveat',
      );
      router.go(diaryEntryLocation(date, id, edit: true));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const ValueKey('diary-title')), findsNothing);
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
        tester.widget<Text>(liveText('A quiet day')).style!.fontFamily,
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

  diaryTest('the editor placeholder is the question it was opened with', (
    tester,
  ) async {
    const question = 'Which moment would you like to remember?';
    final router = await pumpApp(
      tester,
      initialLocation: diaryDayLocation(date),
      diary: repo,
      diaryId: () => id,
    );
    await tap(tester, 'Write an entry');
    expect(find.text('Start writing about your day…'), findsOneWidget);
    expect(find.text(question), findsNothing);
    router.go(diaryDayLocation(date));
    await tester.pumpAndSettle();
    unawaited(
      router.push(diaryEntryLocation(date, id, edit: true), extra: question),
    );
    await tester.pumpAndSettle();
    expect(find.text(question), findsOneWidget);
    expect(find.text('Start writing about your day…'), findsNothing);
  });

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
      expect(find.byType(DiaryEditPage), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const ValueKey('diary-title')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('diary-body')),
        'Hello 👩🏽‍💻\nHabari • 中文',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Save');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(date),
      );
      expect(liveText('Hello 👩🏽‍💻\nHabari • 中文'), findsOneWidget);
      router.go(diaryEntryLocation(date, id));
      await tester.pumpAndSettle();
      expect(find.text('Hello 👩🏽‍💻\nHabari • 中文'), findsOneWidget);
      await tap(tester, 'Edit entry');
      await tester.enterText(
        find.byKey(const ValueKey('diary-body')),
        'Revised writing',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Save');
      expect((await repo.openDocument(id)).entry!.revision, 2);
      expect(find.text('Revised writing'), findsOneWidget);
      await tap(tester, 'Delete entry');
      await tap(tester, 'Keep entry');
      expect((await repo.openDocument(id)).available, isTrue);
      await tap(tester, 'Delete entry');
      await tap(tester, 'Delete');
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
      expect(find.byType(DiaryTitlePage), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('diary-day-title-field')),
        'A day to remember',
      );
      await pickMood(tester, 'calm');
      await tester.enterText(
        find.byKey(const ValueKey('diary-day-themes-field')),
        'Work, Family',
      );
      await tap(tester, 'Save day');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(date),
      );
      expect(liveText('A day to remember'), findsOneWidget);
      expect((await storedDay(tester)).heading, 'A day to remember');
      expect((await storedDay(tester)).mood, DiaryMood.calm);
      expect((await storedDay(tester)).themes, ['Work', 'Family']);
      expect(liveText('😌 Calm · Work · Family'), findsOneWidget);

      await tap(tester, 'Name this day');
      expect(moodSelected(tester, 'calm'), isTrue);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('diary-day-title-field')),
            )
            .controller!
            .text,
        'A day to remember',
      );
      await tester.enterText(
        find.byKey(const ValueKey('diary-day-title-field')),
        '',
      );
      await tap(tester, 'Clear');
      await removeTheme(tester, 'Work');
      await removeTheme(tester, 'Family');
      await tap(tester, 'Save day');
      expect((await storedDay(tester)).heading, '');
      expect((await storedDay(tester)).mood, isNull);
      expect((await storedDay(tester)).themes, isEmpty);
      expect(find.byType(DiaryTitlePrompt).hitTestable(), findsOneWidget);
      final unchanged = (await repo.openDocument(id)).entry!;
      expect(unchanged.revision, original.revision);
      expect(unchanged.text.body, original.text.body);
    },
  );

  diaryTest(
    'mood-only changes are protected on back and invalid themes keep the draft',
    (tester) async {
      final router = await pumpApp(
        tester,
        initialLocation: diaryTitleLocation(date),
        diary: repo,
      );
      await pickMood(tester, 'happy');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard these changes?'), findsOneWidget);
      await tap(tester, 'Keep editing');
      expect(moodSelected(tester, 'happy'), isTrue);
      final themes = find.byKey(const ValueKey('diary-day-themes-field'));
      await tester.enterText(themes, 'One, Two, Three, Four');
      await tester.pump();
      await tap(tester, 'Save day');
      expect(find.text('Choose up to three themes.'), findsOneWidget);
      expect((await storedDay(tester)).revision, 0);
      expect(
        tester.widget<TextField>(themes).controller!.text,
        'Four',
        reason: 'A rejected theme stays for the user to fix.',
      );
      await removeTheme(tester, 'One');
      await removeTheme(tester, 'Two');
      await removeTheme(tester, 'Three');
      await tester.enterText(themes, 'x' * 41);
      await tap(tester, 'Save day');
      expect(
        find.text('Each theme must be at most 40 characters.'),
        findsOneWidget,
      );
      await tester.enterText(themes, ' Work, work, Family ');
      await tap(tester, 'Save day');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(date),
      );
      expect((await storedDay(tester)).heading, '');
      expect((await storedDay(tester)).mood, DiaryMood.happy);
      expect((await storedDay(tester)).themes, ['Work', 'Family']);
      expect(liveText('😊 Happy · Work · Family'), findsOneWidget);
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
      await tester.enterText(
        find.byKey(const ValueKey('diary-day-title-field')),
        'Draft title',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Keep editing');
      expect(find.byType(DiaryTitlePage), findsOneWidget);
      await repo.renameDay(await storedDay(tester), 'Newer title');
      await tester.pumpAndSettle();
      await tap(tester, 'Save day');
      expect(
        find.text('Day details could not be saved. Reopen the day and retry.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('diary-day-title-field')),
            )
            .controller!
            .text,
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
      final leap = DiaryPeriod(2024, 2, 29);
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
      await tester.enterText(
        find.byKey(const ValueKey('diary-day-title-field')),
        'Leap day notebook',
      );
      await tap(tester, 'Save day');
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
        initialLocation: diaryCalendarLocation(DiaryPeriod(2024, 2, 29)),
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

  diaryTest('back from a new entry returns to the day', (tester) async {
    final router = await pumpApp(
      tester,
      initialLocation: diaryDayLocation(date),
      diary: repo,
      diaryId: () => id,
    );
    await tap(tester, 'Write an entry');
    expect(find.byType(DiaryEditPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard this writing?'), findsNothing);
    expect(find.byType(DiaryEditPage), findsNothing);
    expect(find.byType(DiaryEntryPage), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.path,
      diaryDayLocation(date),
    );
    expect(tester.takeException(), isNull);
  });

  diaryTest('a double tap on the prompt opens one editor', (tester) async {
    await pumpApp(
      tester,
      initialLocation: diaryDayLocation(date),
      diary: repo,
      diaryId: () => id,
    );
    final prompt = find.byType(DiaryWritingPrompt).hitTestable();
    await tester.ensureVisible(prompt);
    await tester.tap(prompt);
    await tester.tap(prompt);
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEditPage, skipOffstage: false), findsOneWidget);
  });

  diaryTest('saving a new entry returns to the day with its text', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      initialLocation: diaryDayLocation(date),
      diary: repo,
      diaryId: () => id,
    );
    await tap(tester, 'Write an entry');
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Save entry'), findsNothing);
    expect(find.text('Discard changes'), findsNothing);
    expect(find.byType(NotebookSurface), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('diary-body')),
      'A new page',
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Save');
    expect(find.text('Discard this writing?'), findsNothing);
    expect(find.byType(DiaryEditPage), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.path,
      diaryDayLocation(date),
    );
    expect(liveText('A new page'), findsOneWidget);
  });

  diaryTest('back with unsaved writing asks before leaving', (tester) async {
    final router = await pumpApp(
      tester,
      initialLocation: diaryDayLocation(date),
      diary: repo,
      diaryId: () => id,
    );
    await tap(tester, 'Write an entry');
    await tester.enterText(
      find.byKey(const ValueKey('diary-body')),
      'Maybe keep this',
    );
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard this writing?'), findsOneWidget);
    expect(find.textContaining('will be lost'), findsOneWidget);
    await tap(tester, 'Keep writing');
    expect(find.byType(DiaryEditPage), findsOneWidget);
    expect(find.text('Maybe keep this'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, 'Discard');
    expect(find.byType(DiaryEditPage), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.path,
      diaryDayLocation(date),
    );
    expect((await repo.openDocument(id)).entry, isNull);
  });

  diaryTest('discard dialog buttons are real buttons at any text size', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      initialLocation: diaryDayLocation(date),
      diary: repo,
      diaryId: () => id,
    );
    await tap(tester, 'Write an entry');
    await tester.enterText(find.byKey(const ValueKey('diary-body')), 'Words');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    for (final label in ['Keep writing', 'Discard']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(
          label: label,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    }
    // Side by side, with the safe choice on the thumb's side.
    expect(
      tester.getCenter(find.text('Keep writing')).dx,
      greaterThan(tester.getCenter(find.text('Discard')).dx),
    );
    expect(
      tester.getCenter(find.text('Keep writing')).dy,
      moreOrLessEquals(tester.getCenter(find.text('Discard')).dy, epsilon: 4),
    );

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('Keep writing')).dy,
      lessThan(tester.getCenter(find.text('Discard')).dy),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  diaryTest('a direct link to the editor still goes back to the day', (
    tester,
  ) async {
    await seed();
    await pumpApp(
      tester,
      initialLocation: diaryEntryLocation(date, id, edit: true),
      diary: repo,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEditPage), findsNothing);
    expect(find.byType(DiaryEntryPage), findsNothing);
  });

  diaryTest('editing from the reader goes back to the reader', (tester) async {
    await seed();
    await pumpApp(
      tester,
      initialLocation: diaryEntryLocation(date, id),
      diary: repo,
    );
    await tap(tester, 'Edit entry');
    expect(find.byType(DiaryEditPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEditPage), findsNothing);
    expect(find.byType(DiaryEntryPage), findsOneWidget);
  });

  diaryTest('a saved entry is deleted from the editor menu', (tester) async {
    await seed();
    final router = await pumpApp(
      tester,
      initialLocation: diaryEntryLocation(date, id, edit: true),
      diary: repo,
    );
    await tester.tap(find.byTooltip('Entry options'));
    await tester.pumpAndSettle();
    await tap(tester, 'Delete entry');
    await tap(tester, 'Keep entry');
    expect(find.byType(DiaryEditPage), findsOneWidget);
    expect((await repo.openDocument(id)).available, isTrue);
    await tester.tap(find.byTooltip('Entry options'));
    await tester.pumpAndSettle();
    await tap(tester, 'Delete entry');
    await tap(tester, 'Delete');
    expect((await repo.openDocument(id)).available, isFalse);
    expect(
      router.routeInformationProvider.value.uri.path,
      diaryDayLocation(date),
    );
  });

  diaryTest('back from day details returns to the diary it came from', (
    tester,
  ) async {
    await pumpApp(tester, initialLocation: diaryDayLocation(date), diary: repo);
    final diary = tester.state(find.byType(DiaryDayPage));
    await tap(tester, 'Name this day');
    expect(find.byType(DiaryTitlePage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryTitlePage), findsNothing);
    expect(tester.state(find.byType(DiaryDayPage)), same(diary));
    expect(find.text('Discard these changes?'), findsNothing);
  });

  diaryTest('a mood is circled, tapped again or cleared to remove it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: diaryTitleLocation(date),
      diary: repo,
    );
    expect(find.text('Clear'), findsNothing);
    await pickMood(tester, 'tired');
    expect(moodSelected(tester, 'tired'), isTrue);
    await pickMood(tester, 'low');
    expect(moodSelected(tester, 'tired'), isFalse);
    expect(moodSelected(tester, 'low'), isTrue);
    await pickMood(tester, 'low');
    expect(moodSelected(tester, 'low'), isFalse);
    await pickMood(tester, 'calm');
    await tap(tester, 'Clear');
    expect(moodSelected(tester, 'calm'), isFalse);
    expect(tester.takeException(), isNull);
  });

  diaryTest('themes turn into tags as they are finished, up to three', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: diaryTitleLocation(date),
      diary: repo,
    );
    final field = find.byKey(const ValueKey('diary-day-themes-field'));
    String draft() => tester.widget<TextField>(field).controller!.text;
    await tester.enterText(field, 'Work,');
    await tester.pump();
    expect(find.byType(DiaryThemeTag), findsOneWidget);
    expect(draft(), isEmpty);
    await tester.enterText(field, 'work,');
    await tester.pump();
    expect(find.byType(DiaryThemeTag), findsOneWidget, reason: 'duplicate');
    await tester.enterText(field, 'Family');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(DiaryThemeTag), findsNWidgets(2));
    expect(draft(), isEmpty);
    await tester.enterText(field, 'Rain,');
    await tester.pump();
    expect(find.byType(DiaryThemeTag), findsNWidgets(3));
    expect(field, findsNothing, reason: 'Three is the limit.');
    await removeTheme(tester, 'Family');
    expect(find.byType(DiaryThemeTag), findsNWidgets(2));
    expect(field, findsOneWidget);
    // A theme still being typed is kept by Save rather than lost.
    await tester.enterText(field, 'Garden');
    await tap(tester, 'Save day');
    expect((await storedDay(tester)).themes, ['Work', 'Rain', 'Garden']);
    expect(tester.takeException(), isNull);
  });

  diaryTest('the Grand Maestar only appears when AI is available', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: diaryTitleLocation(date),
      diary: repo,
    );
    expect(find.byKey(const ValueKey('diary-day-ai')), findsNothing);
    expect(find.byKey(const ValueKey('diary-day-maestar')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await pumpApp(
      tester,
      initialLocation: diaryTitleLocation(date),
      diary: repo,
      aiEnabled: true,
    );
    final portrait = tester.widget<Image>(
      find.byKey(const ValueKey('diary-day-maestar')),
    );
    final source = (portrait.image as ResizeImage).imageProvider as AssetImage;
    expect(source.assetName, 'assets/branding/grand_maestar.png');
    expect(tester.takeException(), isNull);
  });

  diaryTest('the writing rules match the text lines and scroll with them', (
    tester,
  ) async {
    await seed(body: List.filled(80, 'A line with 👩🏽‍💻').join('\n'));
    await pumpApp(
      tester,
      initialLocation: diaryEntryLocation(date, id, edit: true),
      diary: repo,
    );
    final rules = find.byKey(const ValueKey('diary-writing-rules'));
    DiaryRulesPainter painter() =>
        tester.widget<CustomPaint>(rules).painter! as DiaryRulesPainter;
    final field = tester.state<EditableTextState>(find.byType(EditableText));
    expect(
      painter().spacing,
      moreOrLessEquals(field.renderEditable.preferredLineHeight),
    );
    final height = tester.getSize(rules).height;
    expect(painter().visibleRules(height).first, painter().firstRule);
    tester
        .widget<TextField>(find.byKey(const ValueKey('diary-body')))
        .scrollController!
        .jumpTo(211);
    await tester.pump();
    final offset = painter().offset.value;
    expect(offset, 211);
    final visible = painter().visibleRules(height).toList();
    expect(visible.length, lessThan(height / painter().spacing + 2));
    for (final y in visible) {
      final place = (y + offset - painter().firstRule) / painter().spacing;
      expect(place, moreOrLessEquals(place.roundToDouble()));
      expect(y, inInclusiveRange(0, height));
    }
    expect(tester.takeException(), isNull);
  });

  diaryTest('typing leaves the paper and rules alone', (tester) async {
    await pumpApp(
      tester,
      initialLocation: diaryDayLocation(date),
      diary: repo,
      diaryId: () => id,
    );
    await tap(tester, 'Write an entry');
    final body = find.byKey(const ValueKey('diary-body'));
    // The first word enables Save, which legitimately repaints its paper.
    await tester.enterText(body, 'W');
    await tester.pumpAndSettle();
    addTearDown(tester.view.resetViewInsets);

    final paper = DiaryPaperStamp.debugPaints;
    final rules = DiaryRulesPainter.debugPaints;
    for (final text in ['Wo', 'Wor', 'Word', 'Words']) {
      await tester.enterText(body, text);
      await tester.pump();
    }
    expect(DiaryPaperStamp.debugPaints, paper, reason: 'typing, paper');
    expect(DiaryRulesPainter.debugPaints, rules, reason: 'typing, rules');

    // Every frame of the keyboard sliding up.
    for (final inset in [80.0, 160.0, 240.0, 320.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump();
    }
    expect(DiaryPaperStamp.debugPaints, paper, reason: 'keyboard, paper');
    tester.view.resetViewInsets();
    await tester.pump();

    // Scrolling redraws the rules, and never the paper.
    await tester.enterText(body, List.filled(80, 'Line').join('\n'));
    await tester.pump();
    final scrolled = DiaryRulesPainter.debugPaints;
    final settledPaper = DiaryPaperStamp.debugPaints;
    tester.widget<TextField>(body).scrollController!.jumpTo(120);
    await tester.pump();
    expect(DiaryRulesPainter.debugPaints, scrolled + 1);
    expect(DiaryPaperStamp.debugPaints, settledPaper, reason: 'scroll, paper');
  });

  diaryTest('only today\'s page is pinned', (tester) async {
    Finder pin() => find.byWidgetPredicate(
      (widget) =>
          widget is DiaryArtwork && widget.assetKey == 'diary.calendar.pin',
    );
    await seed();
    await seed(key: '2' * 32, day: date.shift(-1));
    await pumpApp(
      tester,
      initialLocation: diaryEntryLocation(date, id, edit: true),
      diary: repo,
    );
    expect(
      find.descendant(of: find.byType(DiaryEditPage), matching: pin()),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await pumpApp(
      tester,
      initialLocation: diaryEntryLocation(
        date.shift(-1)!,
        '2' * 32,
        edit: true,
      ),
      diary: repo,
    );
    expect(find.byKey(const ValueKey('diary-writing-rules')), findsOneWidget);
    expect(
      find.descendant(of: find.byType(DiaryEditPage), matching: pin()),
      findsNothing,
    );
  });

  diaryTest('simpler effects leave only paper and rules', (tester) async {
    await seed();
    final appearance = FakeAppearanceRepository(
      const AppearancePreferences(simplerEffects: true),
    );
    addTearDown(appearance.close);
    await pumpApp(
      tester,
      initialLocation: diaryEntryLocation(date, id, edit: true),
      diary: repo,
      repository: appearance,
    );
    expect(find.byType(DiaryWritingBackdrop), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DiaryEditPage),
        matching: find.byType(DiaryArtwork),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('diary-writing-rules')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    await tap(tester, 'Save');
    expect(find.textContaining('Save failed.'), findsOneWidget);
    expect((await repo.openDocument(id)).entry, isNull);
    repo.failCommit = false;
    repo.commitGate = Completer<void>();
    final saving = tester
        .container()
        .read(diaryEditorProvider(address).notifier)
        .save();
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    repo.commitGate!.complete();
    await saving;
    await tester.pumpAndSettle();
    expect(find.textContaining('Save failed.'), findsNothing);
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
      expect(find.text('Discard your edits?'), findsOneWidget);
      expect(
        find.text('Your saved entry will stay as it was.'),
        findsOneWidget,
      );
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
      await tester.enterText(
        find.byKey(const ValueKey('diary-body')),
        'Thrown away',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
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
      final match = find.byKey(const ValueKey('diary-search-match-0'));
      expect(
        find.descendant(of: match, matching: find.text('lake 工作')),
        findsOneWidget,
      );
      await tester.tap(match);
      await tester.pumpAndSettle();
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
          await tester.enterText(
            find.byKey(const ValueKey('diary-day-title-field')),
            'Large text heading',
          );
          await tap(tester, 'Save day');
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
          await tap(tester, 'Save');
          expect((await repo.openDocument(id)).entry!.revision, 2);
          router.go(diaryEntryLocation(date, id, edit: true));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('diary-body')),
            'Large text unsaved',
          );
          await tester.pumpAndSettle();
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tap(tester, 'Keep writing');
          expect(tester.takeException(), isNull);
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
