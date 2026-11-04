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
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        !value.text.isEmpty &&
        (value.draftRevision != null ||
            value.recovering ||
            value.recoveryFailed);
    return PopScope(
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
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close editor',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              tooltip: 'Dictate a note',
              icon: const Icon(Icons.mic_none_rounded),
              onPressed: value == null || readOnly || value.saving || _dictating
                  ? null
                  : _dictate,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
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
                label: Text(value?.saving == true ? 'Saving…' : 'Save'),
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
                    onPressed: () => context.go(AppDestination.notes.location),
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
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                isPreviewMode: false,
                readOnly: readOnly,
                onEdit: () {},
                children: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                            floatingLabelBehavior: FloatingLabelBehavior.never,
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
                            floatingLabelBehavior: FloatingLabelBehavior.never,
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
                                        if (await controller.flushRecovery() &&
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
                                        final id = await controller.saveCopy();
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
    );
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
