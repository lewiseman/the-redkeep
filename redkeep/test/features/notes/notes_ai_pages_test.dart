import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/features/ai/domain/ai_conversation.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_ai_provider.dart';
import '../../support/notes_ai_harness.dart';
import '../../support/pump_app.dart';

import 'package:redkeep/features/notes/presentation/note_read_page.dart';
import 'package:redkeep/features/notes/presentation/note_scan_page.dart';
import 'package:redkeep/features/notes/presentation/note_tag_picker.dart';

import 'package:redkeep/core/media/compress_image.dart';
import 'package:redkeep/features/stock_photos/presentation/stock_photo_preview_page.dart';
import 'package:redkeep/features/stock_photos/presentation/stock_photo_search_page.dart';

import '../../support/fake_stock_photos.dart';
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
          // The Maester is a chat on its own page, not a sheet.
          expect(router.state.uri.path, noteChatLocation(notesTestId));
          expect(find.byKey(const ValueKey('note-chat-input')), findsOneWidget);
          expect(find.text('How shall I help?'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, noteLocation(notesTestId));
          await startEditing(tester);
          await tester.tap(find.byTooltip('AI tools'));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, noteChatLocation(notesTestId));
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          // Back in the editor, still editing.
          expect(find.byTooltip('Close editor'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'a stock photo is chosen from the background sheet and kept by Apply',
    (tester) async {
      final photos = FakeStockPhotoSource(bytes: h.remote.generated);
      try {
        await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          aiProvider: h.aiProvider,
          aiSettings: testAiSettings,
          noteMedia: h.media,
          initialLocation: noteLocation(notesTestId),
          stockPhotos: photos,
          overrides: [
            photoEncoderProvider.overrideWithValue(
              (bytes, {required longEdge, required quality}) async => bytes,
            ),
          ],
        );
        final before = (await h.repository.openDocument(notesTestId))
            .note!
            .details
            .background;
        await tester.tap(find.byTooltip('Note actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Background'));
        await tester.pumpAndSettle();
        expect(find.text('No artwork yet'), findsOneWidget);
        expect(find.byKey(const ValueKey('note-artwork-paint')), findsNothing);

        final browse = find.byKey(const ValueKey('note-artwork-browse'));
        await tester.ensureVisible(browse);
        await tester.pumpAndSettle();
        await tester.tap(browse);
        await tester.pumpAndSettle();
        expect(find.byType(StockPhotoSearchPage), findsOneWidget);
        expect(photos.searches, [('', 1)]);

        await tester.tap(find.text('Leaves'));
        await tester.pumpAndSettle();
        expect(photos.searches.last, ('Leaves', 1));
        await tester.tap(find.bySemanticsLabel(RegExp('^Photo p2')));
        await tester.pumpAndSettle();
        expect(find.byType(StockPhotoPreviewPage), findsOneWidget);
        expect(find.text('Ada Lens'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('stock-photo-use')));
        for (
          var i = 0;
          i < 50 && find.text('Remove artwork').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        expect(photos.downloads, ['p2']);
        // Back on the sheet; the note is unchanged until Apply.
        expect(find.byType(StockPhotoSearchPage), findsNothing);
        expect(find.text('Remove artwork'), findsOneWidget);
        expect(
          (await h.repository.openDocument(notesTestId))
              .note!
              .details
              .background['image'],
          isNull,
        );

        final apply = find.byKey(const ValueKey('note-background-apply'));
        await tester.tap(apply);
        await tester.pumpAndSettle();
        final background = (await h.repository.openDocument(notesTestId))
            .note!
            .details
            .background;
        expect(background['image'], startsWith('note_media/'));
        expect(
          await tester.runAsync(
            () => h.media.resolve(background['image'] as String),
          ),
          isNotNull,
        );
        // The paper color is kept alongside the new artwork.
        expect(background['type'], before['type']);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('the background sheet fits 320px with 3x text', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    try {
      await pumpApp(
        tester,
        notes: h.repository,
        database: h.db,
        aiProvider: h.aiProvider,
        aiSettings: testAiSettings,
        noteMedia: h.media,
        initialLocation: noteLocation(notesTestId),
      );
      await tester.tap(find.byTooltip('Note actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Background'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Apply stays pinned in reach while the sheet scrolls.
      expect(
        tester
            .getRect(find.byKey(const ValueKey('note-background-apply')))
            .bottom,
        lessThanOrEqualTo(760),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('note-artwork-browse')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the Maester edits one passage in chat and keeps it on review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    const passage = 'Plant tomatoes in the raised bed.';
    const rest = 'Water them every morning.';
    const original = '$passage\n\n$rest';
    const replacement = '- [ ] Plant tomatoes in the raised bed.';
    await h.save(body: original);
    h.remote.output = replacement;
    h.aiProvider.turns.addAll([
      const AiConverseReply(
        text: 'I made the first line a checklist item.',
        calls: [
          AiToolCall(
            id: 'call_1',
            name: 'edit_note',
            arguments: {
              'operation': 'custom',
              'instruction': 'Make this a checklist.',
              'passage': passage,
            },
          ),
        ],
      ),
      const AiConverseReply(text: 'Glad it helps.'),
    ]);

    Future<void> settle(Finder until) async {
      for (var i = 0; i < 50 && until.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    Future<void> send(String text) async {
      await tester.enterText(
        find.byKey(const ValueKey('note-chat-input')),
        text,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('note-chat-send')));
      await tester.pump();
    }

    try {
      await pumpApp(
        tester,
        notes: h.repository,
        database: h.db,
        aiProvider: h.aiProvider,
        aiSettings: testAiSettings,
        initialLocation: noteChatLocation(notesTestId),
      );
      await send('Make the first line a checklist');
      final keep = find.byKey(const ValueKey('note-chat-keep'));
      await settle(keep);

      final turn = h.aiProvider.conversations.single;
      expect(turn.user, 'Make the first line a checklist');
      expect(turn.system, contains(passage));
      expect(
        turn.tools.map((t) => t.name),
        containsAll(['edit_note', 'offer_choices']),
      );
      // Only the named passage is sent to be rewritten.
      expect(jsonDecode(h.aiProvider.requests.single.user), {
        'text': passage,
        'intent': 'Make this a checklist.',
      });
      expect(find.byKey(const ValueKey('note-chat-compare')), findsOneWidget);
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        original,
      );

      await tester.ensureVisible(keep);
      await tester.pumpAndSettle();
      await tester.tap(keep);
      await settle(find.text('Kept in your note.'));
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        '$replacement\n\n$rest',
      );

      // The next turn tells the Maester what came of its proposal.
      await send('Thanks');
      await settle(find.text('Glad it helps.'));
      final next = h.aiProvider.conversations.last;
      expect(next.history.single.calls.single.name, 'edit_note');
      expect(
        next.history.single.results.single.content,
        'The person kept this change.',
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'the keyboard search action keeps keyword search and sends nothing',
    (tester) async {
      try {
        final router = await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          initialLocation: '/notes',
        );
        await tester.enterText(
          find.byKey(const ValueKey('notes-search')),
          'tomatoes',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.uri.path, '/notes');
        expect(tester.container().read(notesFilterProvider).search, 'tomatoes');
        expect(find.byKey(const ValueKey('notes-add-button')), findsOneWidget);
        expect(h.remote.submissions, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'the keyboard row suggests a title while the title has the caret',
    (tester) async {
      h.remote.output = '{"titles":["Raised bed plan","Tomato care"]}';
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      try {
        await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          aiProvider: h.aiProvider,
          initialLocation: noteLocation(notesTestId),
        );
        await startEditing(tester);
        final suggest = find.byTooltip('Suggest a title');
        expect(suggest, findsNothing);
        await tester.tap(find.byKey(const ValueKey('note-title')));
        await tester.pumpAndSettle();
        await tester.tap(suggest);
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
        }
        expect(h.remote.submissions.single['prompt'], contains(notesTestBody));
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('note-title')))
              .controller!
              .text,
          'Raised bed plan',
        );
        expect(
          find.byKey(const ValueKey('note-assistant-metadata')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('the tag picker suggests tags with AI, reusing an existing tag', (
    tester,
  ) async {
    await h.save(
      id: 'b' * 32,
      body: 'Seed order for spring.',
      details: const NoteDetails(tags: ['🌿#Garden']),
    );
    h.remote.output = '{"tags":[{"name":"garden","emoji":"🌱"},{"name":"Watering","emoji":"🌿"}]}';
    try {
      await pumpApp(
        tester,
        notes: h.repository,
        database: h.db,
        aiProvider: h.aiProvider,
        initialLocation: '/notes',
      );
      final picked = NoteTagPicker.show(
        tester.element(find.byType(Scaffold).first),
        currentTags: const [],
        noteId: notesTestId,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tag-ai-suggest')));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
      }
      expect(
        jsonDecode(h.remote.submissions.single['prompt'] as String)['existing'],
        [
          {'name': 'Garden', 'emoji': '🌿'},
        ],
      );
      expect(find.text('Watering · new'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tag-ai-garden')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply tags'));
      await tester.pumpAndSettle();
      expect(await picked, ['🌿#Garden']);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('photos read as prints above the writing, files as tags below', (
    tester,
  ) async {
    late String path;
    await tester.runAsync(() async {
      path = await h.media.write(h.remote.generated);
      await h.save(
        body: 'Trip writing',
        details: NoteDetails(
          attachments: [
            NoteAttachment(path: path, type: 'image/png', name: 'Beach.png'),
            const NoteAttachment(
              path: 'note_media/ticket.pdf',
              type: 'application/pdf',
              name: 'Ticket.pdf',
            ),
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
      await tester.pumpAndSettle();
      final print = find.bySemanticsLabel('Photo, Beach.png');
      final writing = find.text('Trip writing', findRichText: true).first;
      final tag = find.text('Ticket.pdf');
      expect(print, findsOneWidget);
      // A photo shows the picture, not its file name.
      expect(find.text('Beach.png'), findsNothing);
      expect(find.text('PDF'), findsOneWidget);
      expect(
        tester.getRect(print).bottom,
        lessThan(tester.getTopLeft(writing).dy),
      );
      expect(
        tester.getTopLeft(tag).dy,
        greaterThan(tester.getRect(writing).bottom),
      );
      expect(find.byTooltip('Remove attachment'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

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
        expect(find.bySemanticsLabel('Photo, Page.png'), findsOneWidget);
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

  testWidgets(
    'scanning opens its own page from note actions while reading and editing',
    (tester) async {
      try {
        final router = await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          aiProvider: h.aiProvider,
          aiSettings: testAiSettings,
          noteMedia: h.media,
          initialLocation: noteLocation(notesTestId),
        );
        for (final editing in [false, true]) {
          if (editing) await startEditing(tester);
          await tester.tap(find.byTooltip('Note actions'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Scan a page'));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, noteScanLocation(notesTestId));
          expect(find.byType(NoteScanPage), findsOneWidget);
          expect(find.text('Read the page'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, noteLocation(notesTestId));
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
}

/// Editing is a state of the note page; this is what the Edit control does.
Future<void> startEditing(WidgetTester tester) async {
  tester.widget<NoteReadView>(find.byType(NoteReadView)).onEdit();
  await tester.pumpAndSettle();
}
