import 'package:redkeep/features/notes/presentation/note_markdown_preview.dart';
import 'package:redkeep/features/assets/presentation/local_artwork.dart';
import 'package:redkeep/features/notes/presentation/note_card.dart';
import 'package:redkeep/features/notes/presentation/note_paper_surface.dart';
import 'package:redkeep/features/notes/presentation/note_paper.dart';
import 'package:redkeep/app/bottom_navbar.dart';

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

import 'package:redkeep/features/notes/presentation/note_read_page.dart';

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
    // Writing saves itself; leaving the editor is the only finish action.
    if (text == 'Save note' || text == 'Save' || text == 'Done') {
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      return;
    }
    if (text == 'Close editor') {
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      return;
    }
    if (text == 'Cancel' &&
        find.byTooltip('Cancel tags').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.byTooltip('Cancel tags'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cancel tags'));
      await tester.pumpAndSettle();
      return;
    }
    final noteActions = {
      'Pin note',
      'Unpin note',
      'Edit tags',
      'Markdown preview',
      'Show plain text',
      'Delete note',
    };
    if (noteActions.contains(text) && find.text(text).evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Note actions'));
      await tester.pumpAndSettle();
    }
    var control = find.text(text);
    if (control.evaluate().isEmpty &&
        find.byTooltip(text).evaluate().isNotEmpty) {
      control = find.byTooltip(text).last;
    } else {
      control = control.first;
    }
    if (control.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        control,
        160,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    final checked = find.ancestor(
      of: control,
      matching: find.byType(CheckedPopupMenuItem<String>),
    );
    if (checked.evaluate().isNotEmpty) control = checked.first;
    expect(control.hitTestable(), findsOneWidget);
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  Future<void> seed({
    String noteId = id,
    String title = 'Synthetic note',
    String body = 'Synthetic writing 👩🏽‍💻 العربية e\u0301',
  }) => repo.saveNote(
    id: noteId,
    text: PlainTextDocument(title: title, body: body),
    expectedRevision: 0,
    details: const NoteDetails(),
  );

  Finder bodyField() => find.byKey(const ValueKey('note-body'));
  String bodyText(WidgetTester tester) =>
      tester.widget<TextField>(bodyField()).controller!.text;
  String path(GoRouter router) =>
      router.routeInformationProvider.value.uri.path;

  double paperFold(WidgetTester tester) =>
      (tester
                  .widget<ClipPath>(
                    find
                        .descendant(
                          of: find.byType(NotePaper),
                          matching: find.byType(ClipPath),
                        )
                        .first,
                  )
                  .clipper!
              as NotePaperShape)
          .fold;

  noteTest(
    'there is no Drafts collection; a user tag named drafts is ordinary',
    (tester) async {
      await seed();
      await repo.organize(id, 1, pinned: true, tags: ['drafts']);
      const other = '22222222222222222222222222222222';
      await seed(noteId: other, title: 'Other saved note');
      final router = await pumpApp(
        tester,
        initialLocation: '/notes',
        notes: repo,
      );
      expect(find.byType(RedkeepBottomNavbar), findsOneWidget);
      expect(find.byType(NoteCard), findsNWidgets(2));
      expect(find.byKey(const ValueKey('notes-drafts')), findsNothing);
      expect(find.text('Draft'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('notes-tag-drafts')));
      await tester.pumpAndSettle();
      expect(tester.container().read(notesFilterProvider).tag, 'drafts');
      expect(find.byType(NoteCard), findsOneWidget);
      await tap(tester, 'Synthetic note');
      expect(path(router), noteLocation(id));
      expect(find.byType(RedkeepBottomNavbar), findsNothing);
      expect(bodyField(), findsNothing, reason: 'notes open for reading');
    },
  );

  for (final reducedMotion in [false, true]) {
    noteTest(
      'reading unfolds, Back collapses, and editing stays on the page; reduced=$reducedMotion',
      (tester) async {
        await seed(
          body: List.filled(80, 'A long line of writing to unfold.').join('\n'),
        );
        final appearance = FakeAppearanceRepository(
          AppearancePreferences(
            reduceMotion: reducedMotion,
            simplerEffects: reducedMotion,
          ),
        );
        addTearDown(appearance.close);
        final router = await pumpApp(
          tester,
          initialLocation: noteLocation(id),
          notes: repo,
          repository: appearance,
        );
        expect(paperFold(tester), greaterThan(0));
        expect(find.byType(RedkeepBottomNavbar), findsNothing);
        await tester.drag(
          find.byType(CustomScrollView).last,
          const Offset(0, -180),
        );
        await tester.pumpAndSettle();
        expect(paperFold(tester), 0);
        expect((await repo.openDocument(id)).note!.revision, 1);
        expect(path(router), noteLocation(id));
        await tap(tester, 'Back');
        expect(paperFold(tester), greaterThan(0));
        expect(
          router.routeInformationProvider.value.uri.path,
          noteLocation(id),
        );
        final readingPaper = tester.state(find.byType(NotePaper));
        await tap(tester, 'Edit note');
        expect(paperFold(tester), 0);
        // Editing is the same paper made editable: no navigation, no new page.
        expect(path(router), noteLocation(id));
        expect(tester.state(find.byType(NotePaper)), same(readingPaper));
        // While editing, pulling down cannot fold the paper back to preview.
        await tester.drag(
          find.byType(CustomScrollView).last,
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();
        expect(paperFold(tester), 0);
        await tester.enterText(bodyField(), 'Changed writing');
        await tester.pumpAndSettle();
        await tap(tester, 'Done');
        expect(path(router), noteLocation(id));
        expect(bodyField(), findsNothing);
        // Done returns to immersive reading on the same paper.
        expect(tester.state(find.byType(NotePaper)), same(readingPaper));
        expect(paperFold(tester), 0);
        expect(find.text('Changed writing'), findsOneWidget);
        // Back folds the immersive paper before leaving the note.
        await tap(tester, 'Back');
        expect(paperFold(tester), greaterThan(0));
        expect(
          (await repo.openDocument(id)).note!.text.body,
          'Changed writing',
        );
        await tap(tester, 'Back');
        expect(router.routeInformationProvider.value.uri.path, '/notes');
        expect(find.byType(RedkeepBottomNavbar), findsOneWidget);
      },
    );
  }

  noteTest('create, read, edit and confirmed deletion on one page', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/notes',
      notes: repo,
      noteId: () => id,
    );
    expect(find.text('Every idea\nstarts somewhere.'), findsOneWidget);
    await tap(tester, 'Create note');
    expect(router.routeInformationProvider.value.uri.path, noteLocation(id));
    await tester.enterText(find.byKey(const ValueKey('note-title')), 'My note');
    await tester.enterText(
      find.byKey(const ValueKey('note-body')),
      'Hello 👩🏽‍💻\nHabari • 中文',
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Done');
    expect(bodyField(), findsNothing);
    expect(find.text('Note unavailable'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is NoteMarkdownPreview &&
            widget.text == 'Hello 👩🏽‍💻\nHabari • 中文',
      ),
      findsOneWidget,
    );
    expect(
      (await repo.openDocument(id)).note!.text.body,
      'Hello 👩🏽‍💻\nHabari • 中文',
    );
    await tap(tester, 'Edit note');
    await tester.enterText(
      find.byKey(const ValueKey('note-body')),
      'Revised writing',
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Done');
    expect((await repo.openDocument(id)).note!.revision, 2);
    // Immersive reading offers only AI and Edit; folding shows the actions.
    expect(find.byTooltip('Note actions'), findsNothing);
    await tap(tester, 'Back');
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
    'back from a new note: empty returns to the list, writing shows the note',
    (tester) async {
      var next = 0;
      final ids = [id, '22222222222222222222222222222222'];
      final router = await pumpApp(
        tester,
        initialLocation: '/notes',
        notes: repo,
        noteId: () => ids[next++],
      );
      await tap(tester, 'Create note');
      expect(path(router), noteLocation(id));
      await tap(tester, 'Close editor');
      expect(path(router), '/notes');
      expect(find.text('Note unavailable'), findsNothing);
      expect(find.text('Open recovery draft'), findsNothing);
      expect((await repo.openDocument(id)).note, isNull);
      expect(find.text('Every idea\nstarts somewhere.'), findsOneWidget);

      await tap(tester, 'Create note');
      expect(path(router), noteLocation(ids[1]));
      await tester.enterText(find.byKey(const ValueKey('note-title')), 'Kept');
      await tester.enterText(bodyField(), 'Saved by going back');
      await tester.pumpAndSettle();
      // The system back gesture or button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // Writing saved itself; leaving the editor shows the note it made.
      expect(path(router), noteLocation(ids[1]));
      expect(bodyField(), findsNothing);
      expect(find.text('Kept'), findsOneWidget);
      expect(
        (await repo.openDocument(ids[1])).note!.text.body,
        'Saved by going back',
      );
      expect(tester.takeException(), isNull);
    },
  );

  noteTest('a failed save keeps editing open with the writing; retry leaves', (
    tester,
  ) async {
    await seed();
    final router = await pumpApp(
      tester,
      initialLocation: noteLocation(id),
      notes: repo,
    );
    await startEditing(tester);
    repo.failSave = true;
    await tester.enterText(bodyField(), 'Retain this buffer');
    await tester.pumpAndSettle();
    await tap(tester, 'Close editor');
    expect(path(router), noteLocation(id));
    expect(bodyText(tester), 'Retain this buffer');
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect((await repo.openDocument(id)).note!.revision, 1);
    repo.failSave = false;
    repo.saveGate = Completer<void>();
    await tester.tap(find.byTooltip('Close editor'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(bodyField(), findsOneWidget, reason: 'waits for the save');
    repo.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(bodyField(), findsNothing);
    expect(path(router), noteLocation(id));
    expect((await repo.openDocument(id)).note!.text.body, 'Retain this buffer');
    expect(tester.takeException(), isNull);
  });

  noteTest('a change elsewhere offers a copy or discarding', (tester) async {
    await seed();
    await pumpApp(
      tester,
      initialLocation: noteLocation(id),
      notes: repo,
      noteId: () => '33333333333333333333333333333333',
    );
    await startEditing(tester);
    await tester.enterText(bodyField(), 'My conflicting words');
    await repo.organize(id, 1, pinned: true, tags: []);
    await tester.pumpAndSettle();
    await tap(tester, 'Done');
    expect(find.textContaining('changed somewhere else'), findsOneWidget);
    await tap(tester, 'Discard changes');
    await tap(tester, 'Keep writing');
    expect(bodyText(tester), 'My conflicting words');
    await tap(tester, 'Save a copy');
    expect(
      (await repo.openDocument('33333333333333333333333333333333'))
          .note!
          .text
          .body,
      'My conflicting words',
    );
    expect(
      (await repo.openDocument(id)).note!.text.body,
      isNot(contains('My')),
    );
    expect(tester.takeException(), isNull);
  });

  noteTest('a missing note is unavailable; list read failures recover', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      initialLocation: noteLocation(id),
      notes: repo,
      noteId: () => id,
    );
    expect(find.text('Note unavailable'), findsOneWidget);
    expect(find.text('Open recovery draft'), findsNothing);
    await tap(tester, 'Return to Notes');
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
    expect(find.text('Every idea\nstarts somewhere.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Router from the first disposed scope is intentionally never reused.
    expect(router, isNotNull);
  });

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
          await tap(tester, 'Show plain text');
          expect(tester.takeException(), isNull);
          await tap(tester, 'Markdown preview');
          await tap(tester, 'Edit tags');
          await tester.enterText(
            find.byKey(const ValueKey('tag-search')),
            '工作, travel',
          );
          await tap(tester, 'Cancel');
          await tap(tester, 'Delete note');
          await tap(tester, 'Keep note');
          expect(tester.takeException(), isNull);
          router.go(noteLocation(id));
          await tester.pumpAndSettle();
          await startEditing(tester);
          await tester.enterText(
            find.byKey(const ValueKey('note-body')),
            'Large text writing 👩🏽‍💻',
          );
          await tester.pumpAndSettle();
          await tap(tester, 'Done');
          expect(find.text('Saved revision 2'), findsOneWidget);
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
      router.go(noteLocation(id));
      await tester.pumpAndSettle();
      await startEditing(tester);
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

  noteTest('switching notes keeps and saves each note\'s writing', (
    tester,
  ) async {
    await seed();
    const other = '22222222222222222222222222222222';
    await seed(noteId: other, title: 'Other', body: 'Other buffer');
    final router = await pumpApp(
      tester,
      initialLocation: noteLocation(id),
      notes: repo,
    );
    await startEditing(tester);
    await tester.enterText(bodyField(), 'First buffer');
    await tester.pumpAndSettle();
    router.go(noteLocation(other));
    await tester.pumpAndSettle();
    await startEditing(tester);
    expect(bodyText(tester), 'Other buffer');
    await tester.pump(NoteEditorController.autosaveDelay);
    await tester.pumpAndSettle();
    expect((await repo.openDocument(id)).note!.text.body, 'First buffer');
    await tester.enterText(bodyField(), 'Second buffer');
    await tester.pumpAndSettle();
    router.go(noteLocation(id));
    await tester.pumpAndSettle();
    await startEditing(tester);
    expect(bodyText(tester), 'First buffer');
    await tester.pump(NoteEditorController.autosaveDelay);
    await tester.pumpAndSettle();
    expect((await repo.openDocument(other)).note!.text.body, 'Second buffer');
    expect(tester.takeException(), isNull);
  });

  noteTest('writing that failed to save survives leaving and reopening', (
    tester,
  ) async {
    await seed();
    final router = await pumpApp(
      tester,
      initialLocation: noteLocation(id),
      notes: repo,
    );
    await startEditing(tester);
    repo.failSave = true;
    await tester.enterText(bodyField(), 'Memory retained across navigation');
    await tester.pumpAndSettle();
    router.go('/notes');
    await tester.pumpAndSettle();
    await tester.pump(NoteEditorController.autosaveDelay);
    await tester.pumpAndSettle();
    router.go(noteLocation(id));
    await tester.pumpAndSettle();
    await startEditing(tester);
    expect(bodyText(tester), 'Memory retained across navigation');
    repo.failSave = false;
    await tap(tester, 'Done');
    expect(
      (await repo.openDocument(id)).note!.text.body,
      'Memory retained across navigation',
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
        find.byKey(const ValueKey('tag-search')),
        'travel',
      );
      await tap(tester, 'Create');
      await tester.enterText(find.byKey(const ValueKey('tag-search')), '工作');
      await tap(tester, 'Create');
      await tap(tester, 'Apply tags');
      expect((await repo.openDocument(id)).note!.tags, [
        '🏷️#travel',
        '🏷️#工作',
      ]);
      router.go('/notes');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('notes-search')),
        'synthetic',
      );
      await tester.tap(find.byKey(const ValueKey('notes-pinned')));
      await tester.pumpAndSettle();
      expect(tester.container().read(notesFilterProvider).pinnedOnly, isTrue);
      await tester.tap(find.byKey(const ValueKey('notes-tag-🏷️#travel')));
      await tester.pumpAndSettle();
      expect(tester.container().read(notesFilterProvider).tag, '🏷️#travel');
      expect(tester.container().read(notesFilterProvider).pinnedOnly, isFalse);
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
      expect((await repo.openDocument(id)).note!.tags, [
        '🏷️#travel',
        '🏷️#工作',
      ]);
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
      router.go(noteLocation(id));
      await tester.pumpAndSettle();
      expect(find.text('Note unavailable'), findsOneWidget);
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
    // The add button draws its artwork twice (shadow and face); both must
    // decode at the bounded size.
    final art = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byWidgetPredicate(
              (widget) =>
                  widget is LocalArtwork && widget.assetKey == 'notes.add',
            ),
            matching: find.byType(Image),
          ),
        )
        .toList();
    expect(art, hasLength(2));
    for (final image in art) {
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).width, 120);
    }
    expect(find.byType(NoteCard).evaluate().length, lessThan(20));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.byType(NoteCard).evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });
  noteTest('restore and permanent deletion from Trash', (tester) async {
    await seed();
    await repo.deleteNote(id, 1);
    await pumpApp(tester, initialLocation: noteLocation(id), notes: repo);
    await tap(tester, 'Restore note');
    expect((await repo.openDocument(id)).available, isTrue);
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
  });
}

/// Editing is a state of the note page; this is what the Edit control does.
Future<void> startEditing(WidgetTester tester) async {
  tester.widget<NoteReadView>(find.byType(NoteReadView)).onEdit();
  await tester.pumpAndSettle();
}
