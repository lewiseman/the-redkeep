import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/app_database.dart';
import '../domain/ai_job.dart';

abstract interface class ProtectedAiTasks {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecureAiTasks implements ProtectedAiTasks {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'redkeep_companion',
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accountName: 'redkeep.companion',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );
  @override
  Future<String?> read() => storage.read(key: 'redkeep.ai.task.v1');
  @override
  Future<void> write(String? value) => value == null
      ? storage.delete(key: 'redkeep.ai.task.v1')
      : storage.write(key: 'redkeep.ai.task.v1', value: value);
}

/// Protected content precedes receipt commits. An interrupted receipt commit is
/// repaired from the protected handle on restore. Receipts never contain text.
class AiJobStore {
  AiJobStore(this.db, this.protected, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  final AppDatabase db;
  final ProtectedAiTasks protected;
  Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<AiJob?> load() => _serial(() async {
    final raw = await protected.read();
    return raw == null
        ? null
        : AiJob.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  });
  Future<void> save(AiJob job, int generation) => _serial(() async {
    void check() {
      if (db.writingBlocked || db.writingGeneration != generation) {
        throw StateError('AI session expired');
      }
    }

    check();
    await protected.write(jsonEncode(job.json()));
    check();
    await db.transaction(() async {
      await db
          .update(db.aiJobReceipts)
          .write(const AiJobReceiptsCompanion(active: Value(false)));
      await db
          .into(db.aiJobReceipts)
          .insertOnConflictUpdate(
            AiJobReceiptsCompanion.insert(
              id: job.id,
              metadata: jsonEncode(job.json(sensitive: false)),
              created: job.created,
              active: const Value(true),
            ),
          );
      await (db.delete(db.aiJobReceipts)..where(
            (r) => r.created.isSmallerThanValue(
              clock().subtract(const Duration(days: 7)).millisecondsSinceEpoch,
            ),
          ))
          .go();
    });
  });
  Future<void> release(AiJob job, int generation) => _serial(() async {
    void check() {
      if (db.writingBlocked || db.writingGeneration != generation) {
        throw StateError('AI session expired');
      }
    }

    check();
    final raw = await protected.read();
    check();
    if (raw != null &&
        AiJob.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map)).id !=
            job.id) {
      return;
    }
    await (db.update(
      db.aiJobReceipts,
    )..where((r) => r.id.equals(job.id))).write(
      AiJobReceiptsCompanion(
        active: const Value(false),
        metadata: Value(jsonEncode(job.json(sensitive: false))),
      ),
    );
    check();
    await protected.write(null);
  });

  /// Read-only typed metadata, with explicit ordering and no protected content.
  Stream<List<AiJob>> watchHistory() =>
      (db.select(db.aiJobReceipts)..orderBy([
            (r) => OrderingTerm.desc(r.created),
            (r) => OrderingTerm.desc(r.id),
          ]))
          .watch()
          .map((rows) {
            final cutoff = clock()
                .subtract(const Duration(days: 7))
                .millisecondsSinceEpoch;
            return [
              for (final row in rows)
                if (row.created >= cutoff)
                  ?_receipt(row.metadata),
            ];
          });

  AiJob? _receipt(String raw) {
    try {
      final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      // Never expose sensitive content, even from malformed historical metadata.
      value.remove('prompt');
      value.remove('source');
      value.remove('text');
      return AiJob.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  Future<List<AiJob>> pendingAcknowledgements() async => [
    for (final row in await db.select(db.aiJobReceipts).get())
      if (_receipt(row.metadata) case final job?)
        if (job.ackPending && !row.active) job,
  ];
  Future<void> acknowledge(AiJob job) async {
    await (db.update(
      db.aiJobReceipts,
    )..where((r) => r.id.equals(job.id))).write(
      AiJobReceiptsCompanion(
        metadata: Value(
          jsonEncode(job.copy(ackPending: false).json(sensitive: false)),
        ),
      ),
    );
  }

  Future<void> clear() => _serial(() async {
    await protected.write(null);
    await db.delete(db.aiJobReceipts).go();
  });
}
