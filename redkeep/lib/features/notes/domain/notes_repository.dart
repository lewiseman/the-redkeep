import 'note_document.dart';
import 'notes_query.dart';

abstract interface class NotesRepository {
  Stream<List<NoteListing>> watchNotes({NotesQuery query = const NotesQuery()});
  Stream<List<String>> watchTags({bool trash = false});
  Stream<List<NoteListing>> watchDrafts();
  Stream<OpenNote> watchDocument(String id);
  Future<OpenNote> openDocument(String id);

  /// Compare-and-swap protects recovery writing from another open editor.
  Future<RecoveryDraft> putDraft({
    required String id,
    required PlainTextDocument text,
    required int baseRevision,
    required int? expectedDraftRevision,
  });

  /// Commit note and remove precisely this draft in one transaction.
  /// Failure, including stale/deleted sources, must leave the draft intact.
  Future<NoteDocument> commitDraft(String id, int expectedDraftRevision);
  Future<void> deleteNote(String id, int expectedRevision);
  Future<void> organize(
    String id,
    int expectedRevision, {
    required bool pinned,
    required List<String> tags,
  });
  Future<void> restoreNote(String id, int expectedRevision);

  /// Only trashed notes. Atomically removes the source, tags and precisely the
  /// recovery draft reviewed by the user. A changed draft blocks deletion.
  Future<void> permanentlyDelete(
    String id,
    int expectedRevision, {
    required int? expectedDraftRevision,
  });
  Future<void> discardDraft(String id, int expectedDraftRevision);
}
