import '../../sync/data/drift_sync_store.dart';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/thought.dart';
import '../domain/flow_repository.dart';

class DriftFlowRepository implements FlowRepository {
  DriftFlowRepository(this._db, {required this._clock})
    : _generation = _db.writingGeneration;
  final AppDatabase _db;
  final int _generation;
  final DateTime Function() _clock;

  void _validate(String id) {
    if (!isThoughtId(id)) throw const FlowException(FlowFailure.unavailable);
  }

  @override
  Stream<List<ThoughtListing>> watchThoughts() => _list(false);
  @override
  Stream<List<ThoughtListing>> watchDrafts() => _list(true);
  Stream<List<ThoughtListing>> _list(bool drafts) => _db
      .customSelect(
        drafts
            ? 'SELECT id, substr(body, 1, 160) AS preview, updated_at AS created_at FROM flow_drafts WHERE capture = 0 ORDER BY updated_at DESC, id DESC'
            : 'SELECT id, substr(body, 1, 160) AS preview, created_at FROM flow_thoughts WHERE deleted_at IS NULL ORDER BY created_at DESC, id DESC',
        readsFrom: {if (drafts) _db.flowDrafts else _db.flowThoughts},
      )
      .watch()
      .map(
        (rows) => rows
            .map(
              (r) => ThoughtListing(
                id: r.read<String>('id'),
                preview: r.read<String>('preview'),
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r.read<int>('created_at'),
                  isUtc: true,
                ),
              ),
            )
            .toList(),
      );

  @override
  Future<ThoughtDraft?> openCapture() async {
    final row = await (_db.select(
      _db.flowDrafts,
    )..where((r) => r.capture.equals(true))).getSingleOrNull();
    return row == null ? null : _draft(row);
  }

  @override
  Stream<OpenThought> watchDocument(String id) {
    _validate(id);
    // Observe tokens before loading one transactional document snapshot.
    return _db
        .customSelect(
          'SELECT (SELECT revision FROM flow_thoughts WHERE id = ?) AS source_revision, '
          '(SELECT draft_revision FROM flow_drafts WHERE id = ?) AS draft_revision',
          variables: [Variable.withString(id), Variable.withString(id)],
          readsFrom: {_db.flowThoughts, _db.flowDrafts},
        )
        .watch()
        .asyncMap((_) => openDocument(id));
  }

  @override
  Future<OpenThought> openDocument(String id) async {
    _validate(id);
    return _db.transaction(() async {
      final entry = await (_db.select(
        _db.flowThoughts,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      final draft = await (_db.select(
        _db.flowDrafts,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      return OpenThought(
        thought: entry == null ? null : _entry(entry),
        draft: draft == null ? null : _draft(draft),
      );
    });
  }

  @override
  Future<ThoughtDraft> putDraft({
    required String id,
    required String body,
    required bool capture,
    required int baseRevision,
    required int? expectedDraftRevision,
  }) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation, recoveryOnly: true);
      _validate(id);

      final old = await (_db.select(
        _db.flowDrafts,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (old?.draftRevision != expectedDraftRevision ||
          (old != null &&
              (old.baseRevision != baseRevision || old.capture != capture))) {
        throw const FlowException(FlowFailure.draftChanged);
      }
      final source = await openDocument(id);
      if (capture && (baseRevision != 0 || source.thought != null)) {
        throw const FlowException(FlowFailure.staleRevision);
      }
      final now = _clock().toUtc().millisecondsSinceEpoch;
      if (old != null) await discardDraft(id, old.draftRevision);
      final version = await _db
          .into(_db.flowDrafts)
          .insert(
            FlowDraftsCompanion.insert(
              id: id,
              body: body,
              capture: capture,
              baseRevision: baseRevision,
              updatedAt: now,
            ),
          );
      return ThoughtDraft(
        id: id,
        body: body,
        capture: capture,
        baseRevision: baseRevision,
        draftRevision: version,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      );
    });
  }

  @override
  Future<Thought> commitDraft(String id, int expectedDraftRevision) async {
    return _db.transaction(() async {
      await checkWritingAccess(
        _db,
        _generation,
        creating:
            (await (_db.select(
              _db.flowThoughts,
            )..where((r) => r.id.equals(id))).getSingleOrNull()) ==
            null,
      );
      _validate(id);

      final snapshot = await openDocument(id);
      final draft = snapshot.draft;
      if (draft == null || draft.draftRevision != expectedDraftRevision) {
        throw const FlowException(FlowFailure.draftChanged);
      }
      if (draft.body.trim().isEmpty) {
        throw const FlowException(FlowFailure.empty);
      }
      final old = snapshot.thought;
      if (old?.deletedAt != null ||
          (old?.revision ?? 0) != draft.baseRevision) {
        throw const FlowException(FlowFailure.staleRevision);
      }
      final now = _clock().toUtc();
      final revision = draft.baseRevision + 1;
      if (old == null) {
        await _db
            .into(_db.flowThoughts)
            .insert(
              FlowThoughtsCompanion.insert(
                id: id,
                body: draft.body,
                revision: revision,
                createdAt: now.millisecondsSinceEpoch,
                updatedAt: now.millisecondsSinceEpoch,
              ),
            );
      } else {
        final count =
            await (_db.update(_db.flowThoughts)..where(
                  (r) =>
                      r.id.equals(id) &
                      r.revision.equals(draft.baseRevision) &
                      r.deletedAt.isNull(),
                ))
                .write(
                  FlowThoughtsCompanion(
                    body: Value(draft.body),
                    revision: Value(revision),
                    updatedAt: Value(now.millisecondsSinceEpoch),
                  ),
                );
        if (count != 1) throw const FlowException(FlowFailure.staleRevision);
      }
      await discardDraft(id, expectedDraftRevision);
      return Thought(
        id: id,
        body: draft.body,
        revision: revision,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
      );
    });
  }

  @override
  Future<void> deleteThought(String id, int expectedRevision) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      _validate(id);
      final now = _clock().toUtc().millisecondsSinceEpoch;
      final count =
          await (_db.update(_db.flowThoughts)..where(
                (r) =>
                    r.id.equals(id) &
                    r.revision.equals(expectedRevision) &
                    r.deletedAt.isNull(),
              ))
              .write(
                FlowThoughtsCompanion(
                  deletedAt: Value(now),
                  body: const Value(''),
                  updatedAt: Value(now),
                  revision: Value(expectedRevision + 1),
                ),
              );
      if (count != 1) throw const FlowException(FlowFailure.staleRevision);
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
          await (_db.delete(_db.flowDrafts)..where(
                (r) =>
                    r.id.equals(id) &
                    r.draftRevision.equals(expectedDraftRevision),
              ))
              .go();
      if (count != 1) throw const FlowException(FlowFailure.draftChanged);
    });
  }

  Thought _entry(ThoughtRow r) => Thought(
    id: r.id,
    body: r.body,
    revision: r.revision,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
    deletedAt: r.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.deletedAt!, isUtc: true),
  );
  ThoughtDraft _draft(ThoughtDraftRow r) => ThoughtDraft(
    id: r.id,
    body: r.body,
    capture: r.capture,
    baseRevision: r.baseRevision,
    draftRevision: r.draftRevision,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
  );
}
