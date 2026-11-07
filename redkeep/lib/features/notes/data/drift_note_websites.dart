import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../../sync/data/drift_sync_store.dart';
import '../domain/note_document.dart';
import '../domain/note_website.dart';

/// Websites kept beside notes on this device. They never enter the note's
/// text, details or sync.
class DriftNoteWebsites {
  DriftNoteWebsites(this._db) : _generation = _db.writingGeneration;
  final AppDatabase _db;
  final int _generation;

  static final _hash = RegExp(r'^[a-f0-9]{64}$');

  Stream<NoteWebsite?> watch(String id) {
    if (!isNoteId(id)) return Stream.value(null);
    return (_db.select(_db.noteWebsites)..where((r) => r.noteId.equals(id)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _fromRow(row));
  }

  Future<NoteWebsite?> get(String id) async {
    if (!isNoteId(id)) return null;
    final row = await (_db.select(
      _db.noteWebsites,
    )..where((r) => r.noteId.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Replaces the note's website. The note itself is not touched.
  Future<void> save(NoteWebsite website) async {
    if (!isNoteId(website.noteId) ||
        website.html.trim().isEmpty ||
        !_hash.hasMatch(website.sourceHash)) {
      throw const NoteException(NoteFailure.unavailable);
    }
    await _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      final note = await (_db.select(
        _db.notes,
      )..where((r) => r.id.equals(website.noteId))).getSingleOrNull();
      if (note == null || note.deletedAt != null) {
        throw const NoteException(NoteFailure.unavailable);
      }
      await _db
          .into(_db.noteWebsites)
          .insertOnConflictUpdate(
            NoteWebsitesCompanion.insert(
              noteId: website.noteId,
              html: website.html,
              sourceHash: website.sourceHash,
              brief: Value(website.brief),
              model: Value(website.model),
              madeAt: website.madeAt.toUtc().millisecondsSinceEpoch,
            ),
          );
    });
  }

  Future<void> delete(String id) async {
    if (!isNoteId(id)) return;
    await _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      await (_db.delete(
        _db.noteWebsites,
      )..where((r) => r.noteId.equals(id))).go();
    });
  }

  static NoteWebsite _fromRow(NoteWebsiteRow row) => NoteWebsite(
    noteId: row.noteId,
    html: row.html,
    sourceHash: row.sourceHash,
    brief: row.brief,
    model: row.model,
    madeAt: DateTime.fromMillisecondsSinceEpoch(row.madeAt, isUtc: true),
  );
}
