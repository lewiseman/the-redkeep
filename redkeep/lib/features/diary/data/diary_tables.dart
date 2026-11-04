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
  TextColumn get photos => text().withDefault(const Constant('[]'))();
  TextColumn get conversation => text().nullable()();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DiaryDayRow')
class DiaryDays extends Table {
  TextColumn get dateKey => text().withLength(min: 10, max: 10)();
  TextColumn get heading => text().withLength(max: 160)();
  TextColumn get mood => text().nullable()();
  TextColumn get themes => text().withDefault(const Constant('[]'))();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  @override
  Set<Column> get primaryKey => {dateKey};
}

@DataClassName('DiaryMediaOpRow')
class DiaryMediaOps extends Table {
  TextColumn get path => text()();
  TextColumn get action => text()();
  TextColumn get owner => text()();
  IntColumn get created => integer()();
  @override
  Set<Column> get primaryKey => {path};
}

@DataClassName('PhotoQuestionCacheRow')
class PhotoQuestionCache extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get created => integer()();
  @override
  Set<Column> get primaryKey => {key};
}
