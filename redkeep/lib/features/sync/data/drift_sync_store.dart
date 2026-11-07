import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../core/storage/app_database.dart';
import 'drift_sync_collection.dart';
import '../../diary/domain/diary_period.dart';

class DriftSyncKeyValueStore implements SyncKeyValueStore {
  DriftSyncKeyValueStore(this.db);
  final AppDatabase db;
  @override
  Future<String?> read(String key) async => (await (db.select(
    db.syncValues,
  )..where((r) => r.key.equals(key))).getSingleOrNull())?.value;
  @override
  Future<void> write(String key, String value) async => db
      .into(db.syncValues)
      .insertOnConflictUpdate(
        SyncValuesCompanion.insert(key: key, value: value),
      );
  @override
  Future<void> remove(String key) async {
    await (db.delete(db.syncValues)..where((r) => r.key.equals(key))).go();
  }

  @override
  Future<List<String>> keys(String prefix) async =>
      (await db
              .customSelect(
                'SELECT key FROM sync_values WHERE substr(key, 1, ?) = ?',
                variables: [Variable(prefix.length), Variable(prefix)],
                readsFrom: {db.syncValues},
              )
              .get())
          .map((r) => r.read<String>('key'))
          .toList();
  @override
  Future<void> clear() async {
    await db.delete(db.syncValues).go();
  }
}

class DriftSyncStateStore extends SyncStateStore {
  DriftSyncStateStore(this.db, {required super.deviceId, super.now})
    : super(storage: DriftSyncKeyValueStore(db));
  final AppDatabase db;
  @override
  Future<List<PendingCreation>> get pendingCreations async {
    final operations = await db.select(db.syncOperations).get();
    final result = <PendingCreation>[];
    for (final op in operations) {
      final collection = DriftSyncCollection(db, op.type);
      final snapshot = await collection.read(op.documentId);
      if (snapshot == null || snapshot.payload['removed'] == true) continue;
      Map<String, dynamic> payload = snapshot.payload;
      if (op.type == 'diary') {
        final entries = (payload['entries'] as List)
            .cast<Map<String, dynamic>>();
        final items = entries.where(
          (e) => e['id'] == op.id && e['deleted_at'] == null,
        );
        if (items.isEmpty) continue;
        payload = {'id': op.documentId, 'schema': 3, 'entry': items.single};
      }
      result.add(
        PendingCreation(
          id: op.id,
          type: op.type,
          documentId: op.documentId,
          payload: payload,
        ),
      );
    }
    return result;
  }

  @override
  Future<void> acknowledgeCreation(PendingCreation value) async {
    await (db.delete(
      db.syncOperations,
    )..where((r) => r.type.equals(value.type) & r.id.equals(value.id))).go();
  }

  @override
  Future<void> setPrimary(PrimaryDevice value) async {
    await super.setPrimary(value);
    await storage.write('deviceId', deviceId);
  }
}

/// Called inside each local write transaction; cached UI role never grants writes.
Future<void> checkWritingAccess(
  AppDatabase db,
  int generation, {
  bool creating = false,
  String? diaryDate,
  DateTime? now,
}) async {
  if (db.writingBlocked || db.writingGeneration != generation) {
    throw StateError(
      'Account reset changed this writing session. Reopen the page.',
    );
  }
  final values = DriftSyncKeyValueStore(db);
  final role = await values.read('role');
  final device = await values.read('deviceId');
  if (role != null &&
      device != null &&
      (jsonDecode(role) as Map)['device_id'] != device) {
    final date = now ?? DateTime.now();
    if (!creating ||
        (diaryDate != null &&
            DiaryPeriod.tryParse(diaryDate)?.isCurrent(date) != true)) {
      throw StateError(
        'This device is add-only. Reclaim primary in Sync & devices to edit existing writing.',
      );
    }
  }
}
