import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/domain/notes_query.dart';

void main() {
  late AppDatabase db;
  late DriftNotesRepository repo;
  final now = DateTime.utc(2026, 11, 2);
  String key(int i) => i.toRadixString(16).padLeft(32, '0');
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftNotesRepository(db, clock: () => now);
  });
  tearDown(() => db.close());
  Future<NoteDocument> seed(
    int i, {
    String title = 'River',
    String body = 'blue water',
    bool pinned = false,
    List<String> tags = const [],
  }) async {
    final draft = await repo.putDraft(
      id: key(i),
      text: PlainTextDocument(title: title, body: body),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    final note = await repo.commitDraft(key(i), draft.draftRevision);
    if (pinned || tags.isNotEmpty) {
      await repo.organize(note.id, note.revision, pinned: pinned, tags: tags);
    }
    return (await repo.openDocument(note.id)).note!;
  }

  Future<List<String>> ids(NotesQuery query) async =>
      (await repo.watchNotes(query: query).first).map((v) => v.id).toList();

  test('keyword, tag, pin and trash filters compose; literal tokens and stable pin ordering', () async {
    await seed(1, pinned: true, tags: [' Travel ', 'TRAVEL', '工作']);
    await seed(2, body: 'green hill', tags: ['travel']);
    await seed(3, title: 'Lake', pinned: true, tags: ['work']);
    await seed(4, body: '100% _literal \' OR 1=1 -- 中文');
    final trashed = await seed(5, pinned: true, tags: ['trash-only']);
    await repo.deleteNote(trashed.id, trashed.revision);
    expect(await ids(const NotesQuery()), [key(1), key(3), key(2), key(4)]);
    for (final search in ['', 'RIVER', 'blue', 'river BLUE', 'missing']) {
      for (final tag in <String?>[null, 'travel', 'work']) {
        for (final pinned in [false, true]) {
          for (final trash in [false, true]) {
            final candidates =
                [
                      (
                        i: 1,
                        title: 'River',
                        body: 'blue water',
                        tags: ['travel', '工作'],
                        pinned: true,
                        trash: false,
                      ),
                      (
                        i: 2,
                        title: 'River',
                        body: 'green hill',
                        tags: ['travel'],
                        pinned: false,
                        trash: false,
                      ),
                      (
                        i: 3,
                        title: 'Lake',
                        body: 'blue water',
                        tags: ['work'],
                        pinned: true,
                        trash: false,
                      ),
                      (
                        i: 4,
                        title: 'River',
                        body: '100% _literal \' OR 1=1 -- 中文',
                        tags: <String>[],
                        pinned: false,
                        trash: false,
                      ),
                      (
                        i: 5,
                        title: 'River',
                        body: 'blue water',
                        tags: ['trash-only'],
                        pinned: true,
                        trash: true,
                      ),
                    ]
                    .where(
                      (n) =>
                          n.trash == trash &&
                          (!pinned || n.pinned) &&
                          (tag == null || n.tags.contains(tag)) &&
                          search
                              .toLowerCase()
                              .split(' ')
                              .every(
                                (token) => '${n.title} ${n.body}'
                                    .toLowerCase()
                                    .contains(token),
                              ),
                    )
                    .toList()
                  ..sort(
                    (a, b) => a.pinned == b.pinned
                        ? a.i.compareTo(b.i)
                        : a.pinned
                        ? -1
                        : 1,
                  );
            expect(
              await ids(
                NotesQuery(
                  search: search,
                  tag: tag,
                  pinnedOnly: pinned,
                  trash: trash,
                ),
              ),
              candidates.map((n) => key(n.i)).toList(),
            );
          }
        }
      }
    }
    for (final literal in ['100%', '_literal', "' OR 1=1 --", '中文']) {
      expect(await ids(NotesQuery(search: literal)), [key(4)]);
    }
    expect(await repo.watchTags().first, ['travel', 'work', '工作']);
    expect(await repo.watchTags(trash: true).first, ['trash-only']);
  });

  test(
    'organization commits atomically, validates tags and rejects stale sources',
    () async {
      final note = await seed(1, tags: ['old']);
      final draft = await repo.putDraft(
        id: note.id,
        text: const PlainTextDocument(body: 'Recovery'),
        baseRevision: note.revision,
        expectedDraftRevision: null,
      );
      await db.customStatement(
        "CREATE TRIGGER fail_tag BEFORE INSERT ON note_tags BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await expectLater(
        repo.organize(note.id, note.revision, pinned: true, tags: ['new']),
        throwsA(isA<Exception>()),
      );
      var opened = await repo.openDocument(note.id);
      expect(opened.note!.tags, ['old']);
      expect(opened.note!.pinned, isFalse);
      expect(opened.note!.revision, note.revision);
      expect(opened.draft!.draftRevision, draft.draftRevision);
      await db.customStatement('DROP TRIGGER fail_tag');
      await expectLater(
        repo.organize(note.id, note.revision, pinned: true, tags: ['x' * 41]),
        throwsA(isA<NoteException>()),
      );
      await repo.organize(
        note.id,
        note.revision,
        pinned: true,
        tags: [' New  tag ', 'new tag', '工作'],
      );
      await expectLater(
        repo.organize(note.id, note.revision, pinned: false, tags: []),
        throwsA(isA<NoteException>()),
      );
      await expectLater(
        repo.commitDraft(note.id, draft.draftRevision),
        throwsA(isA<NoteException>()),
      );
      opened = await repo.openDocument(note.id);
      expect(opened.note!.tags, ['new tag', '工作']);
      expect(opened.note!.pinned, isTrue);
      expect(opened.draft!.text.body, 'Recovery');
    },
  );

  test('trash/restore keep metadata, exclude sources, protect drafts and permanent deletion rolls back', () async {
    var note = await seed(1, pinned: true, tags: ['travel']);
    await expectLater(
      repo.permanentlyDelete(
        note.id,
        note.revision,
        expectedDraftRevision: null,
      ),
      throwsA(isA<NoteException>()),
    );
    await repo.deleteNote(note.id, note.revision);
    expect(await ids(const NotesQuery(search: 'blue')), isEmpty);
    note = (await repo.openDocument(note.id)).note!;
    await expectLater(
      repo.restoreNote(note.id, note.revision - 1),
      throwsA(isA<NoteException>()),
    );
    await repo.restoreNote(note.id, note.revision);
    note = (await repo.openDocument(note.id)).note!;
    expect(note.pinned, isTrue);
    expect(note.tags, ['travel']);
    expect(note.text.body, 'blue water');
    expect(await ids(const NotesQuery(tag: 'travel', pinnedOnly: true)), [
      key(1),
    ]);
    await repo.deleteNote(note.id, note.revision);
    note = (await repo.openDocument(note.id)).note!;
    final draft = await repo.putDraft(
      id: note.id,
      text: const PlainTextDocument(body: 'Last draft'),
      baseRevision: note.revision - 1,
      expectedDraftRevision: null,
    );
    await expectLater(
      repo.permanentlyDelete(
        note.id,
        note.revision,
        expectedDraftRevision: null,
      ),
      throwsA(isA<NoteException>()),
    );
    await db.customStatement(
      "CREATE TRIGGER fail_delete BEFORE DELETE ON notes BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
    );
    await expectLater(
      repo.permanentlyDelete(
        note.id,
        note.revision,
        expectedDraftRevision: draft.draftRevision,
      ),
      throwsA(isA<Exception>()),
    );
    expect((await repo.openDocument(note.id)).draft!.text.body, 'Last draft');
    expect((await repo.openDocument(note.id)).note!.tags, ['travel']);
    await db.customStatement('DROP TRIGGER fail_delete');
    final observed = repo
        .watchDocument(note.id)
        .firstWhere((v) => v.note == null && v.draft == null);
    await repo.permanentlyDelete(
      note.id,
      note.revision,
      expectedDraftRevision: draft.draftRevision,
    );
    await observed;
    expect(await ids(const NotesQuery(trash: true)), isEmpty);
    expect(await repo.watchTags(trash: true).first, isEmpty);
    await expectLater(
      repo.restoreNote(note.id, note.revision),
      throwsA(isA<NoteException>()),
    );
  });

  test('background reopen preserves organization through text edits, trash and restore', () async {
    await db.close();
    final dir = await Directory.systemTemp.createTemp('redkeep-organization-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File.fromUri(dir.uri.resolve('notes.sqlite'));
    db = AppDatabase(NativeDatabase.createInBackground(file));
    repo = DriftNotesRepository(db, clock: () => now);
    var note = await seed(1, pinned: true, tags: ['Travel', '工作']);
    final draft = await repo.putDraft(
      id: note.id,
      text: const PlainTextDocument(body: 'New body'),
      baseRevision: note.revision,
      expectedDraftRevision: null,
    );
    note = await repo.commitDraft(note.id, draft.draftRevision);
    expect(note.pinned, isTrue);
    expect(note.tags, ['travel', '工作']);
    await repo.deleteNote(note.id, note.revision);
    await db.close();
    db = AppDatabase(NativeDatabase.createInBackground(file));
    repo = DriftNotesRepository(db, clock: () => now);
    note = (await repo.openDocument(note.id)).note!;
    expect(note.deletedAt, now);
    expect(note.tags, ['travel', '工作']);
    await repo.restoreNote(note.id, note.revision);
    await db.close();
    db = AppDatabase(NativeDatabase.createInBackground(file));
    repo = DriftNotesRepository(db, clock: () => now);
    expect(
      await ids(const NotesQuery(search: 'new', tag: '工作', pinnedOnly: true)),
      [key(1)],
    );
  });

  test(
    'large collections query metadata only and preserve all results',
    () async {
      await db.transaction(() async {
        for (var i = 1; i <= 2000; i++) {
          await db.customStatement(
            'INSERT INTO notes (id, title, body, revision, created_at, updated_at, pinned) VALUES (?, ?, ?, 1, 0, ?, ?)',
            [
              key(i),
              'Note $i',
              i % 10 == 0 ? 'target' : 'other',
              i,
              i % 100 == 0 ? 1 : 0,
            ],
          );
        }
      });
      expect((await repo.watchNotes().first).length, 2000);
      final matches = await repo
          .watchNotes(
            query: const NotesQuery(search: 'target', pinnedOnly: true),
          )
          .first;
      expect(matches.length, 20);
      expect(matches.first.id, key(2000));
      expect(matches.last.id, key(100));
    },
  );
}
