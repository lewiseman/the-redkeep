import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../application/note_maester_controller.dart';
import '../application/notes_providers.dart';
import 'note_bottom_morph.dart';
import 'note_edit_page.dart';
import 'note_read_page.dart';

/// Reading and editing share one note page. A new note opens in editing.
class NotePage extends ConsumerStatefulWidget {
  const NotePage({super.key, required this.id});
  final String id;

  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<NotePage> {
  late bool _editing;

  /// Entering editing keeps the paper in place, including its scroll position.
  GlobalKey _paperKey = GlobalKey(debugLabel: 'note-paper');

  /// The bottom pill's contents, measured so the next pill grows from them.
  GlobalKey _bottomKey = GlobalKey(debugLabel: 'note-bottom');
  Size? _bottomFrom;

  /// Remembers the pill being left and gives the next one a fresh key.
  void _leaveBottom() {
    _bottomFrom = _bottomKey.currentContext?.size;
    _bottomKey = GlobalKey(debugLabel: 'note-bottom');
  }

  Size? _takeBottom() {
    final from = _bottomFrom;
    _bottomFrom = null;
    return from;
  }

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

  /// Shows the saved note from the top of its folded preview. Empty new notes
  /// return to where they began.
  Future<void> _back() async {
    if (await _hasSavedNote()) {
      if (mounted) {
        setState(() {
          _leaveBottom();
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
  Widget build(BuildContext context) {
    // The Maester's request belongs to the page: leaving the note stops it.
    ref.listen(noteMaesterProvider(widget.id), (_, _) {});
    return _build(context);
  }

  Widget _build(BuildContext context) => NoteBottomMorphScope(
    measure: _bottomKey,
    take: _takeBottom,
    child: _editing
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
            onEdit: () => setState(() {
              _leaveBottom();
              _editing = true;
            }),
          ),
  );
}
