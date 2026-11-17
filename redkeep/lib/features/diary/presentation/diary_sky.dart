import 'dart:math' as math;

import '../../../core/presentation/rendering_policy.dart';
import 'diary_style.dart';

/// How far the diary's sky reaches down a page whose top inset is [top]:
/// past the month, the thread and its tabs, then fading out behind the paper.
double diarySkyExtent(BuildContext context) =>
    MediaQuery.paddingOf(context).top +
    (MediaQuery.textScalerOf(context).scale(13) + 26).clamp(44.0, 80.0) +
    156;

/// The diary's sky: an ink wash in the accent colour, a scatter of stars and
/// a few soft wisps, painted rather than loaded so it follows every accent
/// and brightness. It is painted once and cached on its own layer; scrolling
/// and the calendar's pull only move or cover it.
class DiarySky extends StatelessWidget {
  const DiarySky({super.key, this.strength = 1});

  /// Scales the whole sky, for pages that only need a hint of it.
  final double strength;

  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    return RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('diary-sky'),
        isComplex: true,
        painter: _DiarySkyPainter(
          colors: context.colors,
          strength: strength,
          detailed: !simple,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DiarySkyPainter extends CustomPainter {
  const _DiarySkyPainter({
    required this.colors,
    required this.strength,
    required this.detailed,
  });

  final ColorScheme colors;
  final double strength;
  final bool detailed;

  bool get _dark => colors.brightness == Brightness.dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || strength <= 0) return;
    final rect = Offset.zero & size;
    final sky = Color.alphaBlend(
      colors.primary.withValues(alpha: _dark ? .26 : .15),
      colors.surface,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, .38, .72, 1],
          colors: [
            sky.withValues(alpha: strength),
            sky.withValues(alpha: .78 * strength),
            sky.withValues(alpha: .26 * strength),
            sky.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    if (!detailed) return;

    // A few long, soft wisps of cloud low in the sky.
    final wisp = (_dark ? colors.primary : colors.surface).withValues(
      alpha: (_dark ? .10 : .55) * strength,
    );
    final blur = Paint()
      ..color = wisp
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    for (final (x, y, w, h) in const [
      (.08, .30, .46, .055),
      (.58, .22, .52, .045),
      (.30, .46, .62, .05),
    ]) {
      canvas.drawOval(
        Rect.fromLTWH(
          size.width * x - 20,
          size.height * y,
          size.width * w,
          size.height * h + 6,
        ),
        blur,
      );
    }

    // Stars, fewest near the paper. The same sky on every visit.
    final random = math.Random(17);
    final ink = _dark ? colors.onSurface : colors.primary;
    final count = (size.width * size.height / 2400).clamp(18, 80).round();
    final dot = Paint();
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final depth = math.pow(random.nextDouble(), 1.5).toDouble();
      final y = depth * size.height * .62;
      final radius = .45 + random.nextDouble() * .7;
      final alpha =
          (_dark
              ? .22 + .5 * random.nextDouble()
              : .10 + .2 * random.nextDouble()) *
          (1 - depth * .75) *
          strength;
      dot.color = ink.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, dot);
    }

    // A handful of brighter four-pointed stars.
    final sparkle = Paint()
      ..color = ink.withValues(alpha: (_dark ? .7 : .32) * strength);
    for (final (x, y, r) in const [
      (.13, .14, 3.2),
      (.34, .06, 2.4),
      (.62, .18, 2.2),
      (.91, .40, 2.6),
    ]) {
      canvas.drawPath(
        _sparkle(Offset(size.width * x, size.height * y), r),
        sparkle,
      );
    }
  }

  static Path _sparkle(Offset c, double r) {
    final w = r * .26;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
  }

  @override
  bool shouldRepaint(_DiarySkyPainter oldDelegate) =>
      colors != oldDelegate.colors ||
      strength != oldDelegate.strength ||
      detailed != oldDelegate.detailed;
}
