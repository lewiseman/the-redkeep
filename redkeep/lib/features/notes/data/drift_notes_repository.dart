import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/note_document.dart';
import '../domain/notes_repository.dart';
import '../domain/notes_query.dart';

class DriftNotesRepository implements NotesRepository {
  DriftNotesRepository(this._db, {required this._clock});
  final AppDatabase _db;
  final DateTime Function() _clock;

  void _validate(String id) {
    if (!isNoteId(id)) throw const NoteException(NoteFailure.unavailable);
  }

  @override
  Stream<List<NoteListing>> watchNotes({
    NotesQuery query = const NotesQuery(),
  }) {
    final conditions = <String>[
      query.trash ? 'deleted_at IS NOT NULL' : 'deleted_at IS NULL',
    ];
    final variables = <Variable>[];
    if (query.pinnedOnly) conditions.add('pinned = 1');
    if (query.tag != null) {
      conditions.add(
        'EXISTS (SELECT 1 FROM note_tags WHERE note_id = notes.id AND tag = ?)',
      );
      variables.add(Variable.withString(query.tag!));
    }
    for (final token
        in query.search
            .trim()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)) {
      conditions.add(
        '(instr(lower(title), lower(?)) > 0 OR instr(lower(body), lower(?)) > 0)',
      );
      variables.addAll([
        Variable.withString(token),
        Variable.withString(token),
      ]);
    }
    return _db
        .customSelect(
          'SELECT id, title, revision, updated_at, pinned FROM notes WHERE ${conditions.join(' AND ')} ORDER BY pinned DESC, updated_at DESC, id',
          variables: variables,
          readsFrom: {_db.notes, _db.noteTags},
        )
        .watch()
        .map((rows) => rows.map((r) => _listing(r, 'revision')).toList());
  }

  @override
  Stream<List<String>> watchTags({bool trash = false}) => _db
      .customSelect(
        'SELECT DISTINCT tag FROM note_tags JOIN notes ON notes.id = note_id WHERE ${trash ? 'deleted_at IS NOT NULL' : 'deleted_at IS NULL'} ORDER BY tag',
        readsFrom: {_db.notes, _db.noteTags},
      )
      .watch()
      .map((rows) => rows.map((r) => r.read<String>('tag')).toList());

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
    pinned: row.data['pinned'] == 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('updated_at'),
      isUtc: true,
    ),
  );

  @override
  Stream<OpenNote> watchDocument(String id) {
    _validate(id);
    // Observe tokens/metadata only: joining tags to document bodies would send
    // a copy of a large body per tag across the database isolate.
    return _db
        .customSelect(
          'SELECT (SELECT revision FROM notes WHERE id = ?) AS source_revision, '
          '(SELECT draft_revision FROM note_drafts WHERE id = ?) AS draft_revision, '
          '(SELECT group_concat(tag) FROM note_tags WHERE note_id = ?) AS tags',
          variables: [
            Variable.withString(id),
            Variable.withString(id),
            Variable.withString(id),
          ],
          readsFrom: {_db.notes, _db.noteDrafts, _db.noteTags},
        )
        .watch()
        .asyncMap((_) => openDocument(id));
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
      final tags =
          await (_db.select(_db.noteTags)
                ..where((r) => r.noteId.equals(id))
                ..orderBy([(r) => OrderingTerm.asc(r.tag)]))
              .get();
      return OpenNote(
        note: note == null
            ? null
            : _note(note, tags.map((t) => t.tag).toList()),
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
        pinned: old?.pinned ?? false,
        tags: old?.tags ?? const [],
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
  Future<void> organize(
    String id,
    int expectedRevision, {
    required bool pinned,
    required List<String> tags,
  }) async {
    _validate(id);
    final normalized =
        tags
            .map((t) => t.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (normalized.length > 24 ||
        normalized.any((t) => t.length > 40 || t.contains(','))) {
      throw const NoteException(NoteFailure.invalidTags);
    }
    await _db.transaction(() async {
      final count =
          await (_db.update(_db.notes)..where(
                (r) =>
                    r.id.equals(id) &
                    r.revision.equals(expectedRevision) &
                    r.deletedAt.isNull(),
              ))
              .write(
                NotesCompanion(
                  pinned: Value(pinned),
                  revision: Value(expectedRevision + 1),
                  updatedAt: Value(_clock().toUtc().millisecondsSinceEpoch),
                ),
              );
      if (count != 1) throw const NoteException(NoteFailure.staleRevision);
      await (_db.delete(_db.noteTags)..where((r) => r.noteId.equals(id))).go();
      for (final tag in normalized) {
        await _db
            .into(_db.noteTags)
            .insert(NoteTagsCompanion.insert(noteId: id, tag: tag));
      }
    });
  }

  @override
  Future<void> restoreNote(String id, int expectedRevision) async {
    _validate(id);
    final count =
        await (_db.update(_db.notes)..where(
              (r) =>
                  r.id.equals(id) &
                  r.revision.equals(expectedRevision) &
                  r.deletedAt.isNotNull(),
            ))
            .write(
              NotesCompanion(
                deletedAt: const Value(null),
                revision: Value(expectedRevision + 1),
                updatedAt: Value(_clock().toUtc().millisecondsSinceEpoch),
              ),
            );
    if (count != 1) throw const NoteException(NoteFailure.staleRevision);
  }

  @override
  Future<void> permanentlyDelete(
    String id,
    int expectedRevision, {
    required int? expectedDraftRevision,
  }) async {
    _validate(id);
    await _db.transaction(() async {
      final snapshot = await openDocument(id);
      if (snapshot.note?.deletedAt == null ||
          snapshot.note!.revision != expectedRevision) {
        throw const NoteException(NoteFailure.staleRevision);
      }
      if (snapshot.draft?.draftRevision != expectedDraftRevision) {
        throw const NoteException(NoteFailure.draftChanged);
      }
      if (expectedDraftRevision != null) {
        await discardDraft(id, expectedDraftRevision);
      }
      await (_db.delete(_db.noteTags)..where((r) => r.noteId.equals(id))).go();
      await (_db.delete(_db.notes)..where((r) => r.id.equals(id))).go();
    });
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

  NoteDocument _note(Note r, List<String> tags) => NoteDocument(
    id: r.id,
    text: PlainTextDocument(title: r.title, body: r.body),
    revision: r.revision,
    pinned: r.pinned,
    tags: List.unmodifiable(tags),
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
