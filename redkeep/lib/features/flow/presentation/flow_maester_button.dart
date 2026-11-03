import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../maester/domain/maester_source.dart';
import '../../maester/presentation/maester_button.dart';
import '../application/flow_editor_controller.dart';
import '../application/flow_providers.dart';

class FlowMaesterButton extends ConsumerWidget {
  const FlowMaesterButton({super.key, this.id, this.editing = false});
  final String? id;
  final bool editing;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = editing ? ref.watch(flowEditorProvider(id)).value : null;
    final opened = id == null
        ? null
        : ref.watch(thoughtDocumentProvider(id!)).value;
    final thought = opened?.thought;
    final available = editing
        ? editor != null &&
              !editor.saving &&
              !editor.sourceUnavailable &&
              (editor.baseRevision == 0
                  ? thought == null
                  : opened?.available == true &&
                        thought!.revision == editor.baseRevision)
        : opened?.available == true;
    final text = editor?.body ?? thought?.body ?? '';
    final sourceId = editing && editor != null
        ? ref.read(flowEditorProvider(id).notifier).id
        : id;
    return MaesterButton(
      isCurrent: () =>
          !editing ||
          ref.read(flowEditorProvider(id)).value?.editVersion ==
                  editor?.editVersion &&
              ref.read(flowEditorProvider(id)).value?.body == editor?.body,
      source: !available
          ? null
          : MaesterSource(
              kind: MaesterKind.flow,
              id: sourceId!,
              revision: editor?.baseRevision ?? thought!.revision,
              version: editor?.editVersion ?? thought!.revision,
              body: text,
              end: text.length,
              editing: editing,
            ),
      validate: (source) async {
        if (editing &&
            !await ref.read(flowEditorProvider(id).notifier).flushRecovery()) {
          return false;
        }
        final current = await ref
            .read(flowRepositoryProvider)
            .openDocument(source.id);
        if (source.revision == 0
            ? current.thought != null
            : !current.available ||
                  current.thought!.revision != source.revision) {
          return false;
        }
        if (!editing) return current.thought?.body == source.body;
        final state = ref.read(flowEditorProvider(id)).value;
        return state != null &&
            !state.saving &&
            !state.recoveryFailed &&
            state.baseRevision == source.revision &&
            state.body == source.body &&
            current.draft?.draftRevision == state.draftRevision;
      },
    );
  }
}
