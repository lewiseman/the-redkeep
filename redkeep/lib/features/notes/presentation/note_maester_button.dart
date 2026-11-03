import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../maester/domain/maester_source.dart';
import '../../maester/presentation/maester_button.dart';
import '../../maester/presentation/maester_selection.dart';
import '../application/note_editor_controller.dart';
import '../application/notes_providers.dart';

class NoteMaesterButton extends ConsumerWidget {
  const NoteMaesterButton({super.key, required this.id, this.body});
  final String id;
  final TextEditingController? body;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opened = ref.watch(noteDocumentProvider(id)).value;
    final note = opened?.note;
    final editor = body == null
        ? null
        : ref.watch(noteEditorProvider(id)).value;
    Widget button(
      TextSelection selection,
      int selectionVersion,
      int Function() currentVersion,
    ) {
      final available = body == null
          ? opened?.available == true
          : editor != null &&
                body!.text == editor.text.body &&
                !editor.saving &&
                !editor.sourceUnavailable &&
                (editor.baseRevision == 0
                    ? note == null
                    : opened?.available == true &&
                          note?.revision == editor.baseRevision);
      final text = editor?.text.body ?? note?.text.body ?? '';
      final range = maesterRange(text, selection);
      final capturedValue = body?.value;
      final source = !available
          ? null
          : MaesterSource(
              kind: MaesterKind.note,
              id: id,
              revision: editor?.baseRevision ?? note!.revision,
              version: (
                editor?.editVersion,
                editor?.text.title ?? note?.text.title,
                selectionVersion,
                selection.baseOffset,
                selection.extentOffset,
              ),
              body: text,
              start: range.start,
              end: range.end,
              editing: body != null,
            );
      return MaesterButton(
        isCurrent: () =>
            body == null ||
            body!.value == capturedValue &&
                body!.text == editor?.text.body &&
                currentVersion() == selectionVersion &&
                ref.read(noteEditorProvider(id)).value?.editVersion ==
                    editor?.editVersion,
        source: source,
        validate: (captured) async {
          if (body != null &&
              !await ref
                  .read(noteEditorProvider(id).notifier)
                  .flushRecovery()) {
            return false;
          }
          final current = await ref
              .read(notesRepositoryProvider)
              .openDocument(id);
          if (captured.revision == 0
              ? current.note != null
              : !current.available ||
                    current.note!.revision != captured.revision) {
            return false;
          }
          if (body == null) return current.note?.text.body == captured.body;
          final state = ref.read(noteEditorProvider(id)).value;
          return state != null &&
              !state.saving &&
              !state.recoveryFailed &&
              state.baseRevision == captured.revision &&
              state.text.body == captured.body &&
              current.draft?.draftRevision == state.draftRevision;
        },
        accept: body == null
            ? null
            : (proposal, valid) async {
                final accepted = await ref
                    .read(noteEditorProvider(id).notifier)
                    .acceptReplacement(
                      expected: editor!,
                      start: proposal.source.start,
                      end: proposal.source.end,
                      replacement: proposal.output,
                      stillCurrent: valid,
                    );
                if (accepted) {
                  final text = ref
                      .read(noteEditorProvider(id))
                      .requireValue
                      .text
                      .body;
                  body!.value = TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(
                      offset: proposal.source.start + proposal.output.length,
                    ),
                  );
                }
                return accepted;
              },
        openEditor: body == null && available
            ? () => context.go(noteLocation(id, edit: true))
            : null,
      );
    }

    return body == null
        ? button(const TextSelection.collapsed(offset: -1), 0, () => 0)
        : MaesterSelection(body: body!, builder: button);
  }
}
