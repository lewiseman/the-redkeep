import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/paper_surface.dart';
import '../application/notes_providers.dart';
import '../domain/note_document.dart';

class NotesListPage extends ConsumerStatefulWidget {
  const NotesListPage({super.key});
  @override
  ConsumerState<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends ConsumerState<NotesListPage> {
  String? _error;
  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesListProvider);
    final drafts = ref.watch(recoveryListProvider);
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
                                icon: const Icon(Icons.add),
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
                      'Saved notes',
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
                        : 'Saved revision ${item.revision}',
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
