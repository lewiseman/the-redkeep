import 'package:redkeep/features/notes/application/note_editor_controller.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/features/ai/domain/ai_conversation.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/data/drift_note_websites.dart';
import 'package:redkeep/features/notes/domain/note_website.dart';
import 'package:redkeep/features/notes/domain/website/website_contract.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_ai_provider.dart';
import '../../support/notes_ai_harness.dart';
import '../../support/pump_app.dart';

import 'package:redkeep/features/notes/presentation/note_card.dart';
import 'package:redkeep/features/notes/presentation/note_read_page.dart';
import 'package:redkeep/features/notes/presentation/note_scan_page.dart';
import 'package:redkeep/features/notes/presentation/note_ai_sheet.dart';
import 'package:redkeep/features/notes/presentation/note_ai_widgets.dart';
import 'package:redkeep/features/notes/presentation/note_tag_picker.dart';

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

  testWidgets('artwork is painted in the background sheet and kept by Apply', (
    tester,
  ) async {
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
      final before = (await h.repository.openDocument(notesTestId))
          .note!
          .details
          .background;
      await tester.tap(find.byTooltip('Note actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Background'));
      await tester.pumpAndSettle();
      expect(find.text('No artwork yet'), findsOneWidget);

      final paint = find.byKey(const ValueKey('note-artwork-paint'));
      await tester.ensureVisible(paint);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leaves'));
      await tester.pumpAndSettle();
      await tester.tap(paint);
      // The canvas spins while painting, so wait on the real work instead.
      final removeArtwork = find.text('Remove artwork');
      for (var i = 0; i < 50 && removeArtwork.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(h.aiProvider.images.single, contains('green leaves'));
      // Painted artwork waits on the canvas; the note is unchanged so far.
      expect(find.text('No artwork yet'), findsNothing);
      expect(removeArtwork, findsOneWidget);
      expect(
        (await h.repository.openDocument(notesTestId))
            .note!
            .details
            .background['image'],
        isNull,
      );

      final apply = find.byKey(const ValueKey('note-background-apply'));
      await tester.scrollUntilVisible(
        apply,
        200,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(apply);
      await tester.pumpAndSettle();
      final background = (await h.repository.openDocument(notesTestId))
          .note!
          .details
          .background;
      expect(background['image'], startsWith('note_media/'));
      // The paper color is kept alongside the new artwork.
      expect(background['type'], before['type']);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

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
        find.byKey(const ValueKey('note-artwork-paint')),
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
        containsAll(['edit_note', 'build_website', 'offer_choices']),
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
          expect(find.textContaining('Website · built'), findsOneWidget);
          expect(find.byTooltip('Ask the Maester'), findsOneWidget);

          // Narrow: Edit text is in the menu.
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
          expect(find.textContaining('Website · built'), findsNothing);
          expect(
            find.byTooltip('Ask the Maester (text changed)'),
            findsOneWidget,
          );
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
          // Building again is asked in the Maester's chat, which knows
          // the website; nothing is sent until the person sends it.
          expect(path(), noteChatLocation(notesTestId));
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const ValueKey('note-chat-input')),
                )
                .controller!
                .text,
            'Build the website again from my latest text.',
          );
          expect(find.text('Give the website a darker look'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'the website opens the Maester chat, which changes it and offers undo',
    (tester) async {
      await DriftNoteWebsites(h.db).save(
        NoteWebsite(
          noteId: notesTestId,
          html: sanitizeWebsite(noteWebsiteOutput),
          sourceHash: websiteContentHash(notesTestBody),
          brief: 'A garden guide',
          madeAt: DateTime.utc(2026),
        ),
      );
      h.remote.output = '<<<<<<< FIND\n<h1>Garden plan</h1>\n=======\n<h1>Garden plan</h1><p>Quiz</p>\n>>>>>>> REPLACE';
      h.aiProvider.turns.add(
        const AiConverseReply(
          text: 'Adding a short quiz.',
          calls: [
            AiToolCall(
              id: 'call_1',
              name: 'update_website',
              arguments: {'instruction': 'Add a short quiz'},
            ),
          ],
        ),
      );
      try {
        final router = await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          aiProvider: h.aiProvider,
          aiSettings: testAiSettings,
          initialLocation: noteWebsiteLocation(notesTestId),
        );
        await tester.tap(find.byTooltip('Ask the Maester'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, noteChatLocation(notesTestId));
        await tester.enterText(
          find.byKey(const ValueKey('note-chat-input')),
          'Add a quiz to the site',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('note-chat-send')));
        // The page is edited and checked on background isolates.
        for (var i = 0; i < 50; i++) {
          if (find.text('Website changed.').evaluate().isNotEmpty) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text('Website changed.'), findsOneWidget);
        // The chat knows the note has a website and how it was described.
        final turn = h.aiProvider.conversations.single;
        expect(turn.system, contains('has an interactive website'));
        expect(turn.system, contains('A garden guide'));
        expect(turn.tools.map((t) => t.name), contains('update_website'));
        expect(
          jsonDecode(h.aiProvider.requests.single.user)['instruction'],
          'Add a short quiz',
        );
        final website = await DriftNoteWebsites(h.db).get(notesTestId);
        expect(website!.html, contains('<p>Quiz</p>'));
        expect(website.canUndo, isTrue);
        final undo = find.byKey(const ValueKey('note-chat-undo-website'));
        await tester.ensureVisible(undo);
        await tester.pumpAndSettle();
        await tester.tap(undo);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(
          (await DriftNoteWebsites(h.db).get(notesTestId))!.html,
          isNot(contains('<p>Quiz</p>')),
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

  testWidgets('a new note can start as a website', (tester) async {
    final id = 'f' * 32;
    h.scope.read(noteNewIdsProvider.notifier).add(id);
    final sub = h.scope.listen(noteEditorProvider(id), (_, _) {});
    addTearDown(sub.close);
    h.holdPage();
    await tester.runAsync(() => h.scope.read(noteEditorProvider(id).future));
    const body = '- [ ] Rain jacket\n- [ ] Walking shoes';
    h.aiProvider.replies.addAll([
      jsonEncode({'title': 'Japan packing', 'body': body}),
      noteWebsiteOutput,
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.scope,
        child: MaterialApp(
          builder: (context, child) => RenderingPolicyScope(
            policy: RenderingPolicy(
              osReducedMotion: false,
              preferences: const AppearancePreferences(),
            ),
            child: child!,
          ),
          // As in the desk, the tool scrolls with its sheet.
          home: Scaffold(
            body: ListView(
              children: [
                NoteAiToolPage(
                  tool: NoteAiTool.presentation,
                  id: id,
                  embedded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final idea = find.byKey(const ValueKey('notes-ai-website-idea'));
    expect(idea, findsOneWidget);
    final generate = find.byKey(const ValueKey('notes-ai-generate'));
    await tester.ensureVisible(generate);
    expect(tester.widget<FilledButton>(generate).onPressed, isNull);
    await tester.enterText(idea, 'Packing list for a week in Japan');
    await tester.pump();
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    for (var i = 0; i < 50; i++) {
      if (find
          .byKey(const ValueKey('note-website-view'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('note-website-view')), findsOneWidget);
    final saved = (await tester.runAsync(() => h.repository.openDocument(id)))!
        .note!;
    expect(saved.text.body, body);
    expect(h.aiProvider.requests, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    // Let the editor's autosave timer run out.
    await tester.pump(const Duration(seconds: 2));
    sub.close();
    await tester.pump(const Duration(seconds: 2));
  });

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
