import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/notes/application/note_ai_controller.dart';
import 'package:redkeep/features/notes/application/note_website_bridge.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/data/drift_note_websites.dart';
import 'package:redkeep/features/notes/domain/note_checklist.dart';
import 'package:redkeep/features/notes/domain/note_website.dart';
import 'package:redkeep/features/notes/domain/website/website_contract.dart';

import '../../support/notes_ai_harness.dart';

const _list =
    '# Trip\n\n- [ ] Buy **soil**\n- [x] Water beds\n- [ ] Seeds\n\nNotes';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('note checklist', () {
    test('reads items with their plain words', () {
      final items = noteChecklist(_list);
      expect(
        [for (final i in items) (i.plain, i.done)],
        [('Buy soil', false), ('Water beds', true), ('Seeds', false)],
      );
      expect(items.first.text, 'Buy **soil**');
    });

    test('ticks exactly one matching item and nothing else', () {
      expect(
        setNoteChecklistItem(_list, 'Buy soil', true),
        _list.replaceFirst('- [ ] Buy **soil**', '- [x] Buy **soil**'),
      );
      expect(
        setNoteChecklistItem(_list, 'Water beds', false),
        _list.replaceFirst('- [x] Water beds', '- [ ] Water beds'),
      );
      expect(setNoteChecklistItem(_list, 'Water beds', true), _list);
      expect(setNoteChecklistItem(_list, 'Notes', true), isNull);
      expect(setNoteChecklistItem(_list, 'Trip', true), isNull);
      expect(setNoteChecklistItem(_list, '', true), isNull);
      expect(
        setNoteChecklistItem('- [ ] A\n- [ ] A', 'A', true),
        isNull,
        reason: 'ambiguous',
      );
    });
  });

  group('website bridge, state and remix', () {
    late NotesAiHarness h;
    late DriftNoteWebsites websites;
    final asked = <(String, bool)>[];
    var allow = true, remember = false;

    setUp(() async {
      h = await NotesAiHarness.create();
      h.holdPage();
      websites = h.scope.read(noteWebsitesProvider);
      asked.clear();
      allow = true;
      remember = false;
      await h.save(body: _list);
      await websites.save(
        NoteWebsite(
          noteId: notesTestId,
          html: sanitizeWebsite(noteWebsiteOutput),
          sourceHash: websiteContentHash(_list),
          brief: 'Guide',
          madeAt: DateTime.utc(2026),
        ),
      );
    });
    tearDown(() => h.close());

    NoteWebsiteBridge bridge() => NoteWebsiteBridge(
      h.scope,
      notesTestId,
      saveDelay: Duration.zero,
      confirm: (item, done) async {
        asked.add((item, done));
        return (allow: allow, remember: remember);
      },
    );
    String check(String text, bool done, [int id = 1]) =>
        jsonEncode({'type': 'check', 'id': id, 'text': text, 'done': done});
    Future<String> body() async =>
        (await h.repository.openDocument(notesTestId)).note!.text.body;

    test('a page remembers its own state', () async {
      final b = bridge();
      await b.handle(
        jsonEncode({
          'type': 'save',
          'state': {
            'step': 3,
            'ticked': ['Seeds'],
          },
        }),
      );
      await b.close();
      final saved = (await websites.get(notesTestId))!;
      expect(jsonDecode(saved.state), {
        'step': 3,
        'ticked': ['Seeds'],
      });
      expect(await body(), _list, reason: 'the note is never touched');
      // Handed back on the next open.
      final page = sanitizeWebsite(
        saved.html,
        data: WebsitePageData(
          state: saved.state,
          checklist: noteChecklist(_list),
        ),
      );
      expect(page, contains('"step":3'));
      expect(page, contains('"plain":"Buy soil"'));
    });

    test('oversized or malformed messages are ignored', () async {
      final b = bridge();
      expect(await b.handle('not json'), isNull);
      expect(await b.handle(jsonEncode({'type': 'navigate'})), isNull);
      await b.handle(jsonEncode({'type': 'save', 'state': 'x' * (70 * 1024)}));
      await b.close();
      expect((await websites.get(notesTestId))!.state, isEmpty);
    });

    test('a tick on the page updates the note after it is allowed', () async {
      final b = bridge();
      final reply = await b.handle(check('Buy soil', true, 7));
      expect(reply, (id: 7, ok: true));
      expect(asked, [('Buy soil', true)]);
      expect(await body(), contains('- [x] Buy **soil**'));
      // The page changed the note itself, so it is not outdated.
      expect(
        (await websites.get(notesTestId))!.isOutdatedFor(await body()),
        isFalse,
      );
    });

    test('a refused tick stays on the page only', () async {
      allow = false;
      expect(await bridge().handle(check('Seeds', true)), (id: 1, ok: false));
      expect(await body(), _list);
    });

    test('"always" stops asking for this website', () async {
      remember = true;
      final b = bridge();
      await b.handle(check('Seeds', true));
      await b.handle(check('Water beds', false, 2));
      expect(asked, hasLength(1));
      expect(await body(), contains('- [x] Seeds'));
      expect(await body(), contains('- [ ] Water beds'));
      expect((await websites.get(notesTestId))!.syncChecks, isTrue);
    });

    test('a page cannot change anything but an existing item', () async {
      final b = bridge();
      expect((await b.handle(check('Notes', true)))!.ok, isFalse);
      expect((await b.handle(check('Plant a tree', true)))!.ok, isFalse);
      expect(asked, isEmpty);
      expect(await body(), _list);
    });

    test('an outdated website stays outdated after a tick', () async {
      await h.save(body: '$_list\nMore words');
      final b = bridge();
      expect((await b.handle(check('Seeds', true)))!.ok, isTrue);
      expect(
        (await websites.get(notesTestId))!.isOutdatedFor(await body()),
        isTrue,
      );
    });

    test(
      'a remix edits the page, keeps its source and can be undone',
      () async {
        final before = (await websites.get(notesTestId))!;
        h.remote.output = '<<<<<<< FIND\n<h1>Garden plan</h1>\n=======\n<h1>Garden plan</h1><p class="quiz">Quiz</p>\n>>>>>>> REPLACE';
        final actions = h.scope.read(noteAiControllerProvider);
        await actions.start(
          AiOperation.noteWebsiteRemix,
          notesTestId,
          scope: notesJobScope,
          intent: '  Add a  quiz ',
        );
        final sent = jsonDecode(
          h.remote.submissions.single['prompt'] as String,
        );
        expect(sent['instruction'], 'Add a quiz');
        expect(sent['page'], contains('<h1>Garden plan</h1>'));
        expect(sent['page'], isNot(contains('Content-Security-Policy')));
        final job = h.scope.read(aiJobsProvider(notesJobScope)).job!;
        await actions.apply(job, scope: notesJobScope);
        final after = (await websites.get(notesTestId))!;
        expect(after.html, contains('class="quiz"'));
        expect(after.html, contains('Content-Security-Policy'));
        expect(after.sourceHash, before.sourceHash);
        expect(after.brief, 'Guide');
        expect(await body(), _list);

        expect(await websites.undo(notesTestId), isTrue);
        expect((await websites.get(notesTestId))!.html, before.html);
      },
    );

    test('a remix of a page that changed meanwhile is refused', () async {
      h.remote.output = '<<<<<<< FIND\n<h1>Garden plan</h1>\n=======\n<h1>New</h1>\n>>>>>>> REPLACE';
      final actions = h.scope.read(noteAiControllerProvider);
      await actions.start(
        AiOperation.noteWebsiteRemix,
        notesTestId,
        scope: notesJobScope,
        intent: 'Rename',
      );
      final job = h.scope.read(aiJobsProvider(notesJobScope)).job!;
      await websites.save(
        NoteWebsite(
          noteId: notesTestId,
          html: sanitizeWebsite(
            noteWebsiteOutput.replaceFirst('Garden plan', 'Other'),
          ),
          sourceHash: websiteContentHash(_list),
          madeAt: DateTime.utc(2026),
        ),
      );
      await expectLater(
        actions.apply(job, scope: notesJobScope),
        throwsFormatException,
      );
      expect((await websites.get(notesTestId))!.html, contains('Other'));
    });
  });
}
