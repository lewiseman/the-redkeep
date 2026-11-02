import 'dart:async';

import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/domain/notes_repository.dart';

/// Failure/commit gates wrap a disposable repository, never user storage.
class ControlledNotesRepository implements NotesRepository {
  ControlledNotesRepository(this.inner);
  final NotesRepository inner;
  bool failDraft = false;
  bool failCommit = false;
  bool failRead = false;
  Completer<void>? draftGate;
  Completer<void>? commitGate;
  int commits = 0;

  @override
  Future<RecoveryDraft> putDraft({
    required String id,
    required PlainTextDocument text,
    required int baseRevision,
    required int? expectedDraftRevision,
  }) async {
    await draftGate?.future;
    if (failDraft) throw StateError('synthetic recovery failure');
    return inner.putDraft(
      id: id,
      text: text,
      baseRevision: baseRevision,
      expectedDraftRevision: expectedDraftRevision,
    );
  }

  @override
  Future<NoteDocument> commitDraft(String id, int expectedDraftRevision) async {
    commits++;
    await commitGate?.future;
    if (failCommit) throw StateError('synthetic commit failure');
    return inner.commitDraft(id, expectedDraftRevision);
  }

  @override
  Future<OpenNote> openDocument(String id) async {
    if (failRead) throw StateError('synthetic read failure');
    return inner.openDocument(id);
  }

  @override
  Stream<OpenNote> watchDocument(String id) => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchDocument(id);
  @override
  Stream<List<NoteListing>> watchNotes() => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchNotes();
  @override
  Stream<List<NoteListing>> watchDrafts() => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchDrafts();
  @override
  Future<void> deleteNote(String id, int expectedRevision) =>
      inner.deleteNote(id, expectedRevision);
  @override
  Future<void> discardDraft(String id, int expectedDraftRevision) =>
      inner.discardDraft(id, expectedDraftRevision);
}
