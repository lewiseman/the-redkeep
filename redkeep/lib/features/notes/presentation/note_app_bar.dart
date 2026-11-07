import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';

import 'note_scene.dart';

/// The one app bar of [NotePage], shared by reading and editing so switching
/// between them keeps the same back button, AI button, and paper fill.
class NoteAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NoteAppBar({
    super.key,
    required this.onBack,
    required this.actions,
    this.backTooltip = 'Back',
    this.fill = 1,
  });

  final VoidCallback? onBack;
  final String backTooltip;
  final List<Widget> actions;

  /// How much of the paper surface the bar paints: zero lets the note scene
  /// show through (folded preview), one continues flat paper under the bar.
  final double fill;

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
          color: Theme.of(context).appBarTheme.backgroundColor!
              .withValues(alpha: fill.clamp(0, 1)),
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

/// The round surface button style of the note bar (back and more).
ButtonStyle noteBarButtonStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return IconButton.styleFrom(
    backgroundColor: colors.surface,
    foregroundColor: colors.onSurface,
    minimumSize: const Size.square(48),
  );
}

/// Opens the note's AI tools with the Maester mark.
class NoteAiButton extends StatelessWidget {
  const NoteAiButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'AI tools',
    child: Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Opacity(
          opacity: onPressed == null ? .5 : 1,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/branding/grand_maestar.png',
              width: 40,
              height: 40,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Eases an editing-only action into the bar when editing starts, instead of
/// it popping in. Appears at once with reduced motion.
class NoteBarEntrance extends StatelessWidget {
  const NoteBarEntrance({super.key, required this.child});
  final Widget child;

  static const _duration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    if (!RenderingPolicyScope.of(context).animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: .9 + .1 * t, child: child),
      ),
    );
  }
}
