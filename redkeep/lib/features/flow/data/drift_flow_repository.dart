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
  Stream<List<ThoughtListing>> watchThoughts() => _db
      .customSelect(
        'SELECT id, substr(body, 1, 160) AS preview, created_at FROM flow_thoughts WHERE deleted_at IS NULL ORDER BY created_at DESC, id DESC',
        readsFrom: {_db.flowThoughts},
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
  Stream<OpenThought> watchDocument(String id) {
    _validate(id);
    // Observe tokens before loading one transactional document snapshot.
    return _db
        .customSelect(
          'SELECT (SELECT revision FROM flow_thoughts WHERE id = ?) AS source_revision',
          variables: [Variable.withString(id)],
          readsFrom: {_db.flowThoughts},
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
      return OpenThought(thought: entry == null ? null : _entry(entry));
    });
  }

  @override
  Future<Thought> save({
    required String id,
    required String body,
    required int expectedRevision,
  }) async {
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
      if (body.trim().isEmpty) throw const FlowException(FlowFailure.empty);
      final old = snapshot.thought;
      if (old?.deletedAt != null || (old?.revision ?? 0) != expectedRevision) {
        throw const FlowException(FlowFailure.staleRevision);
      }
      final now = _clock().toUtc();
      final revision = expectedRevision + 1;
      if (old == null) {
        await _db
            .into(_db.flowThoughts)
            .insert(
              FlowThoughtsCompanion.insert(
                id: id,
                body: body,
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
                      r.revision.equals(expectedRevision) &
                      r.deletedAt.isNull(),
                ))
                .write(
                  FlowThoughtsCompanion(
                    body: Value(body),
                    revision: Value(revision),
                    updatedAt: Value(now.millisecondsSinceEpoch),
                  ),
                );
        if (count != 1) throw const FlowException(FlowFailure.staleRevision);
      }
      return Thought(
        id: id,
        body: body,
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
}
