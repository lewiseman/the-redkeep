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
  }) {
    final conditions = <String>[
      query.trash ? 'deleted_at IS NOT NULL' : 'deleted_at IS NULL',
      if (query.pinnedOnly) 'pinned = 1',
    ];
    final variables = <Variable>[];
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
    // Only the bounded excerpt crosses the database boundary, even for very
    // large documents.
    return _db
        .customSelect(
          '''SELECT id, title, substr(body, 1, ${NoteCollectionEntry.excerptCharacters}) AS excerpt,
           updated_at, pinned, details AS card_details,
           EXISTS (SELECT 1 FROM note_websites WHERE note_id = notes.id) AS has_website
         FROM notes WHERE ${conditions.join(' AND ')}
         ORDER BY pinned DESC, updated_at DESC, id''',
          variables: variables,
          readsFrom: {_db.notes, _db.noteTags, _db.noteWebsites},
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
                details: NoteDetails.decode(row.read<String>('card_details')),
                hasWebsite: row.read<int>('has_website') == 1,
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
          '(SELECT group_concat(tag) FROM note_tags WHERE note_id = ?) AS tags',
          variables: [Variable.withString(id), Variable.withString(id)],
          readsFrom: {_db.notes, _db.noteTags},
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
      final tags =
          await (_db.select(_db.noteTags)
                ..where((r) => r.noteId.equals(id))
                ..orderBy([(r) => OrderingTerm.asc(r.tag)]))
              .get();
      return OpenNote(
        note: note == null
            ? null
            : _note(note, tags.map((t) => t.tag).toList()),
      );
    });
  }

  @override
  Future<NoteDocument> saveNote({
    required String id,
    required int expectedRevision,
    required PlainTextDocument text,
    required NoteDetails details,
  }) async {
    return _db.transaction(() async {
      _validate(id);
      await checkWritingAccess(
        _db,
        _generation,
        creating: expectedRevision == 0,
      );
      NoteDetails.decode(details.encode());
      if (text.isEmpty && !details.hasWriting) {
        throw const NoteException(NoteFailure.empty);
      }
      final old = (await openDocument(id)).note;
      if (expectedRevision == 0
          ? old != null
          : old == null ||
                old.deletedAt != null ||
                old.revision != expectedRevision) {
        throw const NoteException(NoteFailure.staleRevision);
      }
      final now = _clock().toUtc();
      final revision = expectedRevision + 1;
      if (old == null) {
        await _db
            .into(_db.notes)
            .insert(
              NotesCompanion.insert(
                id: id,
                title: text.title,
                body: text.body,
                details: Value(details.encode()),
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
                      r.revision.equals(expectedRevision) &
                      r.deletedAt.isNull(),
                ))
                .write(
                  NotesCompanion(
                    title: Value(text.title),
                    body: Value(text.body),
                    details: Value(details.encode()),
                    revision: Value(revision),
                    updatedAt: Value(now.millisecondsSinceEpoch),
                  ),
                );
        if (count != 1) throw const NoteException(NoteFailure.staleRevision);
      }
      await _putTags(id, details.tags);
      return NoteDocument(
        id: id,
        text: text,
        revision: revision,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
        pinned: old?.pinned ?? false,
        tags: details.tags,
        details: details,
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
  Future<void> permanentlyDelete(String id, int expectedRevision) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      _validate(id);

      final snapshot = await openDocument(id);
      if (snapshot.note?.deletedAt == null ||
          snapshot.note!.revision != expectedRevision) {
        throw const NoteException(NoteFailure.staleRevision);
      }
      await (_db.delete(_db.noteTags)..where((r) => r.noteId.equals(id))).go();
      await (_db.delete(
        _db.noteWebsites,
      )..where((r) => r.noteId.equals(id))).go();
      await (_db.delete(_db.notes)..where((r) => r.id.equals(id))).go();
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
  }) => _db.transaction(() async {
    await checkWritingAccess(_db, _generation);
    _validate(id);
    NoteDetails.decode(details.encode());
    final opened = await openDocument(id);
    if (!opened.available || opened.note!.revision != expectedRevision) {
      throw const NoteException(NoteFailure.staleRevision);
    }
    if (text.isEmpty && !details.hasWriting) {
      throw const NoteException(NoteFailure.empty);
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
    return (await openDocument(id)).note!;
  });

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
}
