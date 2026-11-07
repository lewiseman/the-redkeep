import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';

const id = '11111111111111111111111111111111';
final now = DateTime.utc(2026, 11, 2, 12);

void main() {
  late AppDatabase db;
  late DriftNotesRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftNotesRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<NoteDocument> save({
    String body = 'Words',
    int expected = 0,
    String noteId = id,
  }) => repo.saveNote(
    id: noteId,
    text: PlainTextDocument(title: 'Title', body: body),
    expectedRevision: expected,
    details: const NoteDetails(),
  );

  test('empty and whitespace-only notes are rejected', () async {
    for (final text in [
      const PlainTextDocument(),
      const PlainTextDocument(title: ' \n', body: '\t '),
    ]) {
      await expectLater(
        repo.saveNote(
          id: id,
          text: text,
          expectedRevision: 0,
          details: const NoteDetails(),
        ),
        throwsA(isA<NoteException>()),
      );
      expect(await repo.watchNotes().first, isEmpty);
    }
    await save(body: 'Keep this');
    await expectLater(
      repo.saveNote(
        id: id,
        text: const PlainTextDocument(),
        expectedRevision: 1,
        details: const NoteDetails(),
      ),
      throwsA(isA<NoteException>()),
    );
    expect((await repo.openDocument(id)).note!.text.body, 'Keep this');
  });

  test(
    'empty reads seed nothing; create/edit/delete retain a full tombstone',
    () async {
      expect(await repo.watchNotes().first, isEmpty);
      final saved = await save();
      expect(saved.revision, 1);
      expect(saved.createdAt, now);
      expect((await repo.watchNotes().first).single.id, id);
      final updated = await save(expected: 1, body: 'Changed');
      expect(updated.revision, 2);
      expect(updated.createdAt, now);
      await repo.deleteNote(id, 2);
      expect(await repo.watchNotes().first, isEmpty);
      final deleted = await repo.openDocument(id);
      expect(deleted.available, isFalse);
      expect(deleted.note!.text.body, 'Changed');
      expect(deleted.note!.createdAt, now);
      expect(deleted.note!.deletedAt, now);
      expect(deleted.note!.revision, 3);
      await expectLater(
        save(expected: 3, body: 'Revive'),
        throwsA(isA<NoteException>()),
      );
      expect((await repo.openDocument(id)).note!.text.body, 'Changed');
    },
  );

  test(
    'saves compare and swap: no double create, no stale overwrite',
    () async {
      await save();
      await expectLater(
        save(body: 'Second create'),
        throwsA(isA<NoteException>()),
      );
      await save(expected: 1, body: 'Latest');
      await expectLater(
        save(expected: 1, body: 'Old editor'),
        throwsA(isA<NoteException>()),
      );
      expect((await repo.openDocument(id)).note!.text.body, 'Latest');
      await expectLater(repo.deleteNote(id, 1), throwsA(isA<NoteException>()));
    },
  );

  test('saved tags and details travel with the note', () async {
    final saved = await repo.saveNote(
      id: id,
      expectedRevision: 0,
      text: const PlainTextDocument(body: 'Tagged'),
      details: const NoteDetails(tags: ['🌱#Garden']),
    );
    expect(saved.tags, ['🌱#Garden']);
    expect((await repo.openDocument(id)).note!.tags, ['🌱#Garden']);
    expect(await repo.watchTags().first, ['🌱#Garden']);
  });

  test('a failed note write rolls back', () async {
    await db.customStatement(
      "CREATE TRIGGER fail_note BEFORE INSERT ON notes BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
    );
    await expectLater(
      save(body: 'Must not half-save'),
      throwsA(isA<Exception>()),
    );
    expect((await repo.openDocument(id)).note, isNull);
    await db.customStatement('DROP TRIGGER fail_note');
    expect((await save()).revision, 1);
  });

  test('background close/reopen preserves Unicode and large bodies', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp('redkeep-notes-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File.fromUri(directory.uri.resolve('notes.sqlite'));
    const unicode = 'Swahili: Habari • 中文 • العربية • é • 👩🏽‍💻\n';
    final body = List.filled(24000, unicode).join();
    var background = AppDatabase(NativeDatabase.createInBackground(file));
    var repository = DriftNotesRepository(background, clock: () => now);
    final saved = await repository.saveNote(
      id: id,
      text: PlainTextDocument(title: unicode, body: body),
      expectedRevision: 0,
      details: const NoteDetails(),
    );
    await background.close();
    background = AppDatabase(NativeDatabase.createInBackground(file));
    try {
      repository = DriftNotesRepository(background, clock: () => now);
      final restored = await repository.openDocument(id);
      expect(restored.note!.text.body, body);
      expect(restored.note!.text.title, unicode);
      await repository.deleteNote(id, saved.revision);
    } finally {
      await background.close();
    }
    background = AppDatabase(NativeDatabase.createInBackground(file));
    try {
      final deleted = await DriftNotesRepository(
        background,
        clock: () => now,
      ).openDocument(id);
      expect(deleted.available, isFalse);
      expect(deleted.note!.text.body, body);
    } finally {
      await background.close();
    }
  });

  test('watchers reflect saves; invalid IDs are rejected', () async {
    final observed = repo
        .watchDocument(id)
        .firstWhere((v) => v.note?.text.body == 'Words');
    await save();
    expect((await observed).available, isTrue);
    for (final invalid in ['', '../x', 'A' * 32, 'a' * 31]) {
      await expectLater(
        repo.openDocument(invalid),
        throwsA(isA<NoteException>()),
      );
    }
    final missing = await repo.openDocument('2' * 32);
    expect(missing.available, isFalse);
    expect(missing.note, isNull);
  });
}
