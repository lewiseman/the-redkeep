import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/explore_providers.dart';
import '../application/watchlist_providers.dart';
import '../domain/catalog_title.dart';
import '../domain/explore.dart';
import 'watch_explore_parts.dart';
import 'watch_header.dart';
import 'watch_wall.dart';
import 'watch_widgets.dart';

/// The top of a page reached from the wall: the way back, a name in
/// handwriting and its pen underline.
class ExploreTop extends StatelessWidget {
  const ExploreTop({super.key, required this.title, this.ink});

  final String title;

  /// The underline's colour; the accent by default.
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GlassBackButton(),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Semantics(
                header: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: wallHand(context, size: 46)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: ExcludeSemantics(
                child: CustomPaint(
                  size: const Size(150, 14),
                  painter: PenSquiggle(ink ?? palette.accent, 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What search shows before anything is typed: moods as cinema tickets,
/// what is trending as a fanned deck of photos, then the popular films and
/// shows lying loose, each ready to be pinned to the wall.
class ExploreView extends ConsumerStatefulWidget {
  const ExploreView({super.key});

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView> {
  /// What was on the wall when the page opened. These stay out of the way;
  /// titles pinned here stay, taped, so the reader sees them go up.
  Set<String>? _alreadySaved;

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(exploreRowsProvider);
    _alreadySaved ??= ref
        .watch(watchTitlesProvider)
        .value
        ?.map((t) => t.id)
        .toSet();
    final hidden = _alreadySaved ?? const {};
    // Earlier rows stay up while fresh ones load.
    final shown = rows.value
        ?.map(
          (row) => ExploreRow(
            title: row.title,
            titles: [
              for (final t in row.titles)
                if (!hidden.contains(t.key.id)) t,
            ],
          ),
        )
        .where((row) => row.titles.isNotEmpty)
        .toList();
    return RefreshIndicator(
      onRefresh: () => ref.refresh(exploreRowsProvider.future),
      child: CustomScrollView(
        // Coming back from a title returns to the same place.
        key: const PageStorageKey('watch-explore'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          const SliverToBoxAdapter(child: ExploreTop(title: 'Find something')),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
          const SliverToBoxAdapter(child: _TicketRoll()),
          ...switch (shown) {
            final value? => [
              for (final (i, row) in value.indexed)
                SliverToBoxAdapter(
                  child: i == 0 ? _NowShowing(row: row) : _Row(row: row),
                ),
            ],
            _ when rows.hasError => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: WatchMessage(
                    title: 'Trending titles could not load',
                    body: 'Pull down to try again.',
                  ),
                ),
              ),
            ],
            _ => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: WatchLoading(),
                ),
              ),
            ],
          },
          const SliverToBoxAdapter(
            child: SizedBox(height: searchDockClearance + 16),
          ),
        ],
      ),
    );
  }
}

/// Every mood as a ticket, in two rows to flick through.
class _TicketRoll extends StatelessWidget {
  const _TicketRoll();

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    final height = 62 * scale;
    final width = 196 * scale.clamp(1.0, 1.3);
    return SizedBox(
      height: height * 2 + 14 + 8,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        itemCount: Mood.all.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: width,
        ),
        itemBuilder: (context, i) {
          final mood = Mood.all[i];
          return MoodTicket(
            key: ValueKey(mood.id),
            mood: mood,
            onTap: () => context.push(watchMoodLocation(mood.id)),
          );
        },
      ),
    );
  }
}

/// What is trending this week, as a fanned deck with no heading: the photo
/// in front stands straight, the ones either side tip away and sink as they
/// slide off.
class _NowShowing extends StatefulWidget {
  const _NowShowing({required this.row});
  final ExploreRow row;

  @override
  State<_NowShowing> createState() => _NowShowingState();
}

class _NowShowingState extends State<_NowShowing> {
  final _deck = PageController(viewportFraction: .54);

  @override
  void dispose() {
    _deck.dispose();
    super.dispose();
  }

  /// Which photo is in front, read from the scroll offset itself. Cards are
  /// built during the deck's first layout, when the restored offset is known
  /// but [PageController.page] is not yet, and nothing notifies afterwards,
  /// so falling back to page 0 there would leave the fan bent around the
  /// wrong photo after coming back to the page.
  double _page() {
    if (!_deck.hasClients) return _deck.initialPage.toDouble();
    final position = _deck.position;
    if (!position.hasPixels || !position.hasViewportDimension) {
      return _deck.initialPage.toDouble();
    }
    final extent = position.viewportDimension * _deck.viewportFraction;
    if (extent <= 0) return _deck.initialPage.toDouble();
    return position.pixels / extent;
  }

  @override
  Widget build(BuildContext context) {
    final titles = widget.row.titles;
    final animate = RenderingPolicyScope.of(context).animate;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final card = constraints.maxWidth * .54 - 28;
            final height =
                card * 1.5 + 16 + 7 + 2 * 22 * 1.05 * scale + 18 * scale + 40;
            return SizedBox(
              height: height,
              child: PageView.builder(
                controller: _deck,
                itemCount: titles.length,
                itemBuilder: (context, i) {
                  final title = titles[i];
                  final photo = Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ExplorePolaroid(
                        key: ValueKey(title.key),
                        title: title,
                        caption: 22,
                        lean: 0,
                        aboveDock: true,
                        onOpen: () =>
                            context.push(watchTitleLocation(title.key)),
                      ),
                    ),
                  );
                  if (!animate) return photo;
                  return AnimatedBuilder(
                    animation: _deck,
                    child: photo,
                    builder: (context, child) {
                      final d = (i - _page()).clamp(-1.6, 1.6);
                      final away = d.abs();
                      return Transform.translate(
                        offset: Offset(0, 30 * away * away),
                        child: Transform.rotate(
                          angle: d * .13,
                          alignment: Alignment.bottomCenter,
                          child: Transform.scale(
                            scale: 1 - .1 * away,
                            child: child,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A stretch of photos lying loose, to flick along.
class _Row extends StatelessWidget {
  const _Row({required this.row});
  final ExploreRow row;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final width = 138 * scale.clamp(1.0, 1.35);
    final height =
        width * 1.5 + 16 + 7 + 2 * 20 * 1.05 * scale + 18 * scale + 22;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExploreHeading(row.title),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
            itemCount: row.titles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 18),
            itemBuilder: (context, i) {
              final title = row.titles[i];
              return SizedBox(
                width: width,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ExplorePolaroid(
                    key: ValueKey(title.key),
                    title: title,
                    aboveDock: true,
                    onOpen: () => context.push(watchTitleLocation(title.key)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Loose photos laid out as the wall lays them, for results and moods.
class ExploreMasonry extends StatelessWidget {
  const ExploreMasonry({
    super.key,
    required this.titles,
    this.aboveDock = false,
  });
  final List<CatalogTitle> titles;
  final bool aboveDock;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    sliver: SliverLayoutBuilder(
      builder: (context, constraints) => SliverMasonryGrid.count(
        crossAxisCount: wallColumns(context, constraints.crossAxisExtent),
        mainAxisSpacing: 26,
        crossAxisSpacing: 20,
        childCount: titles.length,
        itemBuilder: (context, i) {
          final title = titles[i];
          return WallEntrance(
            key: ValueKey(title.key),
            index: i,
            child: ExplorePolaroid(
              title: title,
              aboveDock: aboveDock,
              onOpen: () => context.push(watchTitleLocation(title.key)),
            ),
          );
        },
      ),
    ),
  );
}

/// Every title for one mood, its name in handwriting over its own colour.
class WatchMoodPage extends ConsumerWidget {
  const WatchMoodPage({super.key, required this.mood});
  final Mood mood;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final cushion = CushionColors.of(context);
    final titles = ref.watch(moodTitlesProvider(mood.id));
    final value = titles.value;
    final hue = MoodStyle.of(mood).hue;
    return Scaffold(
      backgroundColor: palette.ground,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ExploreTop(
                    title: mood.label,
                    ink: Color.lerp(hue, cushion.ink, cushion.dark ? 0 : .2),
                  ),
                ),
                ...switch (value) {
                  final value? when value.isEmpty => [
                    const SliverToBoxAdapter(
                      child: WatchMessage(
                        title: 'Nothing for this mood yet',
                        body: 'Try another mood.',
                      ),
                    ),
                  ],
                  final value? => [ExploreMasonry(titles: value)],
                  _ when titles.hasError => [
                    SliverToBoxAdapter(
                      child: WatchMessage(
                        title: 'This mood could not load',
                        body: watchErrorText(titles.error!),
                        action: TextButton(
                          onPressed: () =>
                              ref.invalidate(moodTitlesProvider(mood.id)),
                          child: const Text('Try again'),
                        ),
                      ),
                    ),
                  ],
                  _ => [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: WatchLoading(),
                      ),
                    ),
                  ],
                },
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 32 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: StatusFade()),
        ],
      ),
    );
  }
}
