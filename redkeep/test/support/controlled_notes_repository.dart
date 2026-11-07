import 'dart:async';

import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/domain/note_collection_entry.dart';
import 'package:redkeep/features/notes/domain/notes_repository.dart';
import 'package:redkeep/features/notes/domain/notes_query.dart';

/// Failure/commit gates wrap a disposable repository, never user storage.
class ControlledNotesRepository implements NotesRepository {
  ControlledNotesRepository(this.inner);
  final NotesRepository inner;
  bool failSave = false;
  bool failRead = false;
  Completer<void>? saveGate;
  int saves = 0;

  @override
  Stream<List<NoteCollectionEntry>> watchCollection({
    NotesQuery query = const NotesQuery(),
  }) => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchCollection(query: query);

  @override
  Future<NoteDocument> saveNote({
    required String id,
    required int expectedRevision,
    required PlainTextDocument text,
    required NoteDetails details,
  }) async {
    saves++;
    await saveGate?.future;
    if (failSave) throw StateError('synthetic save failure');
    return inner.saveNote(
      id: id,
      expectedRevision: expectedRevision,
      text: text,
      details: details,
    );
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
  Future<void> permanentlyDelete(String id, int revision) =>
      inner.permanentlyDelete(id, revision);
  @override
  Future<NoteDocument> applyProposal(
    String id,
    int expectedRevision, {
    required PlainTextDocument text,
    required NoteDetails details,
    required String taskId,
    required String operation,
    bool retainPrior = true,
  }) => inner.applyProposal(
    id,
    expectedRevision,
    text: text,
    details: details,
    taskId: taskId,
    operation: operation,
    retainPrior: retainPrior,
  );
  @override
  Future<List<NotePriorContent>> priorContent(String id) =>
      inner.priorContent(id);
  @override
  Future<void> restorePriorContent(
    String id,
    int recoveryId,
    int expectedRevision,
  ) => inner.restorePriorContent(id, recoveryId, expectedRevision);
  @override
  Future<void> clearPriorContent(String id) => inner.clearPriorContent(id);
}
