import 'package:flutter/material.dart';

import '../domain/note_tag.dart';

/// A note's tags as reading and writing lay them out under the title.
///
/// Chips are tinted from the note's ink (the surrounding text colour) rather
/// than the theme, so they read on light, dark, vivid and photo backgrounds
/// alike. The stored `emoji#name` is shown as emoji and name, like the tag strip.
class NoteTagChips extends StatelessWidget {
  const NoteTagChips({super.key, required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink =
        DefaultTextStyle.of(context).style.color ?? theme.colorScheme.onSurface;
    final style = (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
      color: ink.withValues(alpha: .9),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: .1,
    );
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final raw in tags)
            if (NoteTag.tryParse(raw) case final tag?)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: ink.withValues(alpha: .12),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: ink.withValues(alpha: .22),
                        width: .8,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            tag.emoji,
                            style: style.copyWith(color: ink),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            tag.name,
                            style: style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            semanticsLabel: 'Tag ${tag.name}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
