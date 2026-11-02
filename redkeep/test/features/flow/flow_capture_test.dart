import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/flow/application/flow_providers.dart';
import 'package:redkeep/features/flow/application/flow_editor_controller.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';

import '../../support/controlled_flow_repository.dart';

void main() {
  late AppDatabase db;
  late ControlledFlowRepository repo;
  late ProviderContainer scope;
  final provider = flowEditorProvider(null);
  var sequence = 0;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ControlledFlowRepository(
      DriftFlowRepository(db, clock: () => DateTime.utc(2026, 11, 2)),
    );
    sequence = 0;
    scope = ProviderContainer(
      overrides: [
        flowRepositoryProvider.overrideWithValue(repo),
        flowIdProvider.overrideWithValue(
          () => (++sequence).toRadixString(16).padLeft(32, '0'),
        ),
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
  test('blank capture is ignored; rapid edits coalesce and duplicate submits wait for commit before clearing', () async {
    expect(await editor().save(), isFalse);
    repo.draftGate = Completer<void>();
    for (var i = 0; i < 50; i++) {
      editor().edit('Fast $i 👩🏽‍💻');
    }
    final pending = editor().save();
    expect(state().body, 'Fast 49 👩🏽‍💻');
    expect(await editor().save(), isFalse);
    repo.commitGate = Completer<void>();
    repo.draftGate!.complete();
    await editor().flushRecovery();
    expect((await repo.openCapture())!.body, 'Fast 49 👩🏽‍💻');
    expect(state().body, 'Fast 49 👩🏽‍💻');
    editor().edit('Blocked');
    expect(state().body, 'Fast 49 👩🏽‍💻');
    repo.commitGate!.complete();
    expect(await pending, isTrue);
    expect(state().body, '');
    expect(await repo.openCapture(), isNull);
    expect(repo.commits, 1);
    for (var i = 0; i < 20; i++) {
      editor().edit('Same intentional text');
      expect(await editor().save(), isTrue);
    }
    final rows = await repo.watchThoughts().first;
    expect(rows, hasLength(21));
    // Equal instants use ID DESC; editing never changes capture order.
    expect(rows.first.id, 21.toRadixString(16).padLeft(32, '0'));
  });
  test(
    'failed recovery and failed commit preserve composer, retry commits once',
    () async {
      repo.failDraft = true;
      editor().edit('Keep every byte e\u0301 中文');
      expect(await editor().save(), isFalse);
      expect(state().body, 'Keep every byte e\u0301 中文');
      expect(repo.commits, 0);
      repo.failDraft = false;
      await editor().flushRecovery();
      repo.failCommit = true;
      expect(await editor().save(), isFalse);
      expect((await repo.openCapture())!.body, state().body);
      expect(await repo.watchThoughts().first, isEmpty);
      repo.failCommit = false;
      expect(await editor().save(), isTrue);
      expect(state().body, '');
      expect(await repo.watchThoughts().first, hasLength(1));
    },
  );
  test(
    'fresh scope restores durable composer and explicit discard empties it',
    () async {
      editor().edit('Restart recovery');
      await editor().flushRecovery();
      scope.dispose();
      scope = ProviderContainer(
        overrides: [flowRepositoryProvider.overrideWithValue(repo)],
      );
      scope.listen(provider, (_, _) {});
      expect((await scope.read(provider.future)).body, 'Restart recovery');
      expect(await editor().discard(), isTrue);
      expect(state().body, '');
      expect(await repo.openCapture(), isNull);
    },
  );
}
