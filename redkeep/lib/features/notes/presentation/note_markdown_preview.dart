import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notes_providers.dart';
import '../domain/note_link_launcher.dart';
import 'note_typography.dart';

/// A note's reading view: its Markdown, formatted as the editor shows it.
class NoteMarkdownPreview extends ConsumerStatefulWidget {
  const NoteMarkdownPreview({super.key, required this.text});
  final String text;
  @override
  ConsumerState<NoteMarkdownPreview> createState() =>
      _NoteMarkdownPreviewState();
}

class _NoteMarkdownPreviewState extends ConsumerState<NoteMarkdownPreview> {
  String? _message;
  bool _opening = false;
  @override
  Widget build(BuildContext context) {
    // The same text the editor shows, so reading and writing match.
    final typography = NoteTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
        MarkdownBody(
          data: widget.text.isEmpty ? 'This note is empty.' : widget.text,
          selectable: true,
          styleSheet: typography.markdown(context),
          checkboxBuilder: (checked) => Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: (typography.body.fontSize ?? 16) + 2,
              color: typography.checkbox,
            ),
          ),
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
          () => _message = opened
              ? null
              : 'This link could not be opened. Try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'This link could not be opened. Try again.');
      }
    } finally {
      _opening = false;
    }
  }
}
