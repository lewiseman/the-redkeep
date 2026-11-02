import 'package:redkeep/features/diary/domain/civil_date.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';

const id = '11111111111111111111111111111111';
final now = DateTime.utc(2026, 11, 2, 12);

void main() {
  late AppDatabase db;
  late DriftDiaryRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDiaryRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<DiaryDraft> draft({
    String body = 'Words',
    int base = 0,
    int? expected,
  }) => repo.putDraft(
    id: id,
    date: CivilDate(2026, 11, 2),
    text: DiaryText(title: 'Title', body: body),
    baseRevision: base,
    expectedDraftRevision: expected,
  );

  test('empty days seed nothing; create/edit/delete clear text and retain a tombstone', () async {
    expect(await repo.watchEntries().first, isEmpty);
    expect(await repo.watchDrafts().first, isEmpty);
    final first = await draft();
    expect((await repo.openDocument(id)).entry, isNull);
    final saved = await repo.commitDraft(id, first.draftRevision);
    expect(saved.revision, 1);
    expect(saved.createdAt, now);
    expect((await repo.openDocument(id)).draft, isNull);
    expect(await repo.watchDrafts().first, isEmpty);
    expect((await repo.watchEntries().first).single.id, id);
    final edit = await draft(base: 1, body: 'Changed');
    final updated = await repo.commitDraft(id, edit.draftRevision);
    expect(updated.revision, 2);
    final retained = await draft(base: 2, body: 'Uncommitted');
    await repo.deleteEntry(id, 2);
    expect(await repo.watchEntries().first, isEmpty);
    final deleted = await repo.openDocument(id);
    expect(deleted.available, isFalse);
    expect(deleted.entry!.text.body, '');
    expect(deleted.entry!.createdAt, now);
    expect(deleted.entry!.deletedAt, now);
    expect(deleted.entry!.revision, 3);
    expect(deleted.draft!.text.body, 'Uncommitted');
    await expectLater(
      repo.commitDraft(id, retained.draftRevision),
      throwsA(isA<DiaryException>()),
    );
    expect((await repo.openDocument(id)).draft!.text.body, 'Uncommitted');
  });

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
        throwsA(isA<DiaryException>()),
      );
      expect((await repo.openDocument(id)).entry!.text.body, 'Latest');
      expect((await repo.openDocument(id)).draft!.text.body, 'Old editor');
      await expectLater(
        repo.deleteEntry(id, 1),
        throwsA(isA<DiaryException>()),
      );
      final newer = await draft(
        base: 1,
        body: 'Newest draft',
        expected: stale.draftRevision,
      );
      await expectLater(
        draft(base: 1, body: 'Clobber', expected: stale.draftRevision),
        throwsA(isA<DiaryException>()),
      );
      await expectLater(
        repo.discardDraft(id, stale.draftRevision),
        throwsA(isA<DiaryException>()),
      );
      await repo.discardDraft(id, newer.draftRevision);
      final replacement = await draft(base: 2);
      expect(replacement.draftRevision, greaterThan(newer.draftRevision));
      await expectLater(
        repo.commitDraft(id, stale.draftRevision),
        throwsA(isA<DiaryException>()),
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
        "CREATE TRIGGER fail_note BEFORE INSERT ON diary_entries BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await expectLater(
        repo.commitDraft(id, recovery.draftRevision),
        throwsA(isA<Exception>()),
      );
      expect((await repo.openDocument(id)).draft!.text.body, 'Must survive');
      expect((await repo.openDocument(id)).entry, isNull);
      await db.customStatement('DROP TRIGGER fail_note');
      await db.customStatement(
        "CREATE TRIGGER fail_cleanup BEFORE DELETE ON diary_drafts BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await expectLater(
        repo.commitDraft(id, recovery.draftRevision),
        throwsA(isA<Exception>()),
      );
      expect((await repo.openDocument(id)).entry, isNull);
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
      var repository = DriftDiaryRepository(background, clock: () => now);
      await repository.renameDay(
        DiaryDay(date: CivilDate(2026, 11, 2)),
        'Persistent heading',
      );
      final pending = await repository.putDraft(
        id: id,
        date: CivilDate(2026, 11, 2),
        text: DiaryText(title: unicode, body: body),
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      await background.close();
      background = AppDatabase(NativeDatabase.createInBackground(file));
      repository = DriftDiaryRepository(background, clock: () => now);
      expect((await repository.openDocument(id)).draft!.text.body, body);
      expect(
        (await repository.watchDay(CivilDate(2026, 11, 2)).first).heading,
        'Persistent heading',
      );
      final committed = await repository.commitDraft(id, pending.draftRevision);
      final latest = await repository.putDraft(
        id: id,
        date: CivilDate(2026, 11, 2),
        text: const DiaryText(body: 'Unsaved after commit 👩🏽‍💻'),
        baseRevision: committed.revision,
        expectedDraftRevision: null,
      );
      await background.close();
      background = AppDatabase(NativeDatabase.createInBackground(file));
      try {
        repository = DriftDiaryRepository(background, clock: () => now);
        final restored = await repository.openDocument(id);
        expect(restored.entry!.text.body, body);
        expect(restored.entry!.text.title, unicode);
        expect(restored.draft!.text.body, latest.text.body);
        await repository.deleteEntry(id, committed.revision);
      } finally {
        await background.close();
      }
      background = AppDatabase(NativeDatabase.createInBackground(file));
      try {
        final deleted = await DriftDiaryRepository(
          background,
          clock: () => now,
        ).openDocument(id);
        expect(deleted.available, isFalse);
        expect(deleted.entry!.text.body, '');
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
          throwsA(isA<DiaryException>()),
        );
      }
      final missing = await repo.openDocument('2' * 32);
      expect(missing.available, isFalse);
      expect(missing.draft, isNull);
    },
  );

  test('multiple entries share a civil date independently of day headings and literal local search', () async {
    final date = CivilDate(2026, 11, 2);
    expect((await repo.watchDay(date).first).revision, 0);
    await repo.renameDay(DiaryDay(date: date), 'A day of words');
    for (var i = 1; i <= 3; i++) {
      final key = i.toRadixString(16).padLeft(32, '0');
      final day = i == 3 ? date.shift(1)! : date;
      final draft = await repo.putDraft(
        id: key,
        date: day,
        text: DiaryText(
          title: 'Entry $i',
          body: i == 1 ? 'Habari %_ 工作 SQL; --' : 'habari second',
        ),
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      await repo.commitDraft(key, draft.draftRevision);
    }
    expect((await repo.watchEntries(date: date).first).length, 2);
    expect((await repo.watchEntries(search: 'HABARI').first).length, 3);
    expect(
      (await repo.watchEntries(date: date, search: 'entry second').first)
          .length,
      1,
    );
    for (final term in ['%_', '工作', 'SQL; --']) {
      expect(
        (await repo.watchEntries(search: term).first).single.id,
        '1'.padLeft(32, '0'),
      );
    }
    expect(await repo.watchEntries(search: "' OR 1=1").first, isEmpty);
    final heading = await repo.watchDay(date).first;
    await expectLater(
      repo.renameDay(DiaryDay(date: date), 'Stale'),
      throwsA(isA<DiaryException>()),
    );
    await repo.renameDay(heading, 'Revised heading');
    expect((await repo.watchEntries(date: date).first).length, 2);
    await repo.deleteEntry('1'.padLeft(32, '0'), 1);
    expect(await repo.watchEntries(search: '%_').first, isEmpty);
    expect((await repo.watchDay(date).first).heading, 'Revised heading');
    expect((await repo.watchEntries(date: date).first).single.title, 'Entry 2');
  });

  test('audit instants cross offsets and DST while the selected date remains fixed', () async {
    final date = CivilDate(2026, 11, 1);
    var time = DateTime.parse('2026-11-01T00:30:00+14:00');
    final repository = DriftDiaryRepository(db, clock: () => time);
    var draft = await repository.putDraft(
      id: id,
      date: date,
      text: const DiaryText(body: 'DST'),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    final first = await repository.commitDraft(id, draft.draftRevision);
    expect(first.date, date);
    expect(first.createdAt.day, 31);
    time = DateTime.parse('2026-11-01T23:30:00-12:00');
    draft = await repository.putDraft(
      id: id,
      date: date,
      text: const DiaryText(body: 'Across zones'),
      baseRevision: 1,
      expectedDraftRevision: null,
    );
    final saved = await repository.commitDraft(id, draft.draftRevision);
    expect(saved.date.key, '2026-11-01');
    expect(saved.createdAt, first.createdAt);
    expect(saved.updatedAt.day, 2);
    expect((await repository.watchEntries(date: date).first).length, 1);
    expect(await repository.watchEntries(date: date.shift(1)).first, isEmpty);
    await expectLater(
      repository.putDraft(
        id: id,
        date: date.shift(1)!,
        text: const DiaryText(),
        baseRevision: 2,
        expectedDraftRevision: null,
      ),
      throwsA(isA<DiaryException>()),
    );
  });
}
