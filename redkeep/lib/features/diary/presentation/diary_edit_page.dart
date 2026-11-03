import '../../../core/presentation/confirm_discard_changes.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../sync/application/sync_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      canPop: value == null || (!value.saving && !value.changed),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _leaving || value == null || value.saving) return;
        _leaving = true;
        final discarded = await confirmDiscardChanges(context);
        if (discarded) await controller.discard();
        if (mounted && discarded) {
          // Let PopScope receive the cleared buffer state.
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) Navigator.of(context).pop();
        }
        _leaving = false;
      },
      child: DiaryWritingFrame(
        title: value != null && value.baseRevision > 0
            ? 'Edit entry'
            : 'Add text',
        actions: [
          TextButton(
            onPressed:
                value == null ||
                    value.saving ||
                    value.text.isEmpty ||
                    !value.changed ||
                    (value.baseRevision > 0 && !ref.watch(syncCanEditProvider))
                ? null
                : controller.save,
            child: Text(value?.saving == true ? 'Saving…' : 'Save'),
          ),
        ],
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
            final readOnly =
                state.baseRevision > 0 && !ref.watch(syncCanEditProvider);
            if (!_loaded) {
              _title.text = state.text.title;
              _body.text = state.text.body;
              _loaded = true;
            }
            return NotebookSurface(
              variant: widget.address.date.weekday,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Write a diary entry',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(widget.address.date.key),
                  if (state.sourceUnavailable)
                    const Text(
                      'The original entry was deleted. Save a copy to keep this writing as a new entry.',
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('diary-title'),
                    style: DiaryTypography.of(context).title,
                    controller: _title,
                    enabled: !state.saving && !readOnly,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _edit(controller),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('diary-body'),
                    style: DiaryTypography.of(context).body,
                    controller: _body,
                    enabled: !state.saving && !readOnly,
                    decoration: const InputDecoration(
                      hintText: 'Start writing about your day…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
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
                          (state.changed
                              ? 'Unsaved changes.'
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
                                state.text.isEmpty ||
                                !state.changed
                            ? null
                            : controller.save,
                        child: Text(state.saving ? 'Saving…' : 'Save entry'),
                      ),
                      if (state.baseRevision > 0 && !state.sourceUnavailable)
                        OutlinedButton(
                          onPressed: state.saving
                              ? null
                              : () async {
                                  if ((!state.changed ||
                                          await confirmDiscardChanges(
                                            context,
                                          )) &&
                                      context.mounted) {
                                    await controller.discard();
                                    if (!context.mounted) return;
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
                      if (state.message != null || state.sourceUnavailable)
                        OutlinedButton(
                          onPressed: state.saving || state.text.isEmpty
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
                        child: const Text('Discard changes'),
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
    final confirmed = await confirmDiscardChanges(context);
    if (confirmed == true && await controller.discard() && mounted) {
      context.go(diaryDayLocation(widget.address.date));
    }
  }
}
