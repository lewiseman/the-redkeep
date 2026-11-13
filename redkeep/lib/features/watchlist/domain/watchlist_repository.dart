import '../../../core/storage/app_database.dart';
import 'catalog_title.dart';
import 'watch_title.dart';

/// Changes to a title row, applied to its current state. A removed title is
/// restored blank before the change.
typedef WatchTitleChange = WatchTitlesCompanion Function(WatchTitle? current);

abstract interface class WatchlistRepository {
  /// Every title the reader has touched and not removed, newest first.
  Stream<List<WatchTitle>> watchTitles();
  Stream<WatchTitle?> watchTitle(String id);
  Stream<List<WatchList>> watchLists();

  /// One-off reads, for actions rather than pages.
  Future<List<WatchTitle>> titles();
  Future<WatchTitle?> title(String id);

  Future<WatchTitle> edit(CatalogTitle title, WatchTitleChange change);
  Future<WatchTitle> setStatus(CatalogTitle title, WatchStatus? status);
  Future<WatchTitle> setRating(CatalogTitle title, int? rating);
  Future<WatchTitle> setNote(CatalogTitle title, String note);
  Future<WatchTitle> setEpisodes(
    CatalogTitle title, {
    Set<String> watched = const {},
    Set<String> unwatched = const {},
  });

  /// Clears everything about a title and takes it out of every list.
  Future<void> removeTitle(String id);

  Future<String> createList(String name, {CatalogTitle? first});
  Future<void> renameList(String id, String name);
  Future<void> deleteList(String id);
  Future<void> setInList(String listId, CatalogTitle title, bool member);

  /// The synced taste document's state, or null before the first swipe.
  Stream<Map<String, dynamic>?> watchProfile();
  Future<Map<String, dynamic>?> readProfile();
  Future<void> saveProfile(Map<String, dynamic> state);

  // The local TMDB cache.
  Future<List<CatalogTitle>> catalog();
  Future<int> catalogSize();
  Future<CatalogTitle?> cachedTitle(WatchKey key);
  Future<DateTime?> cachedAt(WatchKey key);
  Future<void> cacheTitles(Iterable<CatalogTitle> titles);
  Future<List<EpisodeSummary>?> cachedSeason(WatchKey key, int season);
  Future<void> cacheSeason(
    WatchKey key,
    int season,
    List<EpisodeSummary> episodes,
  );
}
