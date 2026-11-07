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
    await inner.saveNote(
      id: id,
      expectedRevision: 0,
      text: const PlainTextDocument(body: 'Initial'),
      details: const NoteDetails(),
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
    scope.dispose();
    await db.close();
  });

  NoteEditorController editor() => scope.read(provider.notifier);
  NoteEditorState state() => scope.read(provider).requireValue;
  Future<NoteDocument?> saved([String noteId = id]) async =>
      (await inner.openDocument(noteId)).note;

  Future<NoteEditorController> fresh() async {
    final newId = (await scope.read(notesActionsProvider.notifier).create())!;
    expect(newId, copyId);
    final editor = noteEditorProvider(newId);
    scope.listen(editor, (_, _) {});
    await scope.read(editor.future);
    return scope.read(editor.notifier);
  }

  test('a new note is created by its first non-empty save', () async {
    final controller = await fresh();
    final before = scope.read(noteEditorProvider(copyId)).requireValue;
    expect(before.baseRevision, 0);
    expect(
      await controller.appendReviewedTranscript(
        expected: before,
        transcript: ' Spoken words ',
        stillCurrent: () => true,
      ),
      isTrue,
    );
    expect(await saved(copyId), isNull);
    expect(await controller.save(), isTrue);
    expect((await saved(copyId))!.text.body, 'Spoken words');
    expect(scope.read(noteNewIdsProvider), isNot(contains(copyId)));
    expect(scope.read(noteEditorProvider(copyId)).requireValue.baseRevision, 1);
  });

  test('a new note left empty or whitespace is never created', () async {
    final controller = await fresh();
    controller.edit(const PlainTextDocument(title: ' \n', body: '\t '));
    expect(await controller.save(), isTrue);
    expect(await controller.saveCopy(), isNull);
    expect(await saved(copyId), isNull);
    expect(await inner.watchNotes().first, hasLength(1));
  });

  test('writing autosaves into the note shortly after typing stops', () async {
    editor().edit(const PlainTextDocument(title: 'Title', body: 'Typed'));
    expect(state().dirty, isTrue);
    expect((await saved())!.revision, 1);
    await Future<void>.delayed(
      NoteEditorController.autosaveDelay + const Duration(milliseconds: 300),
    );
    final note = (await saved())!;
    expect(note.text.title, 'Title');
    expect(note.text.body, 'Typed');
    expect(note.revision, 2);
    expect(state().dirty, isFalse);
    expect(state().baseRevision, 2);
  });

  test('typing during a save is kept and saved right after it', () async {
    repo.saveGate = Completer<void>();
    editor().edit(const PlainTextDocument(body: 'First'));
    final saving = editor().save();
    await Future<void>.delayed(Duration.zero);
    expect(state().saving, isTrue);
    editor().edit(const PlainTextDocument(body: 'Last 👩🏽‍💻'));
    expect(state().text.body, 'Last 👩🏽‍💻');
    repo.saveGate!.complete();
    expect(await saving, isTrue);
    expect((await saved())!.text.body, 'Last 👩🏽‍💻');
    expect(state().dirty, isFalse);
  });

  test('an existing note emptied completely is not saved', () async {
    editor().edit(const PlainTextDocument(title: ' ', body: '\n\t'));
    expect(await editor().save(), isFalse);
    expect(state().message, contains('empty note'));
    expect((await saved())!.text.body, 'Initial');
  });

  test('a failed save keeps the writing and a retry saves it', () async {
    repo.failSave = true;
    editor().edit(const PlainTextDocument(body: 'Keep me'));
    expect(await editor().save(), isFalse);
    expect(state().text.body, 'Keep me');
    expect(state().dirty, isTrue);
    expect(state().message, contains('could not be saved'));
    repo.failSave = false;
    expect(await editor().save(), isTrue);
    expect((await saved())!.text.body, 'Keep me');
  });

  test(
    'a change elsewhere becomes a conflict that keeps the writing as a copy',
    () async {
      await inner.saveNote(
        id: id,
        expectedRevision: 1,
        text: const PlainTextDocument(body: 'Other writer'),
        details: const NoteDetails(),
      );
      // The editor is dirty, so it does not adopt the other revision.
      editor().edit(const PlainTextDocument(body: 'My stale writing'));
      expect(await editor().save(), isFalse);
      expect(state().conflict, isTrue);
      expect(state().message, contains('changed'));
      expect(await editor().saveCopy(), copyId);
      expect((await saved(copyId))!.text.body, 'My stale writing');
      expect((await saved())!.text.body, 'Other writer');
      expect(state().dirty, isFalse);
    },
  );

  test('a deleted note becomes a conflict instead of reviving it', () async {
    editor().edit(const PlainTextDocument(body: 'Writing after delete'));
    await inner.deleteNote(id, 1);
    expect(await editor().save(), isFalse);
    expect(state().conflict, isTrue);
    expect((await inner.openDocument(id)).available, isFalse);
    expect(await editor().saveCopy(), copyId);
    expect((await saved(copyId))!.text.body, 'Writing after delete');
  });

  test('a newer saved revision is adopted while nothing is unsaved', () async {
    await inner.applyProposal(
      id,
      1,
      text: const PlainTextDocument(body: 'From AI'),
      details: const NoteDetails(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(state().text.body, 'From AI');
    expect(state().baseRevision, 2);
    editor().edit(const PlainTextDocument(body: 'Then mine'));
    expect(await editor().save(), isTrue);
    expect((await saved())!.revision, 3);
  });

  test('dictation rejects editor and repository changes', () async {
    final before = state();
    editor().edit(const PlainTextDocument(body: 'Manual words'));
    expect(
      await editor().appendReviewedTranscript(
        expected: before,
        transcript: 'Voice',
        stillCurrent: () => true,
      ),
      isFalse,
    );
    expect(state().text.body, 'Manual words');
    expect(await editor().save(), isTrue);
    final current = state();
    await inner.saveNote(
      id: id,
      expectedRevision: current.baseRevision,
      text: const PlainTextDocument(body: 'Other'),
      details: const NoteDetails(),
    );
    expect(
      await editor().appendReviewedTranscript(
        expected: current,
        transcript: 'Voice',
        stillCurrent: () => true,
      ),
      isFalse,
    );
  });

  test('discarding changes leaves the saved note untouched', () async {
    editor().edit(const PlainTextDocument(body: 'Throw away'));
    editor().discardChanges();
    expect(state().dirty, isFalse);
    expect(await editor().save(), isTrue);
    expect((await saved())!.text.body, 'Initial');
    expect((await saved())!.revision, 1);
  });

  test('a read failure can be retried', () async {
    repo.failRead = true;
    scope.invalidate(provider);
    await expectLater(scope.read(provider.future), throwsStateError);
    repo.failRead = false;
    scope.invalidate(provider);
    expect((await scope.read(provider.future)).text.body, 'Initial');
  });
}
