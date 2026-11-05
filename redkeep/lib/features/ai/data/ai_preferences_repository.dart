import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/ai_operation.dart';
import '../domain/ai_preferences.dart';
import '../domain/ai_route.dart';
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
    final routes = _routes(row.routes);
    final tasks = routes['tasks'];
    return AiPreferences(
      defaultRoute:
          AiRoute.tryParse(routes['default']) ?? const AiRoute.companion(),
      overrides: {
        if (tasks is Map)
          for (final op in AiOperation.values)
            if (op.supportsProvider && AiRoute.tryParse(tasks[op.name]) != null)
              op: AiRoute.tryParse(tasks[op.name])!,
      },
      dailyQuestionOptIn: routes['dailyOptIn'] is String
          ? routes['dailyOptIn'] as String
          : null,
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

  static Map<dynamic, dynamic> _routes(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map ? value : const {};
    } on FormatException {
      return const {};
    }
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

  Future<void> _writeRoutes(AiPreferences value) {
    // Opt-in names one provider, so any other routing silently revokes it.
    final route = value.routeFor(AiOperation.dailyQuestion);
    final optIn = route.providerId == value.dailyQuestionOptIn
        ? value.dailyQuestionOptIn
        : null;
    return _write(
      AiPreferencesTableCompanion(
        routes: Value(
          jsonEncode({
            'default': value.defaultRoute.toJson(),
            'tasks': {
              for (final entry in value.overrides.entries)
                entry.key.name: entry.value.toJson(),
            },
            'dailyOptIn': ?optIn,
          }),
        ),
      ),
    );
  }

  Future<void> setDefaultRoute(AiRoute route) async {
    final previous = await read();
    await _writeRoutes(
      AiPreferences(
        defaultRoute: route,
        overrides: previous.overrides,
        dailyQuestionOptIn: previous.dailyQuestionOptIn,
      ),
    );
  }

  /// A null [route] makes the task follow the default again.
  Future<void> setTaskRoute(AiOperation op, AiRoute? route) async {
    final previous = await read();
    await _writeRoutes(
      AiPreferences(
        defaultRoute: previous.defaultRoute,
        overrides: {...previous.overrides, op: ?route}
          ..removeWhere((key, _) => key == op && route == null),
        dailyQuestionOptIn: previous.dailyQuestionOptIn,
      ),
    );
  }

  /// Passing the provider ID allows automatic daily questions; null revokes.
  Future<void> setDailyQuestionOptIn(String? providerId) async {
    final previous = await read();
    await _writeRoutes(
      AiPreferences(
        defaultRoute: previous.defaultRoute,
        overrides: previous.overrides,
        dailyQuestionOptIn: providerId,
      ),
    );
  }

  /// Tasks using a removed provider return to the default, which itself
  /// returns to the computer if it used that provider.
  Future<void> removeProvider(String id) async {
    final previous = await read();
    await _writeRoutes(
      AiPreferences(
        defaultRoute: previous.defaultRoute.providerId == id
            ? const AiRoute.companion()
            : previous.defaultRoute,
        overrides: {...previous.overrides}
          ..removeWhere((_, route) => route.providerId == id),
        dailyQuestionOptIn: previous.dailyQuestionOptIn,
      ),
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
