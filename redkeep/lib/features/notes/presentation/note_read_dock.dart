import 'package:flutter/material.dart';

import '../domain/note_colors.dart';
import 'note_app_bar.dart';
import 'note_bottom_morph.dart';
import 'note_scene.dart';

/// The reading page's actions, floating at the bottom within thumb reach:
/// the Maester, Edit (the main action) and the note's other actions.
///
/// It keeps the app's neutral colors so only the paper carries the note's.
class NoteReadDock extends StatelessWidget {
  const NoteReadDock({
    super.key,
    required this.onEdit,
    required this.onAi,
    required this.actions,
    this.color = NoteColorPreset.plain,
  });

  /// Room the dock takes over the paper, above the system inset.
  static const extent = 80.0;

  final VoidCallback? onEdit;
  final VoidCallback? onAi;

  /// The note's other actions, e.g. a [NoteActionsMenu].
  final Widget actions;

  /// The note's color, which tints Edit so it matches the paper.
  final NoteColorPreset color;

  @override
  Widget build(BuildContext context) => NoteChromeTheme(
    child: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final accent = color.accentOn(colors.surface, primary: colors.primary);
        final onAccent =
            ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : const Color(0xff1c1b19);
        // Narrow screens and large text keep Edit as an icon.
        final compact =
            MediaQuery.sizeOf(context).width < 340 ||
            MediaQuery.textScalerOf(context).scale(14) / 14 > 1.4;
        final edit = Tooltip(
          message: 'Edit note',
          excludeFromSemantics: !compact,
          child: compact
              ? IconButton.filled(
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: onAccent,
                    minimumSize: const Size.square(48),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                )
              : FilledButton.icon(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: onAccent,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  label: const Text('Edit'),
                ),
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.paddingOf(context).bottom + 8,
            ),
            child: DecoratedBox(
              key: const ValueKey('note-read-dock'),
              decoration: ShapeDecoration(
                color: colors.surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .5),
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: .14),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: NoteBottomMorph(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NoteAiButton(onPressed: onAi),
                      const SizedBox(width: 8),
                      edit,
                      const SizedBox(width: 8),
                      actions,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
