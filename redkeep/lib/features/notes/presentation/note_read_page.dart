import '../../sync/application/sync_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/paper_surface.dart';
import '../application/notes_providers.dart';
import '../domain/note_document.dart';
import '../application/note_editor_controller.dart';
import 'note_markdown_preview.dart';
import 'note_paper.dart';
import 'note_action_dialog.dart';

class NoteReadPage extends ConsumerStatefulWidget {
  const NoteReadPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NoteReadPage> createState() => _NoteReadPageState();
}

class _NoteReadPageState extends ConsumerState<NoteReadPage> {
  String? _error;
  bool _preview = false;
  final _paper = NotePaperController();
  final _expansion = ValueNotifier<double>(0);

  @override
  void dispose() {
    _paper.dispose();
    _expansion.dispose();
    super.dispose();
  }

  void _back(bool available) {
    if (available && _expansion.value > 0) {
      _paper.collapse();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppDestination.notes.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(noteDocumentProvider(widget.id), (previous, next) {
      final before = previous?.value?.note;
      final after = next.value?.note;
      if (before != null &&
          after != null &&
          before.revision != after.revision) {
        _paper.collapse();
      }
    });
    final opened = ref.watch(noteDocumentProvider(widget.id));
    final canEdit = ref.watch(syncCanEditProvider);
    final busy = ref.watch(notesActionsProvider) || !canEdit;
    final current = opened.value;
    final note = current?.note;
    return ValueListenableBuilder<double>(
      valueListenable: _expansion,
      builder: (context, expansion, _) => PopScope(
        canPop: current?.available != true || expansion == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _paper.collapse();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => _back(current?.available == true),
            ),
            actions: [
              if (current?.available == true) ...[
                if (expansion > .3 || current!.draft != null)
                  IconButton(
                    tooltip: current!.draft == null
                        ? 'Edit note'
                        : 'Resume draft',
                    onPressed: canEdit
                        ? () => context.go(noteLocation(widget.id, edit: true))
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Note actions',
                  onSelected: (action) {
                    switch (action) {
                      case 'pin':
                        _act(
                          () => ref
                              .read(notesActionsProvider.notifier)
                              .organize(
                                note!,
                                pinned: !note.pinned,
                                tags: note.tags,
                              ),
                        );
                      case 'tags':
                        _tags(note!);
                      case 'preview':
                        setState(() => _preview = !_preview);
                      case 'delete':
                        _delete(note!);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pin',
                      enabled: !busy && current.draft == null,
                      child: Text(note!.pinned ? 'Unpin note' : 'Pin note'),
                    ),
                    PopupMenuItem(
                      value: 'tags',
                      enabled: !busy && current.draft == null,
                      child: const Text('Edit tags'),
                    ),
                    PopupMenuItem(
                      value: 'preview',
                      child: Text(
                        _preview ? 'Show plain text' : 'Markdown preview',
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: !busy,
                      child: const Text('Delete note'),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
          body: SafeArea(
            child: opened.when(
              loading: () => const Center(child: Text('Loading note…')),
              error: (_, _) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('This note could not be loaded.'),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(noteDocumentProvider(widget.id)),
                      child: const Text('Retry loading'),
                    ),
                  ],
                ),
              ),
              data: (value) {
                final note = value.note;
                if (!value.available) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: PaperSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Note unavailable',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This note has not been saved, is missing, or was deleted.',
                          ),
                          if (note?.deletedAt != null) ...[
                            const Text(
                              'This note is in Trash. Restore it to read or edit the saved text.',
                            ),
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => _act(
                                      () => ref
                                          .read(notesActionsProvider.notifier)
                                          .restore(note!),
                                    ),
                              child: const Text('Restore note'),
                            ),
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => _permanentlyDelete(value),
                              child: const Text('Delete forever'),
                            ),
                          ],
                          if (_error != null) _failure(),
                          if (value.draft != null)
                            OutlinedButton(
                              onPressed: !canEdit
                                  ? null
                                  : () => context.go(
                                      noteLocation(widget.id, edit: true),
                                    ),
                              child: const Text('Open recovery draft'),
                            ),
                          FilledButton(
                            onPressed: () =>
                                context.go(AppDestination.notes.location),
                            child: const Text('Return to Notes'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return NotePaper(
                  controller: _paper,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  isPreviewMode: true,
                  readOnly: !canEdit,
                  onExpansionChanged: (value) => _expansion.value = value,
                  onEdit: () => context.go(noteLocation(widget.id, edit: true)),
                  children: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SelectableText(
                            noteTitle(note!.text.title),
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.3,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (note.tags.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            LayoutBuilder(
                              builder: (context, constraints) => Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final tag in note.tags)
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth,
                                      ),
                                      child: Chip(
                                        label: Text(
                                          tag,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        shape: const StadiumBorder(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          if (_preview)
                            NoteMarkdownPreview(
                              key: ValueKey(note.revision),
                              text: note.text.body,
                            )
                          else
                            SelectableText(
                              note.text.body.isEmpty
                                  ? 'This note is empty.'
                                  : note.text.body,
                              style: const TextStyle(fontSize: 16, height: 1.6),
                            ),
                          const SizedBox(height: 24),
                          Text(
                            'Saved revision ${note.revision}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          if (note.pinned) const Text('Pinned'),
                          if (value.draft != null) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'A separate recovery draft is available. This is the committed version. Save or discard the draft before changing tags or pinning.',
                            ),
                          ],
                          if (_error != null) _failure(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _failure() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(liveRegion: true, child: Text(_error!)),
      OutlinedButton(
        onPressed: () {
          setState(() => _error = null);
          ref.invalidate(noteDocumentProvider(widget.id));
        },
        child: const Text('Reload note'),
      ),
    ],
  );

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error is NoteException && error.failure == NoteFailure.invalidTags
              ? 'Use up to 24 tags, each at most 40 characters, separated by commas.'
              : 'This change could not be saved or the note changed. Your writing is kept. Reload and try again.',
        );
      }
    }
  }

  Future<void> _tags(NoteDocument note) async {
    final tags = await showDialog<List<String>>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (_) => _TagsDialog(note: note),
    );
    if (tags == null || !mounted) return;
    await _act(
      () => ref
          .read(notesActionsProvider.notifier)
          .organize(note, pinned: note.pinned, tags: tags),
    );
  }

  Future<void> _permanentlyDelete(OpenNote snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (_) => const _PermanentDeleteDialog(),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _error = null);
    try {
      await ref
          .read(notesActionsProvider.notifier)
          .permanentlyDelete(snapshot.note!, snapshot.draft?.draftRevision);
      if (!mounted) return;
      ref.invalidate(noteEditorProvider(widget.id));
      context.go(AppDestination.notes.location);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Permanent deletion failed or the note or recovery draft changed. Everything is kept. Reload and review again.',
        );
      }
    }
  }

  Future<void> _delete(NoteDocument note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (context) => NoteActionDialog(
        title: const Text('Delete this note?'),
        content: const Text(
          'The note will move to Trash and leave saved lists and search. Its text, tags, pin and recovery draft stay on this device until you choose Delete forever.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep note'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(notesActionsProvider.notifier).delete(note);
      if (mounted) context.go(AppDestination.notes.location);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Deletion failed or this note changed. The current note is kept; reload and try again.',
        );
      }
    }
  }
}

class _TagsDialog extends StatefulWidget {
  const _TagsDialog({required this.note});
  final NoteDocument note;
  @override
  State<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends State<_TagsDialog> {
  late final _tags = TextEditingController(text: widget.note.tags.join(', '));
  @override
  void dispose() {
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NoteActionDialog(
    title: const Text('Edit tags'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Separate tags with commas. Tags use lowercase; up to 24 tags, 40 characters each. Save or discard unfinished writing before changing tags or pinning.',
        ),
        TextField(
          key: const ValueKey('note-tags'),
          controller: _tags,
          maxLines: null,
          decoration: const InputDecoration(labelText: 'Tags'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _tags.text.split(',')),
        child: const Text('Save tags'),
      ),
    ],
  );
}

class _PermanentDeleteDialog extends StatefulWidget {
  const _PermanentDeleteDialog();
  @override
  State<_PermanentDeleteDialog> createState() => _PermanentDeleteDialogState();
}

class _PermanentDeleteDialogState extends State<_PermanentDeleteDialog> {
  final _confirmation = TextEditingController();
  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NoteActionDialog(
    title: const Text('Permanently delete this note?'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'This removes the saved text, tags and current recovery draft from this device. It cannot be restored. Type DELETE to confirm.',
        ),
        TextField(
          key: const ValueKey('delete-confirmation'),
          controller: _confirmation,
          decoration: const InputDecoration(labelText: 'Type DELETE'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Keep in Trash'),
      ),
      FilledButton(
        onPressed: _confirmation.text == 'DELETE'
            ? () => Navigator.pop(context, true)
            : null,
        child: const Text('Delete permanently'),
      ),
    ],
  );
}
