import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'diary_paper_texture.dart';

// Bounded caches retain geometry for the visible sheets, rather than keeping
// a history of every day the reader has visited. The texture is shared.
final _details = <int, _PaperDetail>{};
final _outlines = <({DiaryPaperShape shape, Size size}), _PaperOutline>{};

/// The silhouette shared by the paper painter and content clip.
@immutable
class DiaryPaperShape {
  const DiaryPaperShape({
    this.seed = 0,
    this.expansion = 0,
    this.cornerRadius = 6,
  });

  factory DiaryPaperShape.forDate(
    DateTime date, {
    double expansion = 0,
    double cornerRadius = 6,
  }) => DiaryPaperShape(
    seed:
        DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay,
    expansion: expansion,
    cornerRadius: cornerRadius,
  );

  final int seed;
  final double expansion;
  final double cornerRadius;

  double get detail => 1 - expansion.clamp(0.0, 1.0);

  _PaperDetail get _paperDetail {
    final cached = _details.remove(seed) ?? _PaperDetail(seed);
    _details[seed] = cached;
    if (_details.length > 8) _details.remove(_details.keys.first);
    return cached;
  }

  _PaperOutline _outline(Size size) {
    final key = (shape: this, size: size);
    final cached = _outlines.remove(key);
    if (cached != null) {
      _outlines[key] = cached;
      return cached;
    }
    final value = _makeOutline(size);
    _outlines[key] = value;
    if (_outlines.length > 12) _outlines.remove(_outlines.keys.first);
    return value;
  }

  _PaperOutline _makeOutline(Size size) {
    if (size.isEmpty) {
      return _PaperOutline(const [], Path(), Path());
    }
    if (detail == 0) {
      final rect = Path()..addRect(Offset.zero & size);
      return _PaperOutline(
        [
          Offset.zero,
          Offset(size.width, 0),
          Offset(size.width, size.height),
          Offset(0, size.height),
        ],
        rect,
        rect,
      );
    }
    final amount = detail * (size.shortestSide / 30).clamp(0.0, 1.0);
    final bounds = (Offset.zero & size).deflate(6 * amount);
    final radius = math.min(cornerRadius * detail, bounds.shortestSide / 3);
    final base = Path()
      ..addRRect(RRect.fromRectAndRadius(bounds, Radius.circular(radius)));
    final metric = base.computeMetrics().single;
    final grain = _paperDetail;
    // Fixed sample phases and continuous noise keep bumps from crawling when
    // the sheet changes size. The frequencies never depend on frame count.
    final fringe = <Offset>[];
    final points = List<Offset>.generate(768, (i) {
      final u = i / 768;
      final tangent = metric.getTangentForOffset(metric.length * u)!;
      final inward = Offset(-tangent.vector.dy, tangent.vector.dx);
      var displacement =
          _noise(grain.broad, u) * 2.8 +
          _noise(grain.fine, u) * 2 +
          _noise(grain.micro, u) * .8;
      // Tearing splits the sheet's layers, leaving a pale, fibrous margin
      // that widens and narrows along the edge and opens up inside tears.
      final split = (_noise(grain.fine, u * .5 + .25) + 1) / 2;
      var margin = .5 + 2.6 * split * split;
      for (final tear in grain.tears) {
        final notch = tear.profile(tangent.position, inward, bounds);
        // Leave a small, asymmetric bite in the edge. Ease the grain beneath
        // it so a nearby outward bump cannot hide the tear's tip.
        displacement = displacement * (1 - notch) + tear.depth * notch;
        margin += 2.4 * notch;
      }
      final point = tangent.position + inward * (amount * displacement);
      fringe.add(point - inward * (amount * margin));
      return point;
    });
    return _PaperOutline(
      List.unmodifiable(points),
      pathFromOutline(points),
      pathFromOutline(fringe),
    );
  }

  Path path(Size size) => _outline(size).path;

  /// The torn margin just outside [path]; the same rectangle when flat.
  Path fringe(Size size) => _outline(size).fringe;
  List<Offset> outline(Size size) => _outline(size).points;

  static Path pathFromOutline(List<Offset> points) {
    if (points.isEmpty) return Path();
    final start = Offset.lerp(points.last, points.first, .5)!;
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 0; i < points.length; i++) {
      final next = Offset.lerp(points[i], points[(i + 1) % points.length], .5)!;
      path.quadraticBezierTo(points[i].dx, points[i].dy, next.dx, next.dy);
    }
    return path..close();
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryPaperShape &&
      seed == other.seed &&
      expansion == other.expansion &&
      cornerRadius == other.cornerRadius;

  @override
  int get hashCode => Object.hash(seed, expansion, cornerRadius);
}

double _noise(List<double> values, double u) {
  final position = u * values.length;
  final i = position.floor();
  final t = position - i;
  final smooth = t * t * (3 - 2 * t);
  return values[i % values.length] * (1 - smooth) +
      values[(i + 1) % values.length] * smooth;
}

class _PaperOutline {
  _PaperOutline(this.points, this.path, this.fringe);
  final List<Offset> points;
  final Path path, fringe;

  ({Offset point, Offset tangent}) at(double u) {
    final position = u * points.length;
    final i = position.floor() % points.length;
    final next = (i + 1) % points.length;
    final before = (i + points.length - 1) % points.length;
    final delta = points[next] - points[before];
    return (
      point: Offset.lerp(points[i], points[next], position - position.floor())!,
      tangent: delta / math.max(.001, delta.distance),
    );
  }
}

class _PaperTear {
  const _PaperTear({
    required this.edge,
    required this.position,
    required this.halfWidth,
    required this.depth,
    required this.lean,
  });

  final int edge;
  final double position, halfWidth, depth, lean;

  double profile(Offset point, Offset inward, Rect bounds) {
    final normal = switch (edge) {
      0 => const Offset(0, 1),
      1 => const Offset(-1, 0),
      2 => const Offset(0, -1),
      _ => const Offset(1, 0),
    };
    // Only the chosen straight edge is torn; corners stay softly rounded.
    if ((inward - normal).distanceSquared > .001) return 0;
    final horizontal = edge.isEven;
    final along = horizontal ? point.dx : point.dy;
    final center = horizontal
        ? bounds.left + bounds.width * position
        : bounds.top + bounds.height * position;
    final t = (along - center) / halfWidth;
    if (t <= -1 || t >= 1) return 0;
    final ramp = t < lean ? (t + 1) / (lean + 1) : (1 - t) / (1 - lean);
    return math.pow(ramp, 1.15).toDouble();
  }
}

class _PaperDetail {
  _PaperDetail(int seed) {
    final random = math.Random(seed);
    broad = List.generate(24, (_) => random.nextDouble() * 2 - 1);
    fine = List.generate(160, (_) => random.nextDouble() * 2 - 1);
    micro = List.generate(384, (_) => random.nextDouble() * 2 - 1);
    fibers = List.generate(
      520,
      (i) => (
        u: (i + random.nextDouble()) / 520,
        depth: math.pow(random.nextDouble(), 2).toDouble(),
        length: .6 + random.nextDouble() * 2.6,
        slant: random.nextDouble() * 1.4 - .7,
        tone: random.nextInt(5),
      ),
    );
    // A separate stream preserves the existing fibers and edge grain. Each
    // day gets just one to three small tears, on different sides, away from
    // corners. Relative placement keeps them attached during sheet resizing.
    final tearRandom = math.Random(seed ^ 0x74656172);
    final count = 1 + tearRandom.nextInt(3);
    final edges = [0, 1, 2, 3]..shuffle(tearRandom);
    tears = List.generate(
      count,
      (i) => _PaperTear(
        edge: edges[i],
        position: .18 + tearRandom.nextDouble() * .64,
        halfWidth: 5.5 + tearRandom.nextDouble() * 3.5,
        depth: 14 + tearRandom.nextDouble() * 4,
        lean: tearRandom.nextDouble() * .5 - .25,
      ),
    );
  }

  late final List<double> broad, fine, micro;
  late final List<_PaperTear> tears;

  late final List<
    ({double u, double depth, double length, double slant, int tone})
  >
  fibers;
}

class DiaryPaperClipper extends CustomClipper<Path> {
  const DiaryPaperClipper(this.shape, {this.viewport});
  final DiaryPaperShape shape;
  final Rect? viewport;

  @override
  Path getClip(Size size) {
    final rect = viewport ?? Offset.zero & size;
    return shape.path(rect.size).shift(rect.topLeft);
  }

  @override
  bool shouldReclip(DiaryPaperClipper oldClipper) =>
      shape != oldClipper.shape || viewport != oldClipper.viewport;
}

/// The diary's stock: a warm sheet lifted a little off the page around it, so
/// it reads as paper at night as well as by day. Text keeps the theme's ink.
Color diaryPaperTone(ColorScheme colors) => colors.brightness == Brightness.dark
    ? Color.alphaBlend(const Color(0x17f2e4c6), colors.surface)
    : Color.alphaBlend(const Color(0xa6fff5df), colors.surface);

/// Paints an opaque sheet of paper: a cast shadow, a torn and fibrous
/// margin, formation, fibres and grain from [diaryPaperTexture], soft light
/// across the face and aged edges.
///
/// Every layer scales with [DiaryPaperShape.detail]. At no detail the sheet
/// is a plain rectangle of [flat], the immersive reader's page.
class DiaryPaperPainter extends CustomPainter {
  const DiaryPaperPainter({
    required this.shape,
    required this.paper,
    required this.ink,
    Color? flat,
    this.shadow = false,
    this.shadowColor = const Color(0xff000000),
  }) : flat = flat ?? paper;

  final DiaryPaperShape shape;
  final Color paper, ink, shadowColor;

  /// The sheet's colour once fully expanded.
  final Color flat;
  final bool shadow;

  static const _white = Color(0xffffffff);
  static const _black = Color(0xff000000);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = shape.path(size);
    final detail = shape.detail;
    final dark = paper.computeLuminance() < .2;
    final bounds = Offset.zero & size;
    if (shadow && detail > 0) {
      canvas.drawShadow(
        path.shift(Offset(0, 4 * detail)),
        shadowColor.withValues(alpha: (dark ? .6 : .26) * detail),
        9 * detail,
        true,
      );
      canvas.drawShadow(
        path,
        shadowColor.withValues(alpha: (dark ? .5 : .16) * detail),
        1.4 * detail,
        true,
      );
    }
    if (detail > 0) {
      // Split fibres are paler than the face of the sheet.
      canvas.drawPath(
        shape.fringe(size),
        Paint()
          ..color = Color.lerp(
            paper,
            _white,
            dark ? .2 : .75,
          )!.withValues(alpha: (dark ? .7 : .95) * detail),
      );
    }
    canvas.drawPath(
      path,
      Paint()..color = Color.lerp(flat, paper, detail)!.withValues(alpha: 1),
    );
    if (detail == 0) return;

    canvas.save();
    canvas.clipPath(path);
    final texture = diaryPaperTexture(dark: dark);
    if (texture != null) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = texture
          ..color = _black.withValues(alpha: detail),
      );
    }
    // Light falls from the upper left across a sheet that is not quite flat.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, .42, 1],
          colors: [
            _white.withValues(alpha: (dark ? .05 : .28) * detail),
            _white.withValues(alpha: 0),
            _black.withValues(alpha: (dark ? .14 : .05) * detail),
          ],
        ).createShader(bounds),
    );
    // Handled edges age first: a soft, warm darkening just inside the rim.
    canvas.drawPath(
      path,
      Paint()
        ..color = (dark ? _black : const Color(0xff8a6a3a)).withValues(
          alpha: (dark ? .22 : .10) * detail,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.restore();
    _paintDeckle(canvas, size, detail, dark);
  }

  /// Short fibres where the sheet was torn, mostly reaching outward.
  void _paintDeckle(Canvas canvas, Size size, double detail, bool dark) {
    final source = shape._paperDetail;
    final edge = shape._outline(size);
    if (edge.points.isEmpty) return;
    final light = <Offset>[], shade = <Offset>[];
    for (var i = 0; i < source.fibers.length; i += 2) {
      final fiber = source.fibers[i];
      final sample = edge.at(fiber.u);
      final inward = Offset(-sample.tangent.dy, sample.tangent.dx);
      final start = sample.point + inward * (fiber.depth * 1.6);
      final direction =
          sample.tangent * math.sin(fiber.slant) -
          inward * math.cos(fiber.slant);
      (fiber.tone < 4 ? light : shade).addAll([
        start,
        start + direction * fiber.length * detail,
      ]);
    }
    final fibre = Color.lerp(paper, _white, dark ? .14 : .6)!;
    canvas.drawPoints(
      ui.PointMode.lines,
      light,
      Paint()
        ..color = fibre.withValues(alpha: .75 * detail)
        ..strokeWidth = .6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPoints(
      ui.PointMode.lines,
      shade,
      Paint()
        ..color = ink.withValues(alpha: .12 * detail)
        ..strokeWidth = .5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(DiaryPaperPainter oldDelegate) =>
      shape != oldDelegate.shape ||
      paper != oldDelegate.paper ||
      flat != oldDelegate.flat ||
      ink != oldDelegate.ink ||
      shadow != oldDelegate.shadow ||
      shadowColor != oldDelegate.shadowColor;
}
