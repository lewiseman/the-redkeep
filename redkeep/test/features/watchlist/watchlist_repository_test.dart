import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/watchlist/data/drift_watchlist_repository.dart';
import 'package:redkeep/features/watchlist/domain/catalog_title.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';

const matrix = CatalogTitle(
  key: WatchKey(WatchMedia.movie, 603),
  title: 'The Matrix',
  year: 1999,
  posterPath: '/m.jpg',
);
const thrones = CatalogTitle(
  key: WatchKey(WatchMedia.tv, 1399),
  title: 'Game of Thrones',
  year: 2011,
);

void main() {
  late AppDatabase db;
  late DriftWatchlistRepository repository;
  var clock = DateTime.utc(2026, 11, 13, 20);
  var ids = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 11, 13, 20);
    ids = 0;
    repository = DriftWatchlistRepository(
      db,
      clock: () => clock,
      newId: () => (++ids).toRadixString(16).padLeft(32, '0'),
    );
  });
  tearDown(() => db.close());

  test('ids are deterministic per title, and films and shows never collide', () {
    expect(const WatchKey(WatchMedia.movie, 1).id, isNot(const WatchKey(WatchMedia.tv, 1).id));
    expect(matrix.key.id, WatchKey.tryParse('movie:603')!.id);
    expect(isWatchId(matrix.key.id), isTrue);
    expect(WatchKey.tryParse('movie:0'), isNull);
    expect(WatchKey.tryParse('person:5'), isNull);
    expect(WatchKey.fromRoute('tv', '1399'), thrones.key);
  });

  test('status, rating and note live on one row with a snapshot of the title', () async {
    await repository.setStatus(matrix, WatchStatus.planned);
    clock = clock.add(const Duration(minutes: 1));
    await repository.setRating(matrix, 9);
    final saved = await repository.setNote(matrix, 'Rewatch with Sam');

    expect(saved.id, matrix.key.id);
    expect(saved.status, WatchStatus.planned);
    expect(saved.rating, 9);
    expect(saved.note, 'Rewatch with Sam');
    expect(saved.posterPath, '/m.jpg');
    expect(saved.revision, 4);
    expect(saved.updatedAt, clock);
    expect(() => repository.setRating(matrix, 11), throwsArgumentError);

    final cleared = await repository.setStatus(matrix, null);
    expect(cleared.status, isNull);
    expect(cleared.rating, 9, reason: 'clearing status keeps everything else');
  });

  test('episodes are stored sorted and toggled without duplicates', () async {
    await repository.setEpisodes(thrones, watched: {'s2e1', 's1e10', 's1e2'});
    final saved = await repository.setEpisodes(
      thrones,
      watched: {'s1e2'},
      unwatched: {'s2e1'},
    );
    expect(saved.episodes, {'s1e2', 's1e10'});
    final row = await (db.select(db.watchTitles)).getSingle();
    expect(row.episodes, '["s1e2","s1e10"]');
    expect(() => repository.setEpisodes(thrones, watched: {'e1'}), throwsArgumentError);
  });

  test('ticking an episode starts a planned show, but never reopens a finished one', () async {
    await repository.setStatus(thrones, WatchStatus.planned);
    var saved = await repository.setEpisodes(thrones, watched: {'s1e1'});
    expect(saved.status, WatchStatus.watching);
    await repository.setStatus(thrones, WatchStatus.completed);
    saved = await repository.setEpisodes(thrones, watched: {'s1e2'});
    expect(saved.status, WatchStatus.completed);
    saved = await repository.setEpisodes(matrix, unwatched: {'s1e1'});
    expect(saved.status, isNull, reason: 'unticking starts nothing');
  });

  test('lists hold titles newest first; deleting a list keeps its titles', () async {
    final id = await repository.createList(' Date night ', first: matrix);
    await repository.setInList(id, thrones, true);
    await repository.setInList(id, thrones, true);
    var lists = await repository.watchLists().first;
    expect(lists.single.name, 'Date night');
    expect(lists.single.items, [thrones.key.id, matrix.key.id]);
    expect(await repository.watchTitles().first, hasLength(2));

    await repository.renameList(id, 'Film club');
    await repository.setInList(id, matrix, false);
    lists = await repository.watchLists().first;
    expect(lists.single.name, 'Film club');
    expect(lists.single.items, [thrones.key.id]);

    await repository.deleteList(id);
    expect(await repository.watchLists().first, isEmpty);
    expect(await repository.watchTitles().first, hasLength(2));
    expect(
      () => repository.createList('   '),
      throwsA(isA<WatchlistException>()),
    );
  });

  test('removing a title clears it, leaves its lists and can be added again', () async {
    final list = await repository.createList('Later', first: matrix);
    await repository.setStatus(matrix, WatchStatus.completed);
    await repository.setRating(matrix, 7);
    await repository.removeTitle(matrix.key.id);

    expect(await repository.watchTitles().first, isEmpty);
    expect(await repository.watchTitle(matrix.key.id).first, isNull);
    expect((await repository.watchLists().first).single.items, isEmpty);
    final row = await db.select(db.watchTitles).getSingle();
    expect(row.deletedAt, isNotNull);
    expect(row.rating, isNull);

    final again = await repository.setStatus(matrix, WatchStatus.planned);
    expect(again.removed, isFalse);
    expect(again.rating, isNull, reason: 'returns blank, not as it was');
    expect(again.status, WatchStatus.planned);
    expect(list, isNotEmpty);
  });

  test('the catalog never lets a search summary replace fetched details', () async {
    final details = CatalogTitle(
      key: matrix.key,
      title: 'The Matrix',
      runtime: 136,
      seasons: const [],
      detailed: true,
    );
    await repository.cacheTitles([details]);
    await repository.cacheTitles([matrix]);
    expect((await repository.cachedTitle(matrix.key))!.runtime, 136);

    await repository.cacheTitles([thrones]);
    await repository.cacheSeason(thrones.key, 1, const [
      EpisodeSummary(season: 1, number: 1, name: 'Winter Is Coming'),
    ]);
    expect((await repository.cachedSeason(thrones.key, 1))!.single.code, 's1e1');
    expect(await repository.cachedSeason(thrones.key, 2), isNull);
  });
}
