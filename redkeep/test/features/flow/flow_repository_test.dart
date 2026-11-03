import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';
import 'package:redkeep/features/flow/domain/thought.dart';

const id = '11111111111111111111111111111111';
void main() {
  late AppDatabase db;
  late DriftFlowRepository repo;
  var now = DateTime.utc(2026, 11, 2);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftFlowRepository(db, clock: () => now);
  });
  tearDown(() => db.close());
  Future<Thought> save(String key, {String body = 'Synthetic', int base = 0}) =>
      repo.save(id: key, body: body, expectedRevision: base);

  test(
    'fresh schema has drafts only for notes; blank saves leave no writing',
    () async {
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE '%draft%'",
          )
          .get();
      expect(tables.map((r) => r.read<String>('name')), ['note_drafts']);
      await expectLater(
        repo.save(id: id, body: ' \n\t', expectedRevision: 0),
        throwsA(isA<FlowException>()),
      );
      expect(await repo.watchThoughts().first, isEmpty);
    },
  );
  test('direct saves retain source CAS and deletion tombstones', () async {
    final first = await repo.save(
      id: id,
      body: 'Exact 👩🏽‍💻 中文',
      expectedRevision: 0,
    );
    expect(first.revision, 1);
    await expectLater(
      repo.save(id: id, body: 'Exact 👩🏽‍💻 中文', expectedRevision: 0),
      throwsA(isA<FlowException>()),
    );
    expect((await repo.openDocument(id)).thought!.body, 'Exact 👩🏽‍💻 中文');
    await repo.deleteThought(id, 1);
    expect((await repo.watchDocument(id).first).available, isFalse);
    expect((await repo.openDocument(id)).thought!.body, '');
    await expectLater(
      repo.save(id: id, body: 'Exact 👩🏽‍💻 中文', expectedRevision: 1),
      throwsA(isA<FlowException>()),
    );
    expect(await repo.watchThoughts().first, isEmpty);
    await expectLater(
      repo.openDocument('invalid'),
      throwsA(isA<FlowException>()),
    );
  });
  test('failed save rolls back source and sync queue', () async {
    await db.customStatement(
      "CREATE TRIGGER fail_insert BEFORE INSERT ON flow_thoughts BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
    );
    await expectLater(
      repo.save(id: id, body: 'Exact 👩🏽‍💻 中文', expectedRevision: 0),
      throwsA(isA<Exception>()),
    );
    expect((await repo.openDocument(id)).thought, isNull);
    expect(await db.select(db.syncOperations).get(), isEmpty);
    await db.customStatement('DROP TRIGGER fail_insert');
    await repo.save(id: id, body: 'Exact 👩🏽‍💻 中文', expectedRevision: 0);
    await db.customStatement(
      "CREATE TRIGGER fail_update BEFORE UPDATE ON flow_thoughts BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
    );
    await expectLater(
      repo.save(id: id, body: 'Exact 👩🏽‍💻 中文', expectedRevision: 1),
      throwsA(isA<Exception>()),
    );
    expect((await repo.openDocument(id)).thought!.revision, 1);
  });
  test('saved Unicode survives background database reopen offline', () async {
    final directory = await Directory.systemTemp.createTemp('redkeep-flow-');
    final file = File('${directory.path}/writing.sqlite');
    var disk = AppDatabase(NativeDatabase.createInBackground(file));
    try {
      final local = DriftFlowRepository(disk, clock: () => now);
      await local.save(id: id, body: 'Exact 👩🏽‍💻 中文', expectedRevision: 0);
      await disk.close();
      disk = AppDatabase(NativeDatabase.createInBackground(file));
      final reopened = DriftFlowRepository(disk, clock: () => now);
      expect(
        (await reopened.openDocument(id)).thought!.body,
        'Exact 👩🏽‍💻 中文',
      );
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
    }
  });
  test('creation ordering is deterministic, bodies exact, preview bounded, edits do not reorder', () async {
    for (final key in [id, '2' * 32, '3' * 32]) {
      await save(key, body: '  👩🏽‍💻 e\u0301 中文\n' * 100);
    }
    now = now.add(const Duration(days: 1));
    final saved = await save(id, base: 1, body: 'Edited');
    final list = await repo.watchThoughts().first;
    expect(list.map((r) => r.id), ['3' * 32, '2' * 32, id]);
    expect(list.first.preview.runes.length, 160);
    expect(
      (await repo.openDocument('2' * 32)).thought!.body,
      '  👩🏽‍💻 e\u0301 中文\n' * 100,
    );
    expect(saved.createdAt.isBefore(saved.updatedAt), isTrue);
    await save('4' * 32);
    expect((await repo.watchThoughts().first).first.id, '4' * 32);
  });
}
