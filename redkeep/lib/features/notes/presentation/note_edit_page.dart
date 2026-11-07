import 'note_ai_sheet.dart';
import 'note_app_bar.dart';
import 'note_scene.dart';
import 'note_media_widgets.dart';
import 'note_tag_picker.dart';
import '../data/note_media_store.dart';
import '../domain/note_colors.dart';
import '../../voice/presentation/voice_capture_page.dart';
import '../../voice/application/voice_receipts.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../sync/application/sync_providers.dart';
import '../application/note_editor_controller.dart';
import '../application/notes_providers.dart';
import '../domain/note_document.dart';
import 'note_paper.dart';

/// The editing state of [NotePage]. Writing saves straight into the note, so
/// there is no Done: [onBack] follows the back button or gesture and runs only
/// once everything is saved (or the changes were discarded).
class NoteEditView extends ConsumerStatefulWidget {
  const NoteEditView({
    super.key,
    required this.id,
    required this.onBack,
    required this.paperKey,
  });
  final String id;

  /// The same paper reading used, so editing continues it in place.
  final GlobalKey paperKey;
  final VoidCallback onBack;
  @override
  ConsumerState<NoteEditView> createState() => _NoteEditViewState();
}

class _NoteEditViewState extends ConsumerState<NoteEditView> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _loaded = false;
  bool _leaving = false;
  bool _dictating = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Leaving the app saves too; there is no separate draft to fall back on.
    _lifecycle = AppLifecycleListener(
      onHide: _saveQuietly,
      onPause: _saveQuietly,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(noteEditorProvider(widget.id).future);
        final image = await ref
            .read(noteMediaStoreProvider)
            .recoverPhoto(widget.id);
        if (!mounted || image == null) return;
        final value = ref.read(noteEditorProvider(widget.id)).requireValue;
        ref
            .read(noteEditorProvider(widget.id).notifier)
            .editDetails(
              value.details.copy(
                attachments: [...value.details.attachments, image],
              ),
            );
      } catch (_) {
        /* The pending photo stays recoverable for the next visit. */
      }
    });
  }

  void _saveQuietly() {
    if (!mounted) return;
    final editor = ref.read(noteEditorProvider(widget.id));
    if (editor.hasValue) {
      ref.read(noteEditorProvider(widget.id).notifier).save();
    }
  }

  /// Saves, then leaves editing. Stays put with the message when it can't.
  Future<void> _finish(VoidCallback leave) async {
    if (_leaving) return;
    _leaving = true;
    try {
      final editor = ref.read(noteEditorProvider(widget.id));
      if (!editor.hasValue ||
          await ref.read(noteEditorProvider(widget.id).notifier).save()) {
        if (mounted) {
          FocusScope.of(context).unfocus();
          leave();
        }
      }
    } finally {
      _leaving = false;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(noteEditorProvider(widget.id), (_, next) {
      if (!_loaded || next.value == null) return;
      final text = next.value!.text;
      if (_title.text != text.title) _title.text = text.title;
      if (_body.text != text.body) _body.text = text.body;
    });
    final editor = ref.watch(noteEditorProvider(widget.id));
    final value = editor.value;
    final controller = ref.read(noteEditorProvider(widget.id).notifier);
    final readOnly =
        value != null &&
        value.baseRevision > 0 &&
        !ref.watch(syncCanEditProvider);
    // Until the editor has loaded, the saved note keeps the scene and paper
    // exactly as reading showed them.
    final saved = ref.watch(noteDocumentProvider(widget.id)).value?.note;
    final details = value?.details ?? saved?.details ?? const NoteDetails();
    final paperColor = NoteColors.fromBackground(
      Theme.of(context).colorScheme,
      details.background,
    ).background;
    return NoteScene(
      details: details,
      seed: widget.id.hashCode,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _finish(widget.onBack);
        },
        child: Scaffold(
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                spacing: 8,
                children: [
                  IconButton.filled(
                    tooltip: 'Attach files',
                    icon: const Icon(Icons.file_present_outlined),
                    onPressed: value == null || readOnly ? null : _attach,
                  ),
                  IconButton.filled(
                    tooltip: 'Dictate a note',
                    icon: const Icon(Icons.mic_none_rounded),
                    onPressed: value == null || readOnly || _dictating
                        ? null
                        : _dictate,
                  ),
                  IconButton.filled(
                    tooltip: 'Add checkbox',
                    icon: const Icon(Icons.list_outlined),
                    onPressed: value == null || readOnly ? null : _checkbox,
                  ),
                  IconButton.filled(
                    tooltip: 'Edit tags',
                    icon: const Icon(Icons.sell_outlined),
                    onPressed: value == null || readOnly ? null : _tags,
                  ),
                ],
              ),
            ),
          ),
          appBar: NoteAppBar(
            backTooltip: 'Close editor',
            onBack: () => _finish(widget.onBack),
            actions: [
              NoteAiButton(
                onPressed: value == null
                    ? null
                    : () => showNoteAiTools(context, widget.id, editor: true),
              ),
              NoteBarEntrance(
                child: IconButton(
                  tooltip: 'Choose note background',
                  icon: const Icon(Icons.color_lens_outlined),
                  onPressed: value == null || readOnly ? null : _background,
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: editor.when(
              loading: () => NotePaper(
                key: widget.paperKey,
                color: paperColor,
                isPreviewMode: false,
                readOnly: true,
                onEdit: () {},
                children: [
                  SliverToBoxAdapter(
                    child: Semantics(
                      label: 'Opening editor…',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            noteTitle(saved?.text.title ?? ''),
                            style: _titleStyle,
                          ),
                          if (saved?.tags.isNotEmpty == true) ...[
                            const SizedBox(height: 20),
                            _NoteTagWrap(tags: saved!.tags),
                          ],
                          const SizedBox(height: 20),
                          Text(saved?.text.body ?? '', style: _bodyStyle),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              error: (_, _) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('This note is missing or was deleted.'),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(noteEditorProvider(widget.id)),
                      child: const Text('Retry loading'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          context.go(AppDestination.notes.location),
                      child: const Text('Return to Notes'),
                    ),
                  ],
                ),
              ),
              data: (state) {
                if (!_loaded) {
                  _title.text = state.text.title;
                  _body.text = state.text.body;
                  _loaded = true;
                }
                return NotePaper(
                  key: widget.paperKey,
                  color: paperColor,
                  isPreviewMode: false,
                  readOnly: readOnly,
                  onEdit: () {},
                  children: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NoteAttachmentStrip(
                            attachments: state.details.attachments,
                            onRemove: readOnly
                                ? null
                                : (index) => controller.editDetails(
                                    state.details.copy(
                                      attachments: [
                                        ...state.details.attachments,
                                      ]..removeAt(index),
                                    ),
                                  ),
                          ),
                          if (readOnly)
                            const Text(
                              'This device is add-only. Reclaim primary in Sync & devices to edit.',
                            ),
                          TextField(
                            key: const ValueKey('note-title'),
                            controller: _title,
                            enabled: !readOnly,
                            style: _titleStyle,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'Note Title…',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) => _edit(controller),
                          ),
                          // Same order and gaps as reading, so text stays put.
                          if (state.details.tags.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _NoteTagWrap(tags: state.details.tags),
                          ],
                          const SizedBox(height: 20),
                          TextField(
                            key: const ValueKey('note-body'),
                            controller: _body,
                            enabled: !readOnly,
                            style: _bodyStyle,
                            decoration: const InputDecoration(
                              labelText: 'Body',
                              hintText: 'Write your note…',
                              alignLabelWithHint: true,
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                            minLines: 5,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) => _edit(controller),
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              state.message ??
                                  (state.saving
                                      ? 'Saving…'
                                      : state.dirty
                                      ? 'Unsaved changes'
                                      : state.baseRevision > 0
                                      ? 'Saved'
                                      : ''),
                              key: const ValueKey('note-save-status'),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          if (state.conflict) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: state.saving
                                      ? null
                                      : () async {
                                          final id = await controller
                                              .saveCopy();
                                          if (context.mounted && id != null) {
                                            context.go(noteLocation(id));
                                          }
                                        },
                                  child: const Text('Save a copy'),
                                ),
                                OutlinedButton(
                                  onPressed: state.saving
                                      ? null
                                      : () => _discard(controller),
                                  child: const Text('Discard changes'),
                                ),
                              ],
                            ),
                          ],
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

  Future<void> _editTool(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException
                  ? e.message
                  : 'This change could not be kept. Your writing is safe.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _attach() => _editTool(() async {
    final added = await ref.read(noteMediaStoreProvider).pickFiles();
    if (!mounted || added.isEmpty) return;
    final value = ref.read(noteEditorProvider(widget.id)).requireValue;
    if (value.details.attachments.length + added.length > 40) {
      throw const FormatException('Use up to 40 attachments per note.');
    }
    ref
        .read(noteEditorProvider(widget.id).notifier)
        .editDetails(
          value.details.copy(
            attachments: [...value.details.attachments, ...added],
          ),
        );
  });
  Future<void> _background() => _editTool(() async {
    final value = ref.read(noteEditorProvider(widget.id)).requireValue;
    final background = await pickNoteBackground(
      context,
      widget.id,
      value.details,
    );
    if (!mounted || background == null) return;
    final latest = ref.read(noteEditorProvider(widget.id)).requireValue;
    ref
        .read(noteEditorProvider(widget.id).notifier)
        .editDetails(latest.details.copy(background: background));
  });
  Future<void> _tags() => _editTool(() async {
    final value = ref.read(noteEditorProvider(widget.id)).requireValue;
    final tags = await NoteTagPicker.show(
      context,
      currentTags: value.details.tags,
    );
    if (!mounted || tags == null) return;
    final latest = ref.read(noteEditorProvider(widget.id)).requireValue;
    ref
        .read(noteEditorProvider(widget.id).notifier)
        .editDetails(latest.details.copy(tags: tags));
  });
  void _checkbox() {
    final selection = _body.selection;
    final start = selection.isValid ? selection.start : _body.text.length;
    final end = selection.isValid ? selection.end : start;
    final prefix = start == 0 || _body.text[start - 1] == '\n' ? '' : '\n';
    final inserted = '$prefix- [ ] ';
    _body.value = TextEditingValue(
      text: _body.text.replaceRange(start, end, inserted),
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    _edit(ref.read(noteEditorProvider(widget.id).notifier));
  }

  Future<void> _dictate() async {
    if (_dictating) return;
    setState(() => _dictating = true);
    try {
      final editor = ref.read(noteEditorProvider(widget.id).notifier);
      if (!await editor.save() || !mounted) return;
      final expected = ref.read(noteEditorProvider(widget.id)).requireValue;
      FocusScope.of(context).unfocus();
      final text = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const VoiceCapturePage(title: 'Dictate a note'),
        ),
      );
      if (!mounted || text == null) return;
      final accepted = await editor.appendReviewedTranscript(
        expected: expected,
        transcript: text,
        stillCurrent: () => mounted,
      );
      if (!mounted) return;
      if (accepted) {
        final next = ref.read(noteEditorProvider(widget.id)).requireValue;
        _body.text = next.text.body;
        if (await editor.save()) {
          await ref.read(voiceReceiptsProvider).consume('note');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The note changed during capture. Your transcript is kept; open the microphone to review it again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dictating = false);
    }
  }

  void _edit(NoteEditorController controller) =>
      controller.edit(PlainTextDocument(title: _title.text, body: _body.text));

  Future<void> _discard(NoteEditorController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Discard your changes?'),
        content: const Text(
          'The writing in this editor will be removed. The saved note is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep writing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    controller.discardChanges();
    widget.onBack();
  }
}

const _titleStyle = TextStyle(
  fontSize: 24,
  height: 1.3,
  fontWeight: FontWeight.bold,
);
const _bodyStyle = TextStyle(fontSize: 16, height: 1.6);

/// The note's tags as reading lays them out.
class _NoteTagWrap extends StatelessWidget {
  const _NoteTagWrap({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Chip(
              label: Text(tag, maxLines: 1, overflow: TextOverflow.ellipsis),
              shape: const StadiumBorder(),
            ),
          ),
      ],
    ),
  );
}
