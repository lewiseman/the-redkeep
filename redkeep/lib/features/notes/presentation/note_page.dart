import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../application/notes_providers.dart';
import 'note_edit_page.dart';
import 'note_read_page.dart';

/// One page per note. Reading and editing are states of this page, so
/// switching between them never navigates. A new note opens in editing;
/// leaving it shows the note, or returns to where it began if left empty.
class NotePage extends ConsumerStatefulWidget {
  const NotePage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<NotePage> {
  late bool _editing;

  /// The paper's state (fold, scroll) survives switching to and from editing.
  final _paperKey = GlobalKey(debugLabel: 'note-paper');

  /// Zero is the folded preview; one is immersive paper.
  final _expansion = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    // A new note opens straight into writing.
    _editing = ref.read(noteNewIdsProvider).contains(widget.id);
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppDestination.notes.location);
    }
  }

  bool get _saved =>
      ref.read(noteDocumentProvider(widget.id)).value?.available == true;

  /// Leaving editing shows the saved note, including a just-written one;
  /// an empty new note has nothing to show and returns to where it began.
  Future<void> _back() async {
    if (await _hasSavedNote()) {
      if (mounted) {
        setState(() => _editing = false);
      }
    } else if (mounted) {
      _leave();
    }
  }

  Future<bool> _hasSavedNote() async {
    if (_saved) return true;
    final opened = await ref
        .read(notesRepositoryProvider)
        .openDocument(widget.id);
    return opened.available;
  }

  @override
  void dispose() {
    _expansion.dispose();
    super.dispose();
  }

  /// Reading and editing hand the same paper back and forth, so editing is
  /// the immersive paper made editable rather than a separate page.
  @override
  Widget build(BuildContext context) => _editing
      ? NoteEditView(
          key: const ValueKey('note-editing'),
          id: widget.id,
          paperKey: _paperKey,
          onBack: _back,
        )
      : NoteReadView(
          key: const ValueKey('note-reading'),
          id: widget.id,
          paperKey: _paperKey,
          expansion: _expansion,
          onEdit: () => setState(() => _editing = true),
        );
}
