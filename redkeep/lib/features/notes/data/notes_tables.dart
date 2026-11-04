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

/// No foreign key: new writing is recoverable before a note exists, and a
/// deleted source's unsaved writing remains available for recovery as a copy.
class NoteDrafts extends Table {
  TextColumn get details => text().withDefault(const Constant('{}'))();
  TextColumn get id => text().unique()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  IntColumn get baseRevision =>
      integer().customConstraint('NOT NULL CHECK (base_revision >= 0)')();
  // Never reuse a token after discard/commit, even when the same note is edited
  // again. This also prevents an older editor from clearing a replacement draft.
  IntColumn get draftRevision => integer().autoIncrement()();
  IntColumn get updatedAt => integer()();
}

class NoteTags extends Table {
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get tag => text().withLength(min: 1, max: 40)();
  @override
  Set<Column> get primaryKey => {noteId, tag};
}

class NoteAiRecoveries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get noteId => text()();
  TextColumn get taskId => text().unique()();
  TextColumn get operation => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get details => text()();
  IntColumn get appliedRevision => integer()();
  IntColumn get created => integer()();
}

class NoteMediaOps extends Table {
  TextColumn get path => text()();
  IntColumn get created => integer()();
  @override
  Set<Column> get primaryKey => {path};
}
