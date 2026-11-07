import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// One set of note text styles, so a note reads the same while it is being
/// written as it does afterwards.
@immutable
class NoteTypography {
  const NoteTypography._({
    required this.title,
    required this.body,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.checkbox,
  });

  factory NoteTypography.of(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final ink =
        DefaultTextStyle.of(context).style.color ?? text.bodyLarge?.color;
    TextStyle heading(TextStyle? base, double size) =>
        (base ?? const TextStyle()).copyWith(
          fontSize: size,
          height: 1.3,
          fontWeight: FontWeight.bold,
          color: ink,
        );
    return NoteTypography._(
      title: heading(null, 24),
      body: (text.bodyLarge ?? const TextStyle()).copyWith(
        fontSize: 16,
        height: 1.6,
        color: ink,
      ),
      h1: heading(text.headlineSmall, 22),
      h2: heading(text.titleLarge, 19),
      h3: heading(text.titleMedium, 17),
      checkbox: theme.colorScheme.primary,
    );
  }

  final TextStyle title;
  final TextStyle body;
  final TextStyle h1;
  final TextStyle h2;
  final TextStyle h3;
  final Color checkbox;

  /// Reading a note as Markdown.
  MarkdownStyleSheet markdown(BuildContext context) =>
      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        listBullet: body,
        h1: h1,
        h2: h2,
        h3: h3,
        h1Padding: const EdgeInsets.only(top: 8),
        h2Padding: const EdgeInsets.only(top: 8),
        h3Padding: const EdgeInsets.only(top: 4),
        checkbox: body.copyWith(color: checkbox),
      );

  /// Writing a note in the rich editor.
  DefaultStyles editor() {
    DefaultTextBlockStyle block(TextStyle style, double top) =>
        DefaultTextBlockStyle(
          style,
          HorizontalSpacing.zero,
          VerticalSpacing(top, 0),
          VerticalSpacing.zero,
          null,
        );
    return DefaultStyles(
      paragraph: block(body, 0),
      h1: block(h1, 8),
      h2: block(h2, 8),
      h3: block(h3, 4),
      lists: DefaultListBlockStyle(
        body,
        HorizontalSpacing.zero,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
        NoteCheckboxBuilder(color: checkbox, size: body.fontSize ?? 16),
      ),
      placeHolder: block(
        body.copyWith(color: body.color?.withValues(alpha: .45)),
        0,
      ),
      bold: const TextStyle(fontWeight: FontWeight.bold),
      italic: const TextStyle(fontStyle: FontStyle.italic),
    );
  }
}

/// The checkbox of a checklist item: the same box reading shows, tappable
/// while writing.
class NoteCheckboxBuilder implements QuillCheckboxBuilder {
  const NoteCheckboxBuilder({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build({
    required BuildContext context,
    required bool isChecked,
    required ValueChanged<bool> onChanged,
  }) => Semantics(
    checked: isChecked,
    label: 'Checklist item',
    child: InkResponse(
      onTap: () => onChanged(!isChecked),
      radius: size,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: Icon(
          isChecked ? Icons.check_box : Icons.check_box_outline_blank,
          size: size + 2,
          color: color,
        ),
      ),
    ),
  );
}
