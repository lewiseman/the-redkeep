import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notes_providers.dart';
import '../domain/note_link_launcher.dart';

/// Bound synchronous Markdown parsing/layout; plain text remains unlimited.
class NoteMarkdownPreview extends ConsumerStatefulWidget {
  const NoteMarkdownPreview({super.key, required this.text});
  final String text;
  static const maxCharacters = 32000;
  static const maxLines = 1000;
  @override
  ConsumerState<NoteMarkdownPreview> createState() =>
      _NoteMarkdownPreviewState();
}

class _NoteMarkdownPreviewState extends ConsumerState<NoteMarkdownPreview> {
  String? _message;
  bool _opening = false;
  @override
  Widget build(BuildContext context) {
    if (widget.text.length > NoteMarkdownPreview.maxCharacters ||
        '\n'.allMatches(widget.text).length >= NoteMarkdownPreview.maxLines) {
      return const Text(
        'This note is too long for Markdown preview. Switch to plain text to read the complete note.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
        MarkdownBody(
          data: widget.text.isEmpty ? 'This note is empty.' : widget.text,
          selectable: true,
          // No note attachments, remote fetches, file reads or HTML/WebViews.
          imageBuilder: (_, _, alt) => Text(
            alt == null || alt.isEmpty
                ? 'Image omitted'
                : 'Image omitted: $alt',
          ),
          onTapLink: (_, href, _) => _open(href),
        ),
      ],
    );
  }

  Future<void> _open(String? href) async {
    if (_opening) return;
    final uri = safeNoteLink(href);
    if (uri == null) {
      setState(
        () => _message = 'Only complete http or https web links can be opened.',
      );
      return;
    }
    _opening = true;
    try {
      final opened = await ref.read(noteLinkLauncherProvider).open(uri);
      if (mounted) {
        setState(
          () => _message = opened ? null : 'This link could not be opened. Try again or use plain text to copy it.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'This link could not be opened. Try again or use plain text to copy it.',
        );
      }
    } finally {
      _opening = false;
    }
  }
}
