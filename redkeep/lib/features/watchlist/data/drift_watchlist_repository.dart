import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../../sync/data/drift_sync_store.dart';
import '../domain/catalog_title.dart';
import '../domain/watch_title.dart';
import '../domain/watchlist_repository.dart';
import 'watchlist_sync.dart' show watchProfileId;

class DriftWatchlistRepository implements WatchlistRepository {
  DriftWatchlistRepository(
    this._db, {
    required this._clock,
    required this._newId,
  }) : _generation = _db.writingGeneration;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final String Function() _newId;
  final int _generation;

  int get _now => _clock().toUtc().millisecondsSinceEpoch;

  @override
  Stream<List<WatchTitle>> watchTitles() =>
      (_db.select(_db.watchTitles)
            ..where((r) => r.deletedAt.isNull())
            ..orderBy([
              (r) => OrderingTerm.desc(r.updatedAt),
              (r) => OrderingTerm.desc(r.id),
            ]))
          .watch()
          .map((rows) => rows.map(watchTitleFromRow).toList());

  @override
  Stream<WatchTitle?> watchTitle(String id) =>
      (_db.select(
        _db.watchTitles,
      )..where((r) => r.id.equals(id))).watchSingleOrNull().map(
        (row) => row == null || row.deletedAt != null
            ? null
            : watchTitleFromRow(row),
      );

  @override
  Future<List<WatchTitle>> titles() async =>
      (await (_db.select(_db.watchTitles)
                ..where((r) => r.deletedAt.isNull())
                ..orderBy([
                  (r) => OrderingTerm.desc(r.updatedAt),
                  (r) => OrderingTerm.desc(r.id),
                ]))
              .get())
          .map(watchTitleFromRow)
          .toList();

  @override
  Future<WatchTitle?> title(String id) async {
    final row = await _row(id);
    return row == null || row.deletedAt != null ? null : watchTitleFromRow(row);
  }

  @override
  Stream<List<WatchList>> watchLists() =>
      (_db.select(_db.watchLists)
            ..where((r) => r.deletedAt.isNull())
            ..orderBy([
              (r) => OrderingTerm.asc(r.createdAt),
              (r) => OrderingTerm.asc(r.id),
            ]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                WatchList(
                  id: r.id,
                  name: r.name,
                  items: _ids(r.items),
                  createdAt: _time(r.createdAt)!,
                ),
            ],
          );

  @override
  Future<WatchTitle> edit(
    CatalogTitle title,
    WatchTitleChange change,
  ) => _db.transaction(() async {
    final id = title.key.id;
    final row = await _row(id);
    await checkWritingAccess(_db, _generation, creating: row == null);
    final now = _now;
    final snapshot = WatchTitlesCompanion(
      title: Value(title.title),
      posterPath: Value(title.posterPath ?? row?.posterPath),
      year: Value(title.year ?? row?.year),
      updatedAt: Value(now),
    );
    if (row == null) {
      await _db
          .into(_db.watchTitles)
          .insert(
            WatchTitlesCompanion.insert(
              id: id,
              mediaKey: title.key.value,
              title: title.title,
              posterPath: Value(title.posterPath),
              year: Value(title.year),
              revision: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else if (row.deletedAt != null) {
      await _clear(id, row.revision + 1, now, deletedAt: null);
    }
    final current = await _row(id);
    final changes = change(watchTitleFromRow(current!));
    await (_db.update(_db.watchTitles)..where((r) => r.id.equals(id))).write(
      _merge(snapshot, changes).copyWith(revision: Value(current.revision + 1)),
    );
    return watchTitleFromRow((await _row(id))!);
  });

  /// Fields set on [changes] win over the title snapshot.
  WatchTitlesCompanion _merge(
    WatchTitlesCompanion snapshot,
    WatchTitlesCompanion changes,
  ) => WatchTitlesCompanion(
    title: snapshot.title,
    posterPath: snapshot.posterPath,
    year: snapshot.year,
    updatedAt: snapshot.updatedAt,
    status: changes.status,
    rating: changes.rating,
    note: changes.note,
    swipe: changes.swipe,
    matchState: changes.matchState,
    matchedAt: changes.matchedAt,
    expiresAt: changes.expiresAt,
    nightAt: changes.nightAt,
    outcome: changes.outcome,
    checkedInAt: changes.checkedInAt,
    episodes: changes.episodes,
  );

  @override
  Future<WatchTitle> setStatus(CatalogTitle title, WatchStatus? status) =>
      edit(title, (_) => WatchTitlesCompanion(status: Value(status?.name)));

  @override
  Future<WatchTitle> setRating(CatalogTitle title, int? rating) {
    if (rating != null && (rating < 1 || rating > 10)) {
      throw ArgumentError.value(rating, 'rating');
    }
    return edit(title, (_) => WatchTitlesCompanion(rating: Value(rating)));
  }

  @override
  Future<WatchTitle> setNote(CatalogTitle title, String note) => edit(
    title,
    (_) => WatchTitlesCompanion(
      note: Value(note.length > 4000 ? note.substring(0, 4000) : note),
    ),
  );

  @override
  Future<WatchTitle> setEpisodes(
    CatalogTitle title, {
    Set<String> watched = const {},
    Set<String> unwatched = const {},
  }) {
    for (final code in [...watched, ...unwatched]) {
      if (!episodeCodePattern.hasMatch(code)) {
        throw ArgumentError.value(code, 'episode');
      }
    }
    return edit(title, (current) {
      final episodes = {...?current?.episodes, ...watched}
        ..removeAll(unwatched);
      final sorted = episodes.toList()..sort(compareEpisodeCodes);
      // Ticking an episode means the show is under way.
      final starting =
          watched.isNotEmpty &&
          (current?.status == null || current?.status == WatchStatus.planned);
      return WatchTitlesCompanion(
        episodes: Value(jsonEncode(sorted)),
        status: starting
            ? Value(WatchStatus.watching.name)
            : const Value.absent(),
      );
    });
  }

  @override
  Future<void> removeTitle(String id) => _db.transaction(() async {
    await checkWritingAccess(_db, _generation);
    final row = await _row(id);
    if (row == null || row.deletedAt != null) return;
    final now = _now;
    await _clear(id, row.revision + 1, now, deletedAt: now);
    for (final list in await (_db.select(
      _db.watchLists,
    )..where((r) => r.deletedAt.isNull())).get()) {
      final items = _ids(list.items);
      if (items.remove(id)) await _writeItems(list, items, now);
    }
    await (_db.delete(
      _db.watchChatTurns,
    )..where((r) => r.titleId.equals(id))).go();
  });

  Future<void> _clear(
    String id,
    int revision,
    int now, {
    required int? deletedAt,
  }) => (_db.update(_db.watchTitles)..where((r) => r.id.equals(id))).write(
    WatchTitlesCompanion(
      status: const Value(null),
      rating: const Value(null),
      note: const Value(''),
      swipe: const Value(null),
      matchState: const Value(null),
      matchedAt: const Value(null),
      expiresAt: const Value(null),
      nightAt: const Value(null),
      outcome: const Value(null),
      checkedInAt: const Value(null),
      episodes: const Value('[]'),
      revision: Value(revision),
      updatedAt: Value(now),
      deletedAt: Value(deletedAt),
    ),
  );

  @override
  Future<String> createList(String name, {CatalogTitle? first}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const WatchlistException(WatchlistFailure.emptyName);
    }
    final id = _newId();
    await _db.transaction(() async {
      await checkWritingAccess(_db, _generation, creating: true);
      final now = _now;
      await _db
          .into(_db.watchLists)
          .insert(
            WatchListsCompanion.insert(
              id: id,
              name: _limit(trimmed),
              items: Value(first == null ? '[]' : jsonEncode([first.key.id])),
              revision: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (first != null) await edit(first, (_) => const WatchTitlesCompanion());
    });
    return id;
  }

  @override
  Future<void> renameList(String id, String name) => _db.transaction(() async {
    await checkWritingAccess(_db, _generation);
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const WatchlistException(WatchlistFailure.emptyName);
    }
    final list = await _list(id);
    await (_db.update(_db.watchLists)..where((r) => r.id.equals(id))).write(
      WatchListsCompanion(
        name: Value(_limit(trimmed)),
        revision: Value(list.revision + 1),
        updatedAt: Value(_now),
      ),
    );
  });

  @override
  Future<void> deleteList(String id) => _db.transaction(() async {
    await checkWritingAccess(_db, _generation);
    final list = await _list(id);
    final now = _now;
    await (_db.update(_db.watchLists)..where((r) => r.id.equals(id))).write(
      WatchListsCompanion(
        items: const Value('[]'),
        revision: Value(list.revision + 1),
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  });

  @override
  Future<void> setInList(String listId, CatalogTitle title, bool member) =>
      _db.transaction(() async {
        await checkWritingAccess(_db, _generation);
        final list = await _list(listId);
        final items = _ids(list.items);
        final id = title.key.id;
        if (items.contains(id) == member) return;
        if (member) {
          items.insert(0, id);
          await edit(title, (_) => const WatchTitlesCompanion());
        } else {
          items.remove(id);
        }
        await _writeItems(list, items, _now);
      });

  Future<void> _writeItems(WatchListRow list, List<String> items, int now) =>
      (_db.update(_db.watchLists)..where((r) => r.id.equals(list.id))).write(
        WatchListsCompanion(
          items: Value(jsonEncode(items)),
          revision: Value(list.revision + 1),
          updatedAt: Value(now),
        ),
      );

  Future<WatchListRow> _list(String id) async {
    final list = await (_db.select(
      _db.watchLists,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (list == null || list.deletedAt != null) {
      throw const WatchlistException(WatchlistFailure.unavailable);
    }
    return list;
  }

  Future<WatchTitleRow?> _row(String id) => (_db.select(
    _db.watchTitles,
  )..where((r) => r.id.equals(id))).getSingleOrNull();

  @override
  Stream<Map<String, dynamic>?> watchProfile() =>
      (_db.select(
        _db.watchProfiles,
      )..where((r) => r.id.equals(watchProfileId))).watchSingleOrNull().map(
        (row) =>
            row == null ? null : jsonDecode(row.state) as Map<String, dynamic>,
      );

  @override
  Future<Map<String, dynamic>?> readProfile() async {
    final row = await (_db.select(
      _db.watchProfiles,
    )..where((r) => r.id.equals(watchProfileId))).getSingleOrNull();
    return row == null ? null : jsonDecode(row.state) as Map<String, dynamic>;
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> state) =>
      _db.transaction(() async {
        final row = await (_db.select(
          _db.watchProfiles,
        )..where((r) => r.id.equals(watchProfileId))).getSingleOrNull();
        await checkWritingAccess(_db, _generation, creating: row == null);
        final now = _now;
        final encoded = jsonEncode(state);
        if (row == null) {
          await _db
              .into(_db.watchProfiles)
              .insert(
                WatchProfilesCompanion.insert(
                  id: watchProfileId,
                  state: Value(encoded),
                  revision: 1,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        } else if (row.state != encoded) {
          await (_db.update(
            _db.watchProfiles,
          )..where((r) => r.id.equals(watchProfileId))).write(
            WatchProfilesCompanion(
              state: Value(encoded),
              revision: Value(row.revision + 1),
              updatedAt: Value(now),
            ),
          );
        }
      });

  @override
  Future<List<CatalogTitle>> catalog() async => [
    for (final row in await (_db.select(
      _db.watchCatalog,
    )..orderBy([(r) => OrderingTerm.desc(r.popularity)])).get())
      ?CatalogTitle.fromJson(jsonDecode(row.data) as Map<String, dynamic>),
  ];

  @override
  Future<int> catalogSize() async {
    final count = _db.watchCatalog.mediaKey.count();
    return (await (_db.selectOnly(
          _db.watchCatalog,
        )..addColumns([count])).getSingle()).read(count) ??
        0;
  }

  @override
  Future<CatalogTitle?> cachedTitle(WatchKey key) async {
    final row = await _catalogRow(key);
    if (row == null) return null;
    return CatalogTitle.fromJson(jsonDecode(row.data) as Map<String, dynamic>);
  }

  @override
  Future<DateTime?> cachedAt(WatchKey key) async =>
      _time((await _catalogRow(key))?.fetchedAt);

  Future<WatchCatalogRow?> _catalogRow(WatchKey key) => (_db.select(
    _db.watchCatalog,
  )..where((r) => r.mediaKey.equals(key.value))).getSingleOrNull();

  /// Details replace anything; a summary never replaces details.
  @override
  Future<void> cacheTitles(Iterable<CatalogTitle> titles) =>
      _db.transaction(() async {
        final now = _now;
        for (final title in titles) {
          final old = await _catalogRow(title.key);
          if (old != null && old.detailed && !title.detailed) continue;
          await _db
              .into(_db.watchCatalog)
              .insertOnConflictUpdate(
                WatchCatalogCompanion.insert(
                  mediaKey: title.key.value,
                  data: jsonEncode(title.toJson()),
                  seasons: Value(old?.seasons ?? '{}'),
                  detailed: Value(title.detailed),
                  popularity: Value(title.popularity),
                  fetchedAt: now,
                ),
              );
        }
      });

  @override
  Future<List<EpisodeSummary>?> cachedSeason(WatchKey key, int season) async {
    final row = await _catalogRow(key);
    final seasons = jsonDecode(row?.seasons ?? '{}') as Map<String, dynamic>;
    final episodes = seasons['$season'];
    if (episodes is! List) return null;
    return [
      for (final e in episodes)
        EpisodeSummary.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<void> cacheSeason(
    WatchKey key,
    int season,
    List<EpisodeSummary> episodes,
  ) => _db.transaction(() async {
    final row = await _catalogRow(key);
    if (row == null) return;
    final seasons = jsonDecode(row.seasons) as Map<String, dynamic>;
    seasons['$season'] = [for (final e in episodes) e.toJson()];
    await (_db.update(_db.watchCatalog)
          ..where((r) => r.mediaKey.equals(key.value)))
        .write(WatchCatalogCompanion(seasons: Value(jsonEncode(seasons))));
  });
}

WatchTitle watchTitleFromRow(WatchTitleRow r) => WatchTitle(
  id: r.id,
  key: WatchKey.tryParse(r.mediaKey)!,
  title: r.title,
  posterPath: r.posterPath,
  year: r.year,
  status: WatchStatus.tryParse(r.status),
  rating: r.rating,
  note: r.note,
  swipe: SwipeChoice.tryParse(r.swipe),
  matchState: MatchState.tryParse(r.matchState),
  matchedAt: _time(r.matchedAt),
  expiresAt: _time(r.expiresAt),
  nightAt: _time(r.nightAt),
  outcome: NightOutcome.tryParse(r.outcome),
  checkedInAt: _time(r.checkedInAt),
  episodes: _ids(r.episodes).toSet(),
  revision: r.revision,
  createdAt: _time(r.createdAt)!,
  updatedAt: _time(r.updatedAt)!,
  deletedAt: _time(r.deletedAt),
);

DateTime? _time(int? ms) =>
    ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

List<String> _ids(String json) =>
    (jsonDecode(json) as List).whereType<String>().toList();

String _limit(String name) => name.length > 80 ? name.substring(0, 80) : name;

/// Season, then episode, numerically.
int compareEpisodeCodes(String a, String b) {
  final x = episodeCodePattern.firstMatch(a)!;
  final y = episodeCodePattern.firstMatch(b)!;
  final season = int.parse(x[1]!).compareTo(int.parse(y[1]!));
  return season != 0 ? season : int.parse(x[2]!).compareTo(int.parse(y[2]!));
}
