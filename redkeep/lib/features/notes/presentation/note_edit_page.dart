import '../../sync/application/sync_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'note_maester_button.dart';
import '../../../app/app_shell.dart';
import '../../../app/navigation_destination.dart';
import '../../../core/presentation/paper_surface.dart';
import '../application/note_editor_controller.dart';
import '../domain/note_document.dart';

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
    return PopScope(
      canPop:
          value == null ||
          (!value.saving && !value.recovering && !value.recoveryFailed),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _leaving || value == null || value.saving) return;
        _leaving = true;
        final recovered = await controller.flushRecovery();
        if (mounted && recovered) {
          // Wait for PopScope to receive the now-durable state.
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) Navigator.of(context).pop();
        }
        _leaving = false;
      },
      child: AppShell(
        floatingActionButton: NoteMaesterButton(id: widget.id, body: _body),
        child: editor.when(
          loading: () => const Text('Opening editor…'),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Editor unavailable. The note may be missing or deleted.',
              ),
              OutlinedButton(
                onPressed: () => ref.invalidate(noteEditorProvider(widget.id)),
                child: const Text('Retry loading'),
              ),
              FilledButton(
                onPressed: () => context.go(AppDestination.notes.location),
                child: const Text('Return to Notes'),
              ),
            ],
          ),
          data: (state) {
            final readOnly =
                state.baseRevision > 0 && !ref.watch(syncCanEditProvider);
            if (!_loaded) {
              _title.text = state.text.title;
              _body.text = state.text.body;
              _loaded = true;
            }
            return PaperSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Write a note',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (readOnly)
                    const Text(
                      'This device is add-only. Reclaim primary in Sync & devices to edit. Your draft is kept.',
                    ),
                  const SizedBox(height: 12),
                  const Text('Plain text • saved on this device'),
                  if (state.sourceUnavailable)
                    const Text(
                      'The original note was deleted. Save a copy to keep this draft as a new note.',
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('note-title'),
                    controller: _title,
                    enabled: !state.saving && !readOnly,
                    decoration: const InputDecoration(labelText: 'Title'),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _edit(controller),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('note-body'),
                    controller: _body,
                    enabled: !state.saving && !readOnly,
                    decoration: const InputDecoration(
                      labelText: 'Body',
                      alignLabelWithHint: true,
                    ),
                    minLines: 8,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _edit(controller),
                  ),
                  const SizedBox(height: 16),
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
                      FilledButton(
                        onPressed:
                            readOnly ||
                                state.saving ||
                                (state.draftRevision == null &&
                                    !state.recovering &&
                                    !state.recoveryFailed)
                            ? null
                            : controller.save,
                        child: Text(state.saving ? 'Saving…' : 'Save note'),
                      ),
                      if (state.baseRevision > 0 && !state.sourceUnavailable)
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
                          onPressed: state.saving
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
            );
          },
        ),
      ),
    );
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
