import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/pillow_material.dart' show LiquidMotion;
import '../../sync/presentation/sync_material.dart';
import '../domain/appearance_preferences.dart';

/// A few choices on one cushion, with a drop of the accent's liquid glass
/// under the chosen one. The drop flows to a new choice. Choices sit in a row
/// with their icon above the name; large text stacks them.
class GlassSegments<T> extends StatefulWidget {
  const GlassSegments({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.onSelected,
    this.semanticLabelOf,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final IconData Function(T value) iconOf;

  /// Null while the choice cannot change.
  final ValueChanged<T>? onSelected;

  /// A spoken name that replaces the visible one.
  final String? Function(T value)? semanticLabelOf;

  @override
  State<GlassSegments<T>> createState() => _GlassSegmentsState<T>();
}

class _GlassSegmentsState<T> extends State<GlassSegments<T>>
    with SingleTickerProviderStateMixin {
  static const _pad = 6.0;
  static const _gap = 4.0;

  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    value: 1,
  );
  late int _to = widget.values.indexOf(widget.selected);
  late int _from = _to;
  Rect? _fromRect;
  List<Rect> _slots = const [];

  @override
  void didUpdateWidget(GlassSegments<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.values.indexOf(widget.selected);
    if (next == _to) return;
    // Start from wherever the drop is now, even mid-flow.
    _fromRect = _slots.isEmpty ? null : _dropAt(_move.value);
    _from = _to;
    _to = next;
    if (RenderingPolicyScope.of(context).animate) {
      _move.forward(from: 0);
    } else {
      _move.value = 1;
    }
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  Rect _dropAt(double t) {
    final to = _slots[_to];
    final from = _fromRect ?? _slots[_from];
    return t >= 1 ? to : LiquidMotion.between(from, to, t);
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = CushionColors.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final enabled = widget.onSelected != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = widget.values.length;
        final inner = constraints.maxWidth - 2 * _pad;
        final line = scaler.scale(14) * 1.25;
        final stacked =
            scaler.scale(14) > 20 || (inner - _gap * (count - 1)) / count < 84;
        final slotWidth = stacked
            ? inner
            : (inner - _gap * (count - 1)) / count;
        final slotHeight = stacked
            ? math.max(56.0, line + 26)
            : math.max(72.0, 24 + 6 + line + 24);
        final rtl = Directionality.of(context) == TextDirection.rtl;
        _slots = [
          for (var i = 0; i < count; i++)
            stacked
                ? Rect.fromLTWH(
                    _pad,
                    _pad + i * (slotHeight + _gap),
                    slotWidth,
                    slotHeight,
                  )
                : Rect.fromLTWH(
                    _pad + (rtl ? count - 1 - i : i) * (slotWidth + _gap),
                    _pad,
                    slotWidth,
                    slotHeight,
                  ),
        ];
        final size = Size(
          constraints.maxWidth,
          stacked
              ? 2 * _pad + count * slotHeight + (count - 1) * _gap
              : 2 * _pad + slotHeight,
        );
        final radius = stacked ? 24.0 : size.height / 2;
        return SizedBox.fromSize(
          size: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CushionPainter(
                      colors: colors,
                      radius: radius,
                      stitched: false,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _DropPainter(
                      move: _move,
                      dropAt: _dropAt,
                      slots: _slots,
                      colors: colors,
                      radius: radius - _pad,
                      enabled: enabled,
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < count; i++)
                Positioned.fromRect(
                  rect: _slots[i],
                  child: _segment(i, stacked, palette, enabled),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _segment(int i, bool stacked, MorePalette palette, bool enabled) {
    final value = widget.values[i];
    final selected = i == _to;
    final color = !enabled
        ? palette.muted.withValues(alpha: .6)
        : selected
        ? palette.accent
        : palette.muted;
    final spoken = widget.semanticLabelOf?.call(value);
    final duration = RenderingPolicyScope.of(context).duration;
    final label = AnimatedDefaultTextStyle(
      duration: duration,
      style: TextStyle(
        color: selected && enabled ? palette.ink : palette.muted,
        fontSize: 14,
        height: 1.2,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      child: Text(
        widget.labelOf(value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
    final icon = TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1 : 0),
      duration: RenderingPolicyScope.of(context).animate
          ? const Duration(milliseconds: 520)
          : Duration.zero,
      curve: const ElasticOutCurve(.5),
      builder: (context, t, child) =>
          Transform.scale(scale: 1 + .18 * t, child: child),
      child: Icon(widget.iconOf(value), size: 22, color: color),
    );
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      label: spoken,
      excludeSemantics: spoken != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => widget.onSelected!(value) : null,
        child: stacked
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: label),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [icon, const SizedBox(height: 6), label],
              ),
      ),
    );
  }
}

class _DropPainter extends CustomPainter {
  _DropPainter({
    required this.move,
    required this.dropAt,
    required this.slots,
    required this.colors,
    required this.radius,
    required this.enabled,
  }) : super(repaint: move);

  final Animation<double> move;
  final Rect Function(double t) dropAt;
  final List<Rect> slots;
  final CushionColors colors;
  final double radius;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (slots.isEmpty) return;
    final rect = dropAt(move.value);
    if (rect.width <= 0 || rect.height <= 0) return;
    paintGlass(
      canvas,
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(math.min(radius, rect.shortestSide / 2)),
      ),
      colors: colors,
      tint: colors.tint,
      fill: colors.dark ? .2 : .14,
      strength: enabled ? 1 : .4,
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) =>
      move != old.move ||
      colors != old.colors ||
      radius != old.radius ||
      enabled != old.enabled ||
      !_same(slots, old.slots);

  static bool _same(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Every accent as a bead of coloured glass resting in a dimple on one
/// cushion. The chosen bead swells up out of its dimple and glows.
class AccentTray extends StatelessWidget {
  const AccentTray({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AppAccent selected;
  final ValueChanged<AppAccent>? onSelected;

  static const _cell = 52.0;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = CushionColors.of(context);
    final policy = RenderingPolicyScope.of(context);
    const accents = AppAccent.values;
    return CustomPaint(
      painter: CushionPainter(colors: colors),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth / accents.length >= _cell
                ? accents.length
                : 3;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var start = 0; start < accents.length; start += columns)
                  Row(
                    children: [
                      for (final accent in accents.skip(start).take(columns))
                        Expanded(
                          child: _AccentBead(
                            accent: accent,
                            selected: accent == selected,
                            onTap: onSelected == null
                                ? null
                                : () => onSelected!(accent),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: policy.duration,
                  child: Text(
                    selected.label,
                    key: ValueKey(selected),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 14,
                      height: 1.3,
                      letterSpacing: .2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccentBead extends StatelessWidget {
  const _AccentBead({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CushionColors.of(context);
    final policy = RenderingPolicyScope.of(context);
    final color = colors.dark ? accent.darkPrimary : accent.seed;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: '${accent.label}: ${accent.description}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Springy(
          enabled: onTap != null,
          depth: .12,
          child: SizedBox(
            height: AccentTray._cell,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: selected ? 1 : 0),
              duration: policy.animate
                  ? const Duration(milliseconds: 640)
                  : Duration.zero,
              curve: const ElasticOutCurve(.45),
              builder: (context, rise, _) => CustomPaint(
                painter: _BeadPainter(colors: colors, color: color, rise: rise),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BeadPainter extends CustomPainter {
  const _BeadPainter({
    required this.colors,
    required this.color,
    required this.rise,
  });

  final CushionColors colors;
  final Color color;

  /// 0 resting in its dimple, 1 swollen up and lit.
  final double rise;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    paintDimple(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromCircle(center: centre.translate(0, 1), radius: 15),
        const Radius.circular(15),
      ),
      colors,
    );
    final r = 12 + 6.5 * rise;
    final lifted = centre.translate(0, -2.5 * rise);
    if (rise > 0 && !colors.simple) {
      final reach = r * 1.7;
      canvas.drawCircle(
        lifted,
        reach,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: .5 * rise.clamp(0.0, 1.0)),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: lifted, radius: reach)),
      );
    }
    paintGlass(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromCircle(center: lifted, radius: r),
        Radius.circular(r),
      ),
      colors: colors,
      tint: color,
      fill: 1,
      lift: .4 + rise,
    );
    if (rise > .5) {
      // A ring of light round the chosen bead.
      canvas.drawCircle(
        lifted,
        r + 3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: ((rise - .5) * 2).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_BeadPainter old) =>
      colors != old.colors || color != old.color || rise != old.rise;
}

/// An on/off setting as a cushion of its own: the whole cushion is the switch,
/// glowing with the accent when on.
class CushionToggle extends StatelessWidget {
  const CushionToggle({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.switchKey,
  });

  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = CushionColors.of(context, strength: value ? .18 : 0);
    final enabled = onChanged != null;
    void toggle() => onChanged?.call(!value);
    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: title,
      excludeSemantics: true,
      onTap: enabled ? toggle : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? toggle : null,
        child: Springy(
          enabled: enabled,
          child: CustomPaint(
            painter: CushionPainter(
              colors: colors,
              glow: value ? Alignment.topLeft : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: value ? palette.accent : palette.muted,
                      ),
                      const Spacer(),
                      GlassSwitch(
                        key: switchKey,
                        value: value,
                        enabled: enabled,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
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

/// A groove pressed into the cushion, and a glass bead that flows along it,
/// filling with the accent when on. Purely visual.
class GlassSwitch extends StatefulWidget {
  const GlassSwitch({super.key, required this.value, this.enabled = true});

  final bool value;
  final bool enabled;

  @override
  State<GlassSwitch> createState() => _GlassSwitchState();
}

class _GlassSwitchState extends State<GlassSwitch>
    with SingleTickerProviderStateMixin {
  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
    value: 1,
  );
  late bool _to = widget.value;

  @override
  void didUpdateWidget(GlassSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _to) return;
    _to = widget.value;
    if (RenderingPolicyScope.of(context).animate) {
      _move.forward(from: 0);
    } else {
      _move.value = 1;
    }
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: const Size(52, 30),
      painter: _SwitchPainter(
        move: _move,
        on: _to,
        enabled: widget.enabled,
        colors: CushionColors.of(context),
        off: MorePalette.of(context).muted,
      ),
    ),
  );
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter({
    required this.move,
    required this.on,
    required this.enabled,
    required this.colors,
    required this.off,
  }) : super(repaint: move);

  final Animation<double> move;
  final bool on;
  final bool enabled;
  final CushionColors colors;
  final Color off;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final t = move.value;
    final glow = on
        ? Curves.easeOut.transform(t)
        : 1 - Curves.easeOut.transform(t);
    canvas.drawRRect(
      track,
      Paint()
        ..color = colors.tint.withValues(
          alpha: (colors.dark ? .28 : .2) * glow * (enabled ? 1 : .4),
        ),
    );
    paintDimple(canvas, track, colors);
    const inset = 3.0;
    final knob = size.height - 2 * inset;
    final left = Rect.fromLTWH(inset, inset, knob, knob);
    final right = Rect.fromLTWH(size.width - inset - knob, inset, knob, knob);
    final rect = LiquidMotion.between(on ? left : right, on ? right : left, t);
    paintGlass(
      canvas,
      RRect.fromRectAndRadius(rect, Radius.circular(knob / 2)),
      colors: colors,
      tint: on ? colors.tint : off,
      fill: on ? .85 : .25,
      strength: enabled ? 1 : .4,
    );
  }

  @override
  bool shouldRepaint(_SwitchPainter old) =>
      move != old.move ||
      on != old.on ||
      enabled != old.enabled ||
      colors != old.colors ||
      off != old.off;
}
