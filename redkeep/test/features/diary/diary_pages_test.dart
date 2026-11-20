import 'dart:ui' show SemanticsAction, SemanticsActionEvent;
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/emoji_sphere/emoji_catalog.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/application/diary_editor_controller.dart';
import 'package:redkeep/features/diary/presentation/diary_scene.dart';
import 'package:redkeep/features/diary/presentation/diary_calendar_page.dart';
import 'package:redkeep/features/diary/presentation/diary_artwork.dart';
import 'package:redkeep/features/diary/presentation/diary_day_page.dart';
import 'package:redkeep/features/diary/presentation/diary_edit_page.dart';
import 'package:redkeep/features/diary/presentation/diary_paper_stamp.dart';
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
import '../../support/diary_reader.dart';

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
    if (label == 'Choose mood') {
      // The selected day's own tab on the thread asks for its mood.
      FocusManager.instance.primaryFocus?.unfocus();
      tester
          .state<NestedScrollViewState>(find.byType(NestedScrollView).last)
          .outerController
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byKey(
              ValueKey(
                'diary-calendar-date-${date.calendarDate.toIso8601String()}',
              ),
            )
            .hitTestable()
            .first,
      );
      await tester.pumpAndSettle();
      return;
    }
    if (label == 'Calendar for this month') {
      // The month above the thread shows only on the resting page.
      FocusManager.instance.primaryFocus?.unfocus();
      tester
          .state<NestedScrollViewState>(find.byType(NestedScrollView).last)
          .outerController
          .jumpTo(0);
      await tester.pumpAndSettle();
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

  /// Searches the open mood picker's emoji sphere for [query].
  Future<void> pickMood(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const ValueKey('emoji-sphere-search')),
      query,
    );
    await tester.pumpAndSettle();
  }

  /// Lets a mood save reach the database.
  Future<void> settleSave(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  /// Finds a mood in the open picker and goes back, which keeps it.
  Future<void> chooseMood(WidgetTester tester, String query) async {
    await pickMood(tester, query);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await settleSave(tester);
  }

  /// The open picker's sphere has [mood] in its lens.
  Finder moodOnOffer(DiaryMood mood) => find.descendant(
    of: find.byKey(const ValueKey('diary-mood-picker')),
    matching: find.text(EmojiCatalog.bundled().find(mood.emoji)!.name),
  );

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
    'saved day titles stay hidden; entry readers and editors use the body font',
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
      goDiaryDay(tester, router, date);
      await tester.pumpAndSettle();
      expect(liveText('A quiet day'), findsNothing);
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
        initialLocation: '/diary',
        diaryDay: date,
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
      expectDiaryDay(tester, router, date);
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
      expectDiaryDay(tester, router, date);
      expect((await repo.openDocument(id)).entry!.text.body, '');
      router.go(diaryEntryLocation(date, id));
      await tester.pumpAndSettle();
      expect(find.text('Entry unavailable'), findsOneWidget);
      expect(find.text('Revised writing'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  diaryTest(
    "the selected day's tab sets and clears its mood, keeping title and entries",
    (tester) async {
      await seed();
      await repo.saveDay(
        DiaryDay(date: date, heading: 'A kept title', themes: ['Work']),
      );
      final original = (await repo.openDocument(id)).entry!;
      final router = await pumpApp(
        tester,
        initialLocation: '/diary',
        diaryDay: date,
        diary: repo,
      );
      // Titles stay in the database but no longer show on the page.
      expect(liveText('A kept title'), findsNothing);
      expect(find.byKey(const ValueKey('diary-calendar-mood')), findsNothing);

      await tap(tester, 'Choose mood');
      expect(find.byKey(const ValueKey('diary-mood-picker')), findsOneWidget);
      // The sphere opens on the first preset, but leaving it untouched
      // sets nothing; with no mood there is nothing to clear.
      expect(moodOnOffer(DiaryMood.happy), findsOneWidget);
      expect(find.byKey(const ValueKey('diary-mood-clear')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(find.byKey(const ValueKey('diary-mood-picker')), findsNothing);
      expect((await storedDay(tester)).mood, isNull);

      // Turning to a mood and going back keeps it.
      await tap(tester, 'Choose mood');
      await chooseMood(tester, 'calm');
      expect(find.byKey(const ValueKey('diary-mood-picker')), findsNothing);
      expectDiaryDay(tester, router, date);
      final saved = await storedDay(tester);
      expect(saved.mood, DiaryMood.calm);
      expect(saved.heading, 'A kept title');
      expect(saved.themes, ['Work']);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('diary-calendar-mood')),
          matching: find.text('😌'),
        ),
        findsOneWidget,
      );
      // The mood lives on the tab only, not as a line on the page.
      expect(liveText('😌 Calm'), findsNothing);

      // A tap on the solid middle keeps the picker; one on the faded edge
      // closes it, changing nothing while the sphere is untouched...
      await tap(tester, 'Choose mood');
      expect(moodOnOffer(DiaryMood.calm), findsOneWidget);
      await tester.tap(find.text('How did it feel?'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('diary-mood-picker')), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect(find.byKey(const ValueKey('diary-mood-picker')), findsNothing);
      expect((await storedDay(tester)).mood, DiaryMood.calm);

      // ...and keeping whatever was turned into the lens.
      await tap(tester, 'Choose mood');
      await pickMood(tester, 'tired');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect((await storedDay(tester)).mood, DiaryMood.tired);

      // Clearing rubs it out.
      await tap(tester, 'Choose mood');
      await tester.tap(find.byKey(const ValueKey('diary-mood-clear')));
      await tester.pumpAndSettle();
      await settleSave(tester);
      expect((await storedDay(tester)).mood, isNull);
      expect((await storedDay(tester)).heading, 'A kept title');
      expect(find.byKey(const ValueKey('diary-calendar-mood')), findsNothing);
      final unchanged = (await repo.openDocument(id)).entry!;
      expect(unchanged.revision, original.revision);
      expect(unchanged.text.body, original.text.body);
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
      expectDiaryDay(tester, router, leap);
      await tap(tester, 'Next day');
      expectDiaryDay(tester, router, DiaryPeriod(2024, 3, 1));
      await tap(tester, 'Previous day');
      await tap(tester, 'Calendar for this month');
      expect(find.byType(DiaryCalendarPage), findsOneWidget);
      expect(find.text('February'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('calendar-year-tab-2026')));
      await tester.pumpAndSettle();
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
      expectDiaryDay(tester, router, date);
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
      expectDiaryDay(tester, router, DiaryPeriod(2024, 2, 29));
      handle.dispose();
    },
  );

  diaryTest('back from a new entry returns to the day', (tester) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/diary',
      diaryDay: date,
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
    expectDiaryDay(tester, router, date);
    expect(tester.takeException(), isNull);
  });

  diaryTest('turning days keeps the reader on one /diary page', (tester) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/diary',
      diary: repo,
    );
    final page = tester.state(find.byType(DiaryDayPage));
    await tap(tester, 'Previous day');
    expectDiaryDay(tester, router, date.shift(-1)!);
    // A new route page would replay a page transition over a fresh state.
    expect(find.byType(DiaryDayPage), findsOneWidget);
    expect(tester.state(find.byType(DiaryDayPage)), same(page));
    await tap(tester, 'Next day');
    expectDiaryDay(tester, router, date);
    expect(tester.state(find.byType(DiaryDayPage)), same(page));
  });

  diaryTest('a double tap on the prompt opens one editor', (tester) async {
    await pumpApp(
      tester,
      initialLocation: '/diary',
      diaryDay: date,
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
      initialLocation: '/diary',
      diaryDay: date,
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
    expectDiaryDay(tester, router, date);
    expect(liveText('A new page'), findsOneWidget);
  });

  diaryTest('a new entry for today can be saved as a text-only thought', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/diary',
      diaryDay: date,
      diary: repo,
      diaryId: () => id,
    );
    await tap(tester, 'Write an entry');
    final thought = find.byKey(const ValueKey('diary-save-thought'));
    expect(thought, findsOneWidget);
    expect(tester.widget<DiaryInkAction>(thought).onPressed, isNull);
    // Both ways to keep the writing sit at the foot of the page.
    final screen = tester.getSize(find.byType(DiaryEditPage));
    expect(tester.getCenter(thought).dy, greaterThan(screen.height / 2));
    expect(
      tester.getCenter(find.text('Save')).dy,
      greaterThan(screen.height / 2),
    );
    await tester.enterText(
      find.byKey(const ValueKey('diary-body')),
      'A passing thought',
    );
    await tester.pumpAndSettle();
    await tester.tap(thought);
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEditPage), findsNothing);
    expectDiaryDay(tester, router, date);
    expect(liveText('A passing thought'), findsOneWidget);
    expect(liveText('THOUGHT'), findsOneWidget);
    final saved = (await repo.openDocument(id)).entry!;
    expect(saved.isThought, isTrue);
    expect(saved.photos, isEmpty);

    // Editing keeps it a thought, with no photo option.
    router.go(diaryEntryLocation(date, id, edit: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diary-save-thought')), findsNothing);
    expect(find.byTooltip('Add photos'), findsNothing);
  });

  diaryTest('the thought button is only for new writing today', (tester) async {
    final yesterday = date.shift(-1)!;
    await repo.save(
      id: id,
      date: date,
      text: const DiaryText(body: 'Saved earlier'),
      expectedRevision: 0,
    );
    final router = await pumpApp(
      tester,
      initialLocation: '/diary',
      diaryDay: date,
      diary: repo,
      diaryId: () => '3' * 32,
    );
    router.go(diaryEntryLocation(date, id, edit: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diary-save-thought')), findsNothing);
    expect(liveText('THOUGHT'), findsNothing);
    router.go('/diary');
    await tester.pumpAndSettle();
    await tap(tester, 'Previous day');
    expectDiaryDay(tester, router, yesterday);
    await tap(tester, 'Write an entry');
    expect(find.byType(DiaryEditPage), findsOneWidget);
    expect(find.byKey(const ValueKey('diary-save-thought')), findsNothing);
    // Its place in the tray tells how much is written instead.
    expect(find.text('A blank page'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('diary-body')),
      'Rainy and slow',
    );
    await tester.pumpAndSettle();
    expect(find.text('3 words'), findsOneWidget);
  });

  diaryTest('back with unsaved writing asks before leaving', (tester) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/diary',
      diaryDay: date,
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
    expectDiaryDay(tester, router, date);
    expect((await repo.openDocument(id)).entry, isNull);
  });

  diaryTest('discard dialog buttons are real buttons at any text size', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      initialLocation: '/diary',
      diaryDay: date,
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
    expectDiaryDay(tester, router, date);
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
      initialLocation: '/diary',
      diaryDay: date,
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
      initialLocation: '/diary',
      diaryDay: date,
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
      expectDiaryDay(tester, router, date);
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
          goDiaryDay(tester, router, date);
          await tester.pumpAndSettle();
          await tap(tester, 'Choose mood');
          await chooseMood(tester, 'happy');
          expect((await storedDay(tester)).mood, DiaryMood.happy);
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
