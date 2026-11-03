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
  Future<void> tap(WidgetTester tester, String label) async {
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

  Future<void> seed({
    bool commit = true,
    String body = 'Exact writing 👩🏽‍💻 中文 e\u0301',
    String key = id,
    CivilDate? day,
  }) async {
    final draft = await repo.putDraft(
      id: key,
      date: day ?? date,
      text: DiaryText(title: 'Synthetic entry', body: body),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    if (commit) await repo.commitDraft(key, draft.draftRevision);
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
        tester.widget<Text>(find.text('Synthetic entry')).style!.fontFamily,
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
        tester.widget<Text>(find.text('Synthetic entry')).style!.fontFamily,
        'Poppins',
      );
      expect(
        tester
            .widget<Text>(find.text('Exact writing stays unchanged'))
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
        find.text('No entries for this day. Write whenever you are ready.'),
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
    'selected calendar month, date steps and heading survive entry visits',
    (tester) async {
      final leap = CivilDate(2024, 2, 29);
      final router = await pumpApp(
        tester,
        initialLocation: diaryCalendarLocation(leap),
        diary: repo,
      );
      expect(find.text('2024-02 calendar'), findsOneWidget);
      await tap(tester, '29');
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
      await tap(tester, 'Save heading');
      expect(find.text('Leap day notebook'), findsOneWidget);
      await tap(tester, 'Calendar for this month');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryCalendarLocation(leap),
      );
      expect(find.text('2024-02 calendar'), findsOneWidget);
      await tap(tester, 'Next month');
      expect(find.text('2024-03 calendar'), findsOneWidget);
      await tap(tester, 'Open today');
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
      final control = find.bySemanticsLabel('2024-02-29');
      await tester.scrollUntilVisible(
        control,
        160,
        scrollable: find.byType(Scrollable).first,
      );
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

  diaryTest(
    'failed recovery blocks back, warm navigation retains buffer, commit waits and retry succeeds',
    (tester) async {
      await seed(commit: false);
      final router = await pumpApp(
        tester,
        initialLocation: diaryEntryLocation(date, id, edit: true),
        diary: repo,
      );
      repo.failDraft = true;
      await tester.enterText(
        find.byKey(const ValueKey('diary-body')),
        'Retain this buffer',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryEntryLocation(date, id, edit: true),
      );
      router.go('/diary');
      await tester.pumpAndSettle();
      router.go(diaryEntryLocation(date, id, edit: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('diary-body')))
            .controller!
            .text,
        'Retain this buffer',
      );
      repo.failDraft = false;
      await tap(tester, 'Retry recovery');
      repo.failCommit = true;
      await tap(tester, 'Save entry');
      expect(find.textContaining('Save failed.'), findsOneWidget);
      expect(
        (await repo.openDocument(id)).draft!.text.body,
        'Retain this buffer',
      );
      repo.failCommit = false;
      repo.commitGate = Completer<void>();
      final saving = tester
          .container()
          .read(diaryEditorProvider(address).notifier)
          .save();
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(find.text('Saved revision 1 on this device.'), findsNothing);
      repo.commitGate!.complete();
      await saving;
      await tester.pumpAndSettle();
      expect(find.text('Saved revision 1 on this device.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  diaryTest(
    'draft reopened after a fresh scope; discard keeps committed entry; wrong dates hide source and draft',
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
      expect(find.text('Recover draft'), findsOneWidget);
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
        'Recovered writing',
      );
      await tap(tester, 'Discard draft');
      await tap(tester, 'Discard');
      expect((await repo.openDocument(id)).draft, isNull);
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
    'search crosses days, opens selected entry and excludes deleted text',
    (tester) async {
      await seed(body: 'lake 工作');
      await seed(body: 'Other day lake', key: '2' * 32, day: date.shift(1));
      final router = await pumpApp(
        tester,
        initialLocation: '/diary/search',
        diary: repo,
      );
      await tester.enterText(find.byType(TextField), 'lake 工作');
      await tester.pumpAndSettle();
      expect(find.text(date.key), findsOneWidget);
      expect(find.text(date.shift(1)!.key), findsNothing);
      await tap(tester, 'Synthetic entry');
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryEntryLocation(date, id),
      );
      await repo.deleteEntry(id, 1);
      router.go('/diary/search');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '工作');
      await tester.pumpAndSettle();
      expect(find.text('No matching entries.'), findsOneWidget);
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
          await tester.scrollUntilVisible(
            find.byKey(ValueKey(simple ? 'notebook-simple' : 'notebook-bound')),
            160,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            find.byKey(ValueKey(simple ? 'notebook-simple' : 'notebook-bound')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          router.go(diaryDayLocation(date));
          await tester.pumpAndSettle();
          await tap(tester, 'Name this day');
          await tester.enterText(find.byType(TextField), 'Large text heading');
          await tap(tester, 'Save heading');
          expect(find.text('Large text heading'), findsOneWidget);
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
          await tap(tester, 'Discard draft');
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
