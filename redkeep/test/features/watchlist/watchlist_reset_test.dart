import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/sync/data/drift_account_reset_data.dart';
import 'package:redkeep/features/watchlist/data/drift_watchlist_repository.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';

import 'watchlist_repository_test.dart' show matrix;

void main() {
  test('account reset clears every watchlist table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final watchlist = DriftWatchlistRepository(
      db,
      clock: () => DateTime.utc(2026, 11, 13, 20),
      newId: () => 'b' * 32,
    );
    await watchlist.setStatus(matrix, WatchStatus.planned);
    await watchlist.createList('Later');
    await watchlist.cacheTitles([matrix]);
    await DriftAccountResetData(db).clear();
    expect(await db.select(db.watchTitles).get(), isEmpty);
    expect(await db.select(db.watchLists).get(), isEmpty);
    expect(await db.select(db.watchCatalog).get(), isEmpty);
  });
}
