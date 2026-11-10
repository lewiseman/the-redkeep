import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../application/notes_providers.dart';
import 'note_edit_page.dart';
import 'note_read_page.dart';

/// How a note page opens.
enum NoteOpen { read, edit }

/// Reading and editing share one note page. A new note opens in editing.
class NotePage extends ConsumerStatefulWidget {
  const NotePage({super.key, required this.id, this.startEditing = false});
  final String id;

  /// Opens straight into writing, e.g. "Edit text" on the note's website.
  final bool startEditing;
  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<NotePage> {
  late bool _editing;

  /// Entering editing keeps the paper in place, including its scroll position.
  GlobalKey _paperKey = GlobalKey(debugLabel: 'note-paper');

  @override
  void initState() {
    super.initState();
    // A new note opens straight into writing.
    _editing =
        widget.startEditing || ref.read(noteNewIdsProvider).contains(widget.id);
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

  /// Shows the saved note from the top of its folded preview. Empty new notes
  /// and notes opened only to edit return to where they began.
  Future<void> _back() async {
    // Opened only to edit (from the website): return there.
    if (widget.startEditing) {
      _leave();
      return;
    }
    if (await _hasSavedNote()) {
      if (mounted) {
        setState(() {
          _editing = false;
          // Give the preview a fresh fold and scroll position.
          _paperKey = GlobalKey(debugLabel: 'note-paper');
        });
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
          onEdit: () => setState(() => _editing = true),
        );
}
