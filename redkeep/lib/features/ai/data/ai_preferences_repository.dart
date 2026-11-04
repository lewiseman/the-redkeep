import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/ai_operation.dart';
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
    final overrides = jsonDecode(row.overrides) as Map;
    return AiPreferences(
      mode:
          AiMode.values.where((v) => v.name == row.mode).firstOrNull ??
          AiMode.auto,
      overrides: {
        for (final op in AiOperation.values)
          if (overrides[op.name] is String && overrides[op.name] != 'auto')
            op: AiMode.values.firstWhere(
              (m) => m.name == overrides[op.name],
              orElse: () => AiMode.auto,
            ),
      },
      dailyQuestions: row.dailyQuestions,
      paused: row.recallPaused,
      collections: {
        if (row.recallNotes) 'note',
        if (row.recallDiary) 'diary',
        if (row.recallFlow) 'thought',
      },
      voice: row.replyVoice == null
          ? null
          : Map<String, String>.from(jsonDecode(row.replyVoice!) as Map),
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

  Future<void> mode(AiMode value) =>
      _write(AiPreferencesTableCompanion(mode: Value(value.name)));
  Future<void> override(AiOperation op, AiMode value) async {
    final previous = await read();
    final values = {
      for (final e in previous.overrides.entries) e.key.name: e.value.name,
    };
    value == AiMode.auto
        ? values.remove(op.name)
        : values[op.name] = value.name;
    await _write(
      AiPreferencesTableCompanion(overrides: Value(jsonEncode(values))),
    );
  }

  Future<void> questions(bool value) => db.transaction(() async {
    await _write(AiPreferencesTableCompanion(dailyQuestions: Value(value)));
    if (!value) await db.delete(db.dailyQuestions).go();
  });
  Future<void> pause(bool value) =>
      _write(AiPreferencesTableCompanion(recallPaused: Value(value)));
  Future<void> voice(Map<String, String>? value) => _write(
    AiPreferencesTableCompanion(
      replyVoice: Value(value == null ? null : jsonEncode(value)),
    ),
  );
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
