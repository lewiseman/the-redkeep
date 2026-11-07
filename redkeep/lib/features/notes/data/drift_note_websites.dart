import 'dart:convert';

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
    final row = await _row(id);
    return row == null ? null : _fromRow(row);
  }

  /// The most a page may save for itself.
  static const stateBytes = 64 * 1024;

  /// Replaces the note's website. The note itself is not touched. The page
  /// it replaces is kept once, so the change can be undone; what the page
  /// saved for itself and its checklist choice stay.
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
      final old = await _row(website.noteId);
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
              state: Value(old?.state ?? ''),
              previousHtml: Value(old?.html ?? ''),
              previousSourceHash: Value(old?.sourceHash ?? ''),
              syncChecks: Value(old?.syncChecks ?? false),
            ),
          );
    });
  }

  /// Puts back the page from before the last remix or rebuild. The newer
  /// page becomes the one to undo to, so undo can be undone.
  Future<bool> undo(String id) => _update(id, (row) {
    if (row.previousHtml.isEmpty) return null;
    return NoteWebsitesCompanion(
      html: Value(row.previousHtml),
      sourceHash: Value(row.previousSourceHash),
      previousHtml: Value(row.html),
      previousSourceHash: Value(row.sourceHash),
    );
  });

  /// Keeps what the page saved for itself. Throws [FormatException] when it
  /// is not JSON or larger than [stateBytes].
  Future<bool> saveState(String id, String state) {
    if (state.length > stateBytes || utf8.encode(state).length > stateBytes) {
      throw const FormatException('The page saved too much.');
    }
    jsonDecode(state);
    return _update(id, (_) => NoteWebsitesCompanion(state: Value(state)));
  }

  Future<bool> setSyncChecks(String id, bool value) =>
      _update(id, (_) => NoteWebsitesCompanion(syncChecks: Value(value)));

  /// After the page itself changed the note, the page still matches it:
  /// moves the source from [from] to [to] only if it was current.
  Future<bool> followNote(
    String id, {
    required String from,
    required String to,
  }) => _update(id, (row) {
    if (row.sourceHash != from || !_hash.hasMatch(to)) return null;
    return NoteWebsitesCompanion(sourceHash: Value(to));
  });

  Future<NoteWebsiteRow?> _row(String id) => (_db.select(
    _db.noteWebsites,
  )..where((r) => r.noteId.equals(id))).getSingleOrNull();

  Future<bool> _update(
    String id,
    NoteWebsitesCompanion? Function(NoteWebsiteRow row) change,
  ) async {
    if (!isNoteId(id)) return false;
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      final row = await _row(id);
      final companion = row == null ? null : change(row);
      if (companion == null) return false;
      await (_db.update(
        _db.noteWebsites,
      )..where((r) => r.noteId.equals(id))).write(companion);
      return true;
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
    state: row.state,
    previousHtml: row.previousHtml,
    previousSourceHash: row.previousSourceHash,
    syncChecks: row.syncChecks,
  );
}
