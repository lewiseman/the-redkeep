import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/watchlist_providers.dart';
import '../domain/watch_title.dart';
import 'watch_header.dart';
import 'watch_list_sheet.dart';
import 'watch_spin.dart';
import 'watch_wall.dart';
import 'watch_widgets.dart';

/// The Watchlist, opened from More: a wall of polaroids, stamped as they
/// are watched, kept by Tyrion, who picks one when asked. Every filter and
/// search sit in a cushion under the thumb.
class WatchlistPage extends ConsumerStatefulWidget {
  const WatchlistPage({super.key});

  @override
  ConsumerState<WatchlistPage> createState() => _WatchlistPageState();
}

/// `all`, `status:<name>` or `list:<id>`, so a filter survives its list
/// being renamed.
String _filterId(LibraryTab tab) => switch (tab) {
  AllTab() => 'all',
  StatusTab(:final status) => 'status:${status.name}',
  ListTab(:final list) => 'list:${list.id}',
};

class _WatchlistPageState extends ConsumerState<WatchlistPage> {
  String _filter = 'all';

  void _select(LibraryTab tab) {
    final id = _filterId(tab);
    if (id == _filter) return;
    setState(() => _filter = id);
  }

  /// Tyrion only ever offers one thing: to pick something to watch. With
  /// fewer than two titles there is nothing to pick between, so he is quiet.
  String? _ask(List<WatchTitle> everything, List<WatchTitle> pool) {
    if (pool.length < 2) return null;
    final open = everything.where(
      (t) =>
          t.status != WatchStatus.completed && t.status != WatchStatus.dropped,
    );
    return open.length > 1
        ? 'Can’t choose? Tap me and I’ll pick one.'
        : 'Fancy a rewatch? Tap me and I’ll pick one.';
  }

  Future<void> _newList() async {
    final name = await askListName(context);
    if (name == null || !mounted) return;
    final id = await runWatchAction(
      context,
      () => ref.read(watchlistRepositoryProvider).createList(name),
    );
    if (id != null && mounted) setState(() => _filter = 'list:$id');
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final library = ref.watch(libraryProvider);
    final value = library.value;
    final tab = value == null
        ? const AllTab()
        : value.tabs.firstWhere(
            (t) => _filterId(t) == _filter,
            orElse: () => const AllTab(),
          );
    final everything = value?.titlesFor(const AllTab()) ?? const [];
    final pool = spinPool(everything);
    return Scaffold(
      backgroundColor: palette.ground,
      extendBody: true,
      body: switch (library) {
        AsyncError() => Column(
          children: [
            watchAppBar(context, title: 'Watchlist'),
            const Expanded(
              child: WatchMessage(
                title: 'The Watchlist could not open',
                body: 'Close it and try again.',
              ),
            ),
          ],
        ),
        // The header is up from the first frame, so Tyrion has somewhere
        // to land when he flies in from More.
        _ => _Wall(
          library: value,
          tab: tab,
          ask: _ask(everything, pool),
          onAsk: () => showWatchSpin(context, pool),
        ),
      },
      bottomNavigationBar: value == null
          ? null
          : _Dock(
              library: value,
              selected: _filterId(tab),
              onSelect: _select,
              onNewList: _newList,
            ),
    );
  }
}

class _Wall extends ConsumerWidget {
  const _Wall({
    required this.library,
    required this.tab,
    required this.ask,
    required this.onAsk,
  });

  /// Null while the wall is still loading: only the header shows.
  final Library? library;
  final LibraryTab tab;
  final String? ask;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = this.library;
    final everything = library?.titlesFor(const AllTab()) ?? const [];
    final titles = library?.titlesFor(tab) ?? const [];
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(1).clamp(1.0, 1.6);
    final filter = _filterId(tab);

    final metrics = WallHeaderMetrics.of(context, ask: ask);
    final animate = RenderingPolicyScope.of(context).animate;
    // Let go halfway and the header eases open or shut, never stuck between.
    return NotificationListener<ScrollEndNotification>(
      onNotification: (end) {
        final position = Scrollable.maybeOf(end.context!)?.position;
        final travel = metrics.travel;
        final at = end.metrics.pixels;
        if (!animate || position == null || at <= 0 || at >= travel) {
          return false;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!position.hasPixels) return;
          position.animateTo(
            at < travel / 2 ? 0 : travel,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        });
        return false;
      },
      child: CustomScrollView(
        key: const PageStorageKey('watchlist-wall'),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: WallHeaderDelegate(
              metrics: metrics,
              ask: ask,
              onAsk: ask == null ? null : onAsk,
            ),
          ),
          if (library == null)
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else if (everything.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: 80 * scale),
                child: WatchMessage(
                  title: 'Nothing on your watchlist yet',
                  body: 'Films and shows you want to watch will gather here.',
                  action: FilledButton.tonalIcon(
                    onPressed: () => context.push(watchSearchLocation),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text('Find something'),
                  ),
                ),
              ),
            )
          else ...[
            if (titles.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: WatchMessage(
                    title: _emptyTitle(tab),
                    body: _emptyBody(tab),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) => SliverMasonryGrid.count(
                    crossAxisCount: wallColumns(
                      context,
                      constraints.crossAxisExtent,
                    ),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 18,
                    childCount: titles.length,
                    itemBuilder: (context, i) {
                      final title = titles[i];
                      return WallEntrance(
                        key: ValueKey('$filter/${title.id}'),
                        index: i,
                        child: WallPolaroid(
                          title: title,
                          doubleTapLabel: title.status == WatchStatus.completed
                              ? 'Take off the watched stamp'
                              : 'Stamp watched',
                          onTap: () =>
                              context.push(watchTitleLocation(title.key)),
                          onDoubleTap: () => _stamp(context, ref, title),
                          onLongPress: () => showWatchListSheet(
                            context,
                            catalogFromWatchTitle(title),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
          // Room to scroll the last row clear of the dock.
          SliverToBoxAdapter(
            child: SizedBox(height: 110 * scale + media.padding.bottom),
          ),
        ],
      ),
    );
  }

  /// Stamps a title watched, or lifts the stamp off again.
  static Future<void> _stamp(
    BuildContext context,
    WidgetRef ref,
    WatchTitle title,
  ) async {
    final repository = ref.read(watchlistRepositoryProvider);
    final catalog = catalogFromWatchTitle(title);
    final before = title.status;
    final lifting = before == WatchStatus.completed;
    HapticFeedback.heavyImpact();
    final messenger = ScaffoldMessenger.of(context);
    final done = await runWatchAction(
      context,
      () => repository.setStatus(
        catalog,
        lifting ? WatchStatus.planned : WatchStatus.completed,
      ),
    );
    if (done == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            lifting
                ? '${title.title} is back on the to-see pile'
                : 'Stamped ${title.title} watched',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repository
                .setStatus(catalog, before)
                .then<void>(
                  (_) {},
                  onError: (Object error) => messenger.showSnackBar(
                    SnackBar(content: Text(watchErrorText(error))),
                  ),
                ),
          ),
        ),
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

/// Rename or delete one of the reader's lists, from a sheet within reach.
Future<void> showListOptions(
  BuildContext context,
  WidgetRef ref,
  WatchList list,
) async {
  HapticFeedback.mediumImpact();
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              list.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete list'),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final repository = ref.read(watchlistRepositoryProvider);
  if (choice == 'rename') {
    final name = await askListName(
      context,
      title: 'Rename list',
      initial: list.name,
    );
    if (name == null || !context.mounted) return;
    await runWatchAction(context, () => repository.renameList(list.id, name));
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete “${list.name}”?'),
      content: const Text('The titles stay in your other lists and statuses.'),
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
  await runWatchAction(context, () => repository.deleteList(list.id));
}

/// A stitched cushion under the thumb, like the app's own bar: filters as
/// glass beads, then search.
class _Dock extends ConsumerStatefulWidget {
  const _Dock({
    required this.library,
    required this.selected,
    required this.onSelect,
    required this.onNewList,
  });

  final Library library;
  final String selected;
  final ValueChanged<LibraryTab> onSelect;
  final VoidCallback onNewList;

  @override
  ConsumerState<_Dock> createState() => _DockState();
}

class _DockState extends ConsumerState<_Dock> {
  final _keys = <String, GlobalKey>{};

  @override
  void didUpdateWidget(_Dock old) {
    super.didUpdateWidget(old);
    if (old.selected == widget.selected) return;
    // Bring the chosen filter into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[widget.selected]?.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: .5,
        duration: RenderingPolicyScope.of(context).duration * 2,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final library = widget.library;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final bead = 48 * scale;
    // Statuses with nothing in them stay out of the way.
    final tabs = [
      for (final tab in library.tabs)
        if (tab is! StatusTab ||
            library.titlesFor(tab).isNotEmpty ||
            _filterId(tab) == widget.selected)
          tab,
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: CustomPaint(
            painter: CushionPainter(colors: cushion, radius: bead / 2 + 9),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: bead,
                      // The row fades at its end, hinting there is more.
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0, .88, 1],
                        ).createShader(bounds),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 24),
                          children: [
                            for (final tab in tabs)
                              WatchFilterPill(
                                key: _keys.putIfAbsent(
                                  _filterId(tab),
                                  GlobalKey.new,
                                ),
                                label: tab.label,
                                icon: tab is ListTab
                                    ? Icons.bookmarks_outlined
                                    : null,
                                selected: _filterId(tab) == widget.selected,
                                onTap: () => widget.onSelect(tab),
                                onLongPress: tab is ListTab
                                    ? () => showListOptions(
                                        context,
                                        ref,
                                        tab.list,
                                      )
                                    : null,
                              ),
                            Tooltip(
                              message: 'New list',
                              excludeFromSemantics: true,
                              child: WatchFilterPill(
                                label: '',
                                icon: Icons.add_rounded,
                                selected: false,
                                semanticLabel: 'New list',
                                onTap: widget.onNewList,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _Bead(
                    size: bead,
                    icon: Icons.search_rounded,
                    label: 'Search films and shows',
                    fill: .92,
                    onTap: () => context.push(watchSearchLocation),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ink that reads on glass of [fill] over the cushion.
Color _inkOnGlass(CushionColors cushion, double fill) {
  final body = Color.lerp(cushion.paper, cushion.tint, fill)!;
  return ThemeData.estimateBrightnessForColor(body) == Brightness.dark
      ? Colors.white
      : cushion.ink;
}

/// A round glass bead that sinks under the finger.
class _Bead extends StatelessWidget {
  const _Bead({
    required this.size,
    required this.icon,
    required this.label,
    required this.fill,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final String label;
  final double fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Springy(
            depth: .12,
            child: CustomPaint(
              size: Size.square(size),
              painter: _GlassPainter(cushion, fill),
              child: SizedBox.square(
                dimension: size,
                child: Icon(icon, color: _inkOnGlass(cushion, fill), size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter(this.colors, this.fill);
  final CushionColors colors;
  final double fill;

  @override
  void paint(Canvas canvas, Size size) => paintGlass(
    canvas,
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide / 2),
    ),
    colors: colors,
    tint: colors.tint,
    fill: fill,
    lift: .8,
  );

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.colors != colors || old.fill != fill;
}

/// One filter in the dock: plain words, or a glass bead when chosen.
class WatchFilterPill extends StatelessWidget {
  const WatchFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onLongPress,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final policy = RenderingPolicyScope.of(context);
    final ink = selected
        ? _inkOnGlass(cushion, .9)
        : cushion.ink.withValues(alpha: .78);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 12 : 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, size: 19, color: ink),
            if (icon != null && label.isNotEmpty) const SizedBox(width: 6),
            if (label.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress,
        child: Springy(
          depth: .08,
          child: AnimatedSwitcher(
            duration: policy.duration,
            child: CustomPaint(
              key: ValueKey(selected),
              painter: selected ? _GlassPainter(cushion, .9) : null,
              child: Center(widthFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
