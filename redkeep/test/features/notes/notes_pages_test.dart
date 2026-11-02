import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/app/app_router.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/application/note_editor_controller.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/domain/notes_query.dart';

import '../../support/controlled_notes_repository.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';

const id = '11111111111111111111111111111111';

void main() {
  void noteTest(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    });
  }

  late AppDatabase db;
  late ControlledNotesRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ControlledNotesRepository(
      DriftNotesRepository(db, clock: () => DateTime.utc(2026, 11, 2)),
    );
  });
  tearDown(() => db.close());

  Future<void> tap(WidgetTester tester, String text) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final control = find.text(text);
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
    bool committed = true,
    String body = 'Synthetic writing 👩🏽‍💻 العربية e\u0301',
  }) async {
    final draft = await repo.putDraft(
      id: id,
      text: PlainTextDocument(title: 'Synthetic note', body: body),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    if (committed) await repo.commitDraft(id, draft.draftRevision);
  }

  noteTest('create, committed feedback, read, edit and confirmed deletion', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/notes',
      notes: repo,
      noteId: () => id,
    );
    await tester.scrollUntilVisible(
      find.text('No saved notes yet. Create your first note.'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(tester, 'Create note');
    expect(
      router.routeInformationProvider.value.uri.path,
      noteLocation(id, edit: true),
    );
    await tester.enterText(find.byKey(const ValueKey('note-title')), 'My note');
    await tester.enterText(
      find.byKey(const ValueKey('note-body')),
      'Hello 👩🏽‍💻\nHabari • 中文',
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Save note');
    expect(find.text('Saved revision 1 on this device.'), findsOneWidget);
    await tap(tester, 'Read committed note');
    expect(find.text('Hello 👩🏽‍💻\nHabari • 中文'), findsOneWidget);
    await tap(tester, 'Edit note');
    await tester.enterText(
      find.byKey(const ValueKey('note-body')),
      'Revised writing',
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Save note');
    expect(find.text('Saved revision 2 on this device.'), findsOneWidget);
    await tap(tester, 'Read committed note');
    await tap(tester, 'Delete note');
    await tap(tester, 'Keep note');
    expect((await repo.openDocument(id)).available, isTrue);
    await tap(tester, 'Delete note');
    await tap(tester, 'Delete');
    expect(router.routeInformationProvider.value.uri.path, '/notes');
    expect((await repo.openDocument(id)).note!.text.body, 'Revised writing');
    expect((await repo.openDocument(id)).available, isFalse);
    router.go(noteLocation(id));
    await tester.pumpAndSettle();
    expect(find.text('Note unavailable'), findsOneWidget);
    expect(find.text('Revised writing'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  noteTest(
    'back retains draft, navigation reopens it and discard keeps committed note',
    (tester) async {
      await seed();
      final router = await pumpApp(
        tester,
        initialLocation: noteLocation(id, edit: true),
        notes: repo,
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-body')),
        'Uncommitted navigation writing',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, noteLocation(id));
      expect(find.text('Resume draft'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Recovery drafts'), findsOneWidget);
      await tap(tester, 'Recovery draft • from revision 1');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note-body')))
            .controller!
            .text,
        'Uncommitted navigation writing',
      );
      await tap(tester, 'Discard draft');
      await tap(tester, 'Keep writing');
      expect((await repo.openDocument(id)).draft, isNotNull);
      await tap(tester, 'Discard draft');
      await tap(tester, 'Discard');
      expect((await repo.openDocument(id)).draft, isNull);
      expect((await repo.openDocument(id)).note!.revision, 1);
      expect(router.routeInformationProvider.value.uri.path, '/notes');
      expect(tester.takeException(), isNull);
    },
  );

  noteTest(
    'failed save and recovery retain text, block unsafe back and retry',
    (tester) async {
      await seed(committed: false);
      final router = await pumpApp(
        tester,
        initialLocation: noteLocation(id, edit: true),
        notes: repo,
      );
      repo.failDraft = true;
      await tester.enterText(
        find.byKey(const ValueKey('note-body')),
        'Retain this buffer',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        noteLocation(id, edit: true),
      );
      expect(
        find.textContaining('Recovery could not be saved'),
        findsOneWidget,
      );
      repo.failDraft = false;
      await tap(tester, 'Retry recovery');
      repo.failCommit = true;
      await tap(tester, 'Save note');
      expect(find.textContaining('Save failed.'), findsOneWidget);
      expect(
        (await repo.openDocument(id)).draft!.text.body,
        'Retain this buffer',
      );
      repo.failCommit = false;
      repo.commitGate = Completer<void>();
      final container = tester.container();
      final saving = container.read(noteEditorProvider(id).notifier).save();
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(
        find.textContaining('Saved revision 1 on this device.'),
        findsNothing,
      );
      repo.commitGate!.complete();
      await saving;
      await tester.pumpAndSettle();
      expect(find.text('Saved revision 1 on this device.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  noteTest(
    'missing IDs, draft-only IDs, list/read errors and creation failures recover',
    (tester) async {
      final router = await pumpApp(
        tester,
        initialLocation: noteLocation(id),
        notes: repo,
        noteId: () => id,
      );
      expect(find.text('Note unavailable'), findsOneWidget);
      await tap(tester, 'Return to Notes');
      repo.failDraft = true;
      await tap(tester, 'Create note');
      expect(
        find.textContaining('A draft could not be created'),
        findsOneWidget,
      );
      repo.failDraft = false;
      await tap(tester, 'Create note');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open recovery draft'), findsOneWidget);
      repo.failRead = true;
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, initialLocation: '/notes', notes: repo);
      await tester.scrollUntilVisible(
        find.text('Notes could not be loaded.'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Notes could not be loaded.'), findsOneWidget);
      repo.failRead = false;
      while (find.text('Retry loading').evaluate().isNotEmpty) {
        await tester.ensureVisible(find.text('Retry loading').first);
        await tester.tap(find.text('Retry loading').first);
        await tester.pumpAndSettle();
      }
      expect(
        find.text('No saved notes yet. Create your first note.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      // Router from the first disposed scope is intentionally never reused.
      expect(router, isNotNull);
    },
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final simple in [false, true]) {
      noteTest(
        'all notes layouts at 320px, 3x text, keyboard; $theme simple=$simple',
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
            initialLocation: '/notes',
            notes: repo,
            repository: appearance,
          );
          expect(tester.takeException(), isNull);
          router.go(noteLocation(id));
          await tester.pumpAndSettle();
          expect(find.text('Saved revision 1'), findsOneWidget);
          await tap(tester, 'Markdown preview');
          expect(tester.takeException(), isNull);
          await tap(tester, 'Show plain text');
          await tap(tester, 'Edit tags');
          await tester.enterText(
            find.byKey(const ValueKey('note-tags')),
            '工作, travel',
          );
          await tap(tester, 'Cancel');
          await tap(tester, 'Delete note');
          await tap(tester, 'Keep note');
          expect(tester.takeException(), isNull);
          router.go(noteLocation(id, edit: true));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('note-body')),
            'Large text writing 👩🏽‍💻',
          );
          await tester.pumpAndSettle();
          await tap(tester, 'Save note');
          expect(find.text('Saved revision 2 on this device.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  noteTest(
    'large plain-text body opens for reading and editing without transformation',
    (tester) async {
      final text = List.filled(5000, 'Unicode 👩🏽‍💻 e\u0301 中文\n').join();
      await seed(body: text);
      final router = await pumpApp(
        tester,
        initialLocation: noteLocation(id),
        notes: repo,
      );
      expect(find.text(text), findsOneWidget);
      router.go(noteLocation(id, edit: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note-body')))
            .controller!
            .text,
        text,
      );
      expect(tester.takeException(), isNull);
    },
  );

  noteTest(
    'switching IDs replaces the editor buffer and preserves each draft',
    (tester) async {
      await seed(committed: false);
      const other = '22222222222222222222222222222222';
      await repo.putDraft(
        id: other,
        text: const PlainTextDocument(title: 'Other', body: 'Other buffer'),
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      final router = await pumpApp(
        tester,
        initialLocation: noteLocation(id, edit: true),
        notes: repo,
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-body')),
        'First buffer',
      );
      await tester.pumpAndSettle();
      router.go(noteLocation(other, edit: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note-body')))
            .controller!
            .text,
        'Other buffer',
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-body')),
        'Second buffer',
      );
      await tester.pumpAndSettle();
      router.go(noteLocation(id, edit: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note-body')))
            .controller!
            .text,
        'First buffer',
      );
      expect(
        (await repo.openDocument(other)).draft!.text.body,
        'Second buffer',
      );
      expect(tester.takeException(), isNull);
    },
  );

  noteTest('back waits for a pending recovery commit before leaving', (
    tester,
  ) async {
    await seed(committed: false);
    final router = await pumpApp(
      tester,
      initialLocation: noteLocation(id, edit: true),
      notes: repo,
    );
    repo.draftGate = Completer<void>();
    await tester.enterText(
      find.byKey(const ValueKey('note-body')),
      'Pending recovery',
    );
    await tester.pump();
    await tester.pageBack();
    await tester.pump();
    expect(
      router.routeInformationProvider.value.uri.path,
      noteLocation(id, edit: true),
    );
    repo.draftGate!.complete();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, noteLocation(id));
    expect((await repo.openDocument(id)).draft!.text.body, 'Pending recovery');
    expect(tester.takeException(), isNull);
  });

  noteTest('warm navigation retains a failed in-memory buffer for reopening', (
    tester,
  ) async {
    await seed(committed: false);
    final router = await pumpApp(
      tester,
      initialLocation: noteLocation(id, edit: true),
      notes: repo,
    );
    repo.failDraft = true;
    await tester.enterText(
      find.byKey(const ValueKey('note-body')),
      'Memory retained across platform navigation',
    );
    await tester.pumpAndSettle();
    router.go('/notes');
    await tester.pumpAndSettle();
    router.go(noteLocation(id, edit: true));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!
          .text,
      'Memory retained across platform navigation',
    );
    repo.failDraft = false;
    await tap(tester, 'Retry recovery');
    expect(
      (await repo.openDocument(id)).draft!.text.body,
      'Memory retained across platform navigation',
    );
  });
  noteTest(
    'pin, tags, combined filters and explicit trash restoration/deletion',
    (tester) async {
      await seed();
      final router = await pumpApp(
        tester,
        initialLocation: noteLocation(id),
        notes: repo,
      );
      await tap(tester, 'Pin note');
      expect((await repo.openDocument(id)).note!.pinned, isTrue);
      await tap(tester, 'Edit tags');
      await tester.enterText(
        find.byKey(const ValueKey('note-tags')),
        ' Travel, TRAVEL, 工作',
      );
      await tap(tester, 'Save tags');
      expect((await repo.openDocument(id)).note!.tags, ['travel', '工作']);
      router.go('/notes');
      await tester.pumpAndSettle();
      await tap(tester, 'Search and filters');
      await tester.enterText(
        find.byKey(const ValueKey('notes-search')),
        'synthetic',
      );
      await tap(tester, 'Pinned only');
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('travel').last);
      await tester.pumpAndSettle();
      expect(tester.container().read(notesFilterProvider).tag, 'travel');
      await tester.scrollUntilVisible(
        find.text('Synthetic note'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tap(tester, 'Synthetic note');
      await tap(tester, 'Delete note');
      await tap(tester, 'Delete');
      await tester.scrollUntilVisible(
        find.text('No notes match these filters.'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      router.go(noteLocation(id));
      await tester.pumpAndSettle();
      expect(find.text('Note unavailable'), findsOneWidget);
      expect(
        find.text('Synthetic writing 👩🏽‍💻 العربية e\u0301'),
        findsNothing,
      );
      await tap(tester, 'Restore note');
      expect(find.text('Note unavailable'), findsNothing);
      expect((await repo.openDocument(id)).note!.tags, ['travel', '工作']);
      await tap(tester, 'Delete note');
      await tap(tester, 'Delete');
      tester
          .container()
          .read(notesFilterProvider.notifier)
          .set(const NotesQuery(trash: true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Synthetic note'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tap(tester, 'Synthetic note');
      await tap(tester, 'Delete forever');
      final delete = find.widgetWithText(FilledButton, 'Delete permanently');
      expect(tester.widget<FilledButton>(delete).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('delete-confirmation')),
        'delete',
      );
      expect(tester.widget<FilledButton>(delete).onPressed, isNull);
      await tap(tester, 'Keep in Trash');
      expect((await repo.openDocument(id)).note, isNotNull);
      await tap(tester, 'Delete forever');
      await tester.enterText(
        find.byKey(const ValueKey('delete-confirmation')),
        'DELETE',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Delete permanently');
      expect((await repo.openDocument(id)).note, isNull);
      expect(router.routeInformationProvider.value.uri.path, '/notes');
      router.go(noteLocation(id, edit: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('Editor unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  noteTest('artwork uses a bounded file decode and large lists build lazily', (
    tester,
  ) async {
    await db.transaction(() async {
      for (var i = 1; i <= 2000; i++) {
        await db.customStatement(
          'INSERT INTO notes (id, title, body, revision, created_at, updated_at) VALUES (?, ?, ?, 1, 0, ?)',
          [i.toRadixString(16).padLeft(32, '0'), 'Synthetic $i', 'Body', i],
        );
      }
    });
    await pumpApp(tester, initialLocation: '/notes', notes: repo);
    final art = tester.widgetList<Image>(find.byType(Image)).single;
    expect(art.image, isA<ResizeImage>());
    expect((art.image as ResizeImage).width, 120);
    expect(find.byType(ListTile).evaluate().length, lessThan(20));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });
  noteTest(
    'restore remains available with recovery writing; permanent deletion removes reviewed draft',
    (tester) async {
      await seed();
      await repo.putDraft(
        id: id,
        text: const PlainTextDocument(
          body: 'Retain recovery until deliberate deletion',
        ),
        baseRevision: 1,
        expectedDraftRevision: null,
      );
      await repo.deleteNote(id, 1);
      await pumpApp(tester, initialLocation: noteLocation(id), notes: repo);
      await tap(tester, 'Restore note');
      expect((await repo.openDocument(id)).available, isTrue);
      expect(
        (await repo.openDocument(id)).draft!.text.body,
        'Retain recovery until deliberate deletion',
      );
      await tap(tester, 'Delete note');
      await tap(tester, 'Delete');
      tester.container().read(appRouterProvider).go(noteLocation(id));
      await tester.pumpAndSettle();
      await tap(tester, 'Delete forever');
      await tester.enterText(
        find.byKey(const ValueKey('delete-confirmation')),
        'DELETE',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Delete permanently');
      expect((await repo.openDocument(id)).note, isNull);
      expect((await repo.openDocument(id)).draft, isNull);
    },
  );
}
