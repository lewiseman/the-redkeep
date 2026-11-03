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

const id = 'a1111111111111111111111111111111';
const text = PlainTextDocument(
  title: 'Synthetic title',
  body: 'Before 👩🏽‍💻 中文 e\u0301 after',
);

void main() {
  late AppDatabase db;
  late DriftNotesRepository repository;
  late ControlledNotesRepository controlled;
  late ProviderContainer scope;
  late NoteEditorController editor;
  late NoteEditorState captured;
  var current = true;
  Future<bool> accept() => editor.acceptReplacement(
    expected: captured,
    start: 7,
    end: 14,
    replacement: 'a tree',
    stillCurrent: () => current,
  );
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftNotesRepository(
      db,
      clock: () => DateTime.utc(2026, 11, 3),
    );
    controlled = ControlledNotesRepository(repository);
    final draft = await repository.putDraft(
      id: id,
      text: text,
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    await repository.commitDraft(id, draft.draftRevision);
    scope = ProviderContainer(
      overrides: [notesRepositoryProvider.overrideWithValue(controlled)],
    );
    scope.listen(noteEditorProvider(id), (_, _) {});
    captured = await scope.read(noteEditorProvider(id).future);
    editor = scope.read(noteEditorProvider(id).notifier);
    current = true;
  });
  tearDown(() async {
    scope.dispose();
    await db.close();
  });

  test('explicit acceptance preserves surrounding Unicode/title and only manual save commits', () async {
    expect(await accept(), isTrue);
    await editor.flushRecovery();
    var opened = await repository.openDocument(id);
    expect(opened.note!.text.body, text.body);
    expect(opened.note!.revision, 1);
    expect(opened.draft!.text.body, text.body.replaceRange(7, 14, 'a tree'));
    expect(opened.draft!.text.title, text.title);
    expect(await accept(), isFalse);
    expect(await editor.save(), isTrue);
    opened = await repository.openDocument(id);
    expect(opened.note!.revision, 2);
    expect(opened.draft, isNull);
  });

  for (final change in [
    'edit',
    'edit and undo',
    'delete',
    'revision',
    'draft token',
    'selection',
    'failed recovery',
  ]) {
    test('$change before acceptance preserves both versions', () async {
      switch (change) {
        case 'edit':
          editor.edit(const PlainTextDocument(body: 'New writing'));
        case 'edit and undo':
          editor.edit(const PlainTextDocument(body: 'Temporary edit'));
          editor.edit(text);
        case 'delete':
          await repository.deleteNote(id, 1);
        case 'revision':
          await repository.organize(id, 1, pinned: true, tags: ['tree']);
        case 'draft token':
          await repository.putDraft(
            id: id,
            text: const PlainTextDocument(body: 'Other recovery'),
            baseRevision: 1,
            expectedDraftRevision: null,
          );
        case 'selection':
          current = false;
        case 'failed recovery':
          controlled.failDraft = true;
          editor.edit(
            const PlainTextDocument(body: 'Undurable current writing'),
          );
      }
      expect(await accept(), isFalse);
      await editor.flushRecovery();
      expect((await repository.openDocument(id)).note!.text.body, text.body);
      expect(
        scope.read(noteEditorProvider(id)).requireValue.text.body,
        change == 'edit'
            ? 'New writing'
            : change == 'failed recovery'
            ? 'Undurable current writing'
            : text.body,
      );
    });
  }

  test(
    'selection changes while pending recovery is flushed block replacement',
    () async {
      editor.edit(text);
      controlled.draftGate = Completer<void>();
      editor.edit(text);
      captured = scope.read(noteEditorProvider(id)).requireValue;
      final pending = accept();
      current = false;
      controlled.draftGate!.complete();
      expect(await pending, isFalse);
      expect(
        scope.read(noteEditorProvider(id)).requireValue.text.body,
        text.body,
      );
    },
  );

  test(
    'source changes after accepted buffer still cannot be overwritten by Save',
    () async {
      expect(await accept(), isTrue);
      await editor.flushRecovery();
      await repository.organize(id, 1, pinned: true, tags: []);
      expect(await editor.save(), isFalse);
      final opened = await repository.openDocument(id);
      expect(opened.note!.text.body, text.body);
      expect(opened.note!.revision, 2);
      expect(opened.draft!.text.body, text.body.replaceRange(7, 14, 'a tree'));
    },
  );
}
