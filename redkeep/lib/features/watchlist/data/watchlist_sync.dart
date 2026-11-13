import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/watch_title.dart';

/// Sync type to table. Each row is one whole document; its payload is the row
/// without `revision`, which stays private to this device.
const watchlistTables = {
  'watch': 'watch_titles',
  'watchlist': 'watch_lists',
  'watchtaste': 'watch_profiles',
};

/// The single taste document's id.
final watchProfileId = watchTitleId('profile');

void validateWatchlistPayload(String type, Map<String, dynamic> p) {
  Never invalid() => throw FormatException('Invalid $type payload.');
  bool optionalInt(Object? v) => v == null || v is int;
  bool optionalText(Object? v, int max) =>
      v == null || (v is String && v.length <= max);
  bool optionalName<T extends Enum>(Object? v, List<T> values) =>
      v == null || values.any((e) => e.name == v);
  if (p['created_at'] is! int ||
      p['updated_at'] is! int ||
      !optionalInt(p['deleted_at'])) {
    invalid();
  }
  switch (type) {
    case 'watch':
      final key = WatchKey.tryParse(p['media_key'] as String?);
      if (key == null || key.id != p['id']) invalid();
      final rating = p['rating'];
      if (p['title'] is! String ||
          (p['title'] as String).length > 300 ||
          !optionalText(p['poster_path'], 200) ||
          !optionalInt(p['year']) ||
          !optionalName(p['status'], WatchStatus.values) ||
          (rating != null && (rating is! int || rating < 1 || rating > 10)) ||
          p['note'] is! String ||
          (p['note'] as String).length > 4000 ||
          !optionalName(p['swipe'], SwipeChoice.values) ||
          !optionalName(p['match_state'], MatchState.values) ||
          !optionalName(p['outcome'], NightOutcome.values) ||
          !optionalInt(p['matched_at']) ||
          !optionalInt(p['expires_at']) ||
          !optionalInt(p['night_at']) ||
          !optionalInt(p['checked_in_at'])) {
        invalid();
      }
      final episodes = _jsonList(p['episodes']);
      if (episodes == null ||
          episodes.length > 20000 ||
          episodes.any(
            (e) => e is! String || !episodeCodePattern.hasMatch(e),
          )) {
        invalid();
      }
    case 'watchlist':
      final name = p['name'];
      final items = _jsonList(p['items']);
      if (name is! String ||
          name.length > 80 ||
          items == null ||
          items.length > 5000 ||
          items.any((i) => i is! String || !isWatchId(i))) {
        invalid();
      }
    case 'watchtaste':
      if (p['id'] != watchProfileId ||
          p['state'] is! String ||
          (p['state'] as String).length > 400000 ||
          jsonDecode(p['state'] as String) is! Map) {
        invalid();
      }
    default:
      invalid();
  }
}

List<Object?>? _jsonList(Object? value) {
  if (value is! String) return null;
  try {
    final decoded = jsonDecode(value);
    return decoded is List ? decoded : null;
  } on FormatException {
    return null;
  }
}

Future<int> _revision(AppDatabase db, String table, String id) async {
  final row = await db
      .customSelect(
        'SELECT revision FROM $table WHERE id = ?',
        variables: [Variable(id)],
      )
      .getSingleOrNull();
  return (row?.read<int>('revision') ?? 0) + 1;
}

Future<void> putWatchlistDocument(
  AppDatabase db,
  String type,
  Map<String, dynamic> p,
) async {
  final id = p['id'] as String;
  final revision = await _revision(db, watchlistTables[type]!, id);
  switch (type) {
    case 'watch':
      await db
          .into(db.watchTitles)
          .insertOnConflictUpdate(
            WatchTitlesCompanion.insert(
              id: id,
              mediaKey: p['media_key'] as String,
              title: p['title'] as String,
              posterPath: Value(p['poster_path'] as String?),
              year: Value(p['year'] as int?),
              status: Value(p['status'] as String?),
              rating: Value(p['rating'] as int?),
              note: Value(p['note'] as String),
              swipe: Value(p['swipe'] as String?),
              matchState: Value(p['match_state'] as String?),
              matchedAt: Value(p['matched_at'] as int?),
              expiresAt: Value(p['expires_at'] as int?),
              nightAt: Value(p['night_at'] as int?),
              outcome: Value(p['outcome'] as String?),
              checkedInAt: Value(p['checked_in_at'] as int?),
              episodes: Value(p['episodes'] as String),
              revision: revision,
              createdAt: p['created_at'] as int,
              updatedAt: p['updated_at'] as int,
              deletedAt: Value(p['deleted_at'] as int?),
            ),
          );
    case 'watchlist':
      await db
          .into(db.watchLists)
          .insertOnConflictUpdate(
            WatchListsCompanion.insert(
              id: id,
              name: p['name'] as String,
              items: Value(p['items'] as String),
              revision: revision,
              createdAt: p['created_at'] as int,
              updatedAt: p['updated_at'] as int,
              deletedAt: Value(p['deleted_at'] as int?),
            ),
          );
    case 'watchtaste':
      await db
          .into(db.watchProfiles)
          .insertOnConflictUpdate(
            WatchProfilesCompanion.insert(
              id: id,
              state: Value(p['state'] as String),
              revision: revision,
              createdAt: p['created_at'] as int,
              updatedAt: p['updated_at'] as int,
              deletedAt: Value(p['deleted_at'] as int?),
            ),
          );
  }
}

Future<void> removeWatchlistDocument(
  AppDatabase db,
  String type,
  String id,
) async {
  await db.customStatement(
    'DELETE FROM ${watchlistTables[type]} WHERE id = ?',
    [id],
  );
  if (type == 'watch') {
    await (db.delete(
      db.watchChatTurns,
    )..where((r) => r.titleId.equals(id))).go();
  }
}
