/// Application-owned plain-text boundary. No editor, database or CRDT types.
class PlainTextDocument {
  const PlainTextDocument({this.title = '', this.body = ''});
  final String title;
  final String body;
}

class NoteDocument {
  const NoteDocument({
    required this.id,
    required this.text,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  final String id;
  final PlainTextDocument text;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class RecoveryDraft {
  const RecoveryDraft({
    required this.id,
    required this.text,
    required this.baseRevision,
    required this.draftRevision,
    required this.updatedAt,
  });
  final String id;
  final PlainTextDocument text;
  final int baseRevision;
  final int draftRevision;
  final DateTime updatedAt;
}

class OpenNote {
  const OpenNote({this.note, this.draft});
  final NoteDocument? note;
  final RecoveryDraft? draft;
  bool get available => note != null && note!.deletedAt == null;
}

/// Lists deliberately omit bodies, including very large recovery documents.
class NoteListing {
  const NoteListing({
    required this.id,
    required this.title,
    required this.revision,
    required this.updatedAt,
  });
  final String id;
  final String title;
  final int revision;
  final DateTime updatedAt;
}

String noteTitle(String title) =>
    title.trim().isEmpty ? 'Untitled note' : title;

bool isNoteId(String value) => RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

enum NoteFailure { unavailable, staleRevision, draftChanged }

class NoteException implements Exception {
  const NoteException(this.failure);
  final NoteFailure failure;
}
