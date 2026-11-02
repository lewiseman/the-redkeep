import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/notes/application/note_editor_controller.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';

import '../../support/controlled_notes_repository.dart';

const id = '11111111111111111111111111111111';
const copyId = '22222222222222222222222222222222';

void main() {
  late AppDatabase db;
  late DriftNotesRepository inner;
  late ControlledNotesRepository repo;
  late ProviderContainer scope;
  final provider = noteEditorProvider(id);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    inner = DriftNotesRepository(db, clock: () => DateTime.utc(2026, 11, 2));
    repo = ControlledNotesRepository(inner);
    await inner.putDraft(
      id: id,
      text: const PlainTextDocument(body: 'Initial'),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    scope = ProviderContainer.test(
      overrides: [
        notesRepositoryProvider.overrideWithValue(repo),
        noteIdProvider.overrideWithValue(() => copyId),
      ],
    );
    scope.listen(provider, (_, _) {});
    await scope.read(provider.future);
  });
  tearDown(() async {
    await db.close();
  });

  NoteEditorController editor() => scope.read(provider.notifier);
  NoteEditorState state() => scope.read(provider).requireValue;

  test(
    'coalesced recovery preserves the latest buffer; success waits for commit',
    () async {
      repo.draftGate = Completer<void>();
      editor().edit(const PlainTextDocument(body: 'First'));
      editor().edit(const PlainTextDocument(body: 'Last 👩🏽‍💻'));
      expect(state().recovering, isTrue);
      repo.draftGate!.complete();
      expect(await editor().flushRecovery(), isTrue);
      expect((await inner.openDocument(id)).draft!.text.body, 'Last 👩🏽‍💻');
      repo.commitGate = Completer<void>();
      final saving = editor().save();
      await Future<void>.delayed(Duration.zero);
      expect(state().saving, isTrue);
      expect(state().message, isNull);
      expect((await inner.openDocument(id)).note, isNull);
      expect(await editor().save(), isFalse);
      editor().edit(const PlainTextDocument(body: 'Blocked while saving'));
      expect(state().text.body, 'Last 👩🏽‍💻');
      repo.commitGate!.complete();
      expect(await saving, isTrue);
      expect(state().message, 'Saved revision 1 on this device.');
      expect((await inner.openDocument(id)).draft, isNull);
      expect(repo.commits, 1);
    },
  );

  test('failed recovery or commit keeps writing; retry commits it', () async {
    repo.failDraft = true;
    editor().edit(const PlainTextDocument(body: 'Keep me'));
    expect(await editor().flushRecovery(), isFalse);
    expect(state().text.body, 'Keep me');
    expect(state().recoveryFailed, isTrue);
    expect(await editor().save(), isFalse);
    expect(repo.commits, 0);
    repo.failDraft = false;
    expect(await editor().flushRecovery(), isTrue);
    repo.failCommit = true;
    expect(await editor().save(), isFalse);
    expect(state().message, contains('Save failed'));
    expect((await inner.openDocument(id)).draft!.text.body, 'Keep me');
    expect((await inner.openDocument(id)).note, isNull);
    repo.failCommit = false;
    expect(await editor().save(), isTrue);
    expect((await inner.openDocument(id)).note!.text.body, 'Keep me');
  });

  test(
    'stale revision keeps draft and offers a new stable-ID committed copy',
    () async {
      expect(await editor().save(), isTrue);
      // Another writer commits before this editor has edited its revision 1.
      final elsewhere = await inner.putDraft(
        id: id,
        text: const PlainTextDocument(body: 'Other writer'),
        baseRevision: 1,
        expectedDraftRevision: null,
      );
      await inner.commitDraft(id, elsewhere.draftRevision);
      editor().edit(const PlainTextDocument(body: 'My stale writing'));
      await editor().flushRecovery();
      expect(await editor().save(), isFalse);
      expect(state().message, contains('changed'));
      expect(await editor().saveCopy(), copyId);
      expect(
        (await inner.openDocument(copyId)).note!.text.body,
        'My stale writing',
      );
      expect((await inner.openDocument(id)).note!.text.body, 'Other writer');
      expect(
        (await inner.openDocument(id)).draft!.text.body,
        'My stale writing',
      );
    },
  );

  test(
    'navigation disposal settles pending recovery and reopening restores it',
    () async {
      repo.draftGate = Completer<void>();
      editor().edit(const PlainTextDocument(body: 'Recover after navigation'));
      final pending = editor().flushRecovery();
      scope.dispose();
      repo.draftGate!.complete();
      expect(await pending, isTrue);
      final reopened = ProviderContainer.test(
        overrides: [notesRepositoryProvider.overrideWithValue(repo)],
      );
      reopened.listen(provider, (_, _) {});
      expect(
        (await reopened.read(provider.future)).text.body,
        'Recover after navigation',
      );
    },
  );

  test(
    'read failure retries without modifying drafts; discard is explicit',
    () async {
      repo.failRead = true;
      scope.invalidate(provider);
      await expectLater(scope.read(provider.future), throwsStateError);
      expect((await inner.openDocument(id)).draft!.text.body, 'Initial');
      repo.failRead = false;
      scope.invalidate(provider);
      await scope.read(provider.future);
      expect(await editor().discard(), isTrue);
      expect((await inner.openDocument(id)).draft, isNull);
      expect((await inner.openDocument(id)).note, isNull);
    },
  );

  test('replacement draft during a delayed commit keeps the current buffer recoverable as a copy', () async {
    final token = (await inner.openDocument(id)).draft!.draftRevision;
    repo.commitGate = Completer<void>();
    final saving = editor().save();
    await Future<void>.delayed(Duration.zero);
    await inner.putDraft(
      id: id,
      text: const PlainTextDocument(body: 'Different recovery'),
      baseRevision: 0,
      expectedDraftRevision: token,
    );
    repo.commitGate!.complete();
    expect(await saving, isFalse);
    expect(state().recoveryFailed, isTrue);
    expect(state().text.body, 'Initial');
    expect(
      (await inner.openDocument(id)).draft!.text.body,
      'Different recovery',
    );
    expect(await editor().saveCopy(), copyId);
    expect((await inner.openDocument(copyId)).note!.text.body, 'Initial');
  });

  test('copy commit failure leaves source and copy recovery drafts', () async {
    repo.failCommit = true;
    expect(await editor().saveCopy(), isNull);
    expect((await inner.openDocument(copyId)).draft!.text.body, 'Initial');
    expect((await inner.openDocument(id)).draft!.text.body, 'Initial');
    expect(state().message, contains('Copy could not be committed'));
  });

  test(
    'deleted source reopens its draft and recovers only under a new ID',
    () async {
      await editor().save();
      editor().edit(
        const PlainTextDocument(body: 'Writing after saved revision'),
      );
      await editor().flushRecovery();
      await inner.deleteNote(id, 1);
      scope.invalidate(provider);
      expect((await scope.read(provider.future)).sourceUnavailable, isTrue);
      expect(await editor().save(), isFalse);
      expect(await editor().saveCopy(), copyId);
      expect((await inner.openDocument(id)).available, isFalse);
      expect(
        (await inner.openDocument(id)).draft!.text.body,
        'Writing after saved revision',
      );
      expect(
        (await inner.openDocument(copyId)).note!.text.body,
        'Writing after saved revision',
      );
    },
  );
}
