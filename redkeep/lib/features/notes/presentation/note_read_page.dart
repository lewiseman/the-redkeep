import 'note_actions_menu.dart';
import 'note_ai_sheet.dart';
import 'note_app_bar.dart';
import 'note_scene.dart';
import 'note_media_widgets.dart';
import 'note_tag_chips.dart';
import 'note_tag_picker.dart';
import '../domain/note_colors.dart';
import 'note_maester_composer.dart';
import 'note_read_dock.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/paper_surface.dart';
import '../application/note_maester_controller.dart';
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
  NoteAiLanding? _landing;
  final _paper = NotePaperController();

  /// The Maester's input is open in place of the dock.
  bool _asking = false;
  final _ask = TextEditingController();
  final _askFocus = FocusNode(debugLabel: 'note-maester');

  @override
  void dispose() {
    _paper.dispose();
    _ask.dispose();
    _askFocus.dispose();
    super.dispose();
  }

  void _back() {
    if (_asking) return _closeAsk();
    if (context.canPop()) {
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
    final maester = ref.watch(noteMaesterProvider(widget.id));
    ref.listen(noteMaesterProvider(widget.id).select((s) => s.error), (
      _,
      error,
    ) {
      // With the input closed, a failed request is told here instead.
      if (error != null && !_asking) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        ref.read(noteMaesterProvider(widget.id).notifier).clearError();
      }
    });
    final opened = ref.watch(noteDocumentProvider(widget.id));
    final busy = ref.watch(notesActionsProvider);
    final current = opened.value;
    final note = current?.note;
    final paperShown = current?.available == true;
    return NoteScene(
      details: note?.details ?? const NoteDetails(),
      seed: widget.id.hashCode,
      child: NotePageFrost(
        // Back closes the Maester's input first; a request in progress
        // carries on, shown on the Maester's mark.
        child: PopScope(
          canPop: !_asking,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _closeAsk();
          },
          child: Scaffold(
            appBar: NoteAppBar(onBack: _back),
            // The paper runs to the bottom edge with the dock floating over it.
            body: NoteAiLandingHost(
              landing: _landing,
              details: note?.details ?? const NoteDetails(),
              onDismissed: () => setState(() => _landing = null),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SafeArea(
                    bottom: !paperShown,
                    child: opened.when(
                      loading: () => const Center(child: Text('Loading note…')),
                      error: (_, _) => SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text('This note could not be loaded.'),
                            OutlinedButton(
                              onPressed: () => ref.invalidate(
                                noteDocumentProvider(widget.id),
                              ),
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
                                                    notesActionsProvider
                                                        .notifier,
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
                                    onPressed: () => context.go(
                                      AppDestination.notes.location,
                                    ),
                                    child: const Text('Return to Notes'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final shown = note!;
                        final titled = shown.text.title.trim().isNotEmpty;
                        // This context is outside the note's scene, so its
                        // paper and ink are resolved here directly.
                        final paint = NoteColors.fromBackground(
                          Theme.of(context).colorScheme,
                          shown.details.background,
                        );
                        return NotePaper(
                          key: widget.paperKey,
                          controller: _paper,
                          color: paint.background,
                          bottomPadding: NoteReadDock.extent,
                          children: [
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Every note opens with the same header:
                                  // its date, then the title when it has one.
                                  Text(
                                    [
                                      _updatedLabel(shown.updatedAt),
                                      if (shown.pinned) 'Pinned',
                                    ].join(' · ').toUpperCase(),
                                    key: const ValueKey('note-updated-at'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: paint.foreground.withValues(
                                            alpha: .72,
                                          ),
                                          letterSpacing: 1.1,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (titled)
                                    SelectableText(
                                      shown.text.title,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        height: 1.25,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  if (shown.tags.isNotEmpty) ...[
                                    if (titled) const SizedBox(height: 16),
                                    NoteTagChips(tags: shown.tags),
                                  ],
                                  SizedBox(
                                    height: titled || shown.tags.isNotEmpty
                                        ? 20
                                        : 6,
                                  ),
                                  NotePhotoPrints(
                                    attachments: shown.details.attachments,
                                  ),
                                  // The Maester's writing streams in where
                                  // the body was.
                                  if (maester.preview case final preview?)
                                    NoteMarkdownPreview(
                                      key: const ValueKey(
                                        'note-maester-preview',
                                      ),
                                      text: preview,
                                      selectable: false,
                                      emptyText: '',
                                    )
                                  else
                                    NoteMarkdownPreview(
                                      key: ValueKey((
                                        shown.id,
                                        layout?.revision ?? shown.revision,
                                      )),
                                      text: layout?.body ?? shown.text.body,
                                      readingNoteId: shown.id,
                                    ),
                                  NoteFileTags(
                                    attachments: shown.details.attachments,
                                  ),
                                  if (_error != null) _failure(),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (paperShown && _asking)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: NoteMaesterComposer(
                        controller: _ask,
                        focusNode: _askFocus,
                        working: maester.working,
                        error: maester.error,
                        onSend: _sendAsk,
                        onStop: ref
                            .read(noteMaesterProvider(widget.id).notifier)
                            .stop,
                      ),
                    )
                  else if (paperShown)
                    NoteReadDock(
                      color: NoteColors.presetForType(
                        note!.details.background['type'],
                      ),
                      working: maester.working,
                      onAi: _openAi,
                      // Writing waits until the Maester is done.
                      onEdit: maester.working ? null : _edit,
                      actions: NoteActionsMenu(
                        key: const ValueKey('note-more-actions'),
                        position: PopupMenuPosition.over,
                        style: noteBarButtonStyle(context),
                        isPinned: note.pinned,
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
                        onBackground: busy ? null : () => _background(note),
                        onScan: busy ? null : _scan,
                        onDelete: busy ? null : () => _delete(note),
                      ),
                    ),
                ],
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
    if (mounted) widget.onEdit();
  }

  /// The Maester's input opens over the dock, with the keyboard up.
  void _openAi() {
    setState(() => _asking = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(noteMaesterProvider(widget.id)).working) {
        _askFocus.requestFocus();
      }
    });
  }

  void _closeAsk() {
    _askFocus.unfocus();
    ref.read(noteMaesterProvider(widget.id).notifier).clearError();
    setState(() => _asking = false);
  }

  /// The keyboard goes down so the note can be watched as it is rewritten.
  Future<void> _sendAsk() async {
    final maester = ref.read(noteMaesterProvider(widget.id).notifier);
    if (_ask.text.trim().isEmpty) return;
    _askFocus.unfocus();
    if (await maester.rewriteNote(_ask.text) && mounted) {
      _ask.clear();
      if (_asking) setState(() => _asking = false);
    }
  }

  /// Scanning has its own page; added words are told on the paper, which
  /// scrolls to show them.
  Future<void> _scan() async {
    final landing = await context.push<NoteAiLanding>(
      noteScanLocation(widget.id),
    );
    if (!mounted || landing == null) return;
    _show(landing);
  }

  void _show(NoteAiLanding landing) {
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
    final tags = await NoteTagPicker.show(
      context,
      currentTags: note.tags,
      noteId: note.id,
    );
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
