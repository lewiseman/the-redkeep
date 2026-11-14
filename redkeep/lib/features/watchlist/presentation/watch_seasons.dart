import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/discover_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/catalog_title.dart';
import '../domain/watch_title.dart';
import 'watch_widgets.dart';

/// Where the reader is in a show.
class ShowProgress {
  ShowProgress(this.seasons, Set<String> watched, DateTime now)
    : watched = {
        for (final code in watched)
          if (_inSeasons(code, seasons)) code,
      },
      aired = seasons
          .where((s) => s.airDate != null && !s.airDate!.isAfter(now))
          .fold(0, (sum, s) => sum + s.episodeCount);

  final List<SeasonSummary> seasons;
  final Set<String> watched;

  /// Episodes in seasons that have begun airing.
  final int aired;

  int get total => seasons.fold(0, (sum, s) => sum + s.episodeCount);

  int watchedIn(int season) =>
      watched.where((c) => c.startsWith('s${season}e')).length;

  /// The first episode not yet ticked, in order.
  String? get next {
    for (final s in seasons) {
      for (var e = 1; e <= s.episodeCount; e++) {
        if (!watched.contains(episodeCode(s.number, e))) {
          return 'S${s.number}E$e';
        }
      }
    }
    return null;
  }

  bool get caughtUp => aired > 0 && watched.length >= aired;

  static bool _inSeasons(String code, List<SeasonSummary> seasons) {
    final match = episodeCodePattern.firstMatch(code);
    if (match == null) return false;
    final season = int.parse(match[1]!), episode = int.parse(match[2]!);
    return seasons.any((s) => s.number == season && episode <= s.episodeCount);
  }
}

class WatchSeasons extends ConsumerWidget {
  const WatchSeasons({super.key, required this.title, required this.saved});
  final CatalogTitle title;
  final WatchTitle? saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final now = ref.watch(watchClockProvider)();
    final progress = ShowProgress(title.seasons, saved?.episodes ?? {}, now);
    final next = progress.next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            '${progress.watched.length} of ${progress.total} episodes',
            if (next != null && progress.watched.isNotEmpty) 'next $next',
          ].join(' · '),
          style: TextStyle(color: palette.muted, fontSize: 13),
        ),
        if (progress.total > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.watched.length / progress.total,
              minHeight: 6,
              backgroundColor: palette.cloth,
              color: palette.accent,
              semanticsLabel: 'Episodes watched',
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (final season in title.seasons)
          _Season(
            key: ValueKey(season.number),
            title: title,
            season: season,
            watched: progress.watchedIn(season.number),
            episodes: saved?.episodes ?? const {},
          ),
      ],
    );
  }
}

class _Season extends ConsumerWidget {
  const _Season({
    super.key,
    required this.title,
    required this.season,
    required this.watched,
    required this.episodes,
  });
  final CatalogTitle title;
  final SeasonSummary season;
  final int watched;
  final Set<String> episodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final animate = RenderingPolicyScope.of(context).animate;
    final complete = season.episodeCount > 0 && watched >= season.episodeCount;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      expansionAnimationStyle: animate ? null : AnimationStyle.noAnimation,
      title: Text(season.name),
      subtitle: Text(
        '$watched of ${season.episodeCount}',
        style: TextStyle(color: palette.muted, fontSize: 13),
      ),
      trailing: TextButton(
        onPressed: season.episodeCount == 0
            ? null
            : () => _markSeason(context, ref, watch: !complete),
        child: Text(complete ? 'Unmark' : 'Mark all'),
      ),
      children: [_Episodes(title: title, season: season, episodes: episodes)],
    );
  }

  Future<void> _markSeason(
    BuildContext context,
    WidgetRef ref, {
    required bool watch,
  }) async {
    final codes = {
      for (var e = 1; e <= season.episodeCount; e++)
        episodeCode(season.number, e),
    };
    await markEpisodes(
      context,
      ref,
      title,
      watched: watch ? codes : const {},
      unwatched: watch ? const {} : codes,
    );
  }
}

class _Episodes extends ConsumerWidget {
  const _Episodes({
    required this.title,
    required this.season,
    required this.episodes,
  });
  final CatalogTitle title;
  final SeasonSummary season;
  final Set<String> episodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final now = ref.watch(watchClockProvider)();
    final loaded = ref.watch(
      seasonEpisodesProvider((title.key, season.number)),
    );
    final dates = DateFormat.yMMMd();
    // Without episode names, the count is still enough to tick.
    final list =
        loaded.value ??
        (loaded.hasError
            ? [
                for (var e = 1; e <= season.episodeCount; e++)
                  EpisodeSummary(
                    season: season.number,
                    number: e,
                    name: 'Episode $e',
                  ),
              ]
            : null);
    if (list == null) {
      return const Padding(padding: EdgeInsets.all(16), child: WatchLoading());
    }
    return Column(
      children: [
        for (final episode in list)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: episodes.contains(episode.code),
            title: Text('${episode.number}. ${episode.name}'),
            subtitle: episode.airDate == null
                ? null
                : Text(
                    episode.airedBy(now)
                        ? dates.format(episode.airDate!)
                        : 'Airs ${dates.format(episode.airDate!)}',
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
            onChanged: (watched) => markEpisodes(
              context,
              ref,
              title,
              watched: watched == true ? {episode.code} : const {},
              unwatched: watched == true ? const {} : {episode.code},
            ),
          ),
      ],
    );
  }
}

/// Ticks episodes, then offers to finish a show the reader has caught up on.
Future<void> markEpisodes(
  BuildContext context,
  WidgetRef ref,
  CatalogTitle title, {
  Set<String> watched = const {},
  Set<String> unwatched = const {},
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(watchlistRepositoryProvider);
  final nights = ref.read(watchNightsProvider);
  final saved = await runWatchAction(
    context,
    () => repository.setEpisodes(title, watched: watched, unwatched: unwatched),
  );
  if (saved == null || watched.isEmpty) return;
  final progress = ShowProgress(
    title.seasons,
    saved.episodes,
    ref.read(watchClockProvider)(),
  );
  if (!progress.caughtUp || saved.status == WatchStatus.completed) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('You’re caught up on ${title.title}.'),
        action: SnackBarAction(
          label: 'Mark watched',
          onPressed: () => nights.setStatus(title, WatchStatus.completed),
        ),
      ),
    );
}
