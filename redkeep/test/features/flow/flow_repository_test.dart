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
  Future<ThoughtDraft> draft(
    String key, {
    String body = 'Synthetic',
    bool capture = false,
    int base = 0,
    int? token,
  }) => repo.putDraft(
    id: key,
    body: body,
    capture: capture,
    baseRevision: base,
    expectedDraftRevision: token,
  );
  test('creation ordering is deterministic, bodies exact, preview bounded, edits do not reorder', () async {
    for (final key in [id, '2' * 32, '3' * 32]) {
      final d = await draft(key, body: '  👩🏽‍💻 e\u0301 中文\n' * 100);
      await repo.commitDraft(key, d.draftRevision);
    }
    now = now.add(const Duration(days: 1));
    final changed = await draft(id, base: 1, body: 'Edited');
    final saved = await repo.commitDraft(id, changed.draftRevision);
    final list = await repo.watchThoughts().first;
    expect(list.map((r) => r.id), ['3' * 32, '2' * 32, id]);
    expect(list.first.preview.runes.length, 160);
    expect(
      (await repo.openDocument('2' * 32)).thought!.body,
      '  👩🏽‍💻 e\u0301 中文\n' * 100,
    );
    expect(saved.createdAt.isBefore(saved.updatedAt), isTrue);
    final newest = await draft('4' * 32);
    await repo.commitDraft(newest.id, newest.draftRevision);
    expect((await repo.watchThoughts().first).first.id, '4' * 32);
  });
  test(
    'one capture slot, draft CAS tokens never reused, whitespace cannot commit',
    () async {
      final d = await draft(id, body: '   ', capture: true);
      await expectLater(
        draft('2' * 32, capture: true),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        repo.commitDraft(id, d.draftRevision),
        throwsA(isA<FlowException>()),
      );
      await repo.discardDraft(id, d.draftRevision);
      final next = await draft(id, capture: true);
      expect(next.draftRevision, greaterThan(d.draftRevision));
      await expectLater(
        repo.commitDraft(id, d.draftRevision),
        throwsA(isA<FlowException>()),
      );
      expect(await repo.watchDrafts().first, isEmpty);
    },
  );
  test(
    'source insert and draft cleanup failures roll back both halves',
    () async {
      final d = await draft(id, capture: true);
      await db.customStatement(
        "CREATE TRIGGER fail_insert BEFORE INSERT ON flow_thoughts BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await expectLater(
        repo.commitDraft(id, d.draftRevision),
        throwsA(isA<Exception>()),
      );
      expect((await repo.openCapture())!.body, 'Synthetic');
      expect(await repo.watchThoughts().first, isEmpty);
      await db.customStatement('DROP TRIGGER fail_insert');
      await db.customStatement(
        "CREATE TRIGGER fail_cleanup BEFORE DELETE ON flow_drafts BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await expectLater(
        repo.commitDraft(id, d.draftRevision),
        throwsA(isA<Exception>()),
      );
      expect(await repo.watchThoughts().first, isEmpty);
      expect((await repo.openCapture())!.draftRevision, d.draftRevision);
      await db.customStatement('DROP TRIGGER fail_cleanup');
      await repo.commitDraft(id, d.draftRevision);
      final edit = await draft(id, base: 1, body: 'Failed edit');
      await db.customStatement(
        "CREATE TRIGGER fail_update BEFORE UPDATE ON flow_thoughts BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await expectLater(
        repo.commitDraft(id, edit.draftRevision),
        throwsA(isA<Exception>()),
      );
      await expectLater(repo.deleteThought(id, 1), throwsA(isA<Exception>()));
      expect((await repo.openDocument(id)).thought!.body, 'Synthetic');
      expect((await repo.openDocument(id)).draft!.body, 'Failed edit');
    },
  );
  test('deleted routes hide content; stale writes cannot resurrect; independent draft remains', () async {
    final d = await draft(id);
    await repo.commitDraft(id, d.draftRevision);
    final edit = await draft(id, base: 1, body: 'Unfinished');
    await repo.deleteThought(id, 1);
    final opened = await repo.watchDocument(id).first;
    expect(opened.available, isFalse);
    expect(opened.thought!.body, '');
    expect(opened.draft!.body, 'Unfinished');
    await expectLater(
      repo.commitDraft(id, edit.draftRevision),
      throwsA(isA<FlowException>()),
    );
    expect(await repo.watchThoughts().first, isEmpty);
    expect(await repo.watchDrafts().first, hasLength(1));
    expect((await repo.openDocument('f' * 32)).available, isFalse);
    await expectLater(
      repo.openDocument('invalid'),
      throwsA(isA<FlowException>()),
    );
  });
  test('real background database close/reopen keeps composer, edits and large Unicode offline', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp('redkeep-flow-');
    final file = File('${directory.path}/writing.sqlite');
    var disk = AppDatabase(NativeDatabase.createInBackground(file));
    var local = DriftFlowRepository(disk, clock: () => now);
    final body = '👩🏽‍💻 e\u0301 中文\n' * 24000;
    try {
      final saved = await local.putDraft(
        id: id,
        body: body,
        capture: true,
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      await local.commitDraft(id, saved.draftRevision);
      await local.putDraft(
        id: id,
        body: 'Unfinished edit',
        capture: false,
        baseRevision: 1,
        expectedDraftRevision: null,
      );
      await local.putDraft(
        id: '2' * 32,
        body: 'Unfinished capture',
        capture: true,
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      await disk.close();
      disk = AppDatabase(NativeDatabase.createInBackground(file));
      local = DriftFlowRepository(disk, clock: () => now);
      final opened = await local.openDocument(id);
      expect(opened.thought!.body, body);
      expect(opened.draft!.body, 'Unfinished edit');
      final capture = (await local.openCapture())!;
      expect(capture.body, 'Unfinished capture');
      await local.commitDraft(capture.id, capture.draftRevision);
      expect(await local.watchThoughts().first, hasLength(2));
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
    }
  });
}
