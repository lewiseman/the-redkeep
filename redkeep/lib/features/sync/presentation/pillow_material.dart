import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import 'tome_material.dart';

/// Materials for the opened book's page, in the same language as the app's
/// bottom bar: stuffed paper pillows stitched onto the vellum, and drops of
/// red liquid glass that flow between choices.
///
/// Everything is painted with gradients and crisp, stacked offsets for
/// shadows: no blurs and no backdrop sampling. Pillows never animate, so
/// each sits in its own cached layer; only a moving drop repaints.

/// A paper pillow: lofted in the middle, shaded at the hem, a running stitch
/// round its edge and a glassy lip.
class PillowPainter extends CustomPainter {
  const PillowPainter({
    required this.parchment,
    required this.radius,
    this.stitched = true,
    this.simple = false,
    this.lift = 1,
    this.fill,
  });

  final Parchment parchment;
  final double radius;
  final bool stitched;
  final bool simple;

  /// How proud of the page it sits: 0 is pressed flat.
  final double lift;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final r = math.min(radius, size.shortestSide / 2);
    final body = RRect.fromRectAndRadius(rect, Radius.circular(r));
    final paper = fill ?? parchment.pillow;
    final edge = parchment.fiber;

    if (simple) {
      canvas.drawRRect(body, Paint()..color = paper);
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = edge.withValues(alpha: .35),
      );
      return;
    }

    // Cut-paper shadow: a wide soft step and a tight contact line.
    canvas.drawRRect(
      body.shift(Offset(0, 1 + 3 * lift)),
      Paint()..color = parchment.shadow.withValues(alpha: .08),
    );
    canvas.drawRRect(
      body.shift(Offset(0, .6 + 1.2 * lift)),
      Paint()..color = parchment.shadow.withValues(alpha: .16),
    );

    // The puffed body: bright crown, shaded hem.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(paper, Colors.white, .45)!,
            paper,
            Color.lerp(paper, parchment.aged, .45)!,
          ],
          stops: const [0, .45, 1],
        ).createShader(rect),
    );
    // Loft: an elliptical pool of light high on the cushion.
    canvas.save();
    canvas.clipRRect(body);
    final loft = math.min(size.height, 120.0);
    canvas.translate(size.width / 2, size.height * .12);
    canvas.scale(size.width * .6 / loft, 1);
    canvas.drawCircle(
      Offset.zero,
      loft,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: .42),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: loft)),
    );
    canvas.restore();

    if (stitched) _stitch(canvas, body.deflate(math.min(7.0, r * .45 + 3)));

    // Glassy lip: bright along the top, bounce light along the bottom.
    canvas.drawRRect(
      body.deflate(.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .95),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .35),
          ],
          stops: const [0, .3, .8, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = edge.withValues(alpha: .38),
    );
  }

  void _stitch(Canvas canvas, RRect hem) {
    if (hem.width <= 8 || hem.height <= 8) return;
    final stitches = Path();
    for (final metric in (Path()..addRRect(hem)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        stitches.addPath(metric.extractPath(d, d + 4.5), Offset.zero);
      }
    }
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1;
    canvas.drawPath(
      stitches.shift(const Offset(0, .8)),
      thread..color = Colors.white.withValues(alpha: .7),
    );
    canvas.drawPath(
      stitches,
      thread..color = parchment.faded.withValues(alpha: .5),
    );
  }

  @override
  bool shouldRepaint(PillowPainter oldDelegate) =>
      radius != oldDelegate.radius ||
      stitched != oldDelegate.stitched ||
      simple != oldDelegate.simple ||
      lift != oldDelegate.lift ||
      fill != oldDelegate.fill;
}

/// [child] on a paper pillow sewn to the page.
class Pillow extends StatelessWidget {
  const Pillow({
    super.key,
    required this.child,
    this.radius = 22,
    this.stitched = true,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final double radius;
  final bool stitched;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: PillowPainter(
      parchment: Parchment.of(context),
      radius: radius,
      stitched: stitched,
      simple: RenderingPolicyScope.of(context).simplerEffects,
    ),
    // Ripples land on the pillow, clipped to it, not hidden beneath it.
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// A drop of red liquid glass: tinted body, a specular band across its crown,
/// a bright rim above and refracted colour beneath.
void paintGel(
  Canvas canvas,
  RRect drop, {
  required Parchment parchment,
  required Color tint,
  bool simple = false,
  double lift = 1,
  double strength = 1,
}) {
  final body = Color.alphaBlend(
    tint.withValues(alpha: .16 * strength),
    parchment.pillow,
  );
  if (simple) {
    canvas.drawRRect(drop, Paint()..color = body);
    canvas.drawRRect(
      drop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tint.withValues(alpha: .45 * strength),
    );
    return;
  }
  final rect = drop.outerRect;
  final under = Color.lerp(tint, Colors.black, .5)!;
  canvas.drawRRect(
    drop.shift(Offset(0, 1 + 2.5 * lift)),
    Paint()..color = under.withValues(alpha: .10 * strength),
  );
  canvas.drawRRect(
    drop.shift(Offset(0, .5 + lift)),
    Paint()..color = under.withValues(alpha: .18 * strength),
  );
  canvas.drawRRect(
    drop,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.3, -.9),
        radius: 1.25,
        colors: [
          Color.lerp(body, Colors.white, .6)!,
          body,
          Color.lerp(body, tint, .22 * strength)!,
        ],
        stops: const [0, .55, 1],
      ).createShader(rect),
  );
  // The specular band, the tell of glass.
  final h = rect.height;
  final band = RRect.fromLTRBR(
    rect.left + math.min(h * .32, rect.width * .2),
    rect.top + 2,
    rect.right - math.min(h * .32, rect.width * .2),
    rect.top + h * .42,
    Radius.circular(h * .2),
  );
  if (band.width > 2 && band.height > 1) {
    canvas.drawRRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .75),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(band.outerRect),
    );
  }
  // Rim: bright lip above, tint refracted into the base.
  canvas.drawRRect(
    drop.deflate(.6),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: .95),
          Colors.white.withValues(alpha: 0),
          tint.withValues(alpha: 0),
          tint.withValues(alpha: .5 * strength),
        ],
        stops: const [0, .42, .62, 1],
      ).createShader(rect),
  );
  canvas.drawRRect(
    drop,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = tint.withValues(alpha: .38 * strength),
  );
}

/// A finger's dimple pressed into a pillow.
void paintDent(Canvas canvas, RRect dent, Parchment parchment, double depth) {
  if (depth <= 0) return;
  canvas.drawRRect(
    dent,
    Paint()..color = parchment.shadow.withValues(alpha: .07 * depth),
  );
  canvas.drawRRect(
    dent.deflate(.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          parchment.shadow.withValues(alpha: .22 * depth),
          parchment.shadow.withValues(alpha: 0),
          Colors.white.withValues(alpha: .6 * depth),
        ],
        stops: const [0, .5, 1],
      ).createShader(dent.outerRect),
  );
}

/// How a drop flows from one place to another: its leading edge races ahead
/// and its trailing edge catches up with a small rebound, so it stretches
/// like liquid and settles with a wobble.
abstract final class LiquidMotion {
  static const _lead = Interval(0, .6, curve: Curves.easeOutCubic);
  static const _trail = Interval(.12, 1, curve: Cubic(.45, 0, .25, 1.3));

  static Rect between(Rect from, Rect to, double t) {
    final lead = _lead.transform(t), trail = _trail.transform(t);
    final right = to.center.dx >= from.center.dx;
    final down = to.center.dy >= from.center.dy;
    return Rect.fromLTRB(
      lerpDouble(from.left, to.left, right ? trail : lead)!,
      lerpDouble(from.top, to.top, down ? trail : lead)!,
      lerpDouble(from.right, to.right, right ? lead : trail)!,
      lerpDouble(from.bottom, to.bottom, down ? lead : trail)!,
    );
  }
}

/// One choice among a few, on a stitched pillow, with a drop of liquid glass
/// marking the chosen one. The drop flows to a new choice; a press dimples
/// the pillow, or squashes the drop. Choices share one row when every label
/// fits, else two columns, else one.
class GelSelector<T> extends StatefulWidget {
  const GelSelector({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.keyOf,
    this.enabled = true,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final Key Function(T value)? keyOf;
  final bool enabled;

  @override
  State<GelSelector<T>> createState() => _GelSelectorState<T>();
}

class _GelSelectorState<T> extends State<GelSelector<T>>
    with TickerProviderStateMixin {
  static const _pad = 5.0;
  static const _gap = 2.0;

  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    value: 1,
  );
  late final _squish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 240),
  );
  late int _to = widget.values.indexOf(widget.selected);
  late int _from = _to;
  Rect? _fromRect;
  int? _pressed;
  List<Rect> _slots = const [];

  @override
  void didUpdateWidget(GelSelector<T> oldWidget) {
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
    _squish.dispose();
    super.dispose();
  }

  Rect _dropAt(double t) {
    final to = _slots[_to];
    final from = _fromRect ?? _slots[_from];
    return t >= 1 ? to : LiquidMotion.between(from, to, t);
  }

  void _down(int index) {
    if (!widget.enabled) return;
    setState(() => _pressed = index);
    if (RenderingPolicyScope.of(context).animate) _squish.forward();
  }

  void _release() {
    if (_pressed == null) return;
    if (!RenderingPolicyScope.of(context).animate) {
      setState(() => _pressed = null);
      return;
    }
    _squish.reverse().whenComplete(() {
      if (mounted && !_squish.isAnimating) setState(() => _pressed = null);
    });
  }

  void _select(int index) {
    if (widget.enabled) widget.onSelected(widget.values[index]);
  }

  @override
  Widget build(BuildContext context) {
    final parchment = Parchment.of(context);
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final duration = RenderingPolicyScope.of(context).duration;
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style
        .copyWith(fontSize: 14, height: 1.2, letterSpacing: .2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = widget.values.length;
        var widest = 0.0, lineHeight = 0.0;
        for (final value in widget.values) {
          final painter = TextPainter(
            text: TextSpan(
              text: widget.labelOf(value),
              style: base.copyWith(fontWeight: FontWeight.w700),
            ),
            textScaler: scaler,
            textDirection: Directionality.of(context),
            maxLines: 1,
          )..layout();
          widest = math.max(widest, painter.width);
          lineHeight = math.max(lineHeight, painter.height);
          painter.dispose();
        }
        final inner = constraints.maxWidth - 2 * _pad;
        int columns = count;
        for (final c in [count, 2, 1]) {
          columns = c;
          if (widest + 14 <= (inner - _gap * (c - 1)) / c) break;
        }
        final rows = (count / columns).ceil();
        final slotHeight = math.max(46.0, lineHeight + 22);
        final slotWidth = (inner - _gap * (columns - 1)) / columns;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        _slots = [
          for (var i = 0; i < count; i++)
            Rect.fromLTWH(
              _pad +
                  (rtl ? columns - 1 - i % columns : i % columns) *
                      (slotWidth + _gap),
              _pad + (i ~/ columns) * (slotHeight + _gap),
              slotWidth,
              slotHeight,
            ),
        ];
        final size = Size(
          constraints.maxWidth,
          2 * _pad + rows * slotHeight + (rows - 1) * _gap,
        );
        final radius = rows == 1 ? size.height / 2 : 22.0;
        return SizedBox.fromSize(
          size: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: PillowPainter(
                      parchment: parchment,
                      radius: radius,
                      stitched: false,
                      simple: simple,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _DropPainter(
                      move: _move,
                      squish: _squish,
                      dropAt: _dropAt,
                      slots: _slots,
                      selected: _to,
                      pressed: _pressed,
                      parchment: parchment,
                      radius: rows == 1 ? slotHeight / 2 : radius - _pad,
                      simple: simple,
                      enabled: widget.enabled,
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < count; i++)
                Positioned.fromRect(
                  rect: _slots[i],
                  child: Semantics(
                    key: widget.keyOf?.call(widget.values[i]),
                    container: true,
                    button: true,
                    selected: i == _to,
                    inMutuallyExclusiveGroup: true,
                    enabled: widget.enabled,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _down(i),
                      onTapUp: (_) => _release(),
                      onTapCancel: _release,
                      onTap: widget.enabled ? () => _select(i) : null,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          style: base.copyWith(
                            color: !widget.enabled
                                ? parchment.faded.withValues(alpha: .6)
                                : i == _to
                                ? parchment.rubric
                                : parchment.ink,
                            fontWeight: i == _to
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          child: Text(
                            widget.labelOf(widget.values[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DropPainter extends CustomPainter {
  _DropPainter({
    required this.move,
    required this.squish,
    required this.dropAt,
    required this.slots,
    required this.selected,
    required this.pressed,
    required this.parchment,
    required this.radius,
    required this.simple,
    required this.enabled,
  }) : super(repaint: Listenable.merge([move, squish]));

  final Animation<double> move;
  final Animation<double> squish;
  final Rect Function(double t) dropAt;
  final List<Rect> slots;
  final int selected;
  final int? pressed;
  final Parchment parchment;
  final double radius;
  final bool simple;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (slots.isEmpty) return;
    final depth = squish.value;
    final pressed = this.pressed;
    if (pressed != null && pressed != selected && !simple) {
      paintDent(
        canvas,
        RRect.fromRectAndRadius(
          slots[pressed].deflate(3),
          Radius.circular(radius - 3),
        ),
        parchment,
        depth,
      );
    }
    var rect = dropAt(move.value);
    // A press on the drop itself squashes it wider and lower.
    final squash = pressed == selected ? depth : 0.0;
    rect = Rect.fromLTRB(
      rect.left - 2 * squash,
      rect.top + 1.5 * squash,
      rect.right + 2 * squash,
      rect.bottom + .5 * squash,
    );
    if (rect.width <= 0 || rect.height <= 0) return;
    paintGel(
      canvas,
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(math.min(radius, rect.shortestSide / 2)),
      ),
      parchment: parchment,
      tint: parchment.rubric,
      simple: simple,
      lift: 1 - squash,
      strength: enabled ? 1 : .4,
    );
  }

  @override
  bool shouldRepaint(_DropPainter oldDelegate) =>
      move != oldDelegate.move ||
      squish != oldDelegate.squish ||
      selected != oldDelegate.selected ||
      pressed != oldDelegate.pressed ||
      radius != oldDelegate.radius ||
      simple != oldDelegate.simple ||
      enabled != oldDelegate.enabled ||
      !_sameSlots(slots, oldDelegate.slots);

  static bool _sameSlots(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// An on/off switch: a groove pressed into the paper, and a glass bead that
/// flows along it, tinting the groove red when on. Purely visual; the row
/// around it takes the tap and speaks for it.
class GelSwitch extends StatefulWidget {
  const GelSwitch({super.key, required this.value, this.enabled = true});

  final bool value;
  final bool enabled;

  @override
  State<GelSwitch> createState() => _GelSwitchState();
}

class _GelSwitchState extends State<GelSwitch>
    with SingleTickerProviderStateMixin {
  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );
  late bool _to = widget.value;

  @override
  void didUpdateWidget(GelSwitch oldWidget) {
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
      size: const Size(54, 32),
      painter: _SwitchPainter(
        move: _move,
        on: _to,
        enabled: widget.enabled,
        parchment: Parchment.of(context),
        simple: RenderingPolicyScope.of(context).simplerEffects,
      ),
    ),
  );
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter({
    required this.move,
    required this.on,
    required this.enabled,
    required this.parchment,
    required this.simple,
  }) : super(repaint: move);

  final Animation<double> move;
  final bool on;
  final bool enabled;
  final Parchment parchment;
  final bool simple;

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
    // The groove: sunk into the page, shadowed under its top lip.
    canvas.drawRRect(
      track,
      Paint()
        ..color = Color.alphaBlend(
          parchment.rubric.withValues(alpha: .22 * glow * (enabled ? 1 : .4)),
          Color.lerp(parchment.vellum, parchment.aged, .35)!,
        ),
    );
    if (!simple) {
      canvas.drawRRect(
        track.deflate(.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              parchment.shadow.withValues(alpha: .35),
              parchment.shadow.withValues(alpha: 0),
              Colors.white.withValues(alpha: .7),
            ],
            stops: const [0, .5, 1],
          ).createShader(Offset.zero & size),
      );
    }
    const inset = 3.0;
    final knob = size.height - 2 * inset;
    final off = Rect.fromLTWH(inset, inset, knob, knob);
    final onRect = Rect.fromLTWH(size.width - inset - knob, inset, knob, knob);
    final rect = LiquidMotion.between(on ? off : onRect, on ? onRect : off, t);
    paintGel(
      canvas,
      RRect.fromRectAndRadius(rect, Radius.circular(knob / 2)),
      parchment: parchment,
      tint: on ? parchment.rubric : parchment.faded,
      simple: simple,
      strength: enabled ? (on ? 1 : .55) : .3,
    );
  }

  @override
  bool shouldRepaint(_SwitchPainter oldDelegate) =>
      move != oldDelegate.move ||
      on != oldDelegate.on ||
      enabled != oldDelegate.enabled ||
      simple != oldDelegate.simple;
}

/// Wraps a pressable thing so it sinks a little under the finger and springs
/// back, like pressing into a cushion.
class Squishy extends StatefulWidget {
  const Squishy({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<Squishy> createState() => _SquishyState();
}

class _SquishyState extends State<Squishy> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final animate = RenderingPolicyScope.of(context).animate;
    return Listener(
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && animate ? .97 : 1,
        duration: Duration(milliseconds: _down ? 90 : 260),
        curve: _down ? Curves.easeOut : const Cubic(.3, 1.4, .5, 1),
        child: widget.child,
      ),
    );
  }
}
