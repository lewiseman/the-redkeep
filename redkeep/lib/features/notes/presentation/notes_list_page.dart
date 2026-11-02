import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/paper_surface.dart';
import '../application/notes_providers.dart';
import '../domain/note_document.dart';
import '../domain/notes_query.dart';
import '../../assets/presentation/local_artwork.dart';

class NotesListPage extends ConsumerStatefulWidget {
  const NotesListPage({super.key});
  @override
  ConsumerState<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends ConsumerState<NotesListPage> {
  String? _error;
  final _search = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesListProvider);
    final drafts = ref.watch(recoveryListProvider);
    final filter = ref.watch(notesFilterProvider);
    final tags = ref.watch(noteTagsProvider);
    final busy = ref.watch(notesActionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PaperSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'A place for your words',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Write in plain text. Save when you’re ready; recovery drafts keep unfinished writing on this device.',
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: busy ? null : _create,
                                icon: const LocalArtwork(assetKey: 'notes.add'),
                                label: const Text('Create note'),
                              ),
                              if (_error != null)
                                Semantics(
                                  liveRegion: true,
                                  child: Text(_error!),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ExpansionTile(
                          title: const Text('Search and filters'),
                          subtitle: Text(
                            '${filter.trash ? 'Trash' : 'Saved notes'}${filter.pinnedOnly ? ' • pinned' : ''}${filter.tag != null ? ' • ${filter.tag}' : ''}${filter.search.isNotEmpty ? ' • ${filter.search}' : ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          expansionAnimationStyle: AnimationStyle.noAnimation,
                          children: [
                            TextField(
                              maxLength: 256,
                              key: const ValueKey('notes-search'),
                              controller: _search,
                              decoration: const InputDecoration(
                                labelText: 'Search saved title and body',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (value) => _filter(search: value),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Saved notes'),
                                  selected: !filter.trash,
                                  onSelected: (_) => _filter(trash: false),
                                ),
                                ChoiceChip(
                                  label: const Text('Trash'),
                                  selected: filter.trash,
                                  onSelected: (_) => _filter(trash: true),
                                ),
                                FilterChip(
                                  label: const Text('Pinned only'),
                                  selected: filter.pinnedOnly,
                                  onSelected: (value) => _filter(pinned: value),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            tags.when(
                              loading: () => const Text('Loading tags…'),
                              error: (_, _) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('Tags could not be loaded.'),
                                  OutlinedButton(
                                    onPressed: () =>
                                        ref.invalidate(noteTagsProvider),
                                    child: const Text('Retry tags'),
                                  ),
                                ],
                              ),
                              data: (items) => DropdownButtonFormField<String>(
                                key: ValueKey(filter.tag),
                                initialValue: filter.tag ?? '',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Filter by tag',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('All tags'),
                                  ),
                                  for (final tag in {
                                    ...items,
                                    if (filter.tag != null) filter.tag!,
                                  })
                                    DropdownMenuItem(
                                      value: tag,
                                      child: Text(
                                        tag,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (value) =>
                                    _filter(tag: value, clearTag: value == ''),
                              ),
                            ),
                            if (filter.search.isNotEmpty ||
                                filter.tag != null ||
                                filter.pinnedOnly)
                              TextButton(
                                onPressed: () {
                                  _search.clear();
                                  ref
                                      .read(notesFilterProvider.notifier)
                                      .set(NotesQuery(trash: filter.trash));
                                },
                                child: const Text('Clear filters'),
                              ),
                            const Text(
                              'Recovery drafts are shown separately from saved-note filters.',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Recovery drafts',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                ..._section(drafts, drafts: true),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      filter.trash ? 'Notes in Trash' : 'Saved notes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                ..._section(notes, drafts: false),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _section(
    AsyncValue<List<NoteListing>> value, {
    required bool drafts,
  }) => value.when(
    loading: () => [
      const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(20), child: Text('Loading…')),
      ),
    ],
    error: (_, _) => [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                drafts
                    ? 'Recovery drafts could not be loaded.'
                    : 'Notes could not be loaded.',
              ),
              OutlinedButton(
                onPressed: () => drafts
                    ? ref.invalidate(recoveryListProvider)
                    : ref.invalidate(notesListProvider),
                child: const Text('Retry loading'),
              ),
            ],
          ),
        ),
      ),
    ],
    data: (items) => items.isEmpty
        ? [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  drafts
                      ? 'No unfinished drafts.'
                      : ref.read(notesFilterProvider).search.isNotEmpty ||
                            ref.read(notesFilterProvider).tag != null ||
                            ref.read(notesFilterProvider).pinnedOnly
                      ? 'No notes match these filters.'
                      : ref.read(notesFilterProvider).trash
                      ? 'Trash is empty.'
                      : 'No saved notes yet. Create your first note.',
                ),
              ),
            ),
          ]
        : [
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  title: Text(
                    noteTitle(item.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    drafts
                        ? 'Recovery draft • ${item.revision == 0 ? 'new note' : 'from revision ${item.revision}'}'
                        : '${item.pinned ? 'Pinned • ' : ''}Saved revision ${item.revision}',
                  ),
                  trailing: Icon(
                    drafts ? Icons.edit_outlined : Icons.chevron_right,
                  ),
                  onTap: () => context.go(noteLocation(item.id, edit: drafts)),
                );
              },
            ),
          ],
  );

  Future<void> _create() async {
    setState(() => _error = null);
    try {
      final id = await ref.read(notesActionsProvider.notifier).create();
      if (mounted && id != null) context.go(noteLocation(id, edit: true));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'A draft could not be created. Check device storage and try again.',
        );
      }
    }
  }
}
