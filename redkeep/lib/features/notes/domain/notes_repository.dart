import 'note_document.dart';

abstract interface class NotesRepository {
  Stream<List<NoteListing>> watchNotes();
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
  Future<void> discardDraft(String id, int expectedDraftRevision);
}
