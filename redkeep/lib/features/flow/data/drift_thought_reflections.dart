import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/thought.dart';
import '../domain/thought_reflection.dart';
import '../domain/thought_reflection_contract.dart';

/// Local derived results. All mutations recheck the account generation and source
/// inside the same transaction; secondary devices can use them without sync edits.
class DriftThoughtReflections {
  DriftThoughtReflections(this.db, {required this.clock})
    : generation = db.writingGeneration;
  final AppDatabase db;
  final DateTime Function() clock;
  final int generation;

  void _check() {
    if (db.writingBlocked || db.writingGeneration != generation) {
      throw StateError('This reflection session has ended.');
    }
  }

  Future<Thought?> _thought(String id) async {
    final row = await (db.select(
      db.flowThoughts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : Thought(
            id: row.id,
            body: row.body,
            revision: row.revision,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row.createdAt,
              isUtc: true,
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              row.updatedAt,
              isUtc: true,
            ),
            deletedAt: row.deletedAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    row.deletedAt!,
                    isUtc: true,
                  ),
          );
  }

  int get _cutoff =>
      clock().subtract(const Duration(days: 7)).millisecondsSinceEpoch;

  Stream<ThoughtReflections> watch(Thought thought) =>
      (db.select(
        db.flowReflections,
      )..where((r) => r.thoughtId.equals(thought.id))).watch().map((rows) {
        if (db.writingBlocked ||
            db.writingGeneration != generation ||
            thought.deletedAt != null) {
          return const ThoughtReflections();
        }
        ThoughtReflection? proposal, kept;
        for (final row in rows) {
          if (row.sourceVersion != thoughtRevision(thought) ||
              row.status == 'proposed' && row.created < _cutoff) {
            continue;
          }
          final value = ThoughtReflection(
            taskId: row.taskId,
            thoughtId: row.thoughtId,
            version: row.sourceVersion,
            text: row.body,
            kept: row.status == 'kept',
          );
          if (value.kept) {
            kept = value;
          } else {
            proposal = value;
          }
        }
        return ThoughtReflections(proposal: proposal, kept: kept);
      });

  Future<void> propose(
    String taskId,
    ThoughtReflectionSource source,
    String text,
  ) => db.transaction(() async {
    _check();
    if (!source.matches(await _thought(source.id))) {
      throw const ThoughtReflectionRejected(
        'This thought changed. The reflection was not saved.',
      );
    }
    final parsed = parseThoughtReflection(text, source.body);
    if (await (db.select(
          db.flowReflections,
        )..where((r) => r.taskId.equals(taskId))).getSingleOrNull() !=
        null) {
      return;
    }
    await (db.delete(db.flowReflections)..where(
          (r) =>
              r.status.equals('proposed') &
              (r.thoughtId.equals(source.id) |
                  r.created.isSmallerThanValue(_cutoff)),
        ))
        .go();
    _check();
    await db
        .into(db.flowReflections)
        .insert(
          FlowReflectionsCompanion.insert(
            taskId: taskId,
            thoughtId: source.id,
            sourceVersion: source.version,
            body: parsed,
            status: 'proposed',
            created: clock().millisecondsSinceEpoch,
          ),
        );
  });

  Future<void> keep(ThoughtReflection reflection) => db.transaction(() async {
    _check();
    final thought = await _thought(reflection.thoughtId);
    if (thought == null ||
        thought.deletedAt != null ||
        thoughtRevision(thought) != reflection.version) {
      throw const ThoughtReflectionRejected(
        'This thought changed. Ask for a new reflection.',
      );
    }
    final row = await (db.select(
      db.flowReflections,
    )..where((r) => r.taskId.equals(reflection.taskId))).getSingleOrNull();
    if (row == null ||
        row.status != 'proposed' ||
        row.created < _cutoff ||
        row.sourceVersion != reflection.version) {
      throw const ThoughtReflectionRejected(
        'This proposal is no longer available.',
      );
    }
    await (db.delete(db.flowReflections)..where(
          (r) => r.thoughtId.equals(thought.id) & r.status.equals('kept'),
        ))
        .go();
    _check();
    await (db.update(db.flowReflections)
          ..where((r) => r.taskId.equals(row.taskId)))
        .write(const FlowReflectionsCompanion(status: Value('kept')));
  });

  Future<void> remove(String taskId) => db.transaction(() async {
    _check();
    await (db.delete(
      db.flowReflections,
    )..where((r) => r.taskId.equals(taskId))).go();
  });

  Future<void> prune() => db.transaction(() async {
    _check();
    await (db.delete(db.flowReflections)..where(
          (r) =>
              r.status.equals('proposed') &
              r.created.isSmallerThanValue(_cutoff),
        ))
        .go();
  });
}
