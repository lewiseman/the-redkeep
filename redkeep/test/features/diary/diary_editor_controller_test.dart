import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/application/diary_editor_controller.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';

import '../../support/controlled_diary_repository.dart';

const id = '11111111111111111111111111111111';
const copyId = '22222222222222222222222222222222';
void main() {
  final date = CivilDate(2026, 11, 2);
  final provider = diaryEditorProvider((date: date, id: id));
  late AppDatabase db;
  late DriftDiaryRepository inner;
  late ControlledDiaryRepository repo;
  late ProviderContainer scope;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    inner = DriftDiaryRepository(db, clock: () => DateTime.utc(2026, 11, 2));
    await inner.save(
      id: id,
      date: date,
      text: const DiaryText(body: 'Initial'),
      expectedRevision: 0,
    );
    repo = ControlledDiaryRepository(inner);
    scope = ProviderContainer(
      overrides: [
        diaryRepositoryProvider.overrideWithValue(repo),
        diaryIdProvider.overrideWithValue(() => copyId),
      ],
    );
    scope.listen(provider, (_, _) {});
    await scope.read(provider.future);
  });
  tearDown(() async {
    scope.dispose();
    await db.close();
  });
  DiaryEditorController editor() => scope.read(provider.notifier);
  DiaryEditorState state() => scope.read(provider).requireValue;

  test('editing stays in memory; save waits for storage and blocks duplicate submits', () async {
    editor().edit(const DiaryText(body: 'Changed 👩🏽‍💻'));
    expect(state().changed, isTrue);
    expect((await inner.openDocument(id)).entry!.text.body, 'Initial');
    repo.commitGate = Completer<void>();
    final pending = editor().save();
    expect(state().saving, isTrue);
    expect(await editor().save(), isFalse);
    repo.commitGate!.complete();
    expect(await pending, isTrue);
    expect((await inner.openDocument(id)).entry!.text.body, 'Changed 👩🏽‍💻');
    expect(state().changed, isFalse);
    expect(repo.commits, 1);
  });
  test(
    'failed save keeps buffer for retry without changing saved writing',
    () async {
      editor().edit(const DiaryText(body: 'Changed 👩🏽‍💻'));
      repo.failCommit = true;
      expect(await editor().save(), isFalse);
      expect(state().text.body, 'Changed 👩🏽‍💻');
      expect((await inner.openDocument(id)).entry!.text.body, 'Initial');
      repo.failCommit = false;
      expect(await editor().save(), isTrue);
    },
  );
  test('stale or deleted source cannot overwrite writing; save copy remains explicit', () async {
    editor().edit(const DiaryText(body: 'Changed 👩🏽‍💻'));
    await inner.deleteEntry(id, 1);
    expect(await editor().save(), isFalse);
    expect(state().sourceUnavailable, isTrue);
    expect(await editor().saveCopy(), copyId);
    expect(
      (await inner.openDocument(copyId)).entry!.text.body,
      'Changed 👩🏽‍💻',
    );
    expect((await inner.openDocument(id)).available, isFalse);
  });
  test(
    'discard restores saved text and reopening never restores unsaved edits',
    () async {
      editor().edit(const DiaryText(body: 'Changed 👩🏽‍💻'));
      expect(await editor().discard(), isTrue);
      expect(state().text.body, 'Initial');
      editor().edit(const DiaryText(body: 'Changed 👩🏽‍💻'));
      scope.invalidate(provider);
      expect((await scope.read(provider.future)).text.body, 'Initial');
      expect(repo.commits, 0);
    },
  );
  test('blank saves and copies are ignored', () async {
    editor().edit(const DiaryText(body: ' \n\t'));
    expect(await editor().save(), isFalse);
    expect(await editor().saveCopy(), isNull);
    expect(repo.commits, 0);
  });
}
