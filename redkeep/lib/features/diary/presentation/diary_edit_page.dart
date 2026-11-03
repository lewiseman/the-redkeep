import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'diary_maester_button.dart';
import '../../../app/app_shell.dart';
import '../../../app/navigation_destination.dart';
import 'diary_widgets.dart';
import '../application/diary_editor_controller.dart';
import '../domain/diary_document.dart';

class DiaryEditPage extends ConsumerStatefulWidget {
  const DiaryEditPage({super.key, required this.address});
  final DiaryAddress address;
  @override
  ConsumerState<DiaryEditPage> createState() => _DiaryEditPageState();
}

class _DiaryEditPageState extends ConsumerState<DiaryEditPage> {
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
    final editor = ref.watch(diaryEditorProvider(widget.address));
    final value = editor.value;
    final controller = ref.read(diaryEditorProvider(widget.address).notifier);
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
        floatingActionButton: DiaryMaesterButton(
          address: widget.address,
          body: _body,
        ),
        child: editor.when(
          loading: () => const Text('Opening editor…'),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Editor unavailable. The entry may be missing or deleted.',
              ),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(diaryEditorProvider(widget.address)),
                child: const Text('Retry loading'),
              ),
              FilledButton(
                onPressed: () =>
                    context.go(diaryDayLocation(widget.address.date)),
                child: const Text('Return to day'),
              ),
            ],
          ),
          data: (state) {
            if (!_loaded) {
              _title.text = state.text.title;
              _body.text = state.text.body;
              _loaded = true;
            }
            return NotebookSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Write a diary entry',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(widget.address.date.key),
                  const Text('Plain text • saved on this device'),
                  if (state.sourceUnavailable)
                    const Text(
                      'The original entry was deleted. Save a copy to keep this draft as a new entry.',
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('diary-title'),
                    controller: _title,
                    enabled: !state.saving,
                    decoration: const InputDecoration(labelText: 'Title'),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _edit(controller),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('diary-body'),
                    controller: _body,
                    enabled: !state.saving,
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
                            state.saving ||
                                (state.draftRevision == null &&
                                    !state.recovering &&
                                    !state.recoveryFailed)
                            ? null
                            : controller.save,
                        child: Text(state.saving ? 'Saving…' : 'Save entry'),
                      ),
                      if (state.baseRevision > 0 && !state.sourceUnavailable)
                        OutlinedButton(
                          onPressed: state.saving
                              ? null
                              : () async {
                                  if (await controller.flushRecovery() &&
                                      context.mounted) {
                                    context.go(
                                      diaryEntryLocation(
                                        widget.address.date,
                                        widget.address.id,
                                      ),
                                    );
                                  }
                                },
                          child: const Text('Read committed entry'),
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
                                    context.go(
                                      diaryEntryLocation(
                                        widget.address.date,
                                        id,
                                      ),
                                    );
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

  void _edit(DiaryEditorController controller) =>
      controller.edit(DiaryText(title: _title.text, body: _body.text));

  Future<void> _discard(DiaryEditorController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (context) => DiaryDialog(
        children: [
          const Text('Discard recovery draft?'),
          const Text(
            'Uncommitted writing in this editor will be removed. Any committed entry is kept.',
          ),

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
      context.go(diaryDayLocation(widget.address.date));
    }
  }
}
