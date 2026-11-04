import 'note_ai_sheet.dart';
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
import '../domain/note_document.dart';
import 'note_paper.dart';

class NoteEditPage extends ConsumerStatefulWidget {
  const NoteEditPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends ConsumerState<NoteEditPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _loaded = false;
  bool _leaving = false;
  bool _dictating = false;

  @override
  void initState() {
    super.initState();
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
        /* A retained draft remains available to retry. */
      }
    });
  }

  @override
  void dispose() {
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
    final compact =
        MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;
    final editor = ref.watch(noteEditorProvider(widget.id));
    final value = editor.value;
    final controller = ref.read(noteEditorProvider(widget.id).notifier);
    final readOnly =
        value != null &&
        value.baseRevision > 0 &&
        !ref.watch(syncCanEditProvider);
    final canSave =
        value != null &&
        !readOnly &&
        !value.saving &&
        (!value.text.isEmpty || value.details.hasWriting) &&
        (value.draftRevision != null ||
            value.recovering ||
            value.recoveryFailed);
    return NoteScene(
      details: value?.details ?? const NoteDetails(),
      seed: widget.id.hashCode,
      child: PopScope(
        canPop:
            value == null ||
            (!value.saving && !value.recovering && !value.recoveryFailed),
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || _leaving || value == null || value.saving) return;
          _leaving = true;
          final recovered = await controller.flushRecovery();
          if (mounted && recovered) {
            await WidgetsBinding.instance.endOfFrame;
            if (context.mounted) Navigator.of(context).pop();
          }
          _leaving = false;
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
                    onPressed: value == null || value.saving || readOnly
                        ? null
                        : _attach,
                  ),
                  IconButton.filled(
                    tooltip: 'Dictate a note',
                    icon: const Icon(Icons.mic_none_rounded),
                    onPressed:
                        value == null || value.saving || readOnly || _dictating
                        ? null
                        : _dictate,
                  ),
                  IconButton.filled(
                    tooltip: 'Add checkbox',
                    icon: const Icon(Icons.list_outlined),
                    onPressed: value == null || value.saving || readOnly
                        ? null
                        : _checkbox,
                  ),
                  IconButton.filled(
                    tooltip: 'Edit tags',
                    icon: const Icon(Icons.sell_outlined),
                    onPressed: value == null || value.saving || readOnly
                        ? null
                        : _tags,
                  ),
                ],
              ),
            ),
          ),
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Close editor',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              IconButton(
                tooltip: 'AI tools',
                icon: const Icon(Icons.auto_awesome_outlined),
                onPressed: value == null || value.saving
                    ? null
                    : () => showNoteAiTools(context, widget.id, editor: true),
              ),
              IconButton(
                tooltip: 'Choose note background',
                icon: const Icon(Icons.color_lens_outlined),
                onPressed: value == null || value.saving || readOnly
                    ? null
                    : _background,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Tooltip(
                  message: 'Save note',
                  child: FilledButton.icon(
                    onPressed: canSave
                        ? () async {
                            if (await controller.save() && context.mounted) {
                              final message =
                                  ref
                                      .read(noteEditorProvider(widget.id))
                                      .value
                                      ?.message ??
                                  'Saved on this device.';
                              FocusScope.of(context).unfocus();
                              final messenger = ScaffoldMessenger.of(context);
                              context.go(noteLocation(widget.id));
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: compact
                        ? const SizedBox.shrink()
                        : Text(
                            value?.saving == true ? 'Saving…' : 'Save',
                            maxLines: 1,
                          ),
                    style: FilledButton.styleFrom(
                      minimumSize: compact ? const Size(48, 48) : null,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: editor.when(
              loading: () => const Center(child: Text('Opening editor…')),
              error: (_, _) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Editor unavailable. The note may be missing or deleted.',
                    ),
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
                  color: NoteColors.fromBackground(
                    Theme.of(context).colorScheme,
                    state.details.background,
                  ).background,
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
                            onRemove: readOnly || state.saving
                                ? null
                                : (index) => controller.editDetails(
                                    state.details.copy(
                                      attachments: [
                                        ...state.details.attachments,
                                      ]..removeAt(index),
                                    ),
                                  ),
                          ),
                          if (state.details.tags.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final tag in state.details.tags)
                                  Chip(
                                    label: Text(
                                      tag,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          if (readOnly)
                            const Text(
                              'This device is add-only. Reclaim primary in Sync & devices to edit. Your draft is kept.',
                            ),
                          if (state.sourceUnavailable)
                            const Text(
                              'The original note was deleted. Save a copy to keep this draft as a new note.',
                            ),
                          TextField(
                            key: const ValueKey('note-title'),
                            controller: _title,
                            enabled: !state.saving && !readOnly,
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.3,
                              fontWeight: FontWeight.bold,
                            ),
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
                          const SizedBox(height: 20),
                          TextField(
                            key: const ValueKey('note-body'),
                            controller: _body,
                            enabled: !state.saving && !readOnly,
                            style: const TextStyle(fontSize: 16, height: 1.6),
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
                                  (state.recovering
                                      ? 'Keeping recovery draft…'
                                      : state.recoveryFailed
                                      ? 'Recovery is not saved. Keep this editor open and retry.'
                                      : state.draftRevision != null
                                      ? 'Recovery draft kept on this device. Save to commit.'
                                      : 'No unsaved changes.'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              if (state.baseRevision > 0 &&
                                  !state.sourceUnavailable)
                                OutlinedButton(
                                  onPressed: state.saving
                                      ? null
                                      : () async {
                                          if (await controller
                                                  .flushRecovery() &&
                                              context.mounted) {
                                            context.go(noteLocation(widget.id));
                                          }
                                        },
                                  child: const Text('Read committed note'),
                                ),
                              if (state.recoveryFailed)
                                OutlinedButton(
                                  onPressed: state.saving
                                      ? null
                                      : controller.flushRecovery,
                                  child: const Text('Retry recovery'),
                                ),
                              if (state.message != null ||
                                  state.recoveryFailed ||
                                  state.sourceUnavailable)
                                OutlinedButton(
                                  onPressed: state.saving || state.text.isEmpty
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
                                child: const Text('Discard draft'),
                              ),
                            ],
                          ),
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
      if (!await editor.flushRecovery() || !mounted) return;
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
        if (await editor.flushRecovery()) {
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
        title: const Text('Discard recovery draft?'),
        content: const Text(
          'Uncommitted writing in this editor will be removed. Any committed note is kept.',
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
    if (confirmed == true && await controller.discard() && mounted) {
      context.go(AppDestination.notes.location);
    }
  }
}
