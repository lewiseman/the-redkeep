import 'package:drift/drift.dart';

/// TMDB facts, cached on this device. Never synced: any device can fetch them
/// again. Doubles as the Discover deck's pool of candidates.
@DataClassName('WatchCatalogRow')
class WatchCatalog extends Table {
  TextColumn get mediaKey => text()();

  /// [CatalogTitle.toJson].
  TextColumn get data => text()();

  /// Fetched seasons of a show, `{"1": [episodes...]}`.
  TextColumn get seasons => text().withDefault(const Constant('{}'))();
  BoolColumn get detailed => boolean().withDefault(const Constant(false))();
  RealColumn get popularity => real().withDefault(const Constant(0))();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {mediaKey};
}

/// One synced document per title: status, rating, note, episodes and the
/// title's place in Discover. A small snapshot lets another device show it
/// before the catalog is fetched there.
@DataClassName('WatchTitleRow')
@TableIndex.sql(
  'CREATE INDEX watch_titles_order ON watch_titles (updated_at DESC, id DESC)',
)
class WatchTitles extends Table {
  TextColumn get id => text()();
  TextColumn get mediaKey => text().unique()();
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get status => text().nullable()();
  IntColumn get rating => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get swipe => text().nullable()();
  TextColumn get matchState => text().nullable()();
  IntColumn get matchedAt => integer().nullable()();
  IntColumn get expiresAt => integer().nullable()();
  IntColumn get nightAt => integer().nullable()();
  TextColumn get outcome => text().nullable()();
  IntColumn get checkedInAt => integer().nullable()();

  /// Watched episodes as a JSON array of `s1e4` codes.
  TextColumn get episodes => text().withDefault(const Constant('[]'))();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A list the reader named, synced as one document holding its title ids.
@DataClassName('WatchListRow')
class WatchLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// JSON array of title ids, newest first.
  TextColumn get items => text().withDefault(const Constant('[]'))();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The reader's Discover taste and dealbreakers: one synced row.
@DataClassName('WatchProfileRow')
class WatchProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get state => text().withDefault(const Constant('{}'))();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A conversation with a title: the latest few exchanges, on this device.
/// Never synced.
@DataClassName('WatchChatTurnRow')
class WatchChatTurns extends Table {
  TextColumn get id => text()();
  TextColumn get titleId => text()();
  IntColumn get at => integer()();
  BoolColumn get fromReader => boolean()();
  TextColumn get body => text()();

  @override
  Set<Column> get primaryKey => {id};
}
