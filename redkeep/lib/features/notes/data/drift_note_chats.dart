import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../../sync/data/drift_sync_store.dart';
import '../domain/note_chat.dart';
import '../domain/note_document.dart';

/// Each note's conversation with the Maester, kept on this device only.
class DriftNoteChats {
  DriftNoteChats(this._db) : _generation = _db.writingGeneration;
  final AppDatabase _db;
  final int _generation;

  Stream<List<NoteChatTurn>> watch(String noteId) {
    if (!isNoteId(noteId)) return Stream.value(const []);
    return (_db.select(_db.noteChatTurns)
          ..where((r) => r.noteId.equals(noteId))
          ..orderBy([
            (r) => OrderingTerm.asc(r.at),
            (r) => OrderingTerm.asc(r.id),
          ]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  Future<List<NoteChatTurn>> turns(String noteId) => watch(noteId).first;

  /// Adds [turn] and drops the oldest past [noteChatKeptTurns].
  Future<void> add(NoteChatTurn turn) async {
    if (!isNoteId(turn.noteId)) {
      throw const NoteException(NoteFailure.unavailable);
    }
    await _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      await _db
          .into(_db.noteChatTurns)
          .insert(
            NoteChatTurnsCompanion.insert(
              id: turn.id,
              noteId: turn.noteId,
              at: turn.at.toUtc().millisecondsSinceEpoch,
              ask: turn.ask,
              reply: Value(turn.reply),
              actions: Value(NoteChatTurn.encodeActions(turn.actions)),
            ),
          );
      final kept =
          await (_db.selectOnly(_db.noteChatTurns)
                ..addColumns([_db.noteChatTurns.id])
                ..where(_db.noteChatTurns.noteId.equals(turn.noteId))
                ..orderBy([
                  OrderingTerm.desc(_db.noteChatTurns.at),
                  OrderingTerm.desc(_db.noteChatTurns.id),
                ])
                ..limit(noteChatKeptTurns))
              .map((r) => r.read(_db.noteChatTurns.id)!)
              .get();
      await (_db.delete(
        _db.noteChatTurns,
      )..where((r) => r.noteId.equals(turn.noteId) & r.id.isNotIn(kept))).go();
    });
  }

  /// Changes one call's outcome; false when the turn is gone.
  Future<bool> updateAction(
    String turnId,
    String callId,
    NoteChatAction Function(NoteChatAction action) change,
  ) => _db.transaction(() async {
    await checkWritingAccess(_db, _generation);
    final row = await (_db.select(
      _db.noteChatTurns,
    )..where((r) => r.id.equals(turnId))).getSingleOrNull();
    if (row == null) return false;
    final turn = _fromRow(row).withAction(callId, change);
    await (_db.update(
      _db.noteChatTurns,
    )..where((r) => r.id.equals(turnId))).write(
      NoteChatTurnsCompanion(
        actions: Value(NoteChatTurn.encodeActions(turn.actions)),
      ),
    );
    return true;
  });

  Future<void> clear(String noteId) => _db.transaction(() async {
    await checkWritingAccess(_db, _generation);
    await (_db.delete(
      _db.noteChatTurns,
    )..where((r) => r.noteId.equals(noteId))).go();
  });

  static NoteChatTurn _fromRow(NoteChatTurnRow row) => NoteChatTurn(
    id: row.id,
    noteId: row.noteId,
    at: DateTime.fromMillisecondsSinceEpoch(row.at, isUtc: true),
    ask: row.ask,
    reply: row.reply,
    actions: NoteChatTurn.decodeActions(row.actions),
  );
}
