import 'note_document.dart';
import 'note_collection_entry.dart';
import 'notes_query.dart';

abstract interface class NotesRepository {
  Stream<List<NoteCollectionEntry>> watchCollection({
    NotesQuery query = const NotesQuery(),
  });
  Stream<List<NoteListing>> watchNotes({NotesQuery query = const NotesQuery()});
  Stream<List<String>> watchTags({bool trash = false});
  Stream<OpenNote> watchDocument(String id);
  Future<OpenNote> openDocument(String id);

  /// Saves writing straight into the note with a compare-and-swap.
  /// [expectedRevision] 0 creates the note and fails if it already exists;
  /// otherwise the live note must still be at that revision. Title, body and
  /// details cannot all be empty.
  Future<NoteDocument> saveNote({
    required String id,
    required int expectedRevision,
    required PlainTextDocument text,
    required NoteDetails details,
  });
  Future<void> deleteNote(String id, int expectedRevision);
  Future<void> organize(
    String id,
    int expectedRevision, {
    required bool pinned,
    required List<String> tags,
  });
  Future<void> restoreNote(String id, int expectedRevision);

  /// Only trashed notes. Atomically removes the source and its tags.
  Future<void> permanentlyDelete(String id, int expectedRevision);

  /// Applies a reviewed saved-note proposal atomically.
  Future<NoteDocument> applyProposal(
    String id,
    int expectedRevision, {
    required PlainTextDocument text,
    required NoteDetails details,
  });
}
