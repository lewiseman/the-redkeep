import '../../../core/presentation/confirm_discard_changes.dart';
import '../../sync/application/sync_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/paper_surface.dart';
import '../application/flow_editor_controller.dart';

/// The same editing boundary serves quick capture and ID-based edits.
class FlowEditor extends ConsumerStatefulWidget {
  const FlowEditor({super.key, this.id});
  final String? id;
  @override
  ConsumerState<FlowEditor> createState() => _FlowEditorState();
}

class _FlowEditorState extends ConsumerState<FlowEditor> {
  final _body = TextEditingController();
  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = flowEditorProvider(widget.id);
    final editor = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return editor.when(
      loading: () => const Text('Opening writing…'),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.id == null
                ? 'Composer could not be opened. Retry.'
                : 'Editor unavailable. The thought may be missing or deleted.',
          ),
          OutlinedButton(
            onPressed: () => ref.invalidate(provider),
            child: const Text('Retry opening'),
          ),
          if (widget.id != null)
            OutlinedButton(
              onPressed: () => context.go('/flow'),
              child: const Text('Return to Flow'),
            ),
        ],
      ),
      data: (state) {
        final readOnly =
            state.baseRevision > 0 && !ref.watch(syncCanEditProvider);
        if (_body.text != state.body) {
          _body.value = TextEditingValue(
            text: state.body,
            selection: TextSelection.collapsed(offset: state.body.length),
          );
        }
        return PaperSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.id == null ? 'Catch a thought' : 'Edit thought',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (readOnly)
                const Text(
                  'This device is add-only. Reclaim primary in Sync & devices to edit. Save from your primary device.',
                ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('flow-body'),
                controller: _body,
                enabled: !state.saving && !readOnly,
                decoration: const InputDecoration(
                  labelText: 'Your thought',
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onChanged: controller.edit,
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  state.message ??
                      (state.changed
                          ? 'Unsaved changes.'
                          : 'Plain text • on this device'),
                ),
              ),
              if (state.sourceUnavailable)
                const Text(
                  'The original thought was deleted. Save a copy to keep this writing.',
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        readOnly || state.saving || state.body.trim().isEmpty
                        ? null
                        : controller.save,
                    child: Text(
                      state.saving
                          ? 'Saving…'
                          : widget.id == null
                          ? 'Capture thought'
                          : 'Save thought',
                    ),
                  ),
                  if (state.sourceUnavailable || state.message != null)
                    OutlinedButton(
                      onPressed: state.saving || state.body.trim().isEmpty
                          ? null
                          : () async {
                              final id = await controller.saveCopy();
                              if (context.mounted && id != null) {
                                context.go(thoughtLocation(id));
                              }
                            },
                      child: const Text('Save a copy'),
                    ),
                  if (state.changed)
                    OutlinedButton(
                      onPressed: state.saving
                          ? null
                          : () async {
                              final discard = await confirmDiscardChanges(
                                context,
                              );
                              if (discard == true &&
                                  await controller.discard() &&
                                  context.mounted &&
                                  widget.id != null) {
                                if (context.mounted) {
                                  context.go(thoughtLocation(widget.id!));
                                }
                              }
                            },
                      child: const Text('Discard changes'),
                    ),
                  if (widget.id != null)
                    OutlinedButton(
                      onPressed: state.saving
                          ? null
                          : () async {
                              if ((!state.changed ||
                                      await confirmDiscardChanges(context)) &&
                                  context.mounted) {
                                await controller.discard();
                                if (context.mounted) {
                                  context.go(thoughtLocation(widget.id!));
                                }
                              }
                            },
                      child: const Text('Read committed thought'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
