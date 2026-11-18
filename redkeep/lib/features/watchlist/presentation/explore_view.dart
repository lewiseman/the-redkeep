import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/explore_providers.dart';
import '../application/watchlist_providers.dart';
import '../domain/catalog_title.dart';
import '../domain/explore.dart';
import 'watch_list_sheet.dart';
import 'watch_widgets.dart';

IconData moodIcon(Mood mood) => switch (mood.id) {
  'cozy' => Icons.weekend_outlined,
  'scare' => Icons.nights_stay_outlined,
  'cry' => Icons.water_drop_outlined,
  'laugh' => Icons.sentiment_very_satisfied_outlined,
  'mind' => Icons.psychology_outlined,
  'rush' => Icons.local_fire_department_outlined,
  'short' => Icons.timer_outlined,
  'classic' => Icons.movie_filter_outlined,
  _ => Icons.movie_outlined,
};

/// What search shows before anything is typed: moods, then TMDB's trending
/// and popular titles.
class ExploreView extends ConsumerWidget {
  const ExploreView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(exploreRowsProvider);
    // Titles saved since the rows were built drop out at once, without
    // fetching again.
    final saved = {
      for (final t in ref.watch(watchTitlesProvider).value ?? const []) t.id,
    };
    // Earlier rows stay up while fresh ones load.
    final shown = rows.value
        ?.map(
          (row) => ExploreRow(
            title: row.title,
            titles: [
              for (final t in row.titles)
                if (!saved.contains(t.key.id)) t,
            ],
          ),
        )
        .where((row) => row.titles.isNotEmpty)
        .toList();
    return RefreshIndicator(
      onRefresh: () => ref.refresh(exploreRowsProvider.future),
      child: ListView(
        // Coming back from a title returns to the same place.
        key: const PageStorageKey('watch-explore'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Heading('In the mood for'),
          const _Moods(),
          ...switch (shown) {
            final value? => [for (final row in value) _Row(row: row)],
            _ when rows.hasError => [
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: WatchMessage(
                  title: 'Trending titles could not load',
                  body: 'Pull down to try again.',
                ),
              ),
            ],
            _ => [
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: WatchLoading(),
              ),
            ],
          },
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: TextStyle(
            color: palette.ink,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Moods extends StatelessWidget {
  const _Moods();

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth / scale < 520 ? 2 : 4;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio:
              (constraints.maxWidth - 32) /
              columns /
              (52 * scale.clamp(1, 2.5)),
          children: [
            for (final mood in Mood.all)
              Material(
                color: palette.cloth,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push(watchMoodLocation(mood.id)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(moodIcon(mood), color: palette.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            mood.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final ExploreRow row;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final width = 112 * scale.clamp(1.0, 1.4);
    // Poster plus two title lines and the year, at the current text size.
    final height = width * 1.5 + 10 + scale * (13 * 1.25 * 2 + 12 * 1.3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(row.title),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: row.titles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                SizedBox(width: width, child: _tile(context, row.titles[i])),
          ),
        ),
      ],
    );
  }

  static Widget _tile(BuildContext context, CatalogTitle title) => PosterTile(
    key: ValueKey(title.key),
    title: title.title,
    media: title.media,
    posterPath: title.posterPath,
    year: title.year,
    onTap: () => context.push(watchTitleLocation(title.key)),
    onLongPress: () => showWatchListSheet(context, title),
  );
}

/// Every title for one mood.
class WatchMoodPage extends ConsumerWidget {
  const WatchMoodPage({super.key, required this.mood});
  final Mood mood;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final titles = ref.watch(moodTitlesProvider(mood.id));
    final value = titles.value;
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: watchAppBar(context, title: mood.label),
      body: SafeArea(
        top: false,
        child: switch (value) {
          final value? when value.isEmpty => const WatchMessage(
            title: 'Nothing for this mood yet',
            body: 'Try another mood.',
          ),
          final value? => PosterGrid(
            itemCount: value.length,
            itemBuilder: (context, i) => _Row._tile(context, value[i]),
          ),
          _ when titles.hasError => WatchMessage(
            title: 'This mood could not load',
            body: watchErrorText(titles.error!),
            action: TextButton(
              onPressed: () => ref.invalidate(moodTitlesProvider(mood.id)),
              child: const Text('Try again'),
            ),
          ),
          _ => const WatchLoading(),
        },
      ),
    );
  }
}
