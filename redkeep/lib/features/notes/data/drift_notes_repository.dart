import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/note_document.dart';
import '../domain/notes_repository.dart';

class DriftNotesRepository implements NotesRepository {
  DriftNotesRepository(this._db, {required this._clock});
  final AppDatabase _db;
  final DateTime Function() _clock;

  void _validate(String id) {
    if (!isNoteId(id)) throw const NoteException(NoteFailure.unavailable);
  }

  @override
  Stream<List<NoteListing>> watchNotes() => _db
      .customSelect(
        'SELECT id, title, revision, updated_at FROM notes WHERE deleted_at IS NULL ORDER BY updated_at DESC, id',
        readsFrom: {_db.notes},
      )
      .watch()
      .map((rows) => rows.map((r) => _listing(r, 'revision')).toList());

  @override
  Stream<List<NoteListing>> watchDrafts() => _db
      .customSelect(
        'SELECT id, title, base_revision, updated_at FROM note_drafts ORDER BY updated_at DESC, id',
        readsFrom: {_db.noteDrafts},
      )
      .watch()
      .map((rows) => rows.map((r) => _listing(r, 'base_revision')).toList());

  NoteListing _listing(QueryRow row, String revision) => NoteListing(
    id: row.read<String>('id'),
    title: row.read<String>('title'),
    revision: row.read<int>(revision),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('updated_at'),
      isUtc: true,
    ),
  );

  @override
  Stream<OpenNote> watchDocument(String id) {
    _validate(id);
    // A joined query invalidates on both tables and emits consistent snapshots.
    final query = _db.select(_db.notes).join([
      leftOuterJoin(_db.noteDrafts, _db.noteDrafts.id.equalsExp(_db.notes.id)),
    ])..where(_db.notes.id.equals(id));
    return query.watch().asyncMap((_) => openDocument(id));
  }

  @override
  Future<OpenNote> openDocument(String id) async {
    _validate(id);
    return _db.transaction(() async {
      final note = await (_db.select(
        _db.notes,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      final draft = await (_db.select(
        _db.noteDrafts,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      return OpenNote(
        note: note == null ? null : _note(note),
        draft: draft == null ? null : _draft(draft),
      );
    });
  }

  @override
  Future<RecoveryDraft> putDraft({
    required String id,
    required PlainTextDocument text,
    required int baseRevision,
    required int? expectedDraftRevision,
  }) async {
    _validate(id);
    return _db.transaction(() async {
      final old = await (_db.select(
        _db.noteDrafts,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (old?.draftRevision != expectedDraftRevision ||
          (old != null && old.baseRevision != baseRevision)) {
        throw const NoteException(NoteFailure.draftChanged);
      }
      final now = _clock().toUtc().millisecondsSinceEpoch;
      if (old != null) await discardDraft(id, old.draftRevision);
      final version = await _db
          .into(_db.noteDrafts)
          .insert(
            NoteDraftsCompanion.insert(
              id: id,
              title: text.title,
              body: text.body,
              baseRevision: baseRevision,
              updatedAt: now,
            ),
          );
      return RecoveryDraft(
        id: id,
        text: text,
        baseRevision: baseRevision,
        draftRevision: version,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      );
    });
  }

  @override
  Future<NoteDocument> commitDraft(String id, int expectedDraftRevision) async {
    _validate(id);
    return _db.transaction(() async {
      final snapshot = await openDocument(id);
      final draft = snapshot.draft;
      if (draft == null || draft.draftRevision != expectedDraftRevision) {
        throw const NoteException(NoteFailure.draftChanged);
      }
      final old = snapshot.note;
      if (old?.deletedAt != null ||
          (old?.revision ?? 0) != draft.baseRevision) {
        throw const NoteException(NoteFailure.staleRevision);
      }
      final now = _clock().toUtc();
      final revision = draft.baseRevision + 1;
      if (old == null) {
        await _db
            .into(_db.notes)
            .insert(
              NotesCompanion.insert(
                id: id,
                title: draft.text.title,
                body: draft.text.body,
                revision: revision,
                createdAt: now.millisecondsSinceEpoch,
                updatedAt: now.millisecondsSinceEpoch,
              ),
            );
      } else {
        final count =
            await (_db.update(_db.notes)..where(
                  (r) =>
                      r.id.equals(id) &
                      r.revision.equals(draft.baseRevision) &
                      r.deletedAt.isNull(),
                ))
                .write(
                  NotesCompanion(
                    title: Value(draft.text.title),
                    body: Value(draft.text.body),
                    revision: Value(revision),
                    updatedAt: Value(now.millisecondsSinceEpoch),
                  ),
                );
        if (count != 1) throw const NoteException(NoteFailure.staleRevision);
      }
      await discardDraft(id, expectedDraftRevision);
      return NoteDocument(
        id: id,
        text: draft.text,
        revision: revision,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
      );
    });
  }

  @override
  Future<void> deleteNote(String id, int expectedRevision) async {
    _validate(id);
    final now = _clock().toUtc().millisecondsSinceEpoch;
    final count =
        await (_db.update(_db.notes)..where(
              (r) =>
                  r.id.equals(id) &
                  r.revision.equals(expectedRevision) &
                  r.deletedAt.isNull(),
            ))
            .write(
              NotesCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                revision: Value(expectedRevision + 1),
              ),
            );
    if (count != 1) throw const NoteException(NoteFailure.staleRevision);
  }

  @override
  Future<void> discardDraft(String id, int expectedDraftRevision) async {
    _validate(id);
    final count =
        await (_db.delete(_db.noteDrafts)..where(
              (r) =>
                  r.id.equals(id) &
                  r.draftRevision.equals(expectedDraftRevision),
            ))
            .go();
    if (count != 1) throw const NoteException(NoteFailure.draftChanged);
  }

  NoteDocument _note(Note r) => NoteDocument(
    id: r.id,
    text: PlainTextDocument(title: r.title, body: r.body),
    revision: r.revision,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
    deletedAt: r.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.deletedAt!, isUtc: true),
  );
  RecoveryDraft _draft(NoteDraft r) => RecoveryDraft(
    id: r.id,
    text: PlainTextDocument(title: r.title, body: r.body),
    baseRevision: r.baseRevision,
    draftRevision: r.draftRevision,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
  );
}
