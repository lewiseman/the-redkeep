import 'dart:async';

import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/domain/note_collection_entry.dart';
import 'package:redkeep/features/notes/domain/notes_repository.dart';
import 'package:redkeep/features/notes/domain/notes_query.dart';

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
  Stream<List<NoteCollectionEntry>> watchCollection({
    NotesQuery query = const NotesQuery(),
    bool draftsOnly = false,
  }) => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchCollection(query: query, draftsOnly: draftsOnly);

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
  Stream<List<NoteListing>> watchNotes({
    NotesQuery query = const NotesQuery(),
  }) => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchNotes(query: query);
  @override
  Stream<List<NoteListing>> watchDrafts() => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchDrafts();
  @override
  Future<void> deleteNote(String id, int expectedRevision) =>
      inner.deleteNote(id, expectedRevision);
  @override
  Stream<List<String>> watchTags({bool trash = false}) => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchTags(trash: trash);
  @override
  Future<void> organize(
    String id,
    int revision, {
    required bool pinned,
    required List<String> tags,
  }) => inner.organize(id, revision, pinned: pinned, tags: tags);
  @override
  Future<void> restoreNote(String id, int revision) =>
      inner.restoreNote(id, revision);
  @override
  Future<void> permanentlyDelete(
    String id,
    int revision, {
    required int? expectedDraftRevision,
  }) => inner.permanentlyDelete(
    id,
    revision,
    expectedDraftRevision: expectedDraftRevision,
  );
  @override
  Future<void> discardDraft(String id, int expectedDraftRevision) =>
      inner.discardDraft(id, expectedDraftRevision);
}
