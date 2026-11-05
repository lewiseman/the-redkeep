import 'note_tag_strip.dart';
import 'note_ai_sheet.dart';
import 'note_ai_widgets.dart';
import '../domain/note_tag.dart';
import '../domain/note_document.dart';
import '../../recall/application/recall_search.dart';
import '../../ai/application/ai_lifecycle.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/rendering_policy.dart';
import 'notes_collection_widgets.dart';
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
  final _scroll = ScrollController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(notesFilterProvider).search;
  }

  @override
  void dispose() {
    _scroll.dispose();
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

  /// Special collections share the tag strip; selecting any chip replaces
  /// the current collection rather than stacking filters.
  void _collection(String value) {
    ref
        .read(notesDraftsOnlyProvider.notifier)
        .set(value == NoteTagStrip.drafts);
    final special =
        value == NoteTagStrip.all ||
        value == NoteTagStrip.drafts ||
        value == NoteTagStrip.pinned ||
        value == NoteTagStrip.trash;
    _filter(
      tag: special ? null : value,
      clearTag: special,
      pinned: value == NoteTagStrip.pinned,
      trash: value == NoteTagStrip.trash,
    );
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
    final colors = Theme.of(context).colorScheme;
    final screenPadding = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Center(
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
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverFloatingHeader(
                    snapMode: FloatingHeaderSnapMode.overlay,
                    animationStyle: AnimationStyle(
                      duration: policy.duration,
                      reverseDuration: policy.duration,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeOutCubic,
                    ),
                    child: AnimatedBuilder(
                      animation: _scroll,
                      builder: (context, child) {
                        final raised = _scroll.hasClients
                            ? (_scroll.offset / 72).clamp(0.0, 1.0)
                            : 0.0;
                        final horizontal = 30.0 - 12.0 * raised;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colors.surface.withValues(alpha: raised),
                                colors.surface.withValues(alpha: .85 * raised),
                                colors.surface.withValues(alpha: 0),
                              ],
                              stops: const [0, .5, 1],
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              screenPadding.top + 12,
                              horizontal,
                              6,
                            ),
                            child: Material(
                              elevation: policy.simplerEffects ? 0 : 8 * raised,
                              color: Color.lerp(
                                colors.surfaceContainerLow,
                                colors.surfaceContainerHigh,
                                raised,
                              ),
                              shadowColor: colors.shadow.withValues(alpha: .2),
                              borderRadius: BorderRadius.circular(999),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: TextField(
                        key: const ValueKey('notes-search'),
                        controller: _search,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontSize: 14),
                        maxLength: 256,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        onChanged: (value) => _filter(search: value),
                        decoration: InputDecoration(
                          hintText: filter.trash
                              ? 'Search Trash…'
                              : 'Search notes…',
                          counterText: '',
                          hintStyle: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: colors.primary,
                            size: 22,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          suffixIcon: filter.search.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _search.clear();
                                    _filter(search: '');
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: colors.onSurfaceVariant,
                                    size: 18,
                                  ),
                                ),
                          filled: false,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(color: colors.primary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: NoteTagStrip(
                      tags: [
                        (emoji: '🗂️', name: 'All', value: NoteTagStrip.all),
                        (
                          emoji: '📝',
                          name: 'Drafts',
                          value: NoteTagStrip.drafts,
                        ),
                        (
                          emoji: '📌',
                          name: 'Pinned',
                          value: NoteTagStrip.pinned,
                        ),
                        (
                          emoji: '🗑️',
                          name: 'Trash',
                          value: NoteTagStrip.trash,
                        ),
                        for (final raw in {
                          ...?tags.value,
                          if (filter.tag != null) filter.tag!,
                        })
                          (
                            emoji: NoteTag.tryParse(raw)?.emoji ?? '',
                            name: NoteTag.tryParse(raw)?.name ?? raw,
                            value: raw,
                          ),
                      ],
                      selectedTag: drafts
                          ? NoteTagStrip.drafts
                          : filter.trash
                          ? NoteTagStrip.trash
                          : filter.tag ??
                                (filter.pinnedOnly
                                    ? NoteTagStrip.pinned
                                    : NoteTagStrip.all),
                      isLoading: tags.isLoading,
                      onSelected: _collection,
                    ),
                  ),
                  if (meaning?.message case final message?)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text(
                          message,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  if (!filter.trash)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow =
                                MediaQuery.sizeOf(context).width < 350 ||
                                MediaQuery.textScalerOf(context).scale(14) > 20;
                            final ideas = NoteAiToolCard(
                              key: const ValueKey('notes-assistant-ideas'),
                              tool: NoteAiTool.ideas,
                              horizontal: narrow,
                              onTap: _ideas,
                            );
                            final search = NoteAiToolCard(
                              key: const ValueKey('notes-assistant-search'),
                              tool: NoteAiTool.search,
                              horizontal: narrow,
                              onTap: () => context.push('/notes/ai-search'),
                            );
                            return narrow
                                ? Column(
                                    children: [
                                      ideas,
                                      const SizedBox(height: 10),
                                      search,
                                    ],
                                  )
                                : IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: ideas),
                                        const SizedBox(width: 10),
                                        Expanded(child: search),
                                      ],
                                    ),
                                  );
                          },
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
                          onTap: () => ref.invalidate(notesCollectionProvider),
                        ),
                      ),
                    ],
                    data: (items) => [
                      if (items.isEmpty &&
                          !drafts &&
                          !filter.trash &&
                          filter.search.isEmpty &&
                          filter.tag == null &&
                          !filter.pinnedOnly)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
                              // Unkeyed on purpose: keyed cards are moved
                              // with stale masonry layout when notes reorder,
                              // leaving gaps in a column.
                              return NoteCard(
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
      floatingActionButton: NoteAddButton(
        key: const ValueKey('notes-add-button'),
        onPressed: busy ? null : _create,
      ),
    );
  }

  Future<void> _ideas() async {
    final idea = await showNoteIdeas(context);
    if (idea == null || !mounted) return;
    final id = await ref.read(notesActionsProvider.notifier).create();
    if (id == null) return;
    await ref
        .read(notesRepositoryProvider)
        .putDraft(
          id: id,
          text: PlainTextDocument(title: idea),
          baseRevision: 0,
          expectedDraftRevision: null,
        );
    if (mounted) context.go(noteLocation(id, edit: true));
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
      if (mounted && id != null) context.go(noteLocation(id, edit: true));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The editor could not be opened. Try again.');
      }
    }
  }
}
