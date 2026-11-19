import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../domain/diary_day_details.dart';
import 'diary_emoji_picker_sheet.dart';
import 'photos/diary_ink_action.dart';

/// A question in the diary's hand, with an optional quiet action beside it.
class DiaryDetailsLabel extends StatelessWidget {
  const DiaryDetailsLabel({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: DiaryTypography.of(context).title.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 25,
                height: 1.2,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Five faces to circle, plus any other emoji. Tapping a circled face again
/// rubs it out; the last slot always opens the full picker.
class DiaryMoodPicker extends StatelessWidget {
  const DiaryMoodPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DiaryMood? selected;

  /// Null while the page can't be edited.
  final ValueChanged<DiaryMood?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    Widget face(DiaryMood mood) => _MoodFace(
      key: ValueKey('diary-day-mood-${mood.name}'),
      emoji: mood.emoji,
      label: mood.label,
      semanticsLabel: mood.label,
      seed: DiaryMood.values.indexOf(mood),
      selected: selected == mood,
      onPressed: onChanged == null
          ? null
          : () => onChanged(selected == mood ? null : mood),
    );
    final custom = selected?.isPreset == false ? selected : null;
    final other = _MoodFace(
      key: const ValueKey('diary-day-mood-other'),
      emoji: custom?.emoji,
      label: 'Other',
      semanticsLabel: custom == null
          ? 'Pick any emoji'
          : '${custom.emoji} mood. Pick another emoji',
      seed: custom == null ? 5 : custom.emoji.runes.first % 97,
      selected: custom != null,
      onPressed: onChanged == null
          ? null
          : () async {
              final picked = await showDiaryEmojiPicker(context);
              if (picked != null && context.mounted) onChanged(picked);
            },
    );
    // Six across only fits while the labels stay small.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Wrap(
        spacing: 4,
        runSpacing: 8,
        children: [
          for (final mood in DiaryMood.values)
            SizedBox(width: 96, child: face(mood)),
          SizedBox(width: 96, child: other),
        ],
      );
    }
    return Row(
      children: [
        for (final mood in DiaryMood.values) Expanded(child: face(mood)),
        Expanded(child: other),
      ],
    );
  }
}

class _MoodFace extends StatelessWidget {
  const _MoodFace({
    super.key,
    required this.emoji,
    required this.label,
    required this.semanticsLabel,
    required this.seed,
    required this.selected,
    required this.onPressed,
  });

  /// Null shows the "pick an emoji" mark instead.
  final String? emoji;
  final String label, semanticsLabel;
  final int seed;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    final colors = Theme.of(context).colorScheme;
    return DiaryInkAction(
      label: semanticsLabel,
      selected: selected,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Six faces share 320px, so the circle may shrink a little.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox.square(
                dimension: 56,
                child: CustomPaint(
                  painter: selected
                      ? _InkCircle(color: colors.primary, seed: seed)
                      : null,
                  child: Center(
                    child: AnimatedScale(
                      scale: selected ? 1.1 : 1,
                      duration: policy.duration,
                      curve: Curves.easeOutBack,
                      child: emoji == null
                          ? Icon(
                              Icons.add_reaction_outlined,
                              size: 28,
                              color: colors.onSurfaceVariant,
                            )
                          : MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1,
                              child: Text(
                                emoji!,
                                style: const TextStyle(
                                  fontSize: 30,
                                  height: 1.1,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A circle drawn in one go, overshooting where the pen started.
class _InkCircle extends CustomPainter {
  const _InkCircle({required this.color, required this.seed});

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(4099 + seed * 131);
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final phase = random.nextDouble() * math.pi;
    const steps = 44;
    final path = Path();
    for (var step = 0; step <= steps; step++) {
      final t = step / steps;
      final angle = -math.pi * .65 + t * math.pi * 2.14;
      final wobble =
          math.sin(angle * 2 + phase) * 1.3 + math.sin(angle * 5 + seed) * .4;
      // The ends of the stroke sit slightly apart, as a hand-drawn ring does.
      final reach = radius + wobble + t * 1.6;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * reach;
      step == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: .09),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_InkCircle oldDelegate) =>
      color != oldDelegate.color || seed != oldDelegate.seed;
}

/// The result of [showDiaryMoodSheet]: the mood to keep, null to clear it.
typedef DiaryMoodChoice = ({DiaryMood? mood});

/// Asks how a day felt. Resolves to the new choice, or null when dismissed.
/// Tapping the circled face again clears the mood.
Future<DiaryMoodChoice?> showDiaryMoodSheet(
  BuildContext context, {
  required String dateLabel,
  DiaryMood? current,
}) => showModalBottomSheet<DiaryMoodChoice>(
  context: context,
  // Above the shell's floating bar.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (context) => SingleChildScrollView(
    key: const ValueKey('diary-mood-sheet'),
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          dateLabel,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        const DiaryDetailsLabel(text: 'How did it feel?'),
        const SizedBox(height: 12),
        DiaryMoodPicker(
          selected: current,
          onChanged: (mood) => Navigator.of(context).pop((mood: mood)),
        ),
      ],
    ),
  ),
);
