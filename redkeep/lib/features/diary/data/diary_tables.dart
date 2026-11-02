import 'package:drift/drift.dart';

@DataClassName('DiaryEntryRow')
@TableIndex.sql(
  'CREATE INDEX diary_entries_day_order ON diary_entries (date_key, created_at, id)',
)
class DiaryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get dateKey => text().withLength(min: 10, max: 10)();
  TextColumn get title => text()();
  TextColumn get body => text()();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DiaryDraftRow')
class DiaryDrafts extends Table {
  TextColumn get id => text().unique()();
  TextColumn get dateKey => text().withLength(min: 10, max: 10)();
  TextColumn get title => text()();
  TextColumn get body => text()();
  IntColumn get baseRevision =>
      integer().customConstraint('NOT NULL CHECK (base_revision >= 0)')();
  IntColumn get draftRevision => integer().autoIncrement()();
  IntColumn get updatedAt => integer()();
}

@DataClassName('DiaryDayRow')
class DiaryDays extends Table {
  TextColumn get dateKey => text().withLength(min: 10, max: 10)();
  TextColumn get heading => text().withLength(max: 160)();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  @override
  Set<Column> get primaryKey => {dateKey};
}
