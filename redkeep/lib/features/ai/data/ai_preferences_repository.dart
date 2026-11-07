import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/ai_preferences.dart';
import 'recall_schema.dart';

class AiPreferencesRepository {
  AiPreferencesRepository(this.db);
  final AppDatabase db;
  Stream<AiPreferences> watch() => (db.select(
    db.aiPreferencesTable,
  )..where((r) => r.id.equals(1))).watchSingleOrNull().map(decode);
  Future<AiPreferences> read() async => decode(
    await (db.select(
      db.aiPreferencesTable,
    )..where((r) => r.id.equals(1))).getSingleOrNull(),
  );
  static AiPreferences decode(AiPreferenceRow? row) {
    if (row == null) return const AiPreferences();
    return AiPreferences(
      paused: row.recallPaused,
      collections: {
        if (row.recallNotes) 'note',
        if (row.recallDiary) 'diary',
        if (row.recallFlow) 'thought',
      },
    );
  }

  Future<void> _write(AiPreferencesTableCompanion change) =>
      db.transaction(() async {
        await db
            .into(db.aiPreferencesTable)
            .insert(
              const AiPreferencesTableCompanion(id: Value(1)),
              mode: InsertMode.insertOrIgnore,
            );
        await (db.update(
          db.aiPreferencesTable,
        )..where((r) => r.id.equals(1))).write(change);
      });
  Future<bool> cleanupRequired() async =>
      (await (db.select(
            db.aiPreferencesTable,
          )..where((r) => r.id.equals(1))).getSingleOrNull())
          ?.recallCleanupRequired ??
      false;
  Future<void> cleanupComplete() => _write(
    const AiPreferencesTableCompanion(recallCleanupRequired: Value(false)),
  );

  Future<void> pause(bool value) =>
      _write(AiPreferencesTableCompanion(recallPaused: Value(value)));
  Future<void> collection(String kind, bool value) => db.transaction(() async {
    final column = switch (kind) {
      'note' => 'recall_notes',
      'diary' => 'recall_diary',
      'thought' => 'recall_flow',
      _ => throw ArgumentError.value(kind),
    };
    await _write(const AiPreferencesTableCompanion());
    await db.customUpdate(
      'UPDATE ai_preferences_table SET $column = ? WHERE id = 1',
      variables: [Variable<int>(value ? 1 : 0)],
      updates: {db.aiPreferencesTable},
    );
    if (value) {
      await seedRecallQueue(db, kind: kind);
    } else {
      await _write(
        const AiPreferencesTableCompanion(recallCleanupRequired: Value(true)),
      );
      await (db.delete(db.recallQueue)..where((r) => r.kind.equals(kind))).go();
    }
  });
}
