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

/// A note's generated website, kept beside the note and never in its text or
/// synced details. Local to this device.
@DataClassName('NoteWebsiteRow')
class NoteWebsites extends Table {
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get html => text()();

  /// SHA-256 of the note body the website was made from.
  TextColumn get sourceHash => text()();

  /// The person's description of the website; may be empty.
  TextColumn get brief => text().withDefault(const Constant(''))();
  TextColumn get model => text().withDefault(const Constant(''))();
  IntColumn get madeAt => integer()();

  /// What the page saved for itself (ticks, scores, progress), as JSON.
  TextColumn get state => text().withDefault(const Constant(''))();

  /// The page before the last remix or rebuild, so it can be undone.
  TextColumn get previousHtml => text().withDefault(const Constant(''))();
  TextColumn get previousSourceHash => text().withDefault(const Constant(''))();

  /// Ticks on the page update the note's checklist without asking.
  BoolColumn get syncChecks => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {noteId};
}

/// A note's conversation with the Maester: one row per exchange, only the
/// latest few, on this device. Never synced.
@DataClassName('NoteChatTurnRow')
class NoteChatTurns extends Table {
  TextColumn get id => text()();

  /// Not a reference: a new note can talk before it is first saved.
  TextColumn get noteId => text()();
  IntColumn get at => integer()();
  TextColumn get ask => text()();
  TextColumn get reply => text().withDefault(const Constant(''))();

  /// The Maester's tool calls and what came of them, as JSON.
  TextColumn get actions => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}
