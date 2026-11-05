import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../domain/diary_day_details.dart';
import 'diary_paper_stamp.dart';
import 'photos/diary_ink_action.dart';

const diaryMaestarAsset = 'assets/branding/grand_maestar.png';

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

/// Five faces to circle. Tapping the circled one again rubs it out.
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
    Widget face(DiaryMood mood) => _MoodFace(
      key: ValueKey('diary-day-mood-${mood.name}'),
      mood: mood,
      selected: selected == mood,
      onPressed: onChanged == null
          ? null
          : () => onChanged!(selected == mood ? null : mood),
    );
    // Five across only fits while the labels stay small.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Wrap(
        spacing: 4,
        runSpacing: 8,
        children: [
          for (final mood in DiaryMood.values)
            SizedBox(width: 96, child: face(mood)),
        ],
      );
    }
    return Row(
      children: [
        for (final mood in DiaryMood.values) Expanded(child: face(mood)),
      ],
    );
  }
}

class _MoodFace extends StatelessWidget {
  const _MoodFace({
    super.key,
    required this.mood,
    required this.selected,
    required this.onPressed,
  });

  final DiaryMood mood;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    final colors = Theme.of(context).colorScheme;
    return DiaryInkAction(
      label: mood.label,
      selected: selected,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 56,
              child: CustomPaint(
                painter: selected
                    ? _InkCircle(color: colors.primary, seed: mood.index)
                    : null,
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? 1.1 : 1,
                    duration: policy.duration,
                    curve: Curves.easeOutBack,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1,
                      child: Text(
                        mood.emoji,
                        style: const TextStyle(fontSize: 30, height: 1.1),
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
                mood.label,
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

/// A theme on a torn paper tag, set slightly askew unless effects are simple.
class DiaryThemeTag extends StatelessWidget {
  const DiaryThemeTag({
    super.key,
    required this.theme,
    required this.index,
    required this.onRemove,
  });

  static const _tilts = [-.012, .009, -.006];

  final String theme;
  final int index;

  /// Null while the page can't be edited.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final colors = Theme.of(context).colorScheme;
    final tag = CustomPaint(
      painter: DiaryPaperStamp(
        paper: colors.surfaceContainerHigh,
        ink: colors.onSurface,
        shadowColor: colors.shadow,
        variant: index,
        edgeScale: simple ? 0 : .22,
        shadow: !simple,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 96,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 14,
                  top: 8,
                  bottom: 8,
                ),
                child: Text(
                  theme,
                  style: DiaryTypography.of(context).body.copyWith(
                    color: colors.onSurface,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            DiaryInkAction(
              key: ValueKey('diary-day-theme-remove-$theme'),
              label: 'Remove theme $theme',
              onPressed: onRemove,
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (simple) return tag;
    return Transform.rotate(angle: _tilts[index % _tilts.length], child: tag);
  }
}

/// The Grand Maestar at the foot of the page, offering to read it.
class DiaryMaestarNote extends StatelessWidget {
  const DiaryMaestarNote({
    super.key,
    required this.kindName,
    required this.onPressed,
  });

  static const _portrait = 78.0;

  final String kindName;

  /// Null while suggestions can't be asked for.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final colors = Theme.of(context).colorScheme;
    final portrait = Image.asset(
      diaryMaestarAsset,
      key: const ValueKey('diary-day-maestar'),
      width: _portrait,
      height: _portrait,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      cacheWidth: (_portrait * MediaQuery.devicePixelRatioOf(context)).ceil(),
    );
    // Capped so the whole note stays on screen, and so one tap always lands.
    final slip = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: CustomPaint(
        painter: DiaryPaperStamp(
          paper: colors.surfaceContainerHigh,
          ink: colors.onSurface,
          shadowColor: colors.shadow,
          variant: 2,
          edgeScale: simple ? 0 : .35,
          shadow: !simple,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stuck for words?',
                style: DiaryTypography.of(context).title
                    .copyWith(color: colors.primary, fontSize: 23, height: 1.2),
              ),
              const SizedBox(height: 2),
              Text(
                "Let me read this $kindName's entries and suggest. You choose what to keep.",
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Opacity(
      opacity: onPressed == null ? .55 : 1,
      child: DiaryInkAction(
        key: const ValueKey('diary-day-ai'),
        label:
            'Ask the Grand Maestar to suggest a title, mood and themes for this $kindName',
        onPressed: onPressed,
        // Large text needs the width the portrait would take.
        child: MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [portrait, const SizedBox(height: 6), slip],
              )
            : Row(
                children: [
                  portrait,
                  const SizedBox(width: 6),
                  Expanded(child: slip),
                ],
              ),
      ),
    );
  }
}

/// Marks a field the Grand Maestar filled in until it is edited by hand.
class DiaryMaestarMark extends StatelessWidget {
  const DiaryMaestarMark({super.key});

  static const _size = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            diaryMaestarAsset,
            width: _size,
            height: _size,
            excludeFromSemantics: true,
            cacheWidth: (_size * MediaQuery.devicePixelRatioOf(context)).ceil(),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Suggested by the Grand Maestar',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
