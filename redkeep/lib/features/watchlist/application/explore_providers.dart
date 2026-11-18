import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tmdb_client.dart';
import '../domain/catalog_title.dart';
import '../domain/explore.dart';
import '../domain/watch_title.dart';
import 'watchlist_providers.dart';

class ExploreRow {
  const ExploreRow({required this.title, required this.titles});
  final String title;
  final List<CatalogTitle> titles;
}

/// How long browsing results outlive the search page: opening a title and
/// coming back should not fetch everything again.
const exploreCacheFor = Duration(minutes: 10);

void cacheExplore(Ref ref) => keepWhileAway(ref, exploreCacheFor);

/// What search shows before anything is typed: TMDB's trending and popular
/// titles. Empty without a key.
final exploreRowsProvider = FutureProvider.autoDispose<List<ExploreRow>>((
  ref,
) async {
  cacheExplore(ref);
  final client = ref.watch(tmdbClientProvider);
  if (client == null) return const [];
  final repository = ref.watch(watchlistRepositoryProvider);
  final sources = <(String, Future<List<CatalogTitle>> Function())>[
    ('Trending this week', client.trending),
    ('Popular films', () => client.chart(WatchMedia.movie, 'popular')),
    ('Popular shows', () => client.chart(WatchMedia.tv, 'popular')),
  ];
  final rows = <ExploreRow>[];
  Object? failure;
  for (final (title, fetch) in sources) {
    try {
      final titles = [
        for (final t in await fetch())
          if (t.posterPath != null) t,
      ];
      await repository.cacheTitles(titles);
      if (titles.isNotEmpty) rows.add(ExploreRow(title: title, titles: titles));
    } on TmdbException catch (e) {
      failure = e;
    }
  }
  // Some rows are worth showing; none at all is worth saying.
  if (rows.isEmpty && failure != null) throw failure;
  return rows;
}, retry: (_, _) => null);

/// A mood's films and shows from TMDB, most popular first.
final moodTitlesProvider = FutureProvider.autoDispose
    .family<List<CatalogTitle>, String>((ref, id) async {
      final mood = Mood.byId(id);
      if (mood == null) return const [];
      cacheExplore(ref);
      final client = ref.watch(tmdbClientProvider);
      if (client == null) throw const WatchlistSetupException();
      final repository = ref.watch(watchlistRepositoryProvider);
      final keys = <WatchKey>{};
      final titles = <CatalogTitle>[];
      Object? failure;
      for (final media in WatchMedia.values) {
        final filters = moodFilters(mood, media);
        if (filters == null) continue;
        try {
          titles.addAll([
            for (final t in await client.discover(media, filters))
              if (t.posterPath != null && keys.add(t.key)) t,
          ]);
        } on TmdbException catch (e) {
          failure = e;
        }
      }
      if (titles.isEmpty && failure != null) throw failure;
      titles.sort((a, b) => b.popularity.compareTo(a.popularity));
      await repository.cacheTitles(titles);
      return titles;
    }, retry: (_, _) => null);
