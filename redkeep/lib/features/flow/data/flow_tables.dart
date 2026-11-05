import 'package:drift/drift.dart';

@DataClassName('ThoughtRow')
@TableIndex.sql(
  'CREATE INDEX flow_thoughts_order ON flow_thoughts (created_at DESC, id DESC)',
)
class FlowThoughts extends Table {
  TextColumn get id => text()();
  TextColumn get body => text()();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Derived local data: never registered for writing sync or semantic indexing.
@DataClassName('FlowReflectionRow')
class FlowReflections extends Table {
  TextColumn get taskId => text()();
  TextColumn get thoughtId => text()();
  TextColumn get sourceVersion => text()();
  TextColumn get body => text()();
  TextColumn get status => text().customConstraint(
    "NOT NULL CHECK (status IN ('proposed', 'kept'))",
  )();
  IntColumn get created => integer()();
  @override
  Set<Column> get primaryKey => {taskId};
  @override
  List<Set<Column>> get uniqueKeys => [
    {thoughtId, status},
  ];
}

Future<void> installFlowReflectionCleanup(GeneratedDatabase db) async {
  await db.customStatement(
    '''CREATE TRIGGER IF NOT EXISTS flow_reflections_deleted
    AFTER UPDATE OF deleted_at ON flow_thoughts WHEN NEW.deleted_at IS NOT NULL
    BEGIN DELETE FROM flow_reflections WHERE thought_id = NEW.id; END''',
  );
  await db.customStatement(
    '''CREATE TRIGGER IF NOT EXISTS flow_reflections_removed
    AFTER DELETE ON flow_thoughts
    BEGIN DELETE FROM flow_reflections WHERE thought_id = OLD.id; END''',
  );
}
