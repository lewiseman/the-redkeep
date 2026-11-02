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

@DataClassName('ThoughtDraftRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX flow_single_capture ON flow_drafts (capture) WHERE capture = 1',
)
class FlowDrafts extends Table {
  TextColumn get id => text().unique()();
  TextColumn get body => text()();
  IntColumn get baseRevision =>
      integer().customConstraint('NOT NULL CHECK (base_revision >= 0)')();
  IntColumn get draftRevision => integer().autoIncrement()();
  BoolColumn get capture => boolean()();
  IntColumn get updatedAt => integer()();
}
