import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../domain/note_colors.dart';

/// A single scrolling row of paper swatches, each showing a stroke of the ink
/// the note would use, so the whole palette fits in one line.
class NoteColorStrip extends StatefulWidget {
  const NoteColorStrip({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final NoteColorPreset selected;
  final ValueChanged<NoteColorPreset> onSelected;

  @override
  State<NoteColorStrip> createState() => _NoteColorStripState();
}

class _NoteColorStripState extends State<NoteColorStrip> {
  static const _disc = 56.0;
  static const _gap = 12.0;
  static const _extent = _disc + _gap;
  static const _strip = _disc + 16;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Bring the current color into view so it is visible without scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final index = NoteColors.presets.indexOf(widget.selected);
      final centered =
          index * _extent - (position.viewportDimension - _extent) / 2;
      _scroll.jumpTo(centered.clamp(0, position.maxScrollExtent).toDouble());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policy = context
        .dependOnInheritedWidgetOfExactType<RenderingPolicyScope>()
        ?.policy;
    final duration =
        policy?.duration ??
        (MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : RenderingPolicy.standardDuration);
    final simple = policy?.simplerEffects ?? false;
    final selected = widget.selected;

    final strip = SizedBox(
      height: _strip,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        itemExtent: _extent,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: NoteColors.presets.length,
        itemBuilder: (context, index) {
          final preset = NoteColors.presets[index];
          return Center(
            child: _Swatch(
              preset: preset,
              selected: preset == selected,
              duration: duration,
              size: _disc,
              onTap: () => widget.onSelected(preset),
            ),
          );
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Color',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: duration,
                layoutBuilder: (current, previous) => Stack(
                  alignment: AlignmentDirectional.centerEnd,
                  children: [...previous, ?current],
                ),
                child: Text(
                  '${selected.label} · ${selected.description}',
                  key: ValueKey(selected),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (simple)
          strip
        else
          // Fade the trailing edge to hint that more paper lies beyond.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0, .9, 1],
            ).createShader(bounds),
            child: strip,
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.preset,
    required this.selected,
    required this.duration,
    required this.size,
    required this.onTap,
  });

  final NoteColorPreset preset;
  final bool selected;
  final Duration duration;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = preset.resolveColors(scheme);
    final plain = preset == NoteColors.plain;
    return Tooltip(
      message: preset.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${preset.label}, ${preset.description}',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            padding: EdgeInsets.all(selected ? 4 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                shape: BoxShape.circle,
                // A hairline keeps pale paper visible on a pale sheet.
                border: Border.all(
                  color: plain
                      ? scheme.outlineVariant
                      : scheme.outlineVariant.withValues(alpha: .45),
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: duration,
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          key: const ValueKey(true),
                          size: 24,
                          color: colors.foreground,
                        )
                      : CustomPaint(
                          key: const ValueKey(false),
                          size: const Size(24, 12),
                          painter: _InkStroke(colors.foreground),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small hand-written squiggle in the note's ink color.
class _InkStroke extends CustomPainter {
  const _InkStroke(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(0, size.height / 2);
    for (var x = 0.0; x <= size.width; x += 1) {
      path.lineTo(
        x,
        size.height / 2 +
            math.sin(x / size.width * math.pi * 2.5) * size.height * .3,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_InkStroke oldDelegate) => oldDelegate.color != color;
}
