import '../../recall/application/recall_search.dart';
import '../../ai/application/ai_lifecycle.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../assets/presentation/local_artwork.dart';
import '../application/notes_providers.dart';
import '../domain/notes_query.dart';
import 'note_card.dart';

class NotesListPage extends ConsumerStatefulWidget {
  const NotesListPage({super.key});
  @override
  ConsumerState<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends ConsumerState<NotesListPage> {
  final _search = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(notesFilterProvider).search;
  }

  @override
  void dispose() {
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

  void _collection({String? tag, bool drafts = false}) {
    ref.read(notesDraftsOnlyProvider.notifier).set(drafts);
    _filter(tag: tag, clearTag: tag == null, trash: drafts ? false : null);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(notesHybridCollectionProvider);
    final filter = ref.watch(notesFilterProvider);
    final drafts = ref.watch(notesDraftsOnlyProvider);
    final tags = ref.watch(noteTagsProvider);
    final busy = ref.watch(notesActionsProvider);
    final policy = RenderingPolicyScope.of(context);
    final meaning =
        ref.watch(aiEnabledProvider) &&
            filter.search.isNotEmpty &&
            !filter.trash &&
            !drafts
        ? ref
              .watch(recallSearchProvider((query: filter.search, kind: 'note')))
              .value
        : null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final columns = constraints.maxWidth < 300 || scale > 1.4
                    ? (constraints.maxWidth >= 650 ? 2 : 1)
                    : (constraints.maxWidth >= 700 ? 3 : 2);
                return CustomScrollView(
                  key: const PageStorageKey('notes-collection'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverFloatingHeader(
                      animationStyle: AnimationStyle(
                        duration: policy.duration,
                        reverseDuration: policy.duration,
                      ),
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                          child: TextField(
                            key: const ValueKey('notes-search'),
                            controller: _search,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontSize: 14),
                            maxLength: 256,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            onChanged: (value) => _filter(search: value),
                            decoration: InputDecoration(
                              hintText: filter.trash
                                  ? 'Search Trash…'
                                  : 'Search notes…',
                              counterText: '',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (meaning?.message case final message?)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        message,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  if (filter.search.isNotEmpty)
                                    IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        _search.clear();
                                        _filter(search: '');
                                      },
                                    ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Collection options',
                                    icon: const Icon(Icons.tune_rounded),
                                    onSelected: (value) {
                                      if (value == 'pin') {
                                        _filter(pinned: !filter.pinnedOnly);
                                      }
                                      if (value == 'trash') {
                                        ref
                                            .read(
                                              notesDraftsOnlyProvider.notifier,
                                            )
                                            .set(false);
                                        _filter(trash: !filter.trash);
                                      }
                                      if (value == 'clear') {
                                        _search.clear();
                                        ref
                                            .read(
                                              notesDraftsOnlyProvider.notifier,
                                            )
                                            .set(false);
                                        ref
                                            .read(notesFilterProvider.notifier)
                                            .set(const NotesQuery());
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      CheckedPopupMenuItem(
                                        value: 'pin',
                                        checked: filter.pinnedOnly,
                                        child: const Text('Pinned only'),
                                      ),
                                      CheckedPopupMenuItem(
                                        value: 'trash',
                                        checked: filter.trash,
                                        child: const Text('Trash'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'clear',
                                        child: Text('Clear filters'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                        child: Row(
                          children: [
                            _chip(
                              'All',
                              key: 'notes-all',
                              selected: !drafts && filter.tag == null,
                              onTap: () => _collection(),
                            ),
                            _chip(
                              'Drafts',
                              key: 'notes-drafts',
                              selected: drafts,
                              onTap: () => _collection(drafts: true),
                            ),
                            for (final tag in {
                              ...?tags.value,
                              if (filter.tag != null) filter.tag!,
                            })
                              _chip(
                                tag,
                                key: 'notes-tag-$tag',
                                selected: !drafts && filter.tag == tag,
                                onTap: () => _collection(tag: tag),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (filter.trash || filter.pinnedOnly)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          child: Text(
                            [
                              if (filter.trash) 'Trash',
                              if (filter.pinnedOnly) 'Pinned only',
                            ].join(' • '),
                          ),
                        ),
                      ),
                    if (tags.hasError)
                      SliverToBoxAdapter(
                        child: TextButton(
                          onPressed: () => ref.invalidate(noteTagsProvider),
                          child: const Text('Retry tags'),
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
                        if (items.isEmpty)
                          SliverToBoxAdapter(
                            child: _message(
                              drafts
                                  ? 'No drafts yet.'
                                  : filter.trash
                                  ? 'Trash is empty.'
                                  : filter.search.isNotEmpty ||
                                        filter.tag != null ||
                                        filter.pinnedOnly
                                  ? 'No notes match these filters.'
                                  : 'A little room for your thoughts',
                              action:
                                  drafts ||
                                      filter.trash ||
                                      filter.search.isNotEmpty ||
                                      filter.tag != null ||
                                      filter.pinnedOnly
                                  ? 'Show all notes'
                                  : 'Create note',
                              onTap: () {
                                if (!drafts &&
                                    !filter.trash &&
                                    filter.search.isEmpty &&
                                    filter.tag == null &&
                                    !filter.pinnedOnly) {
                                  _create();
                                } else {
                                  _search.clear();
                                  ref
                                      .read(notesDraftsOnlyProvider.notifier)
                                      .set(false);
                                  ref
                                      .read(notesFilterProvider.notifier)
                                      .set(const NotesQuery());
                                }
                              },
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            sliver: SliverMasonryGrid.count(
                              crossAxisCount: columns,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childCount: items.length,
                              itemBuilder: (context, index) {
                                final entry = items[index];
                                return NoteCard(
                                  key: ValueKey(entry.id),
                                  entry: entry,
                                  index: index,
                                  onTap: () => context.go(
                                    noteLocation(entry.id, edit: entry.isDraft),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 112)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: Tooltip(
        message: 'Create note',
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: 'Create note',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: busy ? null : _create,
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox.square(
                dimension: 72,
                child: Center(
                  child: LocalArtwork(assetKey: 'notes.add', dimension: 64),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(
    String label, {
    required String key,
    required bool selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 6),
    child: ChoiceChip(
      key: ValueKey(key),
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      showCheckmark: false,
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      shape: const StadiumBorder(),
      onSelected: (_) => onTap(),
    ),
  );

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
      if (mounted && id != null) context.go(noteLocation(id, edit: true));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The editor could not be opened. Try again.');
      }
    }
  }
}
