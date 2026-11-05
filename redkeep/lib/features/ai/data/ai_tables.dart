import 'package:drift/drift.dart';

@DataClassName('AiPreferenceRow')
class AiPreferencesTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Default and per-task routes. Holds provider IDs and model names, no tokens.
  TextColumn get routes => text().withDefault(const Constant('{}'))();
  BoolColumn get dailyQuestions =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get recallNotes => boolean().withDefault(const Constant(true))();
  BoolColumn get recallDiary => boolean().withDefault(const Constant(true))();
  BoolColumn get recallFlow => boolean().withDefault(const Constant(true))();
  BoolColumn get recallPaused => boolean().withDefault(const Constant(false))();
  BoolColumn get recallCleanupRequired =>
      boolean().withDefault(const Constant(false))();
  TextColumn get replyVoice => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

@DataClassName('AiJobReceiptRow')
class AiJobReceipts extends Table {
  TextColumn get id => text()();
  TextColumn get metadata => text()();
  BoolColumn get active => boolean().withDefault(const Constant(false))();
  // Durable deduplication after a derived reflection is dismissed or replaced.
  BoolColumn get resultConsumed =>
      boolean().withDefault(const Constant(false))();
  IntColumn get created => integer()();
  @override
  Set<Column> get primaryKey => {id};
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

@DataClassName('DailyQuestionRow')
class DailyQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get day => text()();
  TextColumn get question => text()();
  TextColumn get sourceDate => text().withDefault(const Constant(''))();
  TextColumn get sourceId => text().withDefault(const Constant(''))();
  TextColumn get sourceHash => text().withDefault(const Constant(''))();
  TextColumn get evidence => text().withDefault(const Constant(''))();
  IntColumn get ago => integer().withDefault(const Constant(0))();
  TextColumn get basis => text()();
  TextColumn get sources => text().withDefault(const Constant('[]'))();
  BoolColumn get shown => boolean().withDefault(const Constant(true))();
  IntColumn get created => integer()();
  @override
  Set<Column> get primaryKey => {id};
}
