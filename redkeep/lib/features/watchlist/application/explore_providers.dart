import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tmdb_client.dart';
import '../domain/catalog_title.dart';
import '../domain/explore.dart';
import '../domain/recommender/deck.dart';
import '../domain/recommender/feature_space.dart';
import '../domain/recommender/taste.dart';
import '../domain/watch_title.dart';
import 'watchlist_providers.dart';

class ExploreRow {
  const ExploreRow({required this.title, this.subtitle, required this.titles});
  final String title;
  final String? subtitle;
  final List<CatalogTitle> titles;
}

const exploreRowLength = 15;

/// How long Explore's results outlive the page: moving between Watchlist
/// sections or opening a title should not fetch everything again.
const exploreCacheFor = Duration(minutes: 10);

/// Keeps a provider's result while unwatched, for [exploreCacheFor].
void cacheExplore(Ref ref) {
  final link = ref.keepAlive();
  Timer? release;
  ref.onCancel(() => release = Timer(exploreCacheFor, link.close));
  ref.onResume(() => release?.cancel());
  ref.onDispose(() => release?.cancel());
}

/// Curated rows: personal ones from the local catalog, trending from TMDB.
/// Titles the reader has already saved or swiped are left out.
final exploreRowsProvider = FutureProvider.autoDispose<List<ExploreRow>>((
  ref,
) async {
  cacheExplore(ref);
  final repository = ref.watch(watchlistRepositoryProvider);
  final client = ref.watch(tmdbClientProvider);
  final profile = WatchProfile.fromJson(await repository.readProfile() ?? {});
  final seen = {for (final t in await repository.titles()) t.id};
  final unseen = [
    for (final c in await repository.catalog())
      if (!seen.contains(c.key.id) &&
          DeckBuilder.allowed(c, profile.dealbreakers))
        c,
  ];
  final enjoyment = {
    for (final c in unseen) c.key: profile.enjoyment(FeatureSpace.vector(c)),
  };
  int byEnjoyment(CatalogTitle a, CatalogTitle b) =>
      enjoyment[b.key]!.compareTo(enjoyment[a.key]!);

  var trending = const <CatalogTitle>[];
  if (client != null) {
    try {
      trending = [
        for (final t in await client.trending())
          if (!seen.contains(t.key.id) && t.posterPath != null) t,
      ];
      await repository.cacheTitles(trending);
    } on TmdbException {
      // The other rows still stand offline.
    }
  }
  final picked = [...unseen]..sort(byEnjoyment);
  final gems = unseen.where(isHiddenGem).toList()..sort(byEnjoyment);
  final critics = [...unseen]
    ..sort((a, b) => desirability(b).compareTo(desirability(a)));
  final shows = unseen.where((c) => c.media == WatchMedia.tv).toList()
    ..sort(byEnjoyment);
  return [
    if (picked.isNotEmpty)
      ExploreRow(
        title: profile.empty ? 'Popular right now' : 'Picked for you',
        subtitle: profile.empty ? null : 'From what you like in Discover',
        titles: picked.take(exploreRowLength).toList(),
      ),
    if (trending.isNotEmpty)
      ExploreRow(title: 'Trending this week', titles: trending),
    if (shows.isNotEmpty)
      ExploreRow(
        title: 'Shows to settle into',
        titles: shows.take(exploreRowLength).toList(),
      ),
    if (gems.isNotEmpty)
      ExploreRow(
        title: 'Hidden gems',
        subtitle: 'Loved by few, adored by those few',
        titles: gems.take(exploreRowLength).toList(),
      ),
    if (critics.isNotEmpty)
      ExploreRow(
        title: 'Out of your league',
        subtitle: 'Critics adore them',
        titles: critics.take(exploreRowLength).toList(),
      ),
  ];
}, retry: (_, _) => null);

/// A mood: local matches first, best rated, then more from TMDB.
final moodTitlesProvider = FutureProvider.autoDispose
    .family<List<CatalogTitle>, String>((ref, id) async {
      final mood = Mood.byId(id);
      if (mood == null) return const [];
      cacheExplore(ref);
      final repository = ref.watch(watchlistRepositoryProvider);
      final client = ref.watch(tmdbClientProvider);
      final local = [
        for (final c in await repository.catalog())
          if (c.posterPath != null && mood.matches(c)) c,
      ]..sort((a, b) => desirability(b).compareTo(desirability(a)));
      final keys = {for (final c in local) c.key};
      final remote = <CatalogTitle>[];
      if (client != null) {
        for (final media in WatchMedia.values) {
          final filters = moodFilters(mood, media);
          if (filters == null) continue;
          try {
            remote.addAll([
              for (final t in await client.discover(media, filters))
                if (t.posterPath != null && keys.add(t.key)) t,
            ]);
          } on TmdbException {
            // Local matches are still worth showing.
          }
        }
        remote.sort((a, b) => b.popularity.compareTo(a.popularity));
        await repository.cacheTitles(remote);
      }
      return [...local, ...remote];
    }, retry: (_, _) => null);
