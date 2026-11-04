import '../../sync/data/drift_sync_store.dart';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/note_document.dart';
import '../domain/note_collection_entry.dart';
import '../domain/notes_repository.dart';
import '../domain/notes_query.dart';

class DriftNotesRepository implements NotesRepository {
  DriftNotesRepository(this._db, {required this._clock})
    : _generation = _db.writingGeneration;
  final AppDatabase _db;
  final int _generation;
  final DateTime Function() _clock;

  void _validate(String id) {
    if (!isNoteId(id)) throw const NoteException(NoteFailure.unavailable);
  }

  @override
  Stream<List<NoteCollectionEntry>> watchCollection({
    NotesQuery query = const NotesQuery(),
    bool draftsOnly = false,
  }) {
    final conditions = <String>[
      if (query.trash)
        'deleted_at IS NOT NULL'
      else
        '(deleted_at IS NULL OR is_draft = 1)',
      if (draftsOnly) query.trash ? '0' : 'is_draft = 1',
      if (query.pinnedOnly) 'pinned = 1',
    ];
    final variables = <Variable>[];
    if (query.tag != null) {
      conditions.add(
        'EXISTS (SELECT 1 FROM note_tags WHERE note_id = effective.id AND tag = ?)',
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
    // The CTE keeps filtering and overlaying in SQLite. Only the final bounded
    // excerpt crosses the database boundary, even for very large documents.
    final source = query.trash
        ? '''SELECT id, title, body, updated_at, pinned, deleted_at,
             details, 0 AS is_draft, 0 AS source_unavailable FROM notes'''
        : '''SELECT ids.id,
             CASE WHEN d.id IS NOT NULL THEN d.title ELSE n.title END AS title,
             CASE WHEN d.id IS NOT NULL THEN d.body ELSE n.body END AS body,
             CASE WHEN d.id IS NOT NULL THEN d.updated_at ELSE n.updated_at END AS updated_at,
             coalesce(n.pinned, 0) AS pinned, n.deleted_at,
             CASE WHEN d.id IS NOT NULL THEN d.details ELSE n.details END AS details,
             (d.id IS NOT NULL) AS is_draft,
             (d.id IS NOT NULL AND d.base_revision > 0 AND
               (n.id IS NULL OR n.deleted_at IS NOT NULL)) AS source_unavailable
           FROM (SELECT id FROM notes UNION SELECT id FROM note_drafts) ids
           LEFT JOIN notes n ON n.id = ids.id
           LEFT JOIN note_drafts d ON d.id = ids.id''';
    return _db
        .customSelect(
          '''WITH effective AS ($source)
         SELECT id, title, substr(body, 1, ${NoteCollectionEntry.excerptCharacters}) AS excerpt,
           updated_at, pinned, is_draft, source_unavailable,
           json_remove(details, '\$.website', '\$.websiteSourceHash') AS card_details
         FROM effective WHERE ${conditions.join(' AND ')}
         ORDER BY pinned DESC, updated_at DESC, id''',
          variables: variables,
          readsFrom: {_db.notes, _db.noteDrafts, _db.noteTags},
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              NoteCollectionEntry(
                id: row.read<String>('id'),
                title: row.read<String>('title'),
                excerpt: row.read<String>('excerpt'),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  row.read<int>('updated_at'),
                  isUtc: true,
                ),
                pinned: row.read<int>('pinned') == 1,
                isDraft: row.read<int>('is_draft') == 1,
                sourceUnavailable: row.read<int>('source_unavailable') == 1,
                details: NoteDetails.decode(row.read<String>('card_details')),
              ),
          ],
        );
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
        draft: draft == null
            ? null
            : _draft(
                draft,
                legacyDetails: note == null
                    ? null
                    : NoteDetails.decode(note.details)
                          .copy(tags: tags.map((t) => t.tag).toList()),
              ),
      );
    });
  }

  @override
  Future<RecoveryDraft> putDraft({
    required String id,
    required PlainTextDocument text,
    required int baseRevision,
    required int? expectedDraftRevision,
    NoteDetails? details,
  }) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation, recoveryOnly: true);
      _validate(id);

      final old = await (_db.select(
        _db.noteDrafts,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (old?.draftRevision != expectedDraftRevision ||
          (old != null && old.baseRevision != baseRevision)) {
        throw const NoteException(NoteFailure.draftChanged);
      }
      final source = await openDocument(id);
      final effectiveDetails =
          details ??
          source.draft?.details ??
          source.note?.details.copy(tags: source.note!.tags) ??
          const NoteDetails();
      NoteDetails.decode(effectiveDetails.encode());
      if (text.isEmpty && !effectiveDetails.hasWriting) {
        throw const NoteException(NoteFailure.empty);
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
              details: Value(effectiveDetails.encode()),
              baseRevision: baseRevision,
              updatedAt: now,
            ),
          );
      return RecoveryDraft(
        id: id,
        text: text,
        details: effectiveDetails,
        baseRevision: baseRevision,
        draftRevision: version,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      );
    });
  }

  @override
  Future<NoteDocument> commitDraft(String id, int expectedDraftRevision) async {
    return _db.transaction(() async {
      await checkWritingAccess(
        _db,
        _generation,
        creating:
            (await (_db.select(
              _db.notes,
            )..where((r) => r.id.equals(id))).getSingleOrNull()) ==
            null,
      );
      _validate(id);

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
                details: Value(draft.details.encode()),
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
                    details: Value(draft.details.encode()),
                    revision: Value(revision),
                    updatedAt: Value(now.millisecondsSinceEpoch),
                  ),
                );
        if (count != 1) throw const NoteException(NoteFailure.staleRevision);
      }
      await _putTags(id, draft.details.tags);
      await discardDraft(id, expectedDraftRevision);
      return NoteDocument(
        id: id,
        text: draft.text,
        revision: revision,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
        pinned: old?.pinned ?? false,
        tags: draft.details.tags,
        details: draft.details,
      );
    });
  }

  @override
  Future<void> deleteNote(String id, int expectedRevision) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
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
    });
  }

  @override
  Future<void> organize(
    String id,
    int expectedRevision, {
    required bool pinned,
    required List<String> tags,
  }) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      _validate(id);
      final normalized =
          tags
              .map(
                (t) => t.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase(),
              )
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (normalized.length > 24 ||
          normalized.any((t) => t.length > 40 || t.contains(','))) {
        throw const NoteException(NoteFailure.invalidTags);
      }

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
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
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
    });
  }

  @override
  Future<void> permanentlyDelete(
    String id,
    int expectedRevision, {
    required int? expectedDraftRevision,
  }) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      _validate(id);

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
    return _db.transaction(() async {
      if (_db.writingBlocked || _db.writingGeneration != _generation) {
        throw StateError('Account reset changed this writing session.');
      }
      _validate(id);
      final count =
          await (_db.delete(_db.noteDrafts)..where(
                (r) =>
                    r.id.equals(id) &
                    r.draftRevision.equals(expectedDraftRevision),
              ))
              .go();
      if (count != 1) throw const NoteException(NoteFailure.draftChanged);
    });
  }

  Future<void> _putTags(String id, List<String> tags) async {
    NoteDetails.decode(NoteDetails(tags: tags).encode());
    await (_db.delete(_db.noteTags)..where((r) => r.noteId.equals(id))).go();
    for (final tag in tags.toSet()) {
      await _db
          .into(_db.noteTags)
          .insert(NoteTagsCompanion.insert(noteId: id, tag: tag));
    }
  }

  @override
  Future<NoteDocument> applyProposal(
    String id,
    int expectedRevision, {
    required PlainTextDocument text,
    required NoteDetails details,
    required String taskId,
    required String operation,
    bool retainPrior = true,
  }) => _db.transaction(() async {
    await checkWritingAccess(_db, _generation);
    _validate(id);
    NoteDetails.decode(details.encode());
    final opened = await openDocument(id);
    if (!opened.available ||
        opened.note!.revision != expectedRevision ||
        opened.draft != null) {
      throw const NoteException(NoteFailure.staleRevision);
    }
    final old = opened.note!;
    if (text.isEmpty && !details.hasWriting) {
      throw const NoteException(NoteFailure.empty);
    }
    if (await (_db.select(
          _db.noteAiRecoveries,
        )..where((r) => r.taskId.equals(taskId))).getSingleOrNull() !=
        null) {
      throw const NoteException(NoteFailure.staleRevision);
    }
    final now = _clock().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.notes)..where((r) => r.id.equals(id))).write(
      NotesCompanion(
        title: Value(text.title),
        body: Value(text.body),
        details: Value(details.encode()),
        revision: Value(expectedRevision + 1),
        updatedAt: Value(now),
      ),
    );
    await _putTags(id, details.tags);
    if (retainPrior) {
      await _db
          .into(_db.noteAiRecoveries)
          .insert(
            NoteAiRecoveriesCompanion.insert(
              noteId: id,
              taskId: taskId,
              operation: operation,
              title: old.text.title,
              body: old.text.body,
              details: old.details.copy(tags: old.tags).encode(),
              appliedRevision: expectedRevision + 1,
              created: now,
            ),
          );
      await _db.customStatement(
        'DELETE FROM note_ai_recoveries WHERE id NOT IN (SELECT id FROM note_ai_recoveries ORDER BY id DESC LIMIT 10)',
      );
    }
    return (await openDocument(id)).note!;
  });

  @override
  Future<List<NotePriorContent>> priorContent(String id) async => [
    for (final r
        in await (_db.select(_db.noteAiRecoveries)
              ..where((r) => r.noteId.equals(id))
              ..orderBy([(r) => OrderingTerm.desc(r.id)]))
            .get())
      NotePriorContent(
        id: r.id,
        noteId: r.noteId,
        operation: r.operation,
        title: r.title,
        body: r.body,
        details: NoteDetails.decode(r.details),
        appliedRevision: r.appliedRevision,
        created: DateTime.fromMillisecondsSinceEpoch(r.created, isUtc: true),
      ),
  ];

  @override
  Future<void> restorePriorContent(
    String id,
    int recoveryId,
    int expectedRevision,
  ) => _db.transaction(() async {
    final prior = (await priorContent(id))
        .where((r) => r.id == recoveryId)
        .firstOrNull;
    if (prior == null || prior.appliedRevision != expectedRevision) {
      throw const NoteException(NoteFailure.staleRevision);
    }
    await applyProposal(
      id,
      expectedRevision,
      text: PlainTextDocument(title: prior.title, body: prior.body),
      details: prior.details,
      taskId: 'restore-$recoveryId-$expectedRevision',
      operation: 'restore',
      retainPrior: false,
    );
  });

  @override
  Future<void> clearPriorContent(String id) async {
    await checkWritingAccess(_db, _generation, recoveryOnly: true);
    await (_db.delete(
      _db.noteAiRecoveries,
    )..where((r) => r.noteId.equals(id))).go();
  }

  NoteDocument _note(Note r, List<String> tags) => NoteDocument(
    id: r.id,
    text: PlainTextDocument(title: r.title, body: r.body),
    revision: r.revision,
    pinned: r.pinned,
    tags: List.unmodifiable(tags),
    details: NoteDetails.decode(r.details).copy(tags: tags),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
    deletedAt: r.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.deletedAt!, isUtc: true),
  );
  RecoveryDraft _draft(NoteDraft r, {NoteDetails? legacyDetails}) =>
      RecoveryDraft(
        id: r.id,
        text: PlainTextDocument(title: r.title, body: r.body),
        details: r.details == '{}'
            ? legacyDetails ?? const NoteDetails()
            : NoteDetails.decode(r.details),
        baseRevision: r.baseRevision,
        draftRevision: r.draftRevision,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          r.updatedAt,
          isUtc: true,
        ),
      );
}
