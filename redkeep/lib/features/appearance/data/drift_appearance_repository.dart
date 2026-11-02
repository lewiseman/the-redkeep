import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/appearance_preferences.dart';
import '../domain/appearance_repository.dart';

class DriftAppearanceRepository implements AppearanceRepository {
  DriftAppearanceRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<AppearancePreferences> watch() =>
      (_database.select(
        _database.appearanceSettings,
      )..where((row) => row.id.equals(1))).watchSingleOrNull().map(
        (row) => row == null
            ? const AppearancePreferences()
            : AppearancePreferences(
                theme: AppTheme.values.byName(row.theme),
                reduceMotion: row.reduceMotion,
                simplerEffects: row.simplerEffects,
              ),
      );

  @override
  Future<void> save(AppearancePreferences preferences) async {
    await _database
        .into(_database.appearanceSettings)
        .insertOnConflictUpdate(
          AppearanceSettingsCompanion.insert(
            id: const Value(1),
            theme: Value(preferences.theme.name),
            reduceMotion: Value(preferences.reduceMotion),
            simplerEffects: Value(preferences.simplerEffects),
          ),
        );
  }
}
