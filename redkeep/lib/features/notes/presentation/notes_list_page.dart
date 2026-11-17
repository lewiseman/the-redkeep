import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../app/writing_shell.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../application/notes_providers.dart';
import '../domain/notes_query.dart';
import 'note_card.dart';
import 'notes_collection_sheet.dart';
import 'notes_collection_widgets.dart';
import 'notes_search_dock.dart';

class NotesListPage extends ConsumerStatefulWidget {
  const NotesListPage({super.key});
  @override
  ConsumerState<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends ConsumerState<NotesListPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'notes-search');
  final _scroll = ScrollController();
  String? _error;
  final _navbarHidden = ValueNotifier(false);
  static const _navbarTravel = 24.0;
  double _scrollTravel = 0;

  /// Typing only rebuilds the dock; the query (and the collection behind it)
  /// follows once typing pauses.
  static const _searchDelay = Duration(milliseconds: 160);
  Timer? _searchDebounce;

  void _setNavbarHidden(bool hidden) {
    if (hidden == _navbarHidden.value) return;
    _navbarHidden.value = hidden;
    BottomNavbarVisibilityNotification(hidden: hidden).dispatch(context);
  }

  /// Reading down the collection slides the bar away; scrolling back up, the
  /// top of the list, or a list too short to scroll brings it back. A short
  /// run of travel in one direction ignores jitter at the end of a swipe.
  bool _scrolled(ScrollUpdateNotification notification) {
    final metrics = notification.metrics;
    final delta = notification.scrollDelta ?? 0;
    if (notification.depth != 0 || metrics.axis != Axis.vertical) {
      return false;
    }
    if (metrics.maxScrollExtent <= 0 ||
        metrics.pixels <= metrics.minScrollExtent) {
      _scrollTravel = 0;
      _setNavbarHidden(false);
      return false;
    }
    if (delta == 0) return false;
    _scrollTravel =
        (_scrollTravel.sign == delta.sign ? _scrollTravel : 0) + delta;
    if (_scrollTravel > _navbarTravel) {
      _setNavbarHidden(true);
    } else if (_scrollTravel < -_navbarTravel) {
      _setNavbarHidden(false);
    }
    return false;
  }

  bool _metricsChanged(ScrollMetricsNotification notification) {
    final metrics = notification.metrics;
    if (notification.depth == 0 &&
        metrics.axis == Axis.vertical &&
        metrics.maxScrollExtent <= 0) {
      _setNavbarHidden(false);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(notesFilterProvider).search;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _navbarHidden.dispose();
    _scroll.dispose();
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  void _filter({
    String? search,
    String? tag,
    bool clearTag = false,
    bool? pinned,
    bool? trash,
  }) {
    final old = ref.read(notesFilterProvider);
    ref
        .read(notesFilterProvider.notifier)
        .set(
          NotesQuery(
            search: search ?? old.search,
            tag: clearTag ? null : tag ?? old.tag,
            pinnedOnly: pinned ?? old.pinnedOnly,
            trash: trash ?? old.trash,
          ),
        );
  }

  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDelay, () => _filter(search: value));
  }

  /// Applies typing still waiting on the debounce, so other filter changes
  /// never undo it.
  void _flushSearch() {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
      _filter(search: _search.text);
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _search.clear();
    _filter(search: '');
  }

  void _submitSearch(String _) {
    _flushSearch();
    _searchFocus.unfocus();
  }

  /// Collections replace each other rather than stacking filters.
  void _collection(String value) {
    _flushSearch();
    _filter(
      tag: NoteCollection.isBuiltIn(value) ? null : value,
      clearTag: NoteCollection.isBuiltIn(value),
      pinned: value == NoteCollection.pinned,
      trash: value == NoteCollection.trash,
    );
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _openCollections() async {
    _searchFocus.unfocus();
    final value = await showNoteCollectionSheet(context);
    if (mounted && value != null) _collection(value);
  }

  void _showAll() {
    _searchDebounce?.cancel();
    _search.clear();
    ref.read(notesFilterProvider.notifier).set(const NotesQuery());
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(notesCollectionProvider);
    final filter = ref.watch(notesFilterProvider);
    final busy = ref.watch(notesActionsProvider);
    // Keep the tag list warm for the collections sheet without rebuilding
    // the page when it changes.
    ref.listen(noteTagsProvider, (_, _) {});
    final colors = Theme.of(context).colorScheme;
    final screenPadding = MediaQuery.paddingOf(context);
    final collection = NoteCollection.option(NoteCollection.of(filter));
    final filtered =
        filter.trash ||
        filter.search.isNotEmpty ||
        filter.tag != null ||
        filter.pinnedOnly;
    return Scaffold(
      // The dock follows the keyboard on its own; the collection keeps its
      // size instead of relaying out on every frame of the keyboard.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    final columns = constraints.maxWidth < 300 || scale > 1.4
                        ? (constraints.maxWidth >= 650 ? 2 : 1)
                        : (constraints.maxWidth >= 700 ? 3 : 2);
                    return NotificationListener<ScrollMetricsNotification>(
                      onNotification: _metricsChanged,
                      child: NotificationListener<ScrollUpdateNotification>(
                        onNotification: _scrolled,
                        child: CustomScrollView(
                          key: const PageStorageKey('notes-collection'),
                          controller: _scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          slivers: [
                            SliverToBoxAdapter(
                              child: _CollectionHeader(
                                collection: collection,
                                count: entries.value?.length,
                                search: filter.search.trim(),
                                top: screenPadding.top,
                                onTap: _openCollections,
                                onShowAll:
                                    collection.value == NoteCollection.all
                                    ? null
                                    : () => _collection(NoteCollection.all),
                              ),
                            ),
                            if (_error != null)
                              SliverToBoxAdapter(
                                child: Semantics(
                                  liveRegion: true,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(_error!),
                                  ),
                                ),
                              ),
                            ...entries.when(
                              loading: () => [
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.all(72),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        semanticsLabel: 'Loading notes',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              error: (_, _) => [
                                SliverToBoxAdapter(
                                  child: _message(
                                    'Notes could not be loaded.',
                                    action: 'Retry loading',
                                    onTap: () =>
                                        ref.invalidate(notesCollectionProvider),
                                  ),
                                ),
                              ],
                              data: (items) => [
                                if (items.isEmpty && !filtered)
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      6,
                                      12,
                                      0,
                                    ),
                                    sliver: SliverMasonryGrid.count(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childCount: 1,
                                      itemBuilder: (_, _) =>
                                          NoteFirstCard(onTap: _create),
                                    ),
                                  )
                                else if (items.isEmpty)
                                  SliverToBoxAdapter(
                                    child: _message(
                                      filter.trash && filter.search.isEmpty
                                          ? 'Trash is empty.'
                                          : 'No notes match these filters.',
                                      action: 'Show all notes',
                                      onTap: _showAll,
                                    ),
                                  )
                                else
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      6,
                                      12,
                                      0,
                                    ),
                                    sliver: SliverMasonryGrid.count(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childCount: items.length,
                                      itemBuilder: (context, index) {
                                        final entry = items[index];
                                        // Unkeyed on purpose: keyed cards are
                                        // moved with stale masonry layout when
                                        // notes reorder, leaving gaps in a
                                        // column.
                                        return NoteCard(
                                          entry: entry,
                                          index: index,
                                          // A note with a website opens on it.
                                          onTap: () => context.go(
                                            entry.hasWebsite &&
                                                    !ref
                                                        .read(
                                                          notesFilterProvider,
                                                        )
                                                        .trash
                                                ? noteWebsiteLocation(entry.id)
                                                : noteLocation(entry.id),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                            // The dock and the floating bar overlay the list;
                            // keep room above them.
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height:
                                    NotesSearchDock.height +
                                    28 +
                                    _DockSlot._navbarGap +
                                    screenPadding.bottom,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Plain gradients, not blurs: cards fade under the status bar and
          // the controls without an offscreen pass while scrolling.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenPadding.top + 10,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.surface,
                      colors.surface.withValues(alpha: .9),
                      colors.surface.withValues(alpha: 0),
                    ],
                    stops: const [0, .6, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height:
                screenPadding.bottom +
                NotesSearchDock.height +
                28 +
                _DockSlot._navbarGap,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.surface.withValues(alpha: 0),
                      colors.surface.withValues(alpha: .82),
                      colors.surface.withValues(alpha: .96),
                    ],
                    stops: const [0, .45, 1],
                  ),
                ),
              ),
            ),
          ),
          _DockSlot(
            navbarHidden: _navbarHidden,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: RepaintBoundary(
                    child: NotesSearchDock(
                      controller: _search,
                      focusNode: _searchFocus,
                      collection: collection,
                      onCollections: _openCollections,
                      onChanged: _searchChanged,
                      onSubmitted: _submitSearch,
                      onClear: _clearSearch,
                      addButton: NoteAddButton(
                        key: const ValueKey('notes-add-button'),
                        onPressed: busy ? null : _create,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(
    String title, {
    required String action,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Column(
      children: [
        Icon(
          Icons.notes_rounded,
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onTap,
          child: Text(action, textAlign: TextAlign.center),
        ),
      ],
    ),
  );

  Future<void> _create() async {
    try {
      final id = await ref.read(notesActionsProvider.notifier).create();
      if (mounted && id != null) context.go(noteLocation(id));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The editor could not be opened. Try again.');
      }
    }
  }
}

/// Names what the page is showing and how much of it, so the controls can
/// live at the bottom without the page losing its context.
class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.collection,
    required this.count,
    required this.search,
    required this.top,
    required this.onTap,
    required this.onShowAll,
  });

  final NoteCollectionOption collection;
  final int? count;
  final String search;
  final double top;
  final VoidCallback onTap;
  final VoidCallback? onShowAll;

  String get _summary {
    final count = this.count;
    if (count == null) return ' ';
    if (search.isNotEmpty) {
      return '$count ${count == 1 ? 'match' : 'matches'} for “$search”';
    }
    final notes = count == 1 ? 'note' : 'notes';
    return switch (collection.value) {
      NoteCollection.trash => '$count $notes · restore or delete for good',
      NoteCollection.pinned => '$count pinned $notes',
      _ => '$count $notes',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final all = collection.value == NoteCollection.all;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, top + 14, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              header: true,
              label: all ? 'Notes' : collection.name,
              hint: 'Change collection',
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('notes-header'),
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!all) ...[
                            Text(
                              collection.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              all ? 'Notes' : collection.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.4,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onShowAll != null)
            IconButton(
              key: const ValueKey('notes-show-all'),
              tooltip: 'Show all notes',
              onPressed: onShowAll,
              icon: Icon(Icons.close_rounded, color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// Holds the dock just above the floating bar, follows the bar down when it
/// slides away, and rides on top of the keyboard while searching.
class _DockSlot extends StatelessWidget {
  const _DockSlot({required this.navbarHidden, required this.child});

  /// Extra breathing room between the dock and the bar while the bar shows.
  static const _navbarGap = 10.0;

  final ValueListenable<bool> navbarHidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // The shell's bar consumes the bottom safe area above this page; read the
    // window's own inset so the dock clears the gesture handle once the bar
    // has slid away.
    final view = View.of(context);
    final system = math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      view.viewPadding.bottom / view.devicePixelRatio,
    );
    final navbar = (MediaQuery.paddingOf(context).bottom - system).clamp(
      0.0,
      double.infinity,
    );
    return ValueListenableBuilder<bool>(
      valueListenable: navbarHidden,
      child: child,
      builder: (context, hidden, child) => TweenAnimationBuilder<double>(
        tween: Tween<double>(
          end: hidden || keyboard > 0 ? 0 : navbar + _navbarGap,
        ),
        // The keyboard moves the dock itself; only the bar's slide animates.
        duration: policy.animate && keyboard <= 0
            ? Duration(milliseconds: hidden ? 220 : 260)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        child: child,
        builder: (context, lift, child) => Positioned(
          left: 0,
          right: 0,
          bottom: math.max(keyboard, system) + 2 + lift,
          child: child!,
        ),
      ),
    );
  }
}
