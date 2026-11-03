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

  Future<RecoveryDraft> draft({
    String body = 'Words',
    int base = 0,
    int? expected,
  }) => repo.putDraft(
    id: id,
    text: PlainTextDocument(title: 'Title', body: body),
    baseRevision: base,
    expectedDraftRevision: expected,
  );

  test(
    'empty and whitespace-only drafts are rejected without replacing writing',
    () async {
      for (final text in [
        const PlainTextDocument(),
        const PlainTextDocument(title: ' \n', body: '\t\u00a0'),
      ]) {
        await expectLater(
          repo.putDraft(
            id: id,
            text: text,
            baseRevision: 0,
            expectedDraftRevision: null,
          ),
          throwsA(isA<NoteException>()),
        );
        expect(await repo.watchDrafts().first, isEmpty);
      }
      final existing = await draft(body: 'Keep this');
      await expectLater(
        repo.putDraft(
          id: id,
          text: const PlainTextDocument(),
          baseRevision: 0,
          expectedDraftRevision: existing.draftRevision,
        ),
        throwsA(isA<NoteException>()),
      );
      expect((await repo.openDocument(id)).draft!.text.body, 'Keep this');
    },
  );

  test(
    'empty reads seed nothing; create/edit/delete retain a full tombstone',
    () async {
      expect(await repo.watchNotes().first, isEmpty);
      expect(await repo.watchDrafts().first, isEmpty);
      final first = await draft();
      expect((await repo.openDocument(id)).note, isNull);
      final saved = await repo.commitDraft(id, first.draftRevision);
      expect(saved.revision, 1);
      expect(saved.createdAt, now);
      expect((await repo.openDocument(id)).draft, isNull);
      expect(await repo.watchDrafts().first, isEmpty);
      expect((await repo.watchNotes().first).single.id, id);
      final edit = await draft(base: 1, body: 'Changed');
      final updated = await repo.commitDraft(id, edit.draftRevision);
      expect(updated.revision, 2);
      final retained = await draft(base: 2, body: 'Uncommitted');
      await repo.deleteNote(id, 2);
      expect(await repo.watchNotes().first, isEmpty);
      final deleted = await repo.openDocument(id);
      expect(deleted.available, isFalse);
      expect(deleted.note!.text.body, 'Changed');
      expect(deleted.note!.createdAt, now);
      expect(deleted.note!.deletedAt, now);
      expect(deleted.note!.revision, 3);
      expect(deleted.draft!.text.body, 'Uncommitted');
      await expectLater(
        repo.commitDraft(id, retained.draftRevision),
        throwsA(isA<NoteException>()),
      );
      expect((await repo.openDocument(id)).draft!.text.body, 'Uncommitted');
    },
  );

  test(
    'stale sources and stale draft tokens never overwrite or clear writing',
    () async {
      var recovery = await draft();
      await repo.commitDraft(id, recovery.draftRevision);
      recovery = await draft(base: 1, body: 'Latest');
      await repo.commitDraft(id, recovery.draftRevision);
      final stale = await draft(base: 1, body: 'Old editor');
      await expectLater(
        repo.commitDraft(id, stale.draftRevision),
        throwsA(isA<NoteException>()),
      );
      expect((await repo.openDocument(id)).note!.text.body, 'Latest');
      expect((await repo.openDocument(id)).draft!.text.body, 'Old editor');
      await expectLater(repo.deleteNote(id, 1), throwsA(isA<NoteException>()));
      final newer = await draft(
        base: 1,
        body: 'Newest draft',
        expected: stale.draftRevision,
      );
      await expectLater(
        draft(base: 1, body: 'Clobber', expected: stale.draftRevision),
        throwsA(isA<NoteException>()),
      );
      await expectLater(
        repo.discardDraft(id, stale.draftRevision),
        throwsA(isA<NoteException>()),
      );
      await repo.discardDraft(id, newer.draftRevision);
      final replacement = await draft(base: 2);
      expect(replacement.draftRevision, greaterThan(newer.draftRevision));
      await expectLater(
        repo.commitDraft(id, stale.draftRevision),
        throwsA(isA<NoteException>()),
      );
      expect(
        (await repo.openDocument(id)).draft!.draftRevision,
        replacement.draftRevision,
      );
    },
  );

  test(
    'transaction failures in note write or draft cleanup roll back both',
    () async {
      final recovery = await draft(body: 'Must survive');
      await db.customStatement(
        "CREATE TRIGGER fail_note BEFORE INSERT ON notes BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await expectLater(
        repo.commitDraft(id, recovery.draftRevision),
        throwsA(isA<Exception>()),
      );
      expect((await repo.openDocument(id)).draft!.text.body, 'Must survive');
      expect((await repo.openDocument(id)).note, isNull);
      await db.customStatement('DROP TRIGGER fail_note');
      await db.customStatement(
        "CREATE TRIGGER fail_cleanup BEFORE DELETE ON note_drafts BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await expectLater(
        repo.commitDraft(id, recovery.draftRevision),
        throwsA(isA<Exception>()),
      );
      expect((await repo.openDocument(id)).note, isNull);
      expect((await repo.openDocument(id)).draft!.text.body, 'Must survive');
      await db.customStatement('DROP TRIGGER fail_cleanup');
      await repo.commitDraft(id, recovery.draftRevision);
    },
  );

  test(
    'background close/reopen preserves Unicode, large bodies and drafts',
    () async {
      await db.close();
      final directory = await Directory.systemTemp.createTemp('redkeep-notes-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File.fromUri(directory.uri.resolve('notes.sqlite'));
      const unicode = 'Swahili: Habari • 中文 • العربية • e\u0301 • 👩🏽‍💻\n';
      final body = List.filled(24000, unicode).join();
      var background = AppDatabase(NativeDatabase.createInBackground(file));
      var repository = DriftNotesRepository(background, clock: () => now);
      final pending = await repository.putDraft(
        id: id,
        text: PlainTextDocument(title: unicode, body: body),
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      await background.close();
      background = AppDatabase(NativeDatabase.createInBackground(file));
      repository = DriftNotesRepository(background, clock: () => now);
      expect((await repository.openDocument(id)).draft!.text.body, body);
      final committed = await repository.commitDraft(id, pending.draftRevision);
      final latest = await repository.putDraft(
        id: id,
        text: const PlainTextDocument(body: 'Unsaved after commit 👩🏽‍💻'),
        baseRevision: committed.revision,
        expectedDraftRevision: null,
      );
      await background.close();
      background = AppDatabase(NativeDatabase.createInBackground(file));
      try {
        repository = DriftNotesRepository(background, clock: () => now);
        final restored = await repository.openDocument(id);
        expect(restored.note!.text.body, body);
        expect(restored.note!.text.title, unicode);
        expect(restored.draft!.text.body, latest.text.body);
        await repository.deleteNote(id, committed.revision);
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
        expect(deleted.draft!.text.body, latest.text.body);
      } finally {
        await background.close();
      }
    },
  );

  test(
    'watchers reflect commits and draft-only records; invalid IDs are rejected',
    () async {
      final observed = repo
          .watchDocument(id)
          .firstWhere((v) => v.draft?.text.body == 'Words');
      await draft();
      expect((await observed).available, isFalse);
      for (final invalid in ['', '../x', 'A' * 32, 'a' * 31]) {
        await expectLater(
          repo.openDocument(invalid),
          throwsA(isA<NoteException>()),
        );
      }
      final missing = await repo.openDocument('2' * 32);
      expect(missing.available, isFalse);
      expect(missing.draft, isNull);
    },
  );
}
