import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_brain.dart';
import '../../support/fake_local_model.dart';
import '../../support/pump_app.dart';

const id = '11111111111111111111111111111111';
const secondId = '22222222222222222222222222222222';
const original = 'Before Mira planted a tree. After 😊';

void main() {
  late AppDatabase db;
  late DriftNotesRepository notes;
  late DriftDiaryRepository diary;
  late DriftFlowRepository flow;
  late FakeBrainAssignments assignments;
  late FakeBrainFiles files;
  late FakeModel model;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notes = DriftNotesRepository(db, clock: () => DateTime.utc(2026, 11, 3));
    diary = DriftDiaryRepository(db, clock: () => DateTime.utc(2026, 11, 3));
    flow = DriftFlowRepository(db, clock: () => DateTime.utc(2026, 11, 3));
    assignments = FakeBrainAssignments();
    for (final capability in BrainCapability.values) {
      assignments.values[capability] = qualifiedBrainModel.id;
    }
    files = FakeBrainFiles();
    model = FakeModel();
  });
  tearDown(() => db.close());

  void check(String name, Future<void> Function(WidgetTester) test) =>
      testWidgets(name, (tester) async {
        try {
          await test(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
  Future<void> seed({
    String key = id,
    String body = original,
    bool commit = true,
  }) async {
    final draft = await notes.putDraft(
      id: key,
      text: PlainTextDocument(title: 'Synthetic note', body: body),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    if (commit) await notes.commitDraft(key, draft.draftRevision);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    final button = find.byTooltip('Grand Maester').last;
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<GoRouter> start(
    WidgetTester tester,
    String location, {
    FakeAppearanceRepository? appearance,
  }) => pumpApp(
    tester,
    initialLocation: location,
    notes: notes,
    diary: diary,
    flow: flow,
    flowId: () => secondId,
    brainAssignments: assignments,
    brainFiles: files,
    brainLoader: (_, _) async => model,
    repository: appearance,
  );

  check(
    'saved note setup opens Brain; normal writing and helper opening never loads a model',
    (tester) async {
      await seed();
      assignments.values.clear();
      final router = await start(tester, '/notes/$id');
      expect(files.checks, 0);
      await open(tester);
      expect(find.text('Summarizing: needs setup in Brain.'), findsOneWidget);
      expect(find.text('Rewrite passage'), findsNothing);
      expect(find.text('Rewrite in editor'), findsOneWidget);
      expect(files.checks, 0);
      expect(model.sessions, isEmpty);
      await tap(tester, 'Open Brain');
      expect(router.routeInformationProvider.value.uri.path, '/settings/brain');
      expect((await notes.openDocument(id)).note!.text.body, original);
    },
  );

  check(
    'saved rewrite opens editor; reject leaves text; accepted selected rewrite stays draft until Save',
    (tester) async {
      await seed();
      await start(tester, '/notes/$id');
      await open(tester);
      await tap(tester, 'Rewrite in editor');
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-body')),
      );
      field.controller!.selection = const TextSelection(
        baseOffset: 7,
        extentOffset: 26,
      );
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.textContaining('Selected passage'), findsOneWidget);
      await tap(tester, 'Rewrite passage');
      expect(find.text('Accept replacement'), findsOneWidget);
      expect((await notes.openDocument(id)).note!.text.body, original);
      await tap(tester, 'Reject proposal');
      expect(field.controller!.text, original);
      expect((await notes.openDocument(id)).draft, isNull);
      await open(tester);
      await tap(tester, 'Rewrite passage');
      await tap(tester, 'Accept replacement');
      final expected = original.replaceRange(7, 26, 'one two');
      expect(field.controller!.text, expected);
      final accepted = await notes.openDocument(id);
      expect(accepted.note!.text.body, original);
      expect(accepted.draft!.text.body, expected);
      await tap(tester, 'Save note');
      final saved = await notes.openDocument(id);
      expect(saved.note!.text.body, expected);
      expect(saved.note!.revision, 2);
      expect(saved.draft, isNull);
    },
  );

  check(
    'new current text can be rewritten without committing a production source',
    (tester) async {
      await seed(commit: false);
      await start(tester, '/notes/$id/edit');
      await open(tester);
      await tap(tester, 'Rewrite passage');
      await tap(tester, 'Accept replacement');
      final opened = await notes.openDocument(id);
      expect(opened.note, isNull);
      expect(opened.draft!.text.title, 'Synthetic note');
      expect(opened.draft!.text.body, 'one two');
    },
  );

  for (final feature in [
    'note',
    'diary',
    'flow',
    'current diary',
    'current flow',
  ]) {
    check(
      '$feature summary/reflection views and copies without touching writing',
      (tester) async {
        String location;
        if (feature == 'note') {
          await seed();
          location = '/notes/$id';
        } else if (feature.contains('diary')) {
          await diary.save(
            id: id,
            date: CivilDate(2026, 11, 3),
            text: const DiaryText(title: 'Synthetic diary', body: original),
            expectedRevision: 0,
          );
          location =
              '/diary/2026-11-03/entries/$id${feature.startsWith('current') ? '/edit' : ''}';
        } else {
          await flow.save(id: id, body: original, expectedRevision: 0);
          location = '/flow/$id${feature.startsWith('current') ? '/edit' : ''}';
        }
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await start(tester, location);
        await open(tester);
        await tap(
          tester,
          feature.contains('flow') ? 'Reflect on thought' : 'Summarize text',
        );
        expect(find.text('Accept replacement'), findsNothing);
        expect(model.closed, 1);
        await tap(tester, 'Copy response');
        expect(copied, 'one two');
        await tap(tester, 'Close helper');
        if (feature == 'note') {
          expect((await notes.openDocument(id)).note!.text.body, original);
          expect((await notes.openDocument(id)).draft, isNull);
        } else if (feature.contains('diary')) {
          final current = await diary.openDocument(id);
          expect(current.entry!.text.body, original);
          expect(current.entry!.revision, 1);
        } else {
          final current = await flow.openDocument(id);
          expect(current.thought!.body, original);
        }
      },
    );
  }

  check('summarizing a new diary entry leaves its writing unsaved', (
    tester,
  ) async {
    await start(tester, '/diary/2026-11-03');
    await tap(tester, 'Write an entry');
    final field = find.byKey(const ValueKey('diary-body'));
    await tester.enterText(field, original);
    await tester.pumpAndSettle();
    await open(tester);
    await tap(tester, 'Summarize text');
    expect(find.text('one two'), findsOneWidget);
    await tap(tester, 'Close helper');
    expect(tester.widget<TextField>(field).controller!.text, original);
    expect(await diary.watchEntries().first, isEmpty);
    expect(await db.select(db.noteDrafts).get(), isEmpty);
  });

  check(
    'empty Flow offers no action; explicit current reflection preserves capture text',
    (tester) async {
      await start(tester, '/flow');
      await open(tester);
      expect(find.text('Write some text first.'), findsOneWidget);
      expect(find.text('Reflect on thought'), findsNothing);
      await tap(tester, 'Close helper');
      await tester.enterText(find.byKey(const ValueKey('flow-body')), original);
      await tester.pumpAndSettle();
      await open(tester);
      await tap(tester, 'Reflect on thought');
      await tap(tester, 'Close helper');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('flow-body')))
            .controller!
            .text,
        original,
      );
      expect((await db.select(db.flowThoughts).get()), isEmpty);
    },
  );

  for (final change in [
    'selection',
    'undo',
    'text',
    'source edit',
    'delete',
    'screen',
    'background',
  ]) {
    check(
      '$change during a response cancels and cannot apply to current writing',
      (tester) async {
        await seed();
        await seed(key: secondId, body: 'Other record');
        model.hold = true;
        final router = await start(tester, '/notes/$id/edit');
        await open(tester);
        await tap(tester, 'Rewrite passage');
        expect(find.text('Response · incomplete'), findsOneWidget);
        final body = tester
            .widget<TextField>(find.byKey(const ValueKey('note-body')))
            .controller!;
        switch (change) {
          case 'selection':
            body.selection = const TextSelection(
              baseOffset: 1,
              extentOffset: 5,
            );
          case 'undo':
            final before = body.value;
            body.selection = const TextSelection(
              baseOffset: 1,
              extentOffset: 5,
            );
            body.value = before;
          case 'text':
            // Go through the real editor boundary while the dialog covers the field.
            final field = tester.widget<TextField>(
              find.byKey(const ValueKey('note-body')),
            );
            body.text = 'New current writing';
            field.onChanged!('New current writing');
          case 'source edit':
            await notes.organize(id, 1, pinned: true, tags: []);
          case 'delete':
            await notes.deleteNote(id, 1);
          case 'screen':
            router.go('/notes/$secondId/edit');
          case 'background':
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.hidden,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.hidden,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
        }
        await tester.pumpAndSettle();
        expect(model.sessions.single.stopped, 1);
        expect(model.closed, 1);
        expect(find.text('Accept replacement'), findsNothing);
        expect(
          (await notes.openDocument(secondId)).note!.text.body,
          'Other record',
        );
        expect((await notes.openDocument(id)).note!.text.body, original);
        expect(tester.takeException(), isNull);
      },
    );
  }

  check(
    'cancel, failure and explicit retry never turn partial output into a replacement',
    (tester) async {
      await seed();
      model.hold = true;
      await start(tester, '/notes/$id/edit');
      await open(tester);
      await tap(tester, 'Rewrite passage');
      await tap(tester, 'Cancel response');
      expect(find.text('Accept replacement'), findsNothing);
      model.hold = false;
      model.failAt = 'stream';
      await tap(tester, 'Retry: Rewrite passage');
      expect(
        find.text(BrainException(BrainFailure.generation).message),
        findsOneWidget,
      );
      expect(find.text('Accept replacement'), findsNothing);
      model.failAt = null;
      await tap(tester, 'Retry: Rewrite passage');
      expect(find.text('Accept replacement'), findsOneWidget);
    },
  );

  check(
    'selection changed and undone before a frame cannot accept an older proposal',
    (tester) async {
      await seed();
      await start(tester, '/notes/$id/edit');
      await open(tester);
      await tap(tester, 'Rewrite passage');
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-body')),
      );
      final accept = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Accept replacement'),
          matching: find.byType(FilledButton),
        ),
      );
      final before = field.controller!.value;
      field.controller!.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 4,
      );
      field.controller!.value = before;
      accept.onPressed!();
      await tester.pumpAndSettle();
      expect(field.controller!.text, original);
      expect(find.text('Accept replacement'), findsNothing);
      expect((await notes.openDocument(id)).draft, isNull);
    },
  );

  check('a failed copy retains the reviewed response for another attempt', (
    tester,
  ) async {
    await seed();
    await start(tester, '/notes/$id');
    await open(tester);
    await tap(tester, 'Summarize text');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'synthetic');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tap(tester, 'Copy response');
    expect(
      find.text('Copy failed. Select the response to copy it again.'),
      findsOneWidget,
    );
    expect(find.text('one two'), findsOneWidget);
    expect((await notes.openDocument(id)).note!.text.body, original);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final simple in [false, true]) {
      check('helper/proposal 320px 3x safe keyboard $theme reduced=$simple', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final appearance = FakeAppearanceRepository(
          AppearancePreferences(
            theme: theme,
            reduceMotion: simple,
            simplerEffects: simple,
          ),
        );
        addTearDown(appearance.close);
        await seed();
        await start(tester, '/notes/$id/edit', appearance: appearance);
        await open(tester);
        await tap(tester, 'Rewrite passage');
        for (final label in [
          'Copy response',
          'Accept replacement',
          'Reject proposal',
        ]) {
          final finder = find.text(label);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(finder.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tap(tester, 'Reject proposal');
        expect(tester.takeException(), isNull);
      });
    }
  }

  check(
    'large Unicode body requires a bounded selected passage; no truncation of stored text',
    (tester) async {
      final long = '👩🏽‍💻 中文 e\u0301\n' * 1000;
      await seed(body: long);
      await start(tester, '/notes/$id/edit');
      await open(tester);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Rewrite passage'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(model.sessions, isEmpty);
      await tap(tester, 'Close helper');
      final body = tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!;
      body.selection = const TextSelection(baseOffset: 0, extentOffset: 28);
      await tester.pumpAndSettle();
      await open(tester);
      await tap(tester, 'Rewrite passage');
      await tap(tester, 'Accept replacement');
      expect(body.text, long.replaceRange(0, 28, 'one two'));
      expect((await notes.openDocument(id)).note!.text.body, long);
    },
  );
}
