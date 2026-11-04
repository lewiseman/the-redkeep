import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/domain/note_help_contract.dart';
import 'package:redkeep/features/notes/domain/website/website_contract.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/notes_ai_harness.dart';
import '../../support/pump_app.dart';

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
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('notes-assistant-search')),
            findsOneWidget,
          );
          router.go(noteLocation(notesTestId));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('AI tools'));
          await tester.pumpAndSettle();
          final writing = find.byKey(const ValueKey('note-assistant-writing'));
          await tester.ensureVisible(writing);
          await tester.tap(writing);
          await tester.pumpAndSettle();
          expect(find.text('Writing help'), findsWidgets);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('notes-ai-generate')),
            200,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('notes-ai-tool-list')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            find.byKey(const ValueKey('notes-ai-generate')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(BackButton).last);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('note-assistant-actions')),
            findsOneWidget,
          );
          await tester.tap(find.byTooltip('Close AI tools'));
          await tester.pumpAndSettle();
          router.go(noteLocation(notesTestId, edit: true));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('AI tools'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('note-assistant-save-first')),
            findsOneWidget,
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
    'selective metadata review stays disabled until selected and Undo survives closing the tool',
    (tester) async {
      final note = (await h.repository.openDocument(notesTestId)).note!;
      final source = jsonEncode({
        'noteId': note.id,
        'revision': note.revision,
        'draft': false,
        'title': note.text.title,
        'body': note.text.body,
        'payload': NoteMetadataSource.fromNote(note).encode(),
      });
      h.protected.value = jsonEncode(
        AiJob(
          id: 'review-task-123',
          operation: AiOperation.noteMetadata,
          key: note.id,
          created: DateTime.now().millisecondsSinceEpoch,
          provider: 'device',
          source: source,
          phase: 'completed',
          text: noteMetadataOutput,
        ).json(),
      );
      try {
        final router = await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          tasks: h.protected,
          initialLocation: '/notes',
        );
        await tester.container().read(aiJobsProvider.notifier).restore();
        router.go('/notes/ai-task');
        await tester.pumpAndSettle();
        FilledButton apply() => tester.widget<FilledButton>(
          find.byKey(const ValueKey('notes-ai-apply')),
        );
        expect(apply().onPressed, isNull);
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
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(
          (await h.repository.openDocument(note.id)).note!.text.title,
          'Garden',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('choosing an idea creates an unsaved note with that title', (
    tester,
  ) async {
    h.protected.value = jsonEncode(
      AiJob(
        id: 'ideas-task-123',
        operation: AiOperation.noteIdeas,
        key: 'note-ideas',
        created: DateTime.now().millisecondsSinceEpoch,
        provider: 'device',
        source: '{"payload":"{}","selected":{}}',
        phase: 'completed',
        text: '{"ideas":["A plan for the raised bed"]}',
      ).json(),
    );
    final id = 'c' * 32;
    try {
      await pumpApp(
        tester,
        notes: h.repository,
        database: h.db,
        tasks: h.protected,
        noteId: () => id,
        initialLocation: '/notes',
      );
      await tester.tap(find.byKey(const ValueKey('notes-assistant-ideas')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A plan for the raised bed'));
      await tester.pumpAndSettle();
      final opened = await h.repository.openDocument(id);
      expect(opened.note, isNull);
      expect(opened.draft!.text.title, 'A plan for the raised bed');
      expect(find.byTooltip('AI tools'), findsOneWidget);
      await tester.tap(find.byTooltip('AI tools'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-assistant-template')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('note-assistant-scan')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('note-assistant-background')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'editing attachments keeps a complete draft until the note is saved',
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
          initialLocation: noteLocation(notesTestId, edit: true),
        );
        expect(find.text('Page.png'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('note-body')),
          'My own revised words',
        );
        await tester.pumpAndSettle();
        expect(
          (await h.repository.openDocument(notesTestId))
              .draft!
              .details
              .attachments
              .single
              .path,
          path,
        );
        expect(
          (await h.repository.openDocument(notesTestId)).note!.text.body,
          notesTestBody,
        );
        await tester.tap(find.byTooltip('Remove attachment'));
        await tester.pumpAndSettle();
        final opened = await h.repository.openDocument(notesTestId);
        expect(opened.draft!.details.attachments, isEmpty);
        expect(opened.note!.details.attachments.single.path, path);
        await tester.tap(find.byTooltip('Save note'));
        await tester.pumpAndSettle();
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

  testWidgets(
    'saved websites keep original text accessible and the note AI entry available',
    (tester) async {
      const page =
          '<html><body><h1>Garden</h1><p>A garden plan.</p></body></html>';
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await h.save(
        details: NoteDetails(
          website: page,
          websiteSourceHash: websiteContentHash(notesTestBody),
        ),
      );
      try {
        final router = await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          initialLocation: noteLocation(notesTestId),
        );
        expect(find.byTooltip('AI tools'), findsOneWidget);
        expect(find.byKey(const ValueKey('note-website-view')), findsOneWidget);
        await tester.ensureVisible(find.text('Read note text'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Read note text'));
        await tester.pumpAndSettle();
        expect(find.text('Show website'), findsOneWidget);
        router.go(noteLocation(notesTestId, edit: true));
        await tester.pumpAndSettle();
        expect(
          (tester
                  .widget<TextField>(find.byKey(const ValueKey('note-body')))
                  .controller!)
              .text,
          notesTestBody,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
}
