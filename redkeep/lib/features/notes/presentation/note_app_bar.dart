import 'package:flutter/material.dart';

import 'note_scene.dart';

/// The one app bar of [NotePage], shared by reading and editing so switching
/// between them keeps the same back button over the same paper.
class NoteAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NoteAppBar({
    super.key,
    required this.onBack,
    this.actions = const [],
    this.backTooltip = 'Back',
  });

  final VoidCallback? onBack;
  final String backTooltip;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: Colors.transparent,
    // Painted exactly like the paper surface so the two read as one sheet.
    flexibleSpace: Builder(
      builder: (context) => FadeTransition(
        opacity: NotePaperOpacity.of(context),
        child: ColoredBox(
          color: Theme.of(context).appBarTheme.backgroundColor!,
          child: const SizedBox.expand(),
        ),
      ),
    ),
    // Room for the 12px inset plus the full 48px round button.
    leadingWidth: 60,
    leading: Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: IconButton(
          tooltip: backTooltip,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          style: noteBarButtonStyle(context),
          onPressed: onBack,
        ),
      ),
    ),
    actions: [...actions, const SizedBox(width: 12)],
  );
}

/// The round button style of a note page's controls (back, more, Maester).
/// Neutral, in the app's own colors, whatever the note's paper.
ButtonStyle noteBarButtonStyle(BuildContext context) {
  final colors = NoteChrome.of(context).colorScheme;
  return IconButton.styleFrom(
    // Plain paper is the app's surfaceContainerHigh, so the lighter surface
    // and a hairline keep the button visible on every paper.
    backgroundColor: colors.surface,
    foregroundColor: colors.onSurface,
    side: BorderSide(color: colors.outlineVariant.withValues(alpha: .7)),
    minimumSize: const Size.square(48),
  );
}

/// Opens the note's AI tools with the Maester mark.
class NoteAiButton extends StatelessWidget {
  const NoteAiButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'AI tools',
  });
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: noteBarButtonStyle(context)
        .copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.all(4))),
    icon: Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: Image.asset(
        'assets/branding/grand_maestar.png',
        width: 40,
        height: 40,
        excludeFromSemantics: true,
      ),
    ),
  );
}
