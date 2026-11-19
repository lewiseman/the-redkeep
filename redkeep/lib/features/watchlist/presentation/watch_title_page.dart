import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/watchlist_providers.dart';
import '../domain/catalog_title.dart';
import '../domain/watch_title.dart';
import 'stamp_feel.dart';
import 'watch_list_sheet.dart';
import 'watch_seasons.dart';
import 'watch_title_extras.dart';
import 'watch_title_parts.dart';
import 'watch_title_sections.dart';
import 'watch_wall.dart';
import 'watch_widgets.dart';

/// A film or show's own page, reached by its address. Its poster is pinned
/// up as a polaroid, flown over from the wall; a rack of rubber stamps sits
/// under the thumb for its status, and everything TMDB shares follows.
class WatchTitlePage extends ConsumerWidget {
  const WatchTitlePage({super.key, required this.watchKey});
  final WatchKey watchKey;

  /// Stamps [status] on, or lifts it off when it is already there; a drop
  /// always stamps. The stamp itself is the confirmation: no message.
  static Future<void> stamp(
    BuildContext context,
    WidgetRef ref,
    CatalogTitle title,
    WatchStatus? before,
    WatchStatus status, {
    bool toggle = true,
  }) async {
    final lifting = toggle && before == status;
    if (!lifting && before == status) return;
    await runWatchAction(
      context,
      () => ref
          .read(watchlistRepositoryProvider)
          .setStatus(title, lifting ? null : status),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final catalog = ref.watch(catalogTitleProvider(watchKey));
    final saved = ref.watch(watchTitleProvider(watchKey.id)).value;
    // Without fresh details, what was saved is enough to act on.
    final title =
        catalog.value ?? (saved == null ? null : catalogFromWatchTitle(saved));
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: palette.ground,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: title == null
                ? catalog.hasError
                      ? WatchMessage(
                          title: 'This title could not open',
                          body: catalog.error.toString(),
                          action: TextButton(
                            onPressed: () =>
                                ref.invalidate(catalogTitleProvider(watchKey)),
                            child: const Text('Try again'),
                          ),
                        )
                      : ReelLoading(seed: watchKey.tmdbId)
                : _Details(title: title, saved: saved, stale: catalog.hasError),
          ),
          // The page thins away under the back button as it scrolls.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: top + 72,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.ground,
                      palette.ground.withValues(alpha: .9),
                      palette.ground.withValues(alpha: 0),
                    ],
                    stops: const [0, .55, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: 8, top: top + 8, child: const GlassBackButton()),
        ],
      ),
      bottomNavigationBar: title == null
          ? null
          : StampRack(
              status: saved?.status,
              onStamp: (status) =>
                  stamp(context, ref, title, saved?.status, status),
            ),
    );
  }
}

/// "2h 7m", or "45m" for less than an hour.
String watchRuntime(int minutes) {
  final hours = minutes ~/ 60, rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

class _Details extends ConsumerWidget {
  const _Details({
    required this.title,
    required this.saved,
    required this.stale,
  });
  final CatalogTitle title;
  final WatchTitle? saved;
  final bool stale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final saved = this.saved;
    final tv = title.media == WatchMedia.tv;
    final type = DiaryTypography.of(context);
    final body = type.body.copyWith(
      color: palette.ink,
      fontSize: 15,
      height: 1.6,
    );
    final lists = ref
        .watch(watchListsProvider)
        .value
        ?.where((l) => l.items.contains(title.key.id))
        .map((l) => l.name)
        .toList();
    final region = ref.watch(tmdbRegionProvider);
    final runtime = title.runtime;
    final seasons = title.seasons.length;
    final dates = DateFormat.yMMMd();
    final money = NumberFormat.compactSimpleCurrency(name: 'USD');

    final summary = [
      ?title.year?.toString(),
      tv ? 'Series' : 'Film',
      if (runtime != null) tv ? '${runtime}m episodes' : watchRuntime(runtime),
      ?title.certification,
    ].join(' · ');
    final pinned =
        saved ??
        WatchTitle(
          id: title.key.id,
          key: title.key,
          title: title.title,
          posterPath: title.posterPath,
          year: title.year,
          revision: 0,
          createdAt: DateTime(2000),
          updatedAt: DateTime(2000),
        );
    final pictures = titlePictures(title);
    final posterAt = pictures.indexWhere(
      (p) => p.poster && p.path == title.posterPath,
    );
    final width = math.min(MediaQuery.sizeOf(context).width * .64, 280.0);
    final policy = RenderingPolicyScope.of(context);
    final trailer = title.trailer;
    final homepage = title.homepage;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 22),
      child: Column(
        children: [
          // Drop a stamp from the rack onto the polaroid to print it.
          DragTarget<WatchStatus>(
            onAcceptWithDetails: (drop) {
              StampFeel.thud();
              WatchTitlePage.stamp(
                context,
                ref,
                title,
                saved?.status,
                drop.data,
                toggle: false,
              );
            },
            builder: (context, hovering, _) => AnimatedScale(
              scale: hovering.isEmpty ? 1 : 1.05,
              duration: policy.duration,
              curve: Curves.easeOutBack,
              child: SizedBox(
                width: width,
                child: Semantics(
                  header: true,
                  child: WallPolaroid(
                    title: pinned,
                    captionSize: 31,
                    stampScale: 1.7,
                    showMeta: false,
                    onTap: posterAt < 0
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => TitleGalleryPage(
                                title: title.title,
                                pictures: pictures,
                                initial: posterAt,
                              ),
                            ),
                          ),
                    doubleTapLabel: saved?.status == WatchStatus.completed
                        ? 'Lift the watched stamp'
                        : 'Stamp watched',
                    onDoubleTap: () {
                      StampFeel.thud();
                      WatchTitlePage.stamp(
                        context,
                        ref,
                        title,
                        saved?.status,
                        WatchStatus.completed,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            summary,
            textAlign: TextAlign.center,
            style: body.copyWith(color: palette.muted, fontSize: 14),
          ),
          if (title.tagline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              title.tagline,
              textAlign: TextAlign.center,
              style: body.copyWith(
                color: palette.muted,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TitleActions(
            trailer: trailer == null
                ? null
                : (
                    label: trailer.type == 'Trailer'
                        ? 'Play trailer'
                        : 'Play ${trailer.type?.toLowerCase() ?? 'video'}',
                    open: () => openTitleLink(context, trailer.url),
                  ),
            lists: ListsChip(
              lists: lists ?? const [],
              onTap: () => showWatchListSheet(context, title),
            ),
            onSite: homepage == null
                ? null
                : () => openTitleLink(context, Uri.parse(homepage)),
          ),
        ],
      ),
    );

    String? date(DateTime? value) => value == null ? null : dates.format(value);
    final next = title.nextEpisode;
    final facts = <(String, String)>[
      if (title.status != null) ('Status', title.status!),
      if (date(title.releaseDate) case final released?)
        (tv ? 'First aired' : 'Released', released),
      if (date(title.lastAirDate) case final last?) ('Last aired', last),
      if (next != null)
        (
          'Next episode',
          ['S${next.season} E${next.number}', ?date(next.airDate)].join(' · '),
        ),
      if (tv && seasons > 0)
        (
          'Seasons',
          [
            '$seasons',
            if (title.episodeCount != null) '${title.episodeCount} episodes',
          ].join(' · '),
        ),
      if (title.genres.isNotEmpty) ('Genre', title.genres.join(', ')),
      if (title.certification != null)
        ('Rated', '${title.certification} ($region)'),
      if (title.originalTitle != null) ('Original title', title.originalTitle!),
      if (title.spokenLanguages.isNotEmpty)
        ('Languages', title.spokenLanguages.join(', '))
      else if (title.language != null)
        ('Language', title.language!.toUpperCase()),
      if (title.networks.isNotEmpty) ('Network', title.networks.join(', ')),
      if (title.budget != null) ('Budget', money.format(title.budget)),
      if (title.revenue != null) ('Box office', money.format(title.revenue)),
      if (title.companies.isNotEmpty)
        ('Studios', title.companies.take(4).join(', ')),
      if (title.countries.isNotEmpty) ('Made in', title.countries.join(', ')),
    ];
    // One line a job, as a show lists the same job for many people.
    final jobs = <String, List<String>>{};
    for (final person in title.crew) {
      for (final job in (person.role ?? 'Crew').split(', ')) {
        jobs.putIfAbsent(job, () => []).add(person.name);
      }
    }
    final credits = [
      for (final MapEntry(key: job, value: names) in jobs.entries)
        (
          // "Producers", but "Screenplay" and "Novel" stay as they are.
          names.length > 1 && (job.endsWith('er') || job.endsWith('or'))
              ? '${job}s'
              : job,
          [
            ...names.take(4),
            if (names.length > 4) '+${names.length - 4} more',
          ].join(', '),
        ),
    ];
    final watch = [
      if (title.providers.isNotEmpty) ('Stream', title.providers),
      if (title.rent.isNotEmpty) ('Rent', title.rent),
      if (title.buy.isNotEmpty) ('Buy', title.buy),
    ];
    // Each part of the page dressed for what it is, not one card for all.
    final parts = <Widget>[
      header,
      if (stale)
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
          child: Text(
            'Showing what was saved. TMDB could not be reached.',
            style: TextStyle(color: palette.muted, fontSize: 13),
          ),
        ),
      if (tv && title.seasons.isNotEmpty) ...[
        const TitleHeading('Episodes'),
        TitleCushion(
          child: WatchSeasons(title: title, saved: saved),
        ),
      ],
      if (title.overview.isNotEmpty || title.keywords.isNotEmpty) ...[
        const TitleHeading('About'),
        AboutNote(overview: title.overview, keywords: title.keywords),
      ],
      if (pictures.length > 1) ...[
        const TitleHeading('Pictures'),
        PhotoPile(title: title),
      ],
      if (title.cast.isNotEmpty) ...[
        const TitleHeading('Cast'),
        CastRing(cast: title.cast),
      ],
      if (credits.isNotEmpty) ...[
        TitleHeading(tv ? 'Made by' : 'Crew'),
        CreditsRoll(title: title.title, credits: credits),
      ],
      if (facts.isNotEmpty || title.voteCount > 0) ...[
        const TitleHeading('Details'),
        DetailsTicket(
          facts: facts,
          rating: title.voteCount > 0 ? title.voteAverage : null,
          votes: title.voteCount > 0
              ? '${NumberFormat.compact().format(title.voteCount)} votes'
              : null,
        ),
      ],
      if (watch.isNotEmpty) ...[
        const TitleHeading('Where to watch'),
        WatchHere(
          groups: watch,
          footnote: 'In $region, from JustWatch via TMDB.',
        ),
      ],
      if (title.recommendations.isNotEmpty) ...[
        const TitleHeading('More like this'),
        MoreLikeThisWall(titles: title.recommendations),
      ],
    ];

    final media = MediaQuery.of(context);
    return ListView(
      // Clear of the back button above and the stamp rack below.
      padding: EdgeInsets.fromLTRB(
        12,
        media.padding.top + 52,
        12,
        stampRackHeight(context) + 12,
      ),
      children: [
        for (final part in parts)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: part,
            ),
          ),
      ],
    );
  }
}
