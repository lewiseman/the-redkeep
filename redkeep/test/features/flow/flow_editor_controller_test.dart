import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/flow/application/flow_editor_controller.dart';
import 'package:redkeep/features/flow/application/flow_providers.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';

import '../../support/controlled_flow_repository.dart';

const id = '11111111111111111111111111111111';
const copyId = '22222222222222222222222222222222';
void main() {
  final provider = flowEditorProvider(id);
  late AppDatabase db;
  late DriftFlowRepository inner;
  late ControlledFlowRepository repo;
  late ProviderContainer scope;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    inner = DriftFlowRepository(db, clock: () => DateTime.utc(2026, 11, 2));
    await inner.save(id: id, body: 'Initial', expectedRevision: 0);
    repo = ControlledFlowRepository(inner);
    scope = ProviderContainer(
      overrides: [
        flowRepositoryProvider.overrideWithValue(repo),
        flowIdProvider.overrideWithValue(() => copyId),
      ],
    );
    scope.listen(provider, (_, _) {});
    await scope.read(provider.future);
  });
  tearDown(() async {
    scope.dispose();
    await db.close();
  });
  FlowEditorController editor() => scope.read(provider.notifier);
  FlowEditorState state() => scope.read(provider).requireValue;

  test('editing stays in memory; save waits for storage and blocks duplicate submits', () async {
    editor().edit('Changed 👩🏽‍💻');
    expect(state().changed, isTrue);
    expect((await inner.openDocument(id)).thought!.body, 'Initial');
    repo.commitGate = Completer<void>();
    final pending = editor().save();
    expect(state().saving, isTrue);
    expect(await editor().save(), isFalse);
    repo.commitGate!.complete();
    expect(await pending, isTrue);
    expect((await inner.openDocument(id)).thought!.body, 'Changed 👩🏽‍💻');
    expect(state().changed, isFalse);
    expect(repo.commits, 1);
  });
  test(
    'failed save keeps buffer for retry without changing saved writing',
    () async {
      editor().edit('Changed 👩🏽‍💻');
      repo.failCommit = true;
      expect(await editor().save(), isFalse);
      expect(state().body, 'Changed 👩🏽‍💻');
      expect((await inner.openDocument(id)).thought!.body, 'Initial');
      repo.failCommit = false;
      expect(await editor().save(), isTrue);
    },
  );
  test('stale or deleted source cannot overwrite writing; save copy remains explicit', () async {
    editor().edit('Changed 👩🏽‍💻');
    await inner.deleteThought(id, 1);
    expect(await editor().save(), isFalse);
    expect(state().sourceUnavailable, isTrue);
    expect(await editor().saveCopy(), copyId);
    expect((await inner.openDocument(copyId)).thought!.body, 'Changed 👩🏽‍💻');
    expect((await inner.openDocument(id)).available, isFalse);
  });
  test(
    'discard restores saved text and reopening never restores unsaved edits',
    () async {
      editor().edit('Changed 👩🏽‍💻');
      expect(await editor().discard(), isTrue);
      expect(state().body, 'Initial');
      editor().edit('Changed 👩🏽‍💻');
      scope.invalidate(provider);
      expect((await scope.read(provider.future)).body, 'Initial');
      expect(repo.commits, 0);
    },
  );
  test('blank saves and copies are ignored', () async {
    editor().edit(' \n\t');
    expect(await editor().save(), isFalse);
    expect(await editor().saveCopy(), isNull);
    expect(repo.commits, 0);
  });
}
