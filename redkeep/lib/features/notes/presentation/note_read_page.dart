import 'note_actions_menu.dart';
import 'note_ai_sheet.dart';
import 'note_ai_widgets.dart' show NoteAiTool;
import 'note_app_bar.dart';
import '../../../core/presentation/rendering_policy.dart';
import 'note_scene.dart';
import 'note_media_widgets.dart';
import 'note_tag_picker.dart';
import '../domain/note_colors.dart';
import 'website/note_website_card.dart';
import '../../sync/application/sync_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/paper_surface.dart';
import '../application/note_reading_checklist.dart';
import '../application/notes_providers.dart';
import '../domain/note_document.dart';
import 'note_markdown_preview.dart';
import 'note_paper.dart';
import 'note_action_dialog.dart';

/// The reading state of [NotePage]. [onEdit] switches the same page to
/// editing.
class NoteReadView extends ConsumerStatefulWidget {
  const NoteReadView({
    super.key,
    required this.id,
    required this.onEdit,
    required this.paperKey,
  });
  final String id;
  final VoidCallback onEdit;

  /// Shared with editing so the same paper continues into it.
  final GlobalKey paperKey;

  @override
  ConsumerState<NoteReadView> createState() => _NoteReadViewState();
}

class _NoteReadViewState extends ConsumerState<NoteReadView> {
  String? _error;

  /// While the AI desk is open its kept result decides where the paper goes.
  bool _aiOpen = false;
  NoteAiLanding? _landing;
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
    final checklist = noteReadingChecklistProvider(widget.id);
    // The snapshot starts at the body already on screen. Its checkboxes
    // listen individually, and the saved document stream updates the page.
    final layout = ref.read(checklist).layout;
    ref.listen(checklist.select((state) => state.error), (_, error) {
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    });
    ref.listen(noteDocumentProvider(widget.id), (previous, next) {
      final before = previous?.value?.note;
      final after = next.value?.note;
      if (before != null &&
          after != null &&
          before.revision != after.revision &&
          !ref.read(checklist.notifier).isChecklistSave(after) &&
          !_aiOpen) {
        _paper.collapse();
      }
    });
    final opened = ref.watch(noteDocumentProvider(widget.id));
    final canEdit = ref.watch(syncCanEditProvider);
    final busy = ref.watch(notesActionsProvider) || !canEdit;
    final current = opened.value;
    final note = current?.note;
    final paperShown = current?.available == true;
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
            appBar: NoteAppBar(
              // Folded preview lets the note scene show through the bar;
              // immersive paper continues under it.
              fill: expansion,
              onBack: () => _back(current?.available == true),
              actions: [
                if (current?.available == true) ...[
                  NoteAiButton(onPressed: _openAi),
                  // Immersive paper keeps only AI and Edit; the folded
                  // preview offers the note's actions instead.
                  AnimatedSwitcher(
                    duration: RenderingPolicyScope.of(context).duration,
                    child: expansion > .3
                        ? Padding(
                            key: const ValueKey('note-edit-action'),
                            padding: const EdgeInsetsDirectional.only(start: 4),
                            child: IconButton(
                              tooltip: 'Edit note',
                              style: noteBarButtonStyle(context),
                              onPressed: canEdit ? _edit : null,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('note-more-actions'),
                            child: NoteActionsMenu(
                              isPinned: note!.pinned,
                              onTogglePin: busy
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
                              onTags: busy ? null : () => _tags(note),
                              onBackground: busy
                                  ? null
                                  : () => _background(note),
                              onDelete: busy ? null : () => _delete(note),
                            ),
                          ),
                  ),
                ],
              ],
            ),
            // Immersive paper runs to the bottom edge; its scroll padding
            // keeps text clear of the system inset.
            body: NoteAiLandingHost(
              landing: _landing,
              details: note?.details ?? const NoteDetails(),
              onDismissed: () => setState(() => _landing = null),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.paddingOf(context).bottom *
                      (paperShown ? 1 - expansion.clamp(0.0, 1.0) : 1),
                ),
                child: SafeArea(
                  bottom: false,
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'This note is missing or was deleted.',
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
                                                .read(
                                                  notesActionsProvider.notifier,
                                                )
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
                      final shown = note!;
                      return NotePaper(
                        key: widget.paperKey,
                        controller: _paper,
                        color: NoteColors.fromBackground(
                          Theme.of(context).colorScheme,
                          note.details.background,
                        ).background,
                        isPreviewMode: true,
                        readOnly: !canEdit,
                        onExpansionChanged: (value) => _expansion.value = value,
                        onEdit: _edit,
                        children: [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                NoteWebsiteCard(
                                  noteId: shown.id,
                                  body: shown.text.body,
                                ),
                                NoteAttachmentStrip(
                                  attachments: note.details.attachments,
                                ),
                                if (note.text.title.trim().isNotEmpty)
                                  SelectableText(
                                    note.text.title,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      height: 1.3,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (note.tags.isNotEmpty) ...[
                                  if (note.text.title.trim().isNotEmpty)
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
                                if (note.text.title.trim().isNotEmpty ||
                                    note.tags.isNotEmpty)
                                  const SizedBox(height: 20),
                                NoteMarkdownPreview(
                                  key: ValueKey((
                                    note.id,
                                    layout?.revision ?? note.revision,
                                  )),
                                  text: layout?.body ?? note.text.body,
                                  readingNoteId: note.id,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _updatedLabel(note.updatedAt).toUpperCase(),
                                  key: const ValueKey('note-updated-at'),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                if (note.pinned) const Text('Pinned'),
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
        ),
      ),
    );
  }

  Future<void> _edit() async {
    final saving = ref
        .read(noteReadingChecklistProvider(widget.id).notifier)
        .saving;
    if (saving != null) await saving;
    if (mounted && ref.read(syncCanEditProvider)) widget.onEdit();
  }

  /// The desk closes onto the note; a kept result is told on the paper and,
  /// when words were added at the end, the paper unfolds to show them.
  Future<void> _openAi() async {
    _aiOpen = true;
    final landing = await showNoteAiTools(context, widget.id);
    _aiOpen = false;
    if (!mounted || landing == null) return;
    // A new website opens on its own page; the text is unchanged.
    if (landing.tool == NoteAiTool.presentation) {
      context.push(noteWebsiteLocation(widget.id));
      return;
    }
    setState(() => _landing = landing);
    if (landing.appended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _paper.revealEnd();
      });
    }
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
          ),
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
          .permanentlyDelete(snapshot.note!);
      if (!mounted) return;
      context.go(AppDestination.notes.location);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Permanent deletion failed or the note changed. Everything is kept. Reload and review again.',
        );
      }
    }
  }

  Future<void> _delete(NoteDocument note) async {
    final confirmed = await showNoteDeleteConfirmation(context);
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(notesActionsProvider.notifier)
          .delete(note.id, note.revision);
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
          'This removes the saved text and tags from this device. It cannot be restored. Type DELETE to confirm.',
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

/// A small stamp: the year only when it is not this one.
String _updatedLabel(DateTime updatedAt) {
  final local = updatedAt.toLocal();
  final pattern = local.year == DateTime.now().year
      ? 'MMM d · h:mm a'
      : 'MMM d, y · h:mm a';
  return DateFormat(pattern).format(local);
}
