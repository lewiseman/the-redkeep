import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'rendering_policy.dart';

/// The app surface's stuffed-paper cushions and liquid-glass beads, in the
/// colours of the current theme. The same language as the bottom bar.
///
/// Everything is painted with gradients and crisp stacked offsets: no blurs
/// and no backdrop sampling, so a cushion can sit in a cached layer and only
/// the beads that move ever repaint.
@immutable
class CushionColors {
  const CushionColors({
    required this.paper,
    required this.tint,
    required this.ink,
    required this.edge,
    required this.shadow,
    required this.dark,
    required this.simple,
  });

  /// [tint] washes lightly into the paper; [strength] 1 is a slab of tinted
  /// glass rather than paper.
  factory CushionColors.of(
    BuildContext context, {
    Color? tint,
    double strength = 0,
  }) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final hue = tint ?? colors.primary;
    final base = dark ? colors.surfaceContainer : colors.surfaceContainerLowest;
    final wash = lerpDouble(dark ? .07 : .05, dark ? .62 : .78, strength)!;
    return CushionColors(
      paper: Color.lerp(base, hue, wash)!,
      tint: hue,
      ink: colors.onSurface,
      edge: colors.outlineVariant,
      shadow: colors.shadow,
      dark: dark,
      simple: RenderingPolicyScope.of(context).simplerEffects,
    );
  }

  final Color paper, tint, ink, edge, shadow;
  final bool dark, simple;

  /// Readable ink on this cushion.
  Color get onPaper =>
      ThemeData.estimateBrightnessForColor(paper) == Brightness.dark
      ? Colors.white
      : const Color(0xFF1B1B2B);

  @override
  bool operator ==(Object other) =>
      other is CushionColors &&
      other.paper == paper &&
      other.tint == tint &&
      other.ink == ink &&
      other.edge == edge &&
      other.shadow == shadow &&
      other.dark == dark &&
      other.simple == simple;

  @override
  int get hashCode => Object.hash(paper, tint, ink, edge, shadow, dark, simple);
}

/// A cushion: lofted crown, shaded hem, a running stitch and a glassy lip.
class CushionPainter extends CustomPainter {
  const CushionPainter({
    required this.colors,
    this.radius = 26,
    this.stitched = true,
    this.glow,
  });

  final CushionColors colors;
  final double radius;
  final bool stitched;

  /// Where the tint pools as light, in the cushion's alignment space.
  final Alignment? glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = colors;
    final rect = Offset.zero & size;
    final body = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.min(radius, size.shortestSide / 2)),
    );
    // Light ink needs a deep cushion: keep its shine low so text stays clear.
    final deep = c.dark || c.onPaper == Colors.white;
    if (c.simple) {
      canvas.drawRRect(body, Paint()..color = c.paper);
      _hairline(canvas, body);
      return;
    }
    canvas.drawRRect(
      body.shift(const Offset(0, 5)),
      Paint()..color = c.shadow.withValues(alpha: c.dark ? .26 : .06),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 1.6)),
      Paint()..color = c.shadow.withValues(alpha: c.dark ? .4 : .12),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(c.paper, Colors.white, deep ? .08 : .55)!,
            c.paper,
            Color.lerp(c.paper, Colors.black, c.dark ? .2 : .06)!,
          ],
          stops: const [0, .5, 1],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(body);
    final glow = this.glow;
    if (glow != null) {
      final centre = glow.withinRect(rect);
      final reach = size.longestSide * .7;
      canvas.drawCircle(
        centre,
        reach,
        Paint()
          ..shader = RadialGradient(
            colors: [
              c.tint.withValues(alpha: c.dark ? .3 : .18),
              c.tint.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: reach)),
      );
    }
    final loft = math.min(size.height, 120.0);
    canvas.translate(size.width / 2, size.height * .08);
    canvas.scale(size.width * .6 / loft, 1);
    canvas.drawCircle(
      Offset.zero,
      loft,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: deep ? .07 : .4),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: loft)),
    );
    canvas.restore();

    if (stitched) {
      paintStitches(canvas, Path()..addRRect(body.deflate(7)), c);
    }
    canvas.drawRRect(
      body.deflate(.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: c.dark ? .22 : .95),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            c.tint.withValues(alpha: c.dark ? .32 : .28),
          ],
          stops: const [0, .3, .8, 1],
        ).createShader(rect),
    );
    _hairline(canvas, body);
  }

  void _hairline(Canvas canvas, RRect body) => canvas.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = colors.edge.withValues(alpha: colors.dark ? .85 : .7),
  );

  @override
  bool shouldRepaint(CushionPainter old) =>
      colors != old.colors ||
      radius != old.radius ||
      stitched != old.stitched ||
      glow != old.glow;
}

/// A running stitch along [outline], with a light catch on each thread.
void paintStitches(Canvas canvas, Path outline, CushionColors colors) {
  final stitches = Path();
  for (final metric in outline.computeMetrics()) {
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
    thread..color = Colors.white.withValues(alpha: colors.dark ? .05 : .7),
  );
  canvas.drawPath(
    stitches,
    thread..color = colors.edge.withValues(alpha: colors.dark ? .7 : .85),
  );
}

/// A drop of liquid glass in [tint]: lit crown, a specular band, a bright rim
/// above and the colour refracted into its base. [fill] 1 is solid colour,
/// as a swatch; lower values are clear glass with a tint.
void paintGlass(
  Canvas canvas,
  RRect drop, {
  required CushionColors colors,
  required Color tint,
  double fill = .2,
  double lift = 1,
  double strength = 1,
}) {
  final c = colors;
  final body = Color.lerp(c.paper, tint, (fill * strength).clamp(0.0, 1.0))!;
  if (c.simple) {
    canvas.drawRRect(drop, Paint()..color = body);
    canvas.drawRRect(
      drop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tint.withValues(alpha: .5 * strength),
    );
    return;
  }
  final rect = drop.outerRect;
  final under = Color.lerp(tint, Colors.black, .55)!;
  canvas.drawRRect(
    drop.shift(Offset(0, 1 + 2.5 * lift)),
    Paint()..color = under.withValues(alpha: (c.dark ? .3 : .12) * strength),
  );
  canvas.drawRRect(
    drop.shift(Offset(0, .5 + lift)),
    Paint()..color = under.withValues(alpha: (c.dark ? .45 : .2) * strength),
  );
  canvas.drawRRect(
    drop,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.3, -.9),
        radius: 1.25,
        colors: [
          Color.lerp(body, Colors.white, c.dark ? .3 : .55)!,
          body,
          Color.lerp(body, Colors.black, c.dark ? .25 : .12)!,
        ],
        stops: const [0, .55, 1],
      ).createShader(rect),
  );
  final h = rect.height;
  final band = RRect.fromLTRBR(
    rect.left + math.min(h * .3, rect.width * .2),
    rect.top + 2,
    rect.right - math.min(h * .3, rect.width * .2),
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
            Colors.white.withValues(alpha: c.dark ? .45 : .7),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(band.outerRect),
    );
  }
  canvas.drawRRect(
    drop.deflate(.6),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: c.dark ? .5 : .95),
          Colors.white.withValues(alpha: 0),
          tint.withValues(alpha: 0),
          Color.lerp(tint, Colors.white, .3)!.withValues(alpha: .6 * strength),
        ],
        stops: const [0, .42, .62, 1],
      ).createShader(rect),
  );
  canvas.drawRRect(
    drop,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = under.withValues(alpha: .35 * strength),
  );
}

/// A soft dimple pressed into a cushion.
void paintDimple(Canvas canvas, RRect dent, CushionColors colors) {
  final c = colors;
  canvas.drawRRect(
    dent,
    Paint()..color = c.shadow.withValues(alpha: c.dark ? .22 : .06),
  );
  if (c.simple) return;
  canvas.drawRRect(
    dent.deflate(.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.shadow.withValues(alpha: c.dark ? .5 : .2),
          c.shadow.withValues(alpha: 0),
          Colors.white.withValues(alpha: c.dark ? .07 : .6),
        ],
        stops: const [0, .5, 1],
      ).createShader(dent.outerRect),
  );
}

/// [child] sinks under the finger and springs back with a wobble when let
/// go, like pressing into a cushion. Purely visual; taps pass through.
class Springy extends StatefulWidget {
  const Springy({
    super.key,
    required this.child,
    this.enabled = true,
    this.depth = .04,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final bool enabled;

  /// How far it squashes at full press.
  final double depth;
  final Alignment alignment;

  @override
  State<Springy> createState() => _SpringyState();
}

class _SpringyState extends State<Springy> with SingleTickerProviderStateMixin {
  late final _press = AnimationController(
    vsync: this,
    lowerBound: -1,
    upperBound: 1,
    value: 0,
    duration: const Duration(milliseconds: 110),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    if (!RenderingPolicyScope.of(context).animate) return;
    _press.animateTo(1, curve: Curves.easeOut);
  }

  void _up() {
    if (_press.value == 0 || !RenderingPolicyScope.of(context).animate) {
      return;
    }
    _press.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: const ElasticOutCurve(.42),
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _down(),
    onPointerUp: (_) => _up(),
    onPointerCancel: (_) => _up(),
    child: AnimatedBuilder(
      animation: _press,
      builder: (context, child) {
        final p = _press.value;
        return Transform(
          alignment: widget.alignment,
          transform: Matrix4.diagonal3Values(
            1 - widget.depth * .4 * p,
            1 - widget.depth * p,
            1,
          ),
          child: child,
        );
      },
      child: widget.child,
    ),
  );
}

/// A back button as a glass bead sitting on a small cushion: it sinks under
/// the finger, springs back, and gives a light click.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key, this.onPressed});

  /// Defaults to popping the current route.
  final VoidCallback? onPressed;

  static const size = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = CushionColors.of(context);
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    void back() =>
        onPressed != null ? onPressed!() : Navigator.maybePop(context);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: back,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: back,
          child: SizedBox.square(
            // A full touch target round the smaller bead.
            dimension: 48,
            child: Center(
              child: Springy(
                depth: .12,
                child: CustomPaint(
                  size: const Size.square(size),
                  painter: _BackBeadPainter(colors),
                  child: SizedBox.square(
                    dimension: size,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 21,
                      color: colors.ink,
                    ),
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

class _BackBeadPainter extends CustomPainter {
  const _BackBeadPainter(this.colors);

  final CushionColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final bead = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );
    CushionPainter(
      colors: colors,
      radius: r,
      stitched: false,
    ).paint(canvas, size);
    // A clear glass lens over the cushion, tinted with the accent.
    paintGlass(
      canvas,
      bead.deflate(4),
      colors: colors,
      tint: colors.tint,
      fill: colors.dark ? .14 : .08,
      lift: .3,
      strength: .7,
    );
  }

  @override
  bool shouldRepaint(_BackBeadPainter old) => colors != old.colors;
}
