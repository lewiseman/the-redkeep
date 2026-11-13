import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../assets/presentation/local_artwork.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/discover_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/watch_title.dart';
import 'discover_view.dart';
import 'explore_view.dart';
import 'likes_view.dart';
import 'watch_list_sheet.dart';
import 'watch_widgets.dart';

enum WatchSection { discover, explore, library, likes }

/// The Watchlist, opened from More: Discover, the Library, and Likes.
class WatchlistPage extends ConsumerStatefulWidget {
  const WatchlistPage({super.key});

  @override
  ConsumerState<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends ConsumerState<WatchlistPage> {
  var _section = WatchSection.library;

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
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: watchAppBar(
        context,
        title: switch (_section) {
          WatchSection.discover => 'Discover',
          WatchSection.explore => 'Explore',
          WatchSection.library => 'Watchlist',
          WatchSection.likes => 'Likes',
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
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: switch (_section) {
          WatchSection.discover => const DiscoverView(),
          WatchSection.explore => const ExploreView(),
          WatchSection.library => const LibraryView(),
          WatchSection.likes => const LikesView(),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section.index,
        backgroundColor: palette.ground,
        indicatorColor: palette.cloth,
        labelBehavior: MediaQuery.textScalerOf(context).scale(14) > 24
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) =>
            setState(() => _section = WatchSection.values[i]),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Discover',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          const NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: waiting > 0,
              label: Text('$waiting'),
              child: const Icon(Icons.favorite_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: waiting > 0,
              label: Text('$waiting'),
              child: const Icon(Icons.favorite),
            ),
            label: 'Likes',
          ),
        ],
      ),
    );
  }
}

class LibraryView extends ConsumerWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    return switch (library) {
      AsyncData(:final value) => _Tabs(library: value),
      AsyncError() => const WatchMessage(
        title: 'The Watchlist could not open',
        body: 'Close it and try again.',
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.library});
  final Library library;

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
              tabs: [for (final tab in tabs) Tab(text: tab.label)],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final tab in tabs)
                  _LibraryGrid(library: library, tab: tab),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  const _LibraryGrid({required this.library, required this.tab});
  final Library library;
  final LibraryTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final titles = library.titlesFor(tab);
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
    final Widget body = titles.isEmpty
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
    ListTab() => 'Open a title and add it to this list.',
    StatusTab() => 'Open a title to give it this status.',
  };
}
