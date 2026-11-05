import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_day_details.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';

const id = '11111111111111111111111111111111';
void main() {
  late AppDatabase db;
  late DriftDiaryRepository repo;
  var now = DateTime.utc(2026, 11, 2);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDiaryRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  test('day details save atomically, normalize themes, preserve metadata on rename and reject stale changes', () async {
    final date = CivilDate(2026, 11, 2);
    await repo.saveDay(
      DiaryDay(
        date: date,
        heading: 'A quiet day',
        mood: DiaryMood.calm,
        themes: const [' Work  ', 'work', '  Family   time '],
      ),
    );
    final saved = await repo.watchDay(date).first;
    expect(saved.heading, 'A quiet day');
    expect(saved.mood, DiaryMood.calm);
    expect(saved.themes, ['Work', 'Family time']);
    expect(saved.revision, 1);
    await expectLater(
      repo.saveDay(DiaryDay(date: date, mood: DiaryMood.low)),
      throwsA(isA<DiaryException>()),
    );
    await expectLater(
      repo.saveDay(
        DiaryDay(
          date: date,
          revision: 1,
          themes: const ['One', 'Two', 'Three', 'Four'],
        ),
      ),
      throwsFormatException,
    );
    expect((await repo.watchDay(date).first).revision, 1);
    await repo.renameDay(saved, 'New title');
    final renamed = await repo.watchDay(date).first;
    expect(renamed.mood, DiaryMood.calm);
    expect(renamed.themes, saved.themes);
    await repo.saveDay(DiaryDay(date: date, revision: renamed.revision));
    final cleared = await repo.watchDay(date).first;
    expect(cleared.mood, isNull);
    expect(cleared.themes, isEmpty);
    expect(cleared.heading, '');
  });

  test(
    'fresh schema has drafts only for notes; blank saves leave no writing',
    () async {
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE '%draft%'",
          )
          .get();
      expect(tables.map((r) => r.read<String>('name')), ['note_drafts']);
      final columns = await db
          .customSelect('PRAGMA table_info(diary_entries)')
          .get();
      expect(
        columns.map((r) => r.read<String>('name')),
        isNot(contains('title')),
      );
      await expectLater(
        repo.save(
          id: id,
          date: CivilDate(2026, 11, 2),
          text: const DiaryText(),
          expectedRevision: 0,
        ),
        throwsA(isA<DiaryException>()),
      );
      expect(await repo.watchEntries().first, isEmpty);
    },
  );
  test('direct saves retain source CAS and deletion tombstones', () async {
    final first = await repo.save(
      id: id,
      date: CivilDate(2026, 11, 2),
      text: const DiaryText(body: 'Exact 👩🏽‍💻 中文'),
      expectedRevision: 0,
    );
    expect(first.revision, 1);
    await expectLater(
      repo.save(
        id: id,
        date: CivilDate(2026, 11, 2),
        text: const DiaryText(body: 'Exact 👩🏽‍💻 中文'),
        expectedRevision: 0,
      ),
      throwsA(isA<DiaryException>()),
    );
    expect((await repo.openDocument(id)).entry!.text.body, 'Exact 👩🏽‍💻 中文');
    await repo.deleteEntry(id, 1);
    expect((await repo.watchDocument(id).first).available, isFalse);
    expect((await repo.openDocument(id)).entry!.text.body, '');
    await expectLater(
      repo.save(
        id: id,
        date: CivilDate(2026, 11, 2),
        text: const DiaryText(body: 'Exact 👩🏽‍💻 中文'),
        expectedRevision: 1,
      ),
      throwsA(isA<DiaryException>()),
    );
    expect(await repo.watchEntries().first, isEmpty);
    await expectLater(
      repo.openDocument('invalid'),
      throwsA(isA<DiaryException>()),
    );
  });
  test('failed save rolls back source and sync queue', () async {
    await db.customStatement(
      "CREATE TRIGGER fail_insert BEFORE INSERT ON diary_entries BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
    );
    await expectLater(
      repo.save(
        id: id,
        date: CivilDate(2026, 11, 2),
        text: const DiaryText(body: 'Exact 👩🏽‍💻 中文'),
        expectedRevision: 0,
      ),
      throwsA(isA<Exception>()),
    );
    expect((await repo.openDocument(id)).entry, isNull);
    expect(await db.select(db.syncOperations).get(), isEmpty);
    await db.customStatement('DROP TRIGGER fail_insert');
    await repo.save(
      id: id,
      date: CivilDate(2026, 11, 2),
      text: const DiaryText(body: 'Exact 👩🏽‍💻 中文'),
      expectedRevision: 0,
    );
    await db.customStatement(
      "CREATE TRIGGER fail_update BEFORE UPDATE ON diary_entries BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
    );
    await expectLater(
      repo.save(
        id: id,
        date: CivilDate(2026, 11, 2),
        text: const DiaryText(body: 'Exact 👩🏽‍💻 中文'),
        expectedRevision: 1,
      ),
      throwsA(isA<Exception>()),
    );
    expect((await repo.openDocument(id)).entry!.revision, 1);
  });
  test('saved Unicode survives background database reopen offline', () async {
    final directory = await Directory.systemTemp.createTemp('redkeep-diary-');
    final file = File('${directory.path}/writing.sqlite');
    var disk = AppDatabase(NativeDatabase.createInBackground(file));
    try {
      final local = DriftDiaryRepository(disk, clock: () => now);
      await local.save(
        id: id,
        date: CivilDate(2026, 11, 2),
        text: const DiaryText(body: 'Exact 👩🏽‍💻 中文'),
        expectedRevision: 0,
      );
      await local.saveDay(
        DiaryDay(
          date: CivilDate(2026, 11, 2),
          mood: DiaryMood.happy,
          themes: const ['Family', '工作'],
        ),
      );
      await disk.close();
      disk = AppDatabase(NativeDatabase.createInBackground(file));
      final reopened = DriftDiaryRepository(disk, clock: () => now);
      final details = await reopened.watchDay(CivilDate(2026, 11, 2)).first;
      expect(details.mood, DiaryMood.happy);
      expect(details.themes, ['Family', '工作']);
      expect(
        (await reopened.openDocument(id)).entry!.text.body,
        'Exact 👩🏽‍💻 中文',
      );
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
    }
  });
  test('multiple entries share a civil date independently of day headings and literal local search', () async {
    final date = CivilDate(2026, 11, 2);
    expect((await repo.watchDay(date).first).revision, 0);
    await repo.renameDay(DiaryDay(date: date), 'A day of words');
    for (var i = 1; i <= 3; i++) {
      final key = i.toRadixString(16).padLeft(32, '0');
      final day = i == 3 ? date.shift(1)! : date;
      await repo.save(
        id: key,
        date: day,
        text: DiaryText(
          body: i == 1 ? 'Habari %_ 工作 SQL; --' : 'habari second',
        ),
        expectedRevision: 0,
      );
    }
    expect((await repo.watchEntries(date: date).first).length, 2);
    expect((await repo.watchEntries(search: 'HABARI').first).length, 3);
    expect(
      (await repo.watchEntries(date: date, search: 'habari second').first)
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
    expect(
      (await repo.watchEntries(date: date).first).single.id,
      '2'.padLeft(32, '0'),
    );
  });

  test('audit instants cross offsets and DST while the selected date remains fixed', () async {
    final date = CivilDate(2026, 11, 1);
    var time = DateTime.parse('2026-11-01T00:30:00+14:00');
    final repository = DriftDiaryRepository(db, clock: () => time);
    final first = await repository.save(
      id: id,
      date: date,
      text: const DiaryText(body: 'DST'),
      expectedRevision: 0,
    );
    expect(first.date, date);
    expect(first.createdAt.day, 31);
    time = DateTime.parse('2026-11-01T23:30:00-12:00');
    final saved = await repository.save(
      id: id,
      date: date,
      text: const DiaryText(body: 'Across zones'),
      expectedRevision: 1,
    );
    expect(saved.date.key, '2026-11-01');
    expect(saved.createdAt, first.createdAt);
    expect(saved.updatedAt.day, 2);
    expect((await repository.watchEntries(date: date).first).length, 1);
    expect(await repository.watchEntries(date: date.shift(1)).first, isEmpty);
    await expectLater(
      repository.save(
        id: id,
        date: date.shift(1)!,
        text: const DiaryText(),
        expectedRevision: 2,
      ),
      throwsA(isA<DiaryException>()),
    );
  });
}
