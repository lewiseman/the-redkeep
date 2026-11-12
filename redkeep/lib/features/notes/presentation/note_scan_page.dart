import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../application/note_editor_controller.dart';
import '../application/notes_providers.dart';
import '../domain/note_colors.dart';
import '../domain/note_document.dart';
import 'note_ai_sheet.dart';
import 'note_ai_widgets.dart';

/// Scan a page into a note, on a page of its own. Opened from the note's
/// more actions, for saved notes and new drafts alike. Adding the reviewed
/// words pops back with a [NoteAiLanding] so the note can show them.
class NoteScanPage extends ConsumerWidget {
  const NoteScanPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(noteDocumentProvider(id)).value?.note?.details;
    final draft = saved == null && ref.exists(noteEditorProvider(id))
        ? ref.watch(noteEditorProvider(id)).value?.details
        : null;
    final details = saved ?? draft ?? const NoteDetails();
    return NoteAiPaletteScope(
      noteColor: NoteColors.fromBackground(
        Theme.of(context).colorScheme,
        details.background,
      ).background,
      child: NoteAiToolPage(
        tool: NoteAiTool.scan,
        id: id,
        onLanded: (landing) => context.canPop()
            ? context.pop(landing)
            : context.go(noteLocation(id)),
      ),
    );
  }
}
