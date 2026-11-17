import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/sync/data/drift_account_reset_data.dart';
import 'package:redkeep/features/sync/legacy/legacy_documents.dart';
import 'package:redkeep/features/watchlist/data/drift_watchlist_repository.dart';
import 'package:redkeep/features/watchlist/data/watchlist_sync.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';

import 'watchlist_repository_test.dart' show matrix, thrones;

final now = DateTime.utc(2026, 11, 13, 20);

void main() {
  late AppDatabase db;
  late DriftWatchlistRepository watchlist;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    watchlist = DriftWatchlistRepository(
      db,
      clock: () => now,
      newId: () => 'b' * 32,
    );
  });
  tearDown(() => db.close());

  Map<String, dynamic> title({String name = 'The Matrix'}) => {
    'schema': 1,
    'id': matrix.key.id,
    'media_key': 'movie:603',
    'title': name,
    'note': '',
    'episodes': '[]',
    'created_at': 1,
    'updated_at': 1,
  };

  test('old synced titles, lists and taste are added when missing', () async {
    final store = LegacyDocuments(db);
    expect(await store.insertMissing('watch', title()), 1);
    expect(
      await store.insertMissing('watchlist', {
        'schema': 1,
        'id': 'a' * 32,
        'name': 'Later',
        'items': '["${matrix.key.id}"]',
        'created_at': 1,
        'updated_at': 1,
      }),
      1,
    );
    expect(
      await store.insertMissing('watchtaste', {
        'schema': 1,
        'id': watchProfileId,
        'state': '{"swipes":12}',
        'created_at': 1,
        'updated_at': 1,
      }),
      1,
    );
    expect((await watchlist.readProfile())!['swipes'], 12);
    expect((await db.select(db.watchLists).getSingle()).name, 'Later');
  });

  test('a title this device already has is never overwritten', () async {
    await watchlist.setStatus(matrix, WatchStatus.planned);
    final before = await db.select(db.watchTitles).getSingle();
    expect(
      await LegacyDocuments(db).insertMissing('watch', title(name: 'Old')),
      0,
    );
    final after = await db.select(db.watchTitles).getSingle();
    expect((after.title, after.status), (before.title, before.status));
  });

  test('malformed documents are refused', () {
    expect(LegacyDocuments.decode('watch', title())['id'], matrix.key.id);
    for (final change in <Map<String, Object?>>[
      {'id': thrones.key.id},
      {'media_key': 'person:1'},
      {'status': 'binged'},
      {'rating': 11},
      {'episodes': '["e1"]'},
      {'episodes': 'nope'},
      {'note': 4},
    ]) {
      expect(
        () => LegacyDocuments.decode('watch', {...title(), ...change}),
        throwsFormatException,
        reason: '$change',
      );
    }
    expect(
      () => LegacyDocuments.decode('watchlist', {
        'schema': 1,
        'id': 'a' * 32,
        'name': 'Later',
        'items': '["not-an-id"]',
        'created_at': 1,
        'updated_at': 1,
      }),
      throwsFormatException,
    );
    expect(
      () => LegacyDocuments.decode('watchtaste', {
        'schema': 1,
        'id': 'a' * 32,
        'state': '{}',
        'created_at': 1,
        'updated_at': 1,
      }),
      throwsFormatException,
      reason: 'there is only one taste document',
    );
  });

  test('account reset clears every watchlist table', () async {
    await watchlist.setStatus(matrix, WatchStatus.planned);
    await watchlist.createList('Later');
    await watchlist.cacheTitles([matrix]);
    await DriftAccountResetData(db).clear();
    expect(await db.select(db.watchTitles).get(), isEmpty);
    expect(await db.select(db.watchLists).get(), isEmpty);
    expect(await db.select(db.watchCatalog).get(), isEmpty);
  });
}
