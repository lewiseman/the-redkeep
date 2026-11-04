import 'note_actions_menu.dart';
import 'note_ai_sheet.dart';
import 'note_scene.dart';
import 'note_media_widgets.dart';
import 'note_tag_picker.dart';
import '../domain/note_colors.dart';
import 'website/note_website_view.dart';
import '../domain/website/website_contract.dart';
import '../domain/website/website_render.dart';
import 'website/website_theme_picker.dart';
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
  bool _preview = true;
  bool _showWebsiteText = false;
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
    return NoteScene(
      details: note?.details ?? const NoteDetails(),
      seed: widget.id.hashCode,
      child: ValueListenableBuilder<double>(
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
                  IconButton(
                    tooltip: 'AI tools',
                    icon: const Icon(Icons.auto_awesome_outlined),
                    onPressed: () => showNoteAiTools(context, widget.id),
                  ),
                  if (expansion > .3 ||
                      current!.draft != null ||
                      note!.details.website.isNotEmpty)
                    IconButton(
                      tooltip: current!.draft == null
                          ? 'Edit note'
                          : 'Resume draft',
                      onPressed: canEdit
                          ? () =>
                                context.go(noteLocation(widget.id, edit: true))
                          : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  NoteActionsMenu(
                    isPinned: note!.pinned,
                    onTogglePin: busy || current.draft != null
                        ? null
                        : () => _act(
                            () => ref
                                .read(notesActionsProvider.notifier)
                                .organize(
                                  note,
                                  pinned: !note.pinned,
                                  tags: note.tags,
                                ),
                          ),
                    onTags: busy || current.draft != null
                        ? null
                        : () => _tags(note),
                    onBackground: busy || current.draft != null
                        ? null
                        : () => _background(note),
                    onDelete: busy ? null : () => _delete(note),
                    onPreview: () => setState(() => _preview = !_preview),
                    preview: _preview,
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
                  if (note!.details.website.isNotEmpty && !_showWebsiteText) {
                    return LayoutBuilder(
                      builder: (context, constraints) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight * .45,
                            ),
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      noteTitle(note.text.title),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        TextButton(
                                          onPressed: () => setState(
                                            () => _showWebsiteText = true,
                                          ),
                                          child: const Text('Read note text'),
                                        ),
                                        if (canEdit && value.draft == null) ...[
                                          TextButton.icon(
                                            onPressed: () => _websiteLook(note),
                                            icon: const Icon(
                                              Icons.palette_outlined,
                                            ),
                                            label: const Text('Change look'),
                                          ),
                                          TextButton(
                                            onPressed: () => _act(
                                              () => ref
                                                  .read(notesRepositoryProvider)
                                                  .applyProposal(
                                                    note.id,
                                                    note.revision,
                                                    text: note.text,
                                                    details: note.details.copy(
                                                      website: '',
                                                      websiteSourceHash: '',
                                                    ),
                                                    taskId:
                                                        'remove-website-${DateTime.now().microsecondsSinceEpoch}',
                                                    operation: 'remove-website',
                                                    retainPrior: false,
                                                  ),
                                            ),
                                            child: const Text('Remove website'),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (websiteContentHash(note.text.body) !=
                                        note.details.websiteSourceHash)
                                      const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                          'Your note changed since this website was made.',
                                          key: ValueKey(
                                            'note-website-page-stale',
                                          ),
                                        ),
                                      ),
                                    if (_error != null) _failure(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: NoteWebsiteView(
                              html: note.details.website,
                              photos: note.details.attachments,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return NotePaper(
                    controller: _paper,
                    color: NoteColors.fromBackground(
                      Theme.of(context).colorScheme,
                      note.details.background,
                    ).background,
                    isPreviewMode: true,
                    readOnly: !canEdit,
                    onExpansionChanged: (value) => _expansion.value = value,
                    onEdit: () =>
                        context.go(noteLocation(widget.id, edit: true)),
                    children: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (note.details.website.isNotEmpty)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _showWebsiteText = false),
                                child: const Text('Show website'),
                              ),
                            NoteAttachmentStrip(
                              attachments: note.details.attachments,
                            ),
                            SelectableText(
                              noteTitle(note.text.title),
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
                            if (_preview &&
                                note.text.body.length <=
                                    NoteMarkdownPreview.maxCharacters &&
                                '\n'.allMatches(note.text.body).length <
                                    NoteMarkdownPreview.maxLines)
                              NoteMarkdownPreview(
                                key: ValueKey(note.revision),
                                text: note.text.body,
                              )
                            else
                              SelectableText(
                                note.text.body.isEmpty
                                    ? 'This note is empty.'
                                    : note.text.body,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                ),
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
    final tags = await NoteTagPicker.show(context, currentTags: note.tags);
    if (tags == null || !mounted) return;
    await _act(
      () => ref
          .read(notesActionsProvider.notifier)
          .organize(note, pinned: note.pinned, tags: tags),
    );
  }

  Future<void> _background(NoteDocument note) async {
    final background = await pickNoteBackground(
      context,
      widget.id,
      note.details,
    );
    if (!mounted || background == null) return;
    await _act(
      () => ref
          .read(notesRepositoryProvider)
          .applyProposal(
            note.id,
            note.revision,
            text: note.text,
            details: note.details.copy(background: background),
            taskId: 'background-${DateTime.now().microsecondsSinceEpoch}',
            operation: 'background',
            retainPrior: false,
          ),
    );
  }

  Future<void> _websiteLook(NoteDocument note) async {
    var spec = websiteSpecOf(note.details.website);
    if (spec == null) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Look', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              WebsiteThemeSwatches(
                selected: spec!.theme,
                onSelected: (v) =>
                    update(() => spec = spec!.withStyle(theme: v)),
              ),
              const SizedBox(height: 16),
              Text('Accent', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 10,
                children: [
                  for (final accent in websiteAccentColors.entries)
                    ChoiceChip(
                      label: Text(accent.key),
                      avatar: CircleAvatar(
                        radius: 8,
                        backgroundColor: accent.value,
                      ),
                      selected: spec!.accent == accent.key,
                      onSelected: (_) => update(
                        () => spec = spec!.withStyle(accent: accent.key),
                      ),
                    ),
                ],
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  renderWebsite(spec!, title: note.text.title),
                ),
                child: const Text('Apply look'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _act(() async {
      final page = await sanitizeWebsiteBounded(result);
      await ref
          .read(notesRepositoryProvider)
          .applyProposal(
            note.id,
            note.revision,
            text: note.text,
            details: note.details.copy(website: page),
            taskId: 'website-look-${DateTime.now().microsecondsSinceEpoch}',
            operation: 'website-look',
            retainPrior: false,
          );
    });
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
