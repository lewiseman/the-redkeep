import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../assets/presentation/local_artwork.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/discover_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/watch_title.dart';
import '../../../core/presentation/rendering_policy.dart';
import 'discover_view.dart';
import 'explore_view.dart';
import 'likes_view.dart';
import 'watch_list_sheet.dart';
import 'watch_navbar.dart';
import 'watch_title_page.dart';
import 'watch_widgets.dart';

enum WatchSection { discover, explore, library }

/// The Watchlist, opened from More: Discover, Explore and the Library.
class WatchlistPage extends ConsumerStatefulWidget {
  const WatchlistPage({super.key});

  @override
  ConsumerState<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends ConsumerState<WatchlistPage>
    with SingleTickerProviderStateMixin {
  var _section = WatchSection.library;
  final _stack = GlobalKey();

  /// 0 shows the deck with its bars; 1, the profile grown from a card.
  late final _grow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  ProfileRequest? _profile;
  bool _closing = false;

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  bool get _animate => RenderingPolicyScope.of(context).animate;

  /// The card grows into its profile as the bars move away.
  void _openProfile(ProfileRequest request) {
    if (_profile != null) return;
    setState(() => _profile = request);
    if (_animate) {
      _grow.forward(from: 0);
    } else {
      _grow.value = 1;
    }
  }

  /// Back into the card; a decision then swipes it.
  Future<void> _closeProfile([SwipeChoice? choice]) async {
    final request = _profile;
    if (request == null || _closing) return;
    _closing = true;
    if (_animate) {
      await _grow.reverse();
    } else {
      _grow.value = 0;
    }
    if (!mounted) return;
    setState(() {
      _profile = null;
      _closing = false;
    });
    if (choice != null) request.decide(choice);
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final waiting = ref.watch(
      watchTitlesProvider.select(
        (titles) => titles.value == null
            ? 0
            : LikesGroups(
                titles.value!,
                ref.read(watchClockProvider)().toUtc(),
              ).waiting,
      ),
    );
    final bars = ReverseAnimation(
      CurvedAnimation(parent: _grow, curve: Curves.easeInOutCubic),
    );
    final profile = _profile;
    final appBar = watchAppBar(
      context,
      title: switch (_section) {
        WatchSection.discover => 'Discover',
        WatchSection.explore => 'Explore',
        WatchSection.library => 'Watchlist',
      },
      actions: [
        // Explore has its own search box; Discover is only the deck.
        if (_section == WatchSection.library)
          IconButton(
            tooltip: 'Search films and shows',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(watchSearchLocation),
          ),
        if (_section == WatchSection.discover)
          IconButton(
            tooltip: 'Dealbreakers',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(watchPreferencesLocation),
          ),
        if (_section == WatchSection.library)
          IconButton(
            tooltip: 'New list',
            icon: const Icon(Icons.playlist_add),
            onPressed: () async {
              final name = await askListName(context);
              if (name == null || !context.mounted) return;
              await runWatchAction(
                context,
                () => ref.read(watchlistRepositoryProvider).createList(name),
              );
            },
          ),
      ],
    );
    final navigation = WatchNavbar(
      selectedIndex: _section.index,
      onSelected: (i) => setState(() => _section = WatchSection.values[i]),
      destinations: [
        (
          label: 'Discover',
          icon: Icons.style_outlined,
          selectedIcon: Icons.style,
          badge: 0,
        ),
        (
          label: 'Explore',
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore,
          badge: 0,
        ),
        (
          label: 'Library',
          icon: Icons.auto_stories_outlined,
          selectedIcon: Icons.auto_stories,
          badge: waiting,
        ),
      ],
    );
    return PopScope(
      // Back closes an open profile before it leaves the Watchlist.
      canPop: profile == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeProfile();
      },
      child: Scaffold(
        backgroundColor: palette.ground,
        // In the Scaffold's own slot, so snackbars sit above it.
        bottomNavigationBar: ExcludeSemantics(
          excluding: profile != null,
          child: SizeTransition(
            sizeFactor: bars,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: bars, child: navigation),
          ),
        ),
        body: Stack(
          key: _stack,
          children: [
            IgnorePointer(
              ignoring: profile != null,
              child: ExcludeSemantics(
                excluding: profile != null,
                child: Column(
                  children: [
                    // The bar slides off the top edge.
                    SizeTransition(
                      sizeFactor: bars,
                      alignment: Alignment.bottomCenter,
                      child: FadeTransition(opacity: bars, child: appBar),
                    ),
                    Expanded(
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: switch (_section) {
                          WatchSection.discover => DiscoverView(
                            onOpenProfile: _openProfile,
                          ),
                          WatchSection.explore => const ExploreView(),
                          WatchSection.library => const LibraryView(),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (profile != null)
              Positioned.fill(
                child: _GrowingProfile(
                  stack: _stack,
                  request: profile,
                  grow: _grow,
                  child: WatchProfileView(
                    key: ValueKey(profile.key),
                    watchKey: profile.key,
                    card: profile.card,
                    onClose: _closeProfile,
                    onDecide: _closeProfile,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The profile, laid out at full size, scaled and clipped into the card's
/// place, then grown to fill the screen. The card's photo fades into it.
class _GrowingProfile extends StatelessWidget {
  const _GrowingProfile({
    required this.stack,
    required this.request,
    required this.grow,
    required this.child,
  });
  final GlobalKey stack;
  final ProfileRequest request;
  final Animation<double> grow;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final full = Offset.zero & box.biggest;
      final local = stack.currentContext?.findRenderObject() as RenderBox?;
      final from = local == null || !local.hasSize
          ? full
          : Rect.fromPoints(
              local.globalToLocal(request.from.topLeft),
              local.globalToLocal(request.from.bottomRight),
            );
      return AnimatedBuilder(
        animation: grow,
        child: child,
        builder: (context, child) {
          final t = Curves.easeInOutCubic.transform(grow.value);
          final rect = Rect.lerp(from, full, t)!;
          final scale = rect.width / full.width;
          final photo = (1 - t / .45).clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  ignoring: grow.value < 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18 * (1 - t)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: full.width,
                          maxWidth: full.width,
                          minHeight: full.height,
                          maxHeight: full.height,
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topLeft,
                            child: child,
                          ),
                        ),
                        if (photo > 0)
                          IgnorePointer(
                            child: Opacity(
                              opacity: photo,
                              child: WatchPoster(
                                path: request.photoPath,
                                size: request.photoSize,
                                radius: 0,
                                media: request.key.media,
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
    },
  );
}

class LibraryView extends ConsumerWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final now = ref.watch(watchClockProvider)().toUtc();
    return switch (library) {
      AsyncData(:final value) => _Tabs(
        library: value,
        likes: LikesGroups(value.titles, now),
      ),
      AsyncError() => const WatchMessage(
        title: 'The Watchlist could not open',
        body: 'Close it and try again.',
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.library, required this.likes});
  final Library library;
  final LikesGroups likes;

  /// New matches on Likes; nights to check in on, on Planned.
  int _waiting(LibraryTab tab) => switch (tab) {
    LikesTab() => likes.matches.length,
    StatusTab(status: WatchStatus.planned) => likes.checkIn.length,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final tabs = library.tabs;
    return DefaultTabController(
      // Rebuilds when lists are added or removed.
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: palette.ink,
              unselectedLabelColor: palette.muted,
              indicatorColor: palette.accent,
              dividerColor: palette.rule,
              tabs: [
                for (final tab in tabs)
                  Tab(
                    child: Badge(
                      isLabelVisible: _waiting(tab) > 0,
                      label: Text('${_waiting(tab)}'),
                      offset: const Offset(14, -6),
                      child: Text(tab.label),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final tab in tabs)
                  tab is LikesTab
                      ? const LikesTabView()
                      : _LibraryGrid(library: library, likes: likes, tab: tab),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  const _LibraryGrid({
    required this.library,
    required this.likes,
    required this.tab,
  });
  final Library library;
  final LikesGroups likes;
  final LibraryTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final tab = this.tab;
    final nights = tab is StatusTab && tab.status == WatchStatus.planned
        ? likes
        : null;
    final hidden = nights == null
        ? const <String>{}
        : PlannedNights.idsOf(nights);
    final titles = [
      for (final t in library.titlesFor(tab))
        if (!hidden.contains(t.id)) t,
    ];
    final header = switch (tab) {
      ListTab(:final list) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                titles.length == 1 ? '1 title' : '${titles.length} titles',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'List options',
              onSelected: (choice) async {
                final repository = ref.read(watchlistRepositoryProvider);
                if (choice == 'rename') {
                  final name = await askListName(
                    context,
                    title: 'Rename list',
                    initial: list.name,
                  );
                  if (name == null || !context.mounted) return;
                  await runWatchAction(
                    context,
                    () => repository.renameList(list.id, name),
                  );
                } else {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Delete “${list.name}”?'),
                      content: const Text(
                        'The titles stay in your other lists and statuses.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  await runWatchAction(
                    context,
                    () => repository.deleteList(list.id),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete list')),
              ],
            ),
          ],
        ),
      ),
      _ => null,
    };
    final Widget body = titles.isEmpty && hidden.isEmpty
        ? WatchMessage(
            title: _emptyTitle(tab),
            body: _emptyBody(tab),
            artwork: tab is AllTab
                ? const LocalArtwork(
                    assetKey: 'more.watchlist',
                    dimension: 168,
                    highResolution: true,
                  )
                : null,
            action: tab is AllTab
                ? FilledButton.tonalIcon(
                    onPressed: () => context.push(watchSearchLocation),
                    icon: const Icon(Icons.search),
                    label: const Text('Find something'),
                  )
                : null,
          )
        : PosterGrid(
            header: nights == null || hidden.isEmpty
                ? null
                : PlannedNights(likes: nights),
            itemCount: titles.length,
            itemBuilder: (context, i) {
              final title = titles[i];
              return PosterTile(
                key: ValueKey(title.id),
                title: title.title,
                media: title.media,
                posterPath: title.posterPath,
                year: title.year,
                badge: tab is StatusTab ? null : title.status?.label,
                onTap: () => context.push(watchTitleLocation(title.key)),
                onLongPress: () =>
                    showWatchListSheet(context, catalogFromWatchTitle(title)),
              );
            },
          );
    return header == null
        ? body
        : Column(
            children: [
              header,
              Expanded(child: body),
            ],
          );
  }

  static String _emptyTitle(LibraryTab tab) => switch (tab) {
    AllTab() => 'Nothing on your watchlist yet',
    LikesTab() => 'No matches yet',
    StatusTab(:final status) => switch (status) {
      WatchStatus.planned => 'Nothing planned yet',
      WatchStatus.watching => 'Nothing on the go',
      WatchStatus.completed => 'Nothing watched yet',
      WatchStatus.paused => 'Nothing paused',
      WatchStatus.dropped => 'Nothing dropped',
    },
    ListTab() => 'This list is empty',
  };

  static String _emptyBody(LibraryTab tab) => switch (tab) {
    AllTab() => 'Films and shows you want to watch will gather here.',
    LikesTab() => 'Like titles in Discover.',
    ListTab() => 'Open a title and add it to this list.',
    StatusTab() => 'Open a title to give it this status.',
  };
}
