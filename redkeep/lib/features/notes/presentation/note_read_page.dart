import 'dart:async';
import 'dart:math' as math;

import 'note_actions_menu.dart';
import 'note_app_bar.dart';
import 'note_scene.dart';
import 'note_media_widgets.dart';
import 'note_tag_chips.dart';
import 'note_tag_picker.dart';
import '../domain/note_colors.dart';
import 'note_maester_composer.dart';
import 'note_read_dock.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/paper_surface.dart';
import '../../ai/application/ai_cloud.dart' show aiCapabilitiesProvider;
import '../../ai/domain/ai_provider.dart' show AiCapability;
import '../application/note_maester_controller.dart';
import '../application/note_reading_checklist.dart';
import '../application/notes_providers.dart';
import '../data/note_maester_picker.dart';
import '../domain/note_document.dart';
import '../domain/note_maester_attachment.dart';
import '../domain/note_rich_markdown.dart';
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
  final _paper = NotePaperController();

  /// The Maester's input is open in place of the dock.
  bool _asking = false;

  /// The words the input was opened for; null asks about the whole note.
  String? _askWords;

  /// What is selected in the note's body right now.
  String _selected = '';
  final _ask = TextEditingController();
  final _askFocus = FocusNode(debugLabel: 'note-maester');

  /// Photos and files that go with the next request.
  List<NoteMaesterAttachment> _attachments = const [];
  bool _attaching = false;

  /// Why the last photo or file could not be attached.
  String? _attachError;

  /// The attachment tray is shown where the keyboard was.
  bool _tray = false;

  /// The keyboard is coming back over the tray; the room stays until it
  /// is up, so the input does not move.
  bool _returning = false;
  Timer? _returned;

  /// The height of the keyboard last opened, which the tray matches.
  double _keyboard = 0;
  double _lastInset = 0;

  @override
  void dispose() {
    _paper.dispose();
    _ask.dispose();
    _askFocus.dispose();
    _returned?.cancel();
    super.dispose();
  }

  void _back() {
    if (_tray) return _showKeyboard();
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
    // The Maester needs an AI provider that can write.
    final capabilities = ref.watch(aiCapabilitiesProvider);
    final connected = capabilities.contains(AiCapability.chat);
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
    // The tray takes exactly the keyboard's place: the room below the input
    // is whatever the keyboard does not cover.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    // Measured as the keyboard rises on its own; each opening starts over.
    if (!_tray && !_returning && inset > _lastInset) {
      _keyboard = _lastInset == 0 ? inset : math.max(_keyboard, inset);
    }
    _lastInset = inset;
    final trayHeight = _keyboard > 0
        ? _keyboard
        : (MediaQuery.sizeOf(context).height * .38).clamp(240.0, 340.0);
    final space = _tray || _returning ? math.max(0.0, trayHeight - inset) : 0.0;
    return NoteScene(
      details: note?.details ?? const NoteDetails(),
      seed: widget.id.hashCode,
      child: NotePageFrost(
        // Back closes the Maester's input first; a request in progress
        // carries on, shown on the Maester's mark.
        child: PopScope(
          canPop: !_asking,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            // Back from the tray returns to the keyboard.
            _tray ? _showKeyboard() : _closeAsk();
          },
          child: Scaffold(
            appBar: NoteAppBar(onBack: _back),
            // The paper runs to the bottom edge with the dock floating over it.
            body: Stack(
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
                      // A new title from the Maester shows as it is written.
                      final title = maester.previewTitle ?? shown.text.title;
                      final titled = title.trim().isNotEmpty;
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
                                  style: Theme.of(context).textTheme.labelSmall
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
                                    title,
                                    key: const ValueKey('note-read-title'),
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
                                    key: const ValueKey('note-maester-preview'),
                                    text: preview,
                                    selectable: false,
                                    emptyText: '',
                                  )
                                else
                                  // One selection across the whole body,
                                  // whose menu offers the Maester.
                                  SelectionArea(
                                    onSelectionChanged: (content) =>
                                        _selected = content?.plainText ?? '',
                                    contextMenuBuilder: _contextMenu,
                                    child: NoteMarkdownPreview(
                                      key: ValueKey((
                                        shown.id,
                                        layout?.revision ?? shown.revision,
                                      )),
                                      text: layout?.body ?? shown.text.body,
                                      readingNoteId: shown.id,
                                      selectable: false,
                                    ),
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
                      error: maester.error ?? _attachError,
                      selection: _askWords != null,
                      attachments: _attachments,
                      attaching: _attaching,
                      readsPhotos: capabilities.contains(AiCapability.vision),
                      onTakePhoto: () => _attach(
                        (picker) async => [?await picker.takePhoto()],
                      ),
                      onChoosePhotos: () => _attach(
                        (picker) => picker.choosePhotos(
                          limit:
                              noteMaesterAttachmentLimit - _attachments.length,
                        ),
                      ),
                      onChooseFiles: () =>
                          _attach((picker) => picker.chooseFiles()),
                      onRemoveAttachment: (i) => setState(
                        () => _attachments = [..._attachments]..removeAt(i),
                      ),
                      trayOpen: _tray,
                      space: space,
                      trayHeight: trayHeight,
                      onToggleTray: _tray ? _showKeyboard : _showTray,
                      onInputTap: _tray ? _showKeyboard : null,
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
                    onAi: connected || maester.working ? _openAi : null,
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
                      onDelete: busy ? null : () => _delete(note),
                    ),
                  ),
              ],
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
  void _openAi({String? words}) {
    setState(() {
      _asking = true;
      // Tapping the Maester while it writes shows the request in progress.
      if (!ref.read(noteMaesterProvider(widget.id)).working) _askWords = words;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(noteMaesterProvider(widget.id)).working) {
        _askFocus.requestFocus();
      }
    });
  }

  void _closeAsk() {
    _askFocus.unfocus();
    ref.read(noteMaesterProvider(widget.id).notifier).clearError();
    _returned?.cancel();
    setState(() {
      _asking = false;
      _attachError = null;
      _tray = false;
      _returning = false;
    });
  }

  /// The keyboard goes down and the tray is uncovered in its place. The
  /// input keeps its caret, as in a chat, so the keyboard can come back.
  void _showTray() {
    _returned?.cancel();
    setState(() {
      _tray = true;
      _returning = false;
    });
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  /// The keyboard comes back over the tray. The room is kept a moment so
  /// the input stays put while it rises, or longer if there is none.
  void _showKeyboard() {
    if (!_tray) return;
    setState(() {
      _tray = false;
      _returning = true;
    });
    // The input kept its caret, so its keyboard simply shows again.
    if (_askFocus.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _askFocus.requestFocus();
    }
    _returned?.cancel();
    _returned = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _returning = false);
    });
  }

  /// Adds what the person picks to the next request. Photos need a model
  /// that reads them; anything over the limit is left out and told.
  Future<void> _attach(
    Future<List<NoteMaesterAttachment>> Function(NoteMaesterPicker) pick,
  ) async {
    if (_attaching) return;
    ref.read(noteMaesterProvider(widget.id).notifier).clearError();
    setState(() {
      _attaching = true;
      _attachError = null;
    });
    String? problem;
    var picked = const <NoteMaesterAttachment>[];
    try {
      picked = await pick(ref.read(noteMaesterPickerProvider));
    } on FormatException catch (error) {
      problem = error.message;
    } on PlatformException {
      problem = 'Your photos or files could not be opened.';
    } catch (_) {
      problem = 'That could not be attached. Try another photo or file.';
    }
    if (!mounted) return;
    final readsPhotos = ref
        .read(aiCapabilitiesProvider)
        .contains(AiCapability.vision);
    if (!readsPhotos && picked.any((a) => a.isImage)) {
      picked = [...picked.where((a) => !a.isImage)];
      problem = 'Your AI model cannot read photos. Attach a text file instead.';
    }
    final room = noteMaesterAttachmentLimit - _attachments.length;
    if (picked.length > room) {
      picked = picked.take(room).toList();
      problem = 'Attach at most $noteMaesterAttachmentLimit photos or files.';
    }
    setState(() {
      _attaching = false;
      _attachError = problem;
      _attachments = [..._attachments, ...picked];
    });
    // Something to say about it: back to the keyboard.
    if (picked.isNotEmpty) _tray ? _showKeyboard() : _askFocus.requestFocus();
  }

  /// The keyboard goes down so the note can be watched as it is rewritten.
  Future<void> _sendAsk() async {
    final maester = ref.read(noteMaesterProvider(widget.id).notifier);
    final attachments = _attachments;
    if (_attaching || _ask.text.trim().isEmpty && attachments.isEmpty) return;
    _askFocus.unfocus();
    _returned?.cancel();
    setState(() {
      _attachError = null;
      _tray = false;
      _returning = false;
    });
    final words = _askWords;
    final sent = await maester.rewriteNote(
      _ask.text,
      attachments: attachments,
      part: words == null
          ? null
          : (body) {
              final split = markdownAroundWords(body, words);
              if (split == null) {
                throw const FormatException(
                  'That selection could not be found in the note. Select it again.',
                );
              }
              return NoteMaesterPassage(
                before: split.before,
                text: split.text,
                after: split.after,
              );
            },
    );
    if (sent && mounted) {
      _ask.clear();
      setState(() {
        _asking = false;
        _attachments = const [];
      });
      // What attachments add usually lands at the end of the note.
      if (attachments.isNotEmpty && words == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _paper.revealEnd();
        });
      }
    }
  }

  /// The usual selection menu, with the Maester for the selected words.
  Widget _contextMenu(BuildContext context, SelectableRegionState state) {
    final words = _selected.trim();
    final offer =
        ref.read(aiCapabilitiesProvider).contains(AiCapability.chat) &&
        words.isNotEmpty &&
        !ref.read(noteMaesterProvider(widget.id)).working;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        ...state.contextMenuButtonItems,
        if (offer)
          ContextMenuButtonItem(
            label: 'Ask Maester',
            onPressed: () {
              state.hideToolbar();
              state.clearSelection();
              _openAi(words: words);
            },
          ),
      ],
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
