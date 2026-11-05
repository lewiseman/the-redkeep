import 'package:flutter/material.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import 'diary_paper_stamp.dart';
import 'photos/diary_ink_action.dart';
import 'diary_writing_paper.dart';

/// Asks before unsaved writing is lost, on a scrap of the diary's own paper.
///
/// Keeping the writing is the prominent choice, so a reflexive tap is safe.
/// A saved entry only loses the latest edits, and the wording says so.
Future<bool> confirmDiscardWriting(
  BuildContext context, {
  required bool newEntry,
}) => _confirm(
  context,
  title: newEntry ? 'Discard this writing?' : 'Discard your edits?',
  body: newEntry
      ? "What you've written here hasn't been saved and will be lost."
      : 'Your saved entry will stay as it was.',
  keep: 'Keep writing',
);

/// The same question for a day's title, mood and themes.
Future<bool> confirmDiscardDetails(
  BuildContext context, {
  required String kindName,
}) => _confirm(
  context,
  title: 'Discard these changes?',
  body: "This $kindName's title, mood and themes will stay as they were.",
  keep: 'Keep editing',
);

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String keep,
}) async =>
    await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (context) =>
          _DiscardDialog(title: title, body: body, keep: keep),
    ) ??
    false;

class _DiscardDialog extends StatelessWidget {
  const _DiscardDialog({
    required this.title,
    required this.body,
    required this.keep,
  });

  final String title, body, keep;

  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: CustomPaint(
            painter: DiaryPaperStamp(
              paper: colors.surface,
              ink: colors.onSurface,
              shadowColor: colors.shadow,
              edgeScale: simple ? 0 : .8,
              shadow: !simple,
            ),
            // Every control scrolls into reach at large text.
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: DiaryTypography.of(context).title
                          .copyWith(color: colors.onSurface, fontSize: 30),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DiaryPenLine(
                    color: colors.onSurfaceVariant.withValues(alpha: .5),
                    reach: .62,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    body,
                    style: DiaryTypography.of(context).body.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _DiscardActions(
                    keep: keep,
                    onKeep: () => Navigator.pop(context, false),
                    onDiscard: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Side by side with the safe choice under the thumb, stacked with it first
/// when large text needs the room.
class _DiscardActions extends StatelessWidget {
  const _DiscardActions({
    required this.keep,
    required this.onKeep,
    required this.onDiscard,
  });

  final String keep;
  final VoidCallback onKeep, onDiscard;

  @override
  Widget build(BuildContext context) {
    final keepSlip = DiaryInkSlip(label: keep, onPressed: onKeep);
    final discard = _DiscardWord(onPressed: onDiscard);
    // The labels start large. Capped, they stay big enough to read at any
    // setting while still fitting inside the dialog on a small screen.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.6,
      child: MediaQuery.textScalerOf(context).scale(1) > 1.25
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [keepSlip, const SizedBox(height: 6), discard],
            )
          : Row(
              children: [
                Expanded(flex: 2, child: discard),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: keepSlip),
              ],
            ),
    );
  }
}

TextStyle _actionStyle(BuildContext context, Color color) =>
    DiaryTypography.of(context).title
        .copyWith(color: color, fontSize: 23, height: 1.15);

/// The destructive choice is only a word in red pen, underlined by hand.
class _DiscardWord extends StatelessWidget {
  const _DiscardWord({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DiaryInkAction(
      label: 'Discard',
      onPressed: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Discard',
                    textAlign: TextAlign.center,
                    style: _actionStyle(context, colors.error),
                  ),
                  DiaryPenLine(
                    color: colors.error.withValues(alpha: .7),
                    stroke: 5,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
