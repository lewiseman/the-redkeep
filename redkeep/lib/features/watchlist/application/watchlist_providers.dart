import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/storage_providers.dart';
import '../data/drift_watchlist_repository.dart';
import '../data/tmdb_client.dart';
import '../domain/catalog_title.dart';
import '../domain/watch_title.dart';
import '../domain/watchlist_repository.dart';

/// From `--dart-define-from-file=env.json`. Empty when not configured.
final tmdbApiKeyProvider = Provider<String>(
  (ref) => const String.fromEnvironment('TMDB_API_KEY'),
);
final tmdbRegionProvider = Provider<String>((ref) {
  const region = String.fromEnvironment('TMDB_REGION');
  return RegExp(r'^[A-Z]{2}$').hasMatch(region) ? region : 'US';
});
final tmdbHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Null without a key: the Watchlist still shows what is saved.
final tmdbClientProvider = Provider<TmdbClient?>((ref) {
  final key = ref.watch(tmdbApiKeyProvider).trim();
  if (key.isEmpty) return null;
  return TmdbClient(
    ref.watch(tmdbHttpClientProvider),
    apiKey: key,
    region: ref.watch(tmdbRegionProvider),
  );
});

/// Keeps a provider alive for [duration] after nothing watches it, so moving
/// between Watchlist sections, or into a title and back, keeps its state.
/// [onReturn] runs when something watches it again within that time.
void keepWhileAway(Ref ref, Duration duration, {void Function()? onReturn}) {
  final link = ref.keepAlive();
  Timer? release;
  ref.onCancel(() => release = Timer(duration, link.close));
  ref.onResume(() {
    release?.cancel();
    onReturn?.call();
  });
  ref.onDispose(() => release?.cancel());
}

final watchClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final watchIdProvider = Provider<String Function()>((ref) {
  final random = Random.secure();
  return () => List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
});

final watchlistRepositoryProvider = Provider<WatchlistRepository>(
  (ref) => DriftWatchlistRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(watchClockProvider),
    newId: ref.watch(watchIdProvider),
  ),
);

final watchTitlesProvider = StreamProvider.autoDispose<List<WatchTitle>>(
  (ref) => ref.watch(watchlistRepositoryProvider).watchTitles(),
  retry: (_, _) => null,
);

final watchListsProvider = StreamProvider.autoDispose<List<WatchList>>(
  (ref) => ref.watch(watchlistRepositoryProvider).watchLists(),
  retry: (_, _) => null,
);

final watchTitleProvider = StreamProvider.autoDispose
    .family<WatchTitle?, String>(
      (ref, id) => ref.watch(watchlistRepositoryProvider).watchTitle(id),
      retry: (_, _) => null,
    );

/// How long fetched details are trusted before asking TMDB again.
const catalogFreshness = Duration(days: 7);

/// Details for one title: fresh cache, then TMDB, then any stale cache.
final catalogTitleProvider = FutureProvider.autoDispose
    .family<CatalogTitle, WatchKey>((ref, key) async {
      final repository = ref.watch(watchlistRepositoryProvider);
      final client = ref.watch(tmdbClientProvider);
      final now = ref.watch(watchClockProvider)();
      final cached = await repository.cachedTitle(key);
      final at = await repository.cachedAt(key);
      if (cached != null &&
          cached.detailed &&
          at != null &&
          now.difference(at) < catalogFreshness) {
        return cached;
      }
      if (client == null) {
        if (cached != null) return cached;
        throw const WatchlistSetupException();
      }
      try {
        final details = await client.details(key);
        await repository.cacheTitles([details]);
        return details;
      } on TmdbException {
        if (cached != null) return cached;
        rethrow;
      }
    }, retry: (_, _) => null);

/// One season's episodes, cached once fetched.
final seasonEpisodesProvider = FutureProvider.autoDispose
    .family<List<EpisodeSummary>, (WatchKey, int)>((ref, request) async {
      final (key, season) = request;
      final repository = ref.watch(watchlistRepositoryProvider);
      final cached = await repository.cachedSeason(key, season);
      final client = ref.watch(tmdbClientProvider);
      if (client == null) {
        if (cached != null) return cached;
        throw const WatchlistSetupException();
      }
      try {
        final episodes = await client.season(key.tmdbId, season);
        await repository.cacheSeason(key, season, episodes);
        return episodes;
      } on TmdbException {
        if (cached != null) return cached;
        rethrow;
      }
    }, retry: (_, _) => null);

/// Search results; the page debounces before asking.
final watchSearchProvider = FutureProvider.autoDispose
    .family<List<CatalogTitle>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const [];
      final client = ref.watch(tmdbClientProvider);
      if (client == null) throw const WatchlistSetupException();
      final results = await client.search(trimmed);
      await ref.read(watchlistRepositoryProvider).cacheTitles(results);
      return results;
    }, retry: (_, _) => null);

/// The minimal catalog facts for a saved title, for actions taken from a
/// list without opening it.
CatalogTitle catalogFromWatchTitle(WatchTitle title) => CatalogTitle(
  key: title.key,
  title: title.title,
  year: title.year,
  posterPath: title.posterPath,
);

class WatchlistSetupException implements Exception {
  const WatchlistSetupException();

  @override
  String toString() =>
      'Add TMDB_API_KEY to env.json to search films and shows.';
}

/// Library tabs: everything, likes, each status, then each named list.
sealed class LibraryTab {
  const LibraryTab();
  String get label;
}

class AllTab extends LibraryTab {
  const AllTab();
  @override
  String get label => 'All';
}

/// Live matches not yet moved to a status.
class LikesTab extends LibraryTab {
  const LikesTab();
  @override
  String get label => 'Likes';
}

class StatusTab extends LibraryTab {
  const StatusTab(this.status);
  final WatchStatus status;
  @override
  String get label => status.label;
}

class ListTab extends LibraryTab {
  const ListTab(this.list);
  final WatchList list;
  @override
  String get label => list.name;
}

class Library {
  const Library({required this.titles, required this.lists});

  final List<WatchTitle> titles;
  final List<WatchList> lists;

  List<LibraryTab> get tabs => [
    const AllTab(),
    const LikesTab(),
    for (final s in WatchStatus.values) StatusTab(s),
    for (final l in lists) ListTab(l),
  ];

  Set<String> get _listed => {for (final l in lists) ...l.items};

  /// A live match not yet moved to a status. Kept in step with
  /// `LikesGroups.isLiked`.
  static bool _liked(WatchTitle t) =>
      t.matchState == MatchState.active && t.status == null;

  /// Titles saved by like, status or list. Discover's passes stay out.
  List<WatchTitle> titlesFor(LibraryTab tab) {
    final listed = _listed;
    return switch (tab) {
      AllTab() => [
        for (final t in titles)
          if (t.status != null || _liked(t) || listed.contains(t.id)) t,
      ],
      LikesTab() => [
        for (final t in titles)
          if (_liked(t)) t,
      ],
      StatusTab(:final status) => [
        for (final t in titles)
          if (t.status == status) t,
      ],
      ListTab(:final list) => [
        for (final id in list.items)
          ?titles.where((t) => t.id == id).firstOrNull,
      ],
    };
  }

  List<WatchList> listsHolding(String titleId) => [
    for (final l in lists)
      if (l.items.contains(titleId)) l,
  ];
}

final libraryProvider = Provider.autoDispose<AsyncValue<Library>>((ref) {
  final titles = ref.watch(watchTitlesProvider);
  final lists = ref.watch(watchListsProvider);
  if (titles.hasError) {
    return AsyncError(titles.error!, titles.stackTrace ?? StackTrace.empty);
  }
  if (lists.hasError) {
    return AsyncError(lists.error!, lists.stackTrace ?? StackTrace.empty);
  }
  if (!titles.hasValue || !lists.hasValue) return const AsyncLoading();
  return AsyncData(
    Library(titles: titles.requireValue, lists: lists.requireValue),
  );
});
