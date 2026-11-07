import 'package:drift/drift.dart';

@DataClassName('AiPreferenceRow')
class AiPreferencesTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  BoolColumn get recallNotes => boolean().withDefault(const Constant(true))();
  BoolColumn get recallDiary => boolean().withDefault(const Constant(true))();
  BoolColumn get recallFlow => boolean().withDefault(const Constant(true))();
  BoolColumn get recallPaused => boolean().withDefault(const Constant(false))();
  BoolColumn get recallCleanupRequired =>
      boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

@DataClassName('RecallQueueRow')
class RecallQueue extends Table {
  TextColumn get kind => text()();
  TextColumn get sourceId => text()();
  IntColumn get generation => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {kind, sourceId};
}

@DataClassName('RecallManifestRow')
class RecallManifests extends Table {
  TextColumn get profile => text()();
  TextColumn get kind => text()();
  TextColumn get sourceId => text()();
  TextColumn get hash => text()();
  IntColumn get revision => integer()();
  TextColumn get chunks => text()();
  BoolColumn get complete => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {profile, kind, sourceId};
}

/// Estimated cloud AI spending per calendar month (`YYYY-MM`).
@DataClassName('AiUsageMonthRow')
class AiUsageMonths extends Table {
  TextColumn get month => text()();
  IntColumn get costMicros => integer().withDefault(const Constant(0))();
  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {month};
}
