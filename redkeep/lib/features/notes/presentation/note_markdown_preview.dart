import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../../sync/application/sync_providers.dart';
import '../application/note_reading_checklist.dart';
import '../application/notes_providers.dart';
import '../domain/note_link_launcher.dart';
import 'note_markdown_task_list.dart';
import 'note_typography.dart';

/// A note's reading view: its Markdown, formatted as the editor shows it.
class NoteMarkdownPreview extends ConsumerStatefulWidget {
  const NoteMarkdownPreview({
    super.key,
    required this.text,
    this.selectable = true,
    this.readingNoteId,
  });
  final String text;

  /// Off where taps and drags mean something else, e.g. AI previews.
  final bool selectable;

  /// Only the saved note's own reading view can change its task markers.
  final String? readingNoteId;

  @override
  ConsumerState<NoteMarkdownPreview> createState() =>
      _NoteMarkdownPreviewState();
}

class _NoteMarkdownPreviewState extends ConsumerState<NoteMarkdownPreview> {
  String? _message;
  bool _opening = false;
  late NoteMarkdownTaskList? _taskList = _taskListFor(widget);

  NoteMarkdownTaskList? _taskListFor(NoteMarkdownPreview preview) =>
      preview.readingNoteId != null &&
          NoteMarkdownTaskList.hasTasks(preview.text)
      ? NoteMarkdownTaskList(preview.text)
      : null;

  @override
  void didUpdateWidget(NoteMarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.readingNoteId != widget.readingNoteId) {
      _taskList = _taskListFor(widget);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The same text the editor shows, so reading and writing match.
    final typography = NoteTypography.of(context);
    final body = widget.text;
    final noteId = widget.readingNoteId;
    final taskList = _taskList;
    final markers = taskList == null ? null : _TaskMarkers();
    final size = (typography.body.fontSize ?? 16) + 2;
    final color = typography.checkbox;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
        MarkdownBody(
          key: ValueKey(noteId),
          data: body.isEmpty ? 'This note is empty.' : body,
          selectable: widget.selectable,
          styleSheet: typography.markdown(context),
          extensionSet: taskList?.extensions,
          paddingBuilders: {'li': ?markers},
          checkboxBuilder: (checked) {
            final marker = markers?.next();
            return marker == null || noteId == null
                ? _checkboxIcon(checked, size, color)
                : _ReadingCheckbox(
                    noteId: noteId,
                    body: body,
                    marker: marker,
                    initiallyChecked: checked,
                    size: size,
                    color: color,
                  );
          },
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

// Observe each list item without replacing the renderer's text builder.
// It builds checkbox bullets after visiting children, so nested checkboxes
// come first. Unmapped checkboxes still occupy a slot in that order.
class _TaskMarkers extends MarkdownPaddingBuilder {
  final _markers = Queue<int?>();
  final _visited = Expando<bool>();

  @override
  void visitElementBefore(md.Element element) {
    if (_visited[element] != true) _collect(element);
  }

  void _collect(md.Element element) {
    final children = element.children?.whereType<md.Element>();
    for (final child in children ?? const <md.Element>[]) {
      _collect(child);
    }
    if (element.tag == 'li') {
      _visited[element] = true;
      final first = element.children?.firstOrNull;
      if (first is md.Element && first.attributes['type'] == 'checkbox') {
        _markers.add(
          int.tryParse(element.attributes[noteTaskMarkerAttribute] ?? ''),
        );
      }
    }
  }

  int? next() => _markers.isEmpty ? null : _markers.removeFirst();

  @override
  EdgeInsets getPadding() => EdgeInsets.zero;
}

class _ReadingCheckbox extends ConsumerWidget {
  const _ReadingCheckbox({
    required this.noteId,
    required this.body,
    required this.marker,
    required this.initiallyChecked,
    required this.size,
    required this.color,
  });

  final String noteId, body;
  final int marker;
  final bool initiallyChecked;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked =
        ref.watch(
          noteReadingChecklistProvider(noteId).select((s) => s.checks[marker]),
        ) ??
        initiallyChecked;
    final canEdit = ref.watch(syncCanEditProvider);
    final icon = _checkboxIcon(checked, size, color);
    return Semantics(
      checked: checked,
      enabled: canEdit,
      label: 'Checklist item',
      child: canEdit
          ? InkWell(
              splashFactory: NoSplash.splashFactory,
              onTap: () {
                final checklist = noteReadingChecklistProvider(noteId);
                final current =
                    ref.read(checklist).checks[marker] ?? initiallyChecked;
                ref.read(checklist.notifier).toggle(body, marker, !current);
              },
              child: icon,
            )
          : icon,
    );
  }
}

Widget _checkboxIcon(bool checked, double size, Color color) => Padding(
  padding: const EdgeInsetsDirectional.only(end: 4),
  child: Icon(
    checked ? Icons.check_box : Icons.check_box_outline_blank,
    size: size,
    color: color,
  ),
);
