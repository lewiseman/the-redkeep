import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../maester/domain/maester_source.dart';
import '../../maester/presentation/maester_button.dart';
import '../../maester/presentation/maester_selection.dart';
import '../application/diary_editor_controller.dart';
import '../application/diary_providers.dart';
import '../domain/diary_document.dart';

class DiaryMaesterButton extends ConsumerWidget {
  const DiaryMaesterButton({super.key, required this.address, this.body});
  final DiaryAddress address;
  final TextEditingController? body;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opened = ref.watch(diaryDocumentProvider(address.id)).value;
    final entry = opened?.entry;
    final editor = body == null
        ? null
        : ref.watch(diaryEditorProvider(address)).value;
    Widget button(
      TextSelection selection,
      int version,
      int Function() currentVersion,
    ) {
      final available = body == null
          ? opened?.available == true && entry!.date == address.date
          : editor != null &&
                body!.text == editor.text.body &&
                !editor.saving &&
                !editor.sourceUnavailable &&
                (editor.baseRevision == 0
                    ? entry == null
                    : opened?.available == true &&
                          entry!.date == address.date &&
                          entry.revision == editor.baseRevision);
      final text = editor?.text.body ?? entry?.text.body ?? '';
      final range = maesterRange(text, selection);
      final capturedValue = body?.value;
      return MaesterButton(
        isCurrent: () =>
            body == null ||
            body!.value == capturedValue &&
                body!.text == editor?.text.body &&
                currentVersion() == version &&
                ref.read(diaryEditorProvider(address)).value?.editVersion ==
                    editor?.editVersion,
        source: !available
            ? null
            : MaesterSource(
                kind: MaesterKind.diary,
                id: address.id,
                revision: editor?.baseRevision ?? entry!.revision,
                version: (
                  address.date,
                  editor?.editVersion,
                  editor?.text.title ?? entry?.text.title,
                  version,
                  selection.baseOffset,
                  selection.extentOffset,
                ),
                body: text,
                start: range.start,
                end: range.end,
                editing: body != null,
              ),
        validate: (source) async {
          final current = await ref
              .read(diaryRepositoryProvider)
              .openDocument(address.id);
          if (current.entry != null && current.date != address.date) {
            return false;
          }
          if (source.revision == 0
              ? current.entry != null
              : !current.available ||
                    current.entry!.revision != source.revision) {
            return false;
          }
          if (body == null) return current.entry?.text.body == source.body;
          final state = ref.read(diaryEditorProvider(address)).value;
          return state != null &&
              !state.saving &&
              state.baseRevision == source.revision &&
              state.text.body == source.body;
        },
        openEditor: body == null && available
            ? () => context.go(
                diaryEntryLocation(address.date, address.id, edit: true),
              )
            : null,
      );
    }

    return body == null
        ? button(const TextSelection.collapsed(offset: -1), 0, () => 0)
        : MaesterSelection(body: body!, builder: button);
  }
}
