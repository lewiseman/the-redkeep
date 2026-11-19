import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_ai_provider.dart';
import '../../support/notes_ai_harness.dart';
import '../../support/pump_app.dart';

import 'package:image/image.dart' as img;
import 'package:redkeep/features/ai/domain/note_operation_prompts.dart';
import 'package:redkeep/features/notes/data/note_maester_picker.dart';
import 'package:redkeep/features/notes/domain/note_maester_attachment.dart';
import 'package:redkeep/features/notes/presentation/note_maester_composer.dart';
import 'package:redkeep/features/notes/presentation/note_read_page.dart';
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
          await tester.tap(find.byTooltip('Ask the Maester'));
          await tester.pumpAndSettle();
          // The Maester asks on the note itself, in place of the dock, with
          // the keyboard up.
          expect(router.state.uri.path, noteLocation(notesTestId));
          final input = find.byKey(const ValueKey('note-maester-input'));
          expect(input, findsOneWidget);
          expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
          expect(find.byKey(const ValueKey('note-read-dock')), findsNothing);
          expect(tester.takeException(), isNull);
          // Back closes the input and stays on the note.
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(router.state.uri.path, noteLocation(notesTestId));
          expect(input, findsNothing);
          expect(find.byKey(const ValueKey('note-read-dock')), findsOneWidget);
          await startEditing(tester);
          // Writing has no Maester; it is offered while reading.
          expect(find.byTooltip('Close editor'), findsOneWidget);
          expect(find.byTooltip('Ask the Maester'), findsNothing);
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

  Future<void> settle(WidgetTester tester, Finder until) async {
    for (var i = 0; i < 50 && until.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump();
  }

  Future<void> ask(WidgetTester tester, String request) async {
    await tester.enterText(
      find.byKey(const ValueKey('note-maester-input')),
      request,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-maester-send')));
    await tester.pump();
  }

  testWidgets('the Maester rewrites the note as it streams in; Edit waits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    const original = 'Plant tomatoes in the raised bed.';
    await h.save(body: original);
    final stream = h.aiProvider.stream = StreamController<String>();
    try {
      await pumpApp(
        tester,
        notes: h.repository,
        database: h.db,
        aiProvider: h.aiProvider,
        aiSettings: testAiSettings,
        initialLocation: noteLocation(notesTestId),
      );
      await tester.tap(find.byTooltip('Ask the Maester'));
      await tester.pumpAndSettle();
      await ask(tester, 'Make it a checklist');
      final working = find.byKey(const ValueKey('note-maester-working'));
      await settle(tester, working);

      // The note stays until the answer starts arriving.
      expect(find.text(original), findsOneWidget);
      expect(find.text('The Maester is writing…'), findsOneWidget);
      expect(jsonDecode(h.aiProvider.requests.single.user), {
        'title': 'Garden',
        'text': original,
        'intent': 'Make it a checklist',
      });

      stream.add('- [ ] Plant tomatoes');
      for (
        var i = 0;
        i < 50 && find.text(original).evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      // The old text clears as the new text streams in.
      expect(find.text(original), findsNothing);
      expect(find.textContaining('Plant tomatoes'), findsOneWidget);
      // Nothing is saved until the Maester has finished.
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        original,
      );

      // Back closes the input; the Maester keeps writing and shows it.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const ValueKey('note-maester-input')), findsNothing);
      expect(working, findsOneWidget);
      // Narrow screens and large text keep Edit as an icon.
      VoidCallback? edit() => tester
          .widget<IconButton>(
            find.descendant(
              of: find.byTooltip('Edit note'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed;
      expect(edit(), isNull);

      stream.add('\n- [ ] Water each morning');
      await stream.close();
      for (var i = 0; i < 20 && working.evaluate().isNotEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(working, findsNothing);
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        '- [ ] Plant tomatoes\n- [ ] Water each morning',
      );
      expect(edit(), isNotNull);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the Maester changes the title, the text, or both, as asked', (
    tester,
  ) async {
    const original = 'Plant tomatoes in the raised bed.';
    await h.save(body: original);
    Future<String> saved(String Function(PlainTextDocument) part) async =>
        part((await h.repository.openDocument(notesTestId)).note!.text);
    try {
      await pumpApp(
        tester,
        notes: h.repository,
        database: h.db,
        aiProvider: h.aiProvider,
        aiSettings: testAiSettings,
        initialLocation: noteLocation(notesTestId),
      );
      Future<void> request(String words, String reply, String until) async {
        h.aiProvider.reply = reply;
        await tester.tap(find.byTooltip('Ask the Maester'));
        await tester.pumpAndSettle();
        await ask(tester, words);
        for (var i = 0; i < 50; i++) {
          if ((await saved((t) => '${t.title}|${t.body}')).contains(until)) {
            break;
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      // Only the title: the writing stays exactly as it was.
      await request('Call it Tomato plan', '<<TITLE>> Tomato plan', 'Tomato');
      expect(h.aiProvider.requests.last.system, startsWith(noteMaesterSystem));
      expect(await saved((t) => t.title), 'Tomato plan');
      expect(await saved((t) => t.body), original);
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const ValueKey('note-read-title')),
            )
            .data,
        'Tomato plan',
      );

      // Both at once.
      await request(
        'Rename it and make a checklist',
        '<<TITLE>> Raised bed\n<<TEXT>>\n- [ ] Plant tomatoes',
        'Raised bed',
      );
      expect(await saved((t) => t.title), 'Raised bed');
      expect(await saved((t) => t.body), '- [ ] Plant tomatoes');
      expect(
        jsonDecode(h.aiProvider.requests.last.user)['title'],
        'Tomato plan',
      );

      // Only the writing: the title stays.
      await request('Shorter', '<<TEXT>>\n- [ ] Tomatoes', 'Tomatoes');
      expect(await saved((t) => t.title), 'Raised bed');
      expect(await saved((t) => t.body), '- [ ] Tomatoes');
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('leaving the note while the Maester writes changes nothing', (
    tester,
  ) async {
    const original = 'Plant tomatoes in the raised bed.';
    await h.save(body: original);
    final stream = h.aiProvider.stream = StreamController<String>();
    try {
      final router = await pumpApp(
        tester,
        notes: h.repository,
        database: h.db,
        aiProvider: h.aiProvider,
        aiSettings: testAiSettings,
        initialLocation: noteLocation(notesTestId),
      );
      await tester.tap(find.byTooltip('Ask the Maester'));
      await tester.pumpAndSettle();
      await ask(tester, 'Shorten it');
      await settle(tester, find.byKey(const ValueKey('note-maester-working')));
      stream.add('Tomatoes.');
      await settle(tester, find.textContaining('Tomatoes.'));

      router.go('/notes');
      await tester.pumpAndSettle();
      stream.add(' More.');
      await stream.close();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(h.aiProvider.aborted, isTrue);
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        original,
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('without an AI provider the Maester is greyed out and absent', (
    tester,
  ) async {
    await h.save(body: 'Plant tomatoes in the raised bed.');
    try {
      await pumpApp(
        tester,
        notes: h.repository,
        database: h.db,
        aiProvider: h.aiProvider,
        aiSettings: null,
        initialLocation: noteLocation(notesTestId),
      );
      await tester.pumpAndSettle();
      final button = find.ancestor(
        of: find.byType(NoteMaesterMark),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      expect(
        find.descendant(of: button, matching: find.byType(ColorFiltered)),
        findsOneWidget,
      );

      final word = find.textContaining('Plant tomatoes', findRichText: true);
      await tester.longPressAt(
        tester.getTopLeft(word.first) + const Offset(70, 10),
      );
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Ask Maester'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Ask Maester on a reading selection rewrites only that part', (
    tester,
  ) async {
    const rest = 'Water them every morning.';
    await h.save(body: 'Plant tomatoes in the raised bed.\n\n$rest');
    h.aiProvider.reply = 'basil';
    try {
      await pumpApp(
        tester,
        notes: h.repository,
        database: h.db,
        aiProvider: h.aiProvider,
        aiSettings: testAiSettings,
        initialLocation: noteLocation(notesTestId),
      );
      await tester.pumpAndSettle();
      // Long press selects a word and brings up the selection menu.
      final word = find.textContaining('Plant tomatoes', findRichText: true);
      await tester.longPressAt(
        tester.getTopLeft(word.first) + const Offset(70, 10),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ask Maester'), findsOneWidget);
      await tester.tap(find.text('Ask Maester'));
      await tester.pumpAndSettle();
      expect(find.text('How should this part change?'), findsOneWidget);

      await ask(tester, 'Make it basil');
      for (var i = 0; i < 40; i++) {
        final body = (await h.repository.openDocument(notesTestId))
            .note!
            .text
            .body;
        if (body.contains('basil')) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      final sent = jsonDecode(h.aiProvider.requests.single.user) as Map;
      expect(sent['intent'], 'Make it basil');
      // Only the long-pressed word was sent and replaced.
      expect(sent['text'], isNot(contains(' ')));
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        'Plant tomatoes in the raised bed.\n\n$rest'.replaceFirst(
          sent['text'] as String,
          'basil',
        ),
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
        expect(find.byTooltip('Ask the Maester'), findsOneWidget);
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
    'photos and files attached to the Maester go with the note; sending them alone adds them',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await h.save(body: 'Shopping');
      h.aiProvider.reply = 'Shopping\n\nMeet Sam at 3pm';
      final picker = _FakeMaesterPicker();
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 4, height: 4)),
      );
      try {
        await pumpApp(
          tester,
          notes: h.repository,
          database: h.db,
          aiProvider: h.aiProvider,
          aiSettings: testAiSettings,
          initialLocation: noteLocation(notesTestId),
          overrides: [noteMaesterPickerProvider.overrideWithValue(picker)],
        );
        await tester.tap(find.byTooltip('Ask the Maester'));
        await tester.pumpAndSettle();
        final send = find.byKey(const ValueKey('note-maester-send'));
        expect(tester.widget<IconButton>(send).onPressed, isNull);

        // The tray takes the keyboard's place, and back brings the keyboard
        // back, with the input staying where it is throughout.
        final composer = find.byKey(const ValueKey('note-maester-composer'));
        final tray = find.byKey(const ValueKey('note-maester-tray'));
        final input = find.byKey(const ValueKey('note-maester-input'));
        // The input keeps its caret; only the keyboard comes and goes.
        bool typing() =>
            tester.widget<TextField>(input).focusNode!.hasFocus &&
            tester.testTextInput.isVisible;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final place = tester.getRect(composer);
        expect(typing(), isTrue);
        await tester.tap(find.byKey(const ValueKey('note-maester-attach')));
        await tester.pump();
        expect(typing(), isFalse);
        expect(tester.getRect(composer), place);
        tester.view.viewInsets = const FakeViewPadding(bottom: 120);
        await tester.pump();
        expect(tester.getRect(composer), place);
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(tray, findsOneWidget);
        expect(tester.getRect(composer), place);
        expect(tester.getRect(tray).top, greaterThan(place.bottom));
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(typing(), isTrue);
        expect(tester.getRect(composer), place);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tray, findsNothing);
        expect(tester.getRect(composer), place);
        // From here no keyboard is shown, as when it closes with the tray.
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();

        Future<void> attach(String item) async {
          await tester.tap(find.byKey(const ValueKey('note-maester-attach')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey('note-maester-$item')));
          await tester.pumpAndSettle();
        }

        picker.next = [NoteMaesterAttachment.image('page.png', png)];
        await attach('camera');
        picker.next = [NoteMaesterAttachment.image('extra.png', png)];
        await attach('photos');
        picker.next = [NoteMaesterAttachment.text('list.txt', 'eggs')];
        await attach('files');
        expect(find.byTooltip('Remove page.png'), findsOneWidget);
        expect(find.byTooltip('Remove list.txt'), findsOneWidget);
        expect(
          find.text('What should the Maester do with it?'),
          findsOneWidget,
        );

        // One is taken off again before sending.
        await tester.tap(find.byTooltip('Remove extra.png'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Remove extra.png'), findsNothing);

        // A file that cannot be read is told, and nothing else changes.
        picker.failure = const FormatException('This file is empty.');
        await attach('files');
        expect(find.text('This file is empty.'), findsOneWidget);
        expect(find.byTooltip('Remove list.txt'), findsOneWidget);

        // With nothing typed, the attachments are added to the note.
        expect(tester.widget<IconButton>(send).onPressed, isNotNull);
        await tester.tap(send);
        for (var i = 0; i < 50; i++) {
          final body = (await h.repository.openDocument(notesTestId))
              .note!
              .text
              .body;
          if (body.contains('Sam')) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final request = h.aiProvider.requests.single;
        expect(jsonDecode(request.user), {
          'title': 'Garden',
          'text': 'Shopping',
          'intent': noteMaesterAttachmentIntent,
          'files': [
            {'name': 'list.txt', 'text': 'eggs'},
          ],
        });
        expect(request.images.single.bytes, png);
        expect(request.images.single.mime, 'image/png');
        expect(request.system, endsWith(noteAttachmentRules));
        expect(
          (await h.repository.openDocument(notesTestId)).note!.text.body,
          'Shopping\n\nMeet Sam at 3pm',
        );

        // Sent attachments are not kept for the next request.
        expect(find.byKey(const ValueKey('note-maester-input')), findsNothing);
        await tester.tap(find.byTooltip('Ask the Maester'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Remove page.png'), findsNothing);
        expect(tester.takeException(), isNull);
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

/// Hands back what a test sets, as if the person picked it.
class _FakeMaesterPicker implements NoteMaesterPicker {
  List<NoteMaesterAttachment> next = const [];
  Object? failure;

  List<NoteMaesterAttachment> _pick() {
    final error = failure;
    failure = null;
    if (error != null) throw error;
    final picked = next;
    next = const [];
    return picked;
  }

  @override
  Future<NoteMaesterAttachment?> takePhoto() async {
    final picked = _pick();
    return picked.isEmpty ? null : picked.first;
  }

  @override
  Future<List<NoteMaesterAttachment>> choosePhotos({
    required int limit,
  }) async => _pick().take(limit).toList();

  @override
  Future<List<NoteMaesterAttachment>> chooseFiles() async => _pick();
}
