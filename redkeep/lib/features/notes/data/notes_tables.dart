import 'package:drift/drift.dart';

class Notes extends Table {
  TextColumn get details => text().withDefault(const Constant('{}'))();
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class NoteTags extends Table {
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get tag => text().withLength(min: 1, max: 40)();
  @override
  Set<Column> get primaryKey => {noteId, tag};
}

class NoteMediaOps extends Table {
  TextColumn get path => text()();
  IntColumn get created => integer()();
  @override
  Set<Column> get primaryKey => {path};
}
