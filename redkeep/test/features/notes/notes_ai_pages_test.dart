import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/data/drift_note_websites.dart';
import 'package:redkeep/features/notes/domain/note_website.dart';
import 'package:redkeep/features/notes/domain/website/website_contract.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/notes_ai_harness.dart';
import '../../support/pump_app.dart';

import 'package:redkeep/features/notes/presentation/note_card.dart';
import 'package:redkeep/features/notes/presentation/note_read_page.dart';
import 'package:redkeep/features/notes/presentation/note_ai_sheet.dart';
import 'package:redkeep/features/notes/presentation/note_ai_widgets.dart';

import 'note_body_test_helpers.dart';

void main() {
  late NotesAiHarness h;
  setUp(() async {
    h = await NotesAiHarness.create();
    await h.save();
  });
  tearDown(() => h.close());

  for (final simple in [false, true]) {
    testWidgets(
      'notes AI entry, nested back, and draft tools work at 320px and 3x text; simple=$simple',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final appearance = FakeAppearanceRepository(
          AppearancePreferences(
            theme: AppTheme.dark,
            simplerEffects: simple,
            reduceMotion: simple,
          ),
        );
        addTearDown(appearance.close);
        try {
          final router = await pumpApp(
            tester,
            notes: h.repository,
            database: h.db,
            repository: appearance,
            initialLocation: '/notes',
          );
          expect(
            find.byKey(const ValueKey('notes-assistant-ideas')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('notes-assistant-search')),
            findsNothing,
          );
          router.go(noteLocation(notesTestId));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('AI tools'));
          await tester.pumpAndSettle();
          final writing = find.byKey(const ValueKey('note-assistant-writing'));
          await tester.scrollUntilVisible(
            writing,
            200,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('note-assistant-actions')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.ensureVisible(writing);
          await tester.pumpAndSettle();
          await tester.tap(writing);
          await tester.pumpAndSettle();
          expect(find.text('Writing help'), findsWidgets);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('notes-ai-generate')),
            200,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('note-assistant-actions')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            find.byKey(const ValueKey('notes-ai-generate')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          // The chosen craft works on the note itself, shown as a folio.
          expect(find.byKey(const ValueKey('notes-ai-folio')), findsOneWidget);
          await tester.tap(find.byTooltip('All tools'));
          await tester.pumpAndSettle();
          // Back at the desk: the ribbon unfolds into every craft again.
          expect(find.text('The Maester'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('note-ribbon-writing')),
            findsNothing,
          );
          await tester.tap(find.byTooltip('Close AI tools'));
          await tester.pumpAndSettle();
          router.go(noteLocation(notesTestId));
          await tester.pumpAndSettle();
          await startEditing(tester);
          await tester.tap(find.byTooltip('AI tools'));
          await tester.pumpAndSettle();
          // Editing a saved note no longer blocks the tools: they save
          // first and then run on what is shown.
          expect(
            find.byKey(const ValueKey('note-assistant-save-first')),
            findsNothing,
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('note-assistant-writing')),
            200,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('note-assistant-actions')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'typing filters by keyword; the keyboard search action opens AI note search without sending',
    (tester) async {
      try {
        final router = await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          initialLocation: '/notes',
        );
        expect(find.text('Keyword and meaning results'), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('notes-search')),
          'tomatoes',
        );
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.uri.path, '/notes');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('notes-ai-search-field')),
          findsOneWidget,
        );
        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('notes-ai-search-field')),
        );
        expect(field.controller!.text, 'tomatoes');
        expect(h.remote.submissions, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'keeping a result closes the AI desk onto the note and shows what changed',
    (tester) async {
      h.remote.output = noteMetadataOutput;
      try {
        final router = await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          aiProvider: h.aiProvider,
          initialLocation: '/notes',
        );
        router.go(noteLocation(notesTestId));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('AI tools'));
        await tester.pumpAndSettle();
        final metadata = find.byKey(const ValueKey('note-assistant-metadata'));
        await tester.ensureVisible(metadata);
        await tester.tap(metadata);
        await tester.pumpAndSettle();
        // The cards fold into a ribbon to switch crafts in one tap.
        expect(
          find.byKey(const ValueKey('note-ribbon-writing')),
          findsOneWidget,
        );
        final generate = find.byKey(const ValueKey('notes-ai-generate'));
        await tester.ensureVisible(generate);
        await tester.tap(generate);
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
        }
        final title = find.text('Raised bed plan');
        await tester.ensureVisible(title.last);
        await tester.tap(title.last);
        await tester.pumpAndSettle();
        // The chosen title is written onto the folio before keeping it.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('notes-ai-folio')),
            matching: find.text('Raised bed plan'),
          ),
          findsOneWidget,
        );
        final apply = find.byKey(const ValueKey('notes-ai-apply'));
        await tester.ensureVisible(apply);
        await tester.tap(apply);
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
        }
        expect(
          (await h.repository.openDocument(notesTestId)).note!.text.title,
          'Raised bed plan',
        );
        expect(
          find.byKey(const ValueKey('note-assistant-actions')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('note-ai-landing')), findsOneWidget);
        expect(find.text('Title & tags updated'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('note-ai-landing')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('note-ai-landing')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'selective metadata review stays disabled until a suggestion is selected',
    (tester) async {
      final note = (await h.repository.openDocument(notesTestId)).note!;
      h.remote.output = noteMetadataOutput;
      try {
        await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          aiProvider: h.aiProvider,
          initialLocation: '/notes',
        );
        unawaited(
          Navigator.of(tester.element(find.byType(Scaffold).first)).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  NoteAiToolPage(tool: NoteAiTool.metadata, id: note.id),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('notes-ai-generate')));
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
        }
        FilledButton apply() => tester.widget<FilledButton>(
          find.byKey(const ValueKey('notes-ai-apply')),
        );
        expect(apply().onPressed, isNull);
        await tester.ensureVisible(find.text('Raised bed plan'));
        await tester.tap(find.text('Raised bed plan'));
        await tester.pumpAndSettle();
        expect(apply().onPressed, isNotNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('notes-ai-apply')),
        );
        await tester.tap(find.byKey(const ValueKey('notes-ai-apply')));
        await tester.pumpAndSettle();
        expect(
          (await h.repository.openDocument(note.id)).note!.text.title,
          'Raised bed plan',
        );
        expect(find.text('Undo'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'editing attachments saves into the note and Done returns to reading',
    (tester) async {
      late String path;
      await tester.runAsync(() async {
        path = await h.media.write(h.remote.generated);
        await h.save(
          details: NoteDetails(
            attachments: [
              NoteAttachment(path: path, type: 'image/png', name: 'Page.png'),
            ],
          ),
        );
      });
      try {
        await pumpApp(
          tester,
          notes: h.repository,
          noteMedia: h.media,
          database: h.db,
          initialLocation: noteLocation(notesTestId),
        );
        await startEditing(tester);
        expect(find.text('Page.png'), findsOneWidget);
        await enterNoteBody(tester, 'My own revised words');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Remove attachment'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close editor'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('note-body')), findsNothing);
        expect(find.byTooltip('AI tools'), findsOneWidget);
        expect(
          (await h.repository.openDocument(notesTestId))
              .note!
              .details
              .attachments,
          isEmpty,
        );
        expect(
          (await h.repository.openDocument(notesTestId)).note!.text.body,
          'My own revised words',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'a website note opens on its page, edits its text and marks itself outdated; dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final appearance = FakeAppearanceRepository(
          AppearancePreferences(
            theme: dark ? AppTheme.dark : AppTheme.light,
            reduceMotion: dark,
            simplerEffects: dark,
          ),
        );
        addTearDown(appearance.close);
        await DriftNoteWebsites(h.db).save(
          NoteWebsite(
            noteId: notesTestId,
            html: noteWebsiteOutput,
            sourceHash: websiteContentHash(notesTestBody),
            brief: 'A garden guide',
            madeAt: DateTime.utc(2026),
          ),
        );
        try {
          final router = await pumpApp(
            tester,
            notes: h.repository,
            database: h.db,
            repository: appearance,
            initialLocation: '/notes',
          );
          String path() => router.state.uri.path;
          // What tapping the card does (at 3x text it sits under the bar).
          tester.widget<NoteCard>(find.byType(NoteCard).first).onTap();
          await tester.pumpAndSettle();
          expect(path(), noteWebsiteLocation(notesTestId));
          expect(
            find.byKey(const ValueKey('note-website-view')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('note-website-outdated')),
            findsNothing,
          );

          // Narrow, large text: the actions are in the menu.
          await tester.tap(find.byKey(const ValueKey('note-website-menu')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Edit text'));
          await tester.pumpAndSettle();
          expect(path(), noteLocation(notesTestId));
          expect(noteBodyText(tester), notesTestBody);

          // The text changes; the website is kept but marked outdated.
          await h.save(body: 'Plant peppers instead.');
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Close editor'));
          await tester.pumpAndSettle();
          expect(path(), noteWebsiteLocation(notesTestId));
          final pill = find.byKey(const ValueKey('note-website-outdated'));
          expect(pill, findsOneWidget);
          expect(
            (await h.repository.openDocument(notesTestId)).note!.text.body,
            'Plant peppers instead.',
          );

          await tester.tap(pill);
          await tester.pumpAndSettle();
          final again = find.byKey(
            const ValueKey('note-website-outdated-regenerate'),
          );
          await tester.ensureVisible(again);
          await tester.pumpAndSettle();
          await tester.tap(again);
          await tester.pumpAndSettle();
          final brief = find.byKey(const ValueKey('notes-ai-website-brief'));
          await tester.ensureVisible(brief);
          expect(
            tester.widget<TextField>(brief).controller!.text,
            'A garden guide',
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets('the note text page links back to its website', (tester) async {
    await DriftNoteWebsites(h.db).save(
      NoteWebsite(
        noteId: notesTestId,
        html: noteWebsiteOutput,
        sourceHash: websiteContentHash('older text'),
        madeAt: DateTime.utc(2026),
      ),
    );
    try {
      final router = await pumpApp(
        tester,
        notes: h.repository,
        database: h.db,
        initialLocation: noteLocation(notesTestId),
      );
      final card = find.byKey(const ValueKey('note-website-card'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const ValueKey('note-website-outdated')),
        ),
        findsOneWidget,
      );
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, noteWebsiteLocation(notesTestId));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}

/// Editing is a state of the note page; this is what the Edit control does.
Future<void> startEditing(WidgetTester tester) async {
  tester.widget<NoteReadView>(find.byType(NoteReadView)).onEdit();
  await tester.pumpAndSettle();
}
