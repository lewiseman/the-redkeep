import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

/// Colors for the old leather-bound journal: dark tanned hide rubbed paler
/// at its edges, tarnished bronze fittings, gilt mostly worn away, and
/// yellowed leaves. The leather stays dark in both themes, faintly stained
/// by the reader's accent.
class TomePalette {
  TomePalette.of(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    // Dark mode binds the journal in deep brown leather; light mode in a
    // mid saddle tan, still dark enough for its gilt and lettering to read.
    leather = Color.lerp(
      dark ? const Color(0xff3b2619) : const Color(0xff6e4a2e),
      colors.primary,
      .06,
    )!;
    leatherLight = Color.lerp(leather, const Color(0xff8b6647), .34)!;
    leatherDeep = Color.lerp(leather, const Color(0xff0a0604), .55)!;
    board = Color.lerp(leather, const Color(0xff0a0604), .76)!;
    rubbed = Color.lerp(leather, const Color(0xffa07e5c), .45)!;
    bronzeLight = const Color(0xffb09662);
    bronze = const Color(0xff7a6139);
    bronzeDark = const Color(0xff33261a);
    gilt = dark ? const Color(0xffbfa36b) : const Color(0xffc8aa6c);
    giltDeep = const Color(0xff6b5128);
    onLeather = const Color(0xffe6d5b0);
    onLeatherMuted = onLeather.withValues(alpha: dark ? .62 : .84);
    warning = const Color(0xffffa493);
    pages = dark ? const Color(0xffa69170) : const Color(0xffc9b48c);
    pageLine = const Color(0xff4f3c22).withValues(alpha: .5);
    shadow = Colors.black.withValues(alpha: dark ? .6 : .34);
  }

  late final Color leather,
      leatherLight,
      leatherDeep,
      board,
      rubbed,
      bronzeLight,
      bronze,
      bronzeDark,
      gilt,
      giltDeep,
      onLeather,
      onLeatherMuted,
      warning,
      pages,
      pageLine,
      shadow;

  /// Lettering pressed into the leather, its gilt mostly rubbed off.
  TextStyle stamped({
    required double fontSize,
    double letterSpacing = 1,
    Color? color,
  }) => TextStyle(
    fontFamily: 'serif',
    color: color ?? gilt.withValues(alpha: .9),
    fontSize: fontSize,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: letterSpacing,
    shadows: [
      // Dark above and pale below reads as a letter sunk into the hide.
      Shadow(
        color: Colors.black.withValues(alpha: .7),
        offset: const Offset(0, -.8),
      ),
      Shadow(
        color: const Color(0xffd9b98a).withValues(alpha: .16),
        offset: const Offset(0, 1),
      ),
    ],
  );
}

/// A smooth, irregular wobble in about -1..1, so hand-made edges and tool
/// marks stay put while the tome changes size.
double _wobble(double x) =>
    math.sin(x * .083 + 1.3) * .5 +
    math.sin(x * .21 + .4) * .3 +
    math.sin(x * .57 + 2.1) * .2;

/// [rect]'s outline, unevenly cut and worn: rounded corners of differing
/// radii and edges that wander by about [amplitude].
Path _roughOutline(
  Rect rect, {
  double radius = 6,
  double amplitude = 1.2,
  double seed = 0,
}) {
  final base = Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(radius * .6),
        topRight: Radius.circular(radius * 1.4),
        bottomRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius * .8),
      ),
    );
  final metric = base.computeMetrics().first;
  final out = Path();
  const step = 4.0;
  for (var d = 0.0; d < metric.length; d += step) {
    final tangent = metric.getTangentForOffset(d)!;
    final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
    final p = tangent.position + normal * (amplitude * _wobble(d + seed));
    d == 0 ? out.moveTo(p.dx, p.dy) : out.lineTo(p.dx, p.dy);
  }
  return out..close();
}

/// Lines pressed into leather with a hand tool: each has a dark furrow and a
/// pale lip, and the pressure (so the depth) varies along it. Collected and
/// drawn in a handful of batched calls.
class _Tooling {
  final _deep = <double>[];
  final _faint = <double>[];

  void line(Offset a, Offset b, {double seed = 0}) {
    final length = (b - a).distance;
    if (length < 1) return;
    const step = 9.0;
    final count = math.max(1, (length / step).ceil());
    for (var i = 0; i < count; i++) {
      final t0 = i / count, t1 = (i + 1) / count;
      final p0 = Offset.lerp(a, b, t0)!, p1 = Offset.lerp(a, b, t1)!;
      final depth = _wobble(seed + i * step);
      // Now and then the tool skipped, leaving a gap.
      if (depth < -.72) continue;
      (depth > -.1 ? _deep : _faint).addAll([p0.dx, p0.dy, p1.dx, p1.dy]);
    }
  }

  void rect(Rect r, {double seed = 0}) {
    line(r.topLeft, r.topRight, seed: seed);
    line(r.topRight, r.bottomRight, seed: seed + 31);
    line(r.bottomRight, r.bottomLeft, seed: seed + 67);
    line(r.bottomLeft, r.topLeft, seed: seed + 97);
  }

  void paint(Canvas canvas, {double strength = 1, double width = 1.1}) {
    final deep = Float32List.fromList(_deep);
    final faint = Float32List.fromList(_faint);
    final pen = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    void pass(Float32List points, double alpha, Color color, Offset shift) {
      if (points.isEmpty) return;
      pen.color = color.withValues(alpha: alpha * strength);
      canvas.save();
      canvas.translate(shift.dx, shift.dy);
      canvas.drawRawPoints(PointMode.lines, points, pen);
      canvas.restore();
    }

    const lip = Color(0xffd2b089);
    pass(deep, .13, lip, const Offset(.7, .9));
    pass(faint, .07, lip, const Offset(.7, .9));
    pass(deep, .5, Colors.black, Offset.zero);
    pass(faint, .24, Colors.black, Offset.zero);
  }
}

/// Paints an old, heavy leather tome behind [child]: a corded spine, a
/// blind-tooled lattice, tarnished bronze corners and a strap clasp, with
/// the aged text block and back board showing beneath. The cover fills the
/// box less [thickness] on the right and bottom.
class TomeBinding extends StatelessWidget {
  const TomeBinding({
    super.key,
    this.clasp = true,
    this.shadow = true,
    this.child,
  });

  /// Depth of the pages and back board below and right of the cover.
  static const thickness = 13.0;

  /// Width of the corded spine on the cover's left.
  static const spine = 16.0;

  /// How far the innermost tooled fillet sits inside the cover's edges (and
  /// past the spine on the left), on a full-size cover. Contents that sit
  /// inside it read as set into the panel.
  static const panelInset = 20.0;

  final bool clasp;
  final bool shadow;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: TomePainter(
      palette: TomePalette.of(context),
      clasp: clasp,
      shadow: shadow,
    ),
    child: child,
  );
}

class TomePainter extends CustomPainter {
  const TomePainter({
    required this.palette,
    this.clasp = true,
    this.shadow = true,
    this.thickness = TomeBinding.thickness,
    this.bare = false,
    this.stained = true,
  });

  final TomePalette palette;
  final bool clasp;
  final bool shadow;
  final double thickness;

  /// Only the hide: the inside of a board, without tooling or metal.
  final bool bare;

  /// Whether the hide carries its water marks and grime.
  final bool stained;

  /// Fixed speckle positions (x, y, tone) for the leather's pores.
  static final List<(double, double, double)> _grain = () {
    final random = math.Random(11);
    return List.generate(
      420,
      (_) => (random.nextDouble(), random.nextDouble(), random.nextDouble()),
    );
  }();

  /// Fixed stains (x, y, size, alpha): water marks, grease, handling.
  static const _stains = [
    (.16, .20, .26, .26),
    (.78, .12, .18, .18),
    (.88, .74, .30, .30),
    (.30, .86, .22, .22),
    (.60, .52, .16, .14),
    (.06, .58, .14, .20),
    (.46, .10, .10, .16),
  ];

  /// Fixed scratches as normalized polylines.
  static const _scratches = [
    [(.22, .30), (.27, .33), (.31, .32)],
    [(.64, .18), (.70, .23)],
    [(.74, .62), (.79, .60), (.86, .64)],
    [(.40, .70), (.43, .76)],
    [(.12, .80), (.18, .78)],
    [(.55, .35), (.61, .34), (.63, .38)],
    [(.84, .30), (.88, .37)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final d = thickness;
    final cover = Rect.fromLTWH(0, 0, size.width - d, size.height - d);
    if (cover.width < 48 || cover.height < 24) return;
    final s = (cover.height / 170).clamp(.45, 1.0);

    if (shadow) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(3, 9, size.width + 2, size.height + 4),
          const Radius.circular(8),
        ),
        Paint()
          ..color = palette.shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    if (d > .5) _paintEdges(canvas, cover, d, s);

    final outline = _roughOutline(cover, radius: 7, amplitude: 1.1);
    canvas.drawPath(
      outline,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(.15, -.35),
              radius: 1.1,
              colors: [
                palette.leatherLight,
                palette.leather,
                palette.leatherDeep,
              ],
              stops: const [0, .55, 1],
              // Sized from the long side, so wide strips are not all edge.
            ).createShader(
              Rect.fromCircle(
                center: cover.center,
                radius: math.max(cover.width, cover.height) / 2,
              ),
            ),
    );

    canvas.save();
    canvas.clipPath(outline);
    if (stained) _paintStains(canvas, cover);
    _paintGrain(canvas, cover);
    if (!bare) {
      _paintTooling(canvas, cover, s);
      _paintSpine(canvas, cover, s);
    }
    _paintWear(canvas, cover, outline, s);
    if (!bare) _paintCorners(canvas, cover, s);
    canvas.restore();

    if (clasp && !bare && cover.height >= 52) {
      _paintClasp(canvas, cover, size, s);
    }
  }

  /// How far the book's depth reaches right and down for a [thickness].
  /// A little steeper than 45°, as if seen from slightly low and right.
  static Offset depthOf(double thickness) => Offset(thickness * .72, thickness);

  /// The book's edges seen past the cover: on the fore-edge (right) and
  /// tail (bottom), the front board's leather edge, the text block sunk
  /// between the boards, and the back board. The spine's leather wraps the
  /// tail at the left. Faces turned from the light are darker.
  void _paintEdges(Canvas canvas, Rect cover, double d, double s) {
    final v = depthOf(d);
    Path quad(Offset a, Offset b, double t0, double t1) => Path()
      ..moveTo(a.dx + v.dx * t0, a.dy + v.dy * t0)
      ..lineTo(b.dx + v.dx * t0, b.dy + v.dy * t0)
      ..lineTo(b.dx + v.dx * t1, b.dy + v.dy * t1)
      ..lineTo(a.dx + v.dx * t1, a.dy + v.dy * t1)
      ..close();
    Color shade(Color color, double amount) =>
        Color.lerp(color, Colors.black, amount.clamp(0.0, 1.0))!;

    // The back board, whose own corners show past the faces.
    canvas.drawPath(
      _roughOutline(cover.shift(v), radius: 8, amplitude: 1, seed: 40),
      Paint()..color = palette.board,
    );

    const front = .2, back = .84;
    final corner = 22 * s + 6;
    final spineEnd = cover.left + TomeBinding.spine + 1;
    final faces = [
      // Fore-edge: lit from the side, so only a little shaded.
      (
        a: Offset(cover.right, cover.top + 5),
        b: Offset(cover.right, cover.bottom),
        pagesFrom: Offset(cover.right, cover.top + 8),
        shade: .04,
      ),
      // Tail: turned down, away from the light.
      (
        a: Offset(cover.left + 3, cover.bottom),
        b: Offset(cover.right, cover.bottom),
        pagesFrom: Offset(spineEnd + 2, cover.bottom),
        shade: .2,
      ),
    ];
    final boardEdge = Color.lerp(palette.leather, palette.rubbed, .3)!;
    final backEdge = Color.lerp(palette.board, palette.leather, .35)!;
    final crease = Paint()
      ..strokeWidth = .9
      ..color = Colors.black.withValues(alpha: .55);
    for (final face in faces) {
      final a = face.a, b = face.b;
      // Board edges first, under everything else on the face.
      canvas.drawPath(
        quad(a, b, -.15, front),
        Paint()..color = shade(boardEdge, face.shade),
      );
      canvas.drawPath(
        quad(a, b, back, 1),
        Paint()..color = shade(backEdge, face.shade),
      );
      // The text block: old leaves, darkest where the boards overhang them.
      final from = face.pagesFrom;
      final g0 = from + v * front, g1 = from + v * back;
      canvas.drawPath(
        quad(from, b, front, back),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              shade(palette.pages, face.shade + .32),
              shade(palette.pages, face.shade + .04),
              shade(palette.pages, face.shade - .04),
              shade(palette.pages, face.shade + .08),
              shade(palette.pages, face.shade + .36),
            ],
            stops: const [0, .22, .5, .78, 1],
          ).createShader(Rect.fromPoints(g0, g1)),
      );
      // A few gatherings show as faint, uneven seams along the edge.
      final seams = <double>[];
      final faint = <double>[];
      var k = 0;
      for (final t in const [.34, .42, .51, .58, .67, .73]) {
        final w = _wobble(k++ * 23.0 + face.shade * 100);
        final p0 = from + v * (t + w * .02), p1 = b + v * (t - w * .02);
        (w > 0 ? seams : faint).addAll([p0.dx, p0.dy, p1.dx, p1.dy]);
      }
      final leaf = Paint()..strokeWidth = .6;
      leaf.color = palette.pageLine.withValues(alpha: .34);
      canvas.drawRawPoints(PointMode.lines, Float32List.fromList(seams), leaf);
      leaf.color = palette.pageLine.withValues(alpha: .12);
      canvas.drawRawPoints(PointMode.lines, Float32List.fromList(faint), leaf);
      // Shadowed creases where the leaves meet each board.
      for (final t in const [front, back]) {
        final p0 = from + v * t, p1 = b + v * t;
        canvas.drawLine(p0, p1, crease);
      }
      if (!bare) {
        // The bronze corners wrap round onto the board's edge.
        final along = (b - a) / (b - a).distance;
        final metal = Paint()..color = shade(palette.bronze, face.shade * .8);
        for (final end in [a, b - along * corner * .85]) {
          canvas.drawPath(
            quad(end, end + along * corner * .85, -.15, front),
            metal,
          );
        }
      }
    }
    // The spine's leather turns in over the tail.
    final tail = Offset(cover.left + 3, cover.bottom);
    canvas.drawPath(
      quad(tail, Offset(spineEnd + 2, cover.bottom), -.15, 1),
      Paint()..color = shade(palette.leather, .3),
    );
    // The far outline, where the back board meets the table.
    final rim = Path()
      ..moveTo(cover.right + v.dx, cover.top + 5 + v.dy)
      ..lineTo(cover.right + v.dx, cover.bottom + v.dy)
      ..lineTo(cover.left + 3 + v.dx, cover.bottom + v.dy);
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: .5),
    );
  }

  void _paintStains(Canvas canvas, Rect cover) {
    final unit = math.max(cover.width, cover.height);
    for (final (x, y, size, alpha) in _stains) {
      final center = Offset(
        cover.left + x * cover.width,
        cover.top + y * cover.height,
      );
      final radius = size * unit;
      final tone = Colors.black.withValues(alpha: alpha);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              tone,
              tone.withValues(alpha: alpha * .6),
              tone.withValues(alpha: 0),
            ],
            stops: const [0, .55, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    // A pale tide line where water once dried.
    final tide = Offset(
      cover.left + cover.width * .84,
      cover.top + cover.height * .78,
    );
    canvas.drawCircle(
      tide,
      unit * .2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = palette.rubbed.withValues(alpha: .10),
    );
  }

  void _paintGrain(Canvas canvas, Rect cover) {
    final dark = Float32List(_grain.length * 2);
    final light = Float32List(_grain.length * 2);
    var darkCount = 0, lightCount = 0;
    for (final (x, y, tone) in _grain) {
      final px = cover.left + x * cover.width;
      final py = cover.top + y * cover.height;
      if (tone < .7) {
        dark[darkCount++] = px;
        dark[darkCount++] = py;
      } else {
        light[lightCount++] = px;
        light[lightCount++] = py;
      }
    }
    final speck = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8
      ..color = Colors.black.withValues(alpha: .26);
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.sublistView(dark, 0, darkCount),
      speck,
    );
    speck
      ..strokeWidth = 1.2
      ..color = palette.rubbed.withValues(alpha: .16);
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.sublistView(light, 0, lightCount),
      speck,
    );
    // Scratches catch the light paler than the hide around them.
    final lines = <double>[];
    for (final scratch in _scratches) {
      for (var i = 0; i < scratch.length - 1; i++) {
        final (x0, y0) = scratch[i];
        final (x1, y1) = scratch[i + 1];
        lines.addAll([
          cover.left + x0 * cover.width,
          cover.top + y0 * cover.height,
          cover.left + x1 * cover.width,
          cover.top + y1 * cover.height,
        ]);
      }
    }
    canvas.drawRawPoints(
      PointMode.lines,
      Float32List.fromList(lines),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = .9
        ..color = palette.rubbed.withValues(alpha: .30),
    );
  }

  /// Blind tooling: triple fillets around a panel crossed by a diagonal
  /// lattice, a small stamp pressed where the lines meet.
  void _paintTooling(Canvas canvas, Rect cover, double s) {
    final inset = 7 * s + 2;
    final outer = Rect.fromLTRB(
      cover.left + TomeBinding.spine + inset,
      cover.top + inset,
      cover.right - inset,
      cover.bottom - inset,
    );
    if (outer.width < 24 || outer.height < 16) return;
    final fillets = _Tooling()..rect(outer, seed: 3);
    if (s > .6) {
      fillets
        ..rect(outer.deflate(3), seed: 17)
        ..rect(outer.deflate(11), seed: 29);
      final panel = outer.deflate(11);
      final gap = 30 * s;
      final lattice = _Tooling();
      final reach = panel.width + panel.height;
      // Diagonals run along x - y = a and x + y = b for each offset.
      final downs = <double>[], ups = <double>[];
      for (var k = -panel.height; k < panel.width; k += gap) {
        downs.add(panel.left + k - panel.top);
        ups.add(panel.right - k + panel.top);
        lattice
          ..line(
            Offset(panel.left + k, panel.top),
            Offset(panel.left + k + reach, panel.top + reach),
            seed: k * 1.7,
          )
          ..line(
            Offset(panel.right - k, panel.top),
            Offset(panel.right - k - reach, panel.top + reach),
            seed: k * 2.3 + 11,
          );
      }
      final stamps = <double>[];
      for (final a in downs) {
        for (final b in ups) {
          final x = (a + b) / 2, y = (b - a) / 2;
          if (x > panel.left + 2 &&
              x < panel.right - 2 &&
              y > panel.top + 2 &&
              y < panel.bottom - 2) {
            stamps.addAll([x, y]);
          }
        }
      }
      canvas.save();
      canvas.clipRect(panel);
      lattice.paint(canvas, strength: .5, width: 1);
      canvas.restore();
      _stamp(canvas, Float32List.fromList(stamps), 3.2 * s + .4);
    }
    fillets.paint(canvas, width: 1.2);
  }

  void _stamp(Canvas canvas, Float32List points, double size) {
    final pen = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size;
    pen.color = const Color(0xffd2b089).withValues(alpha: .10);
    canvas.save();
    canvas.translate(.7, .9);
    canvas.drawRawPoints(PointMode.points, points, pen);
    canvas.restore();
    pen.color = Colors.black.withValues(alpha: .28);
    canvas.drawRawPoints(PointMode.points, points, pen);
    pen
      ..strokeWidth = size * .38
      ..color = palette.rubbed.withValues(alpha: .22);
    canvas.drawRawPoints(PointMode.points, points, pen);
  }

  void _paintSpine(Canvas canvas, Rect cover, double s) {
    const w = TomeBinding.spine;
    final spine = Rect.fromLTWH(cover.left, cover.top, w, cover.height);
    canvas.drawRect(
      spine,
      Paint()
        ..shader = LinearGradient(
          colors: [
            palette.board.withValues(alpha: .9),
            palette.leather.withValues(alpha: .3),
            palette.leatherDeep.withValues(alpha: .8),
          ],
          stops: const [0, .45, 1],
        ).createShader(spine),
    );
    // The hinge, cracked from opening: a dark furrow with a worn lip.
    final hinge = Path()..moveTo(spine.right, cover.top);
    for (var y = 0.0; y <= cover.height; y += 6) {
      hinge.lineTo(spine.right + _wobble(y * 2.1) * .7, cover.top + y);
    }
    canvas.drawPath(
      hinge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.black.withValues(alpha: .6),
    );
    canvas.drawPath(
      hinge.shift(const Offset(1.8, 0)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = palette.rubbed.withValues(alpha: .28),
    );
    // Creases fanning out from the hinge.
    final creases = <double>[];
    for (var y = 9.0; y < cover.height - 9; y += 13) {
      final length = 4 + 5 * (_wobble(y * 3.3) + 1);
      creases.addAll([
        spine.right + 2,
        cover.top + y,
        spine.right + 2 + length,
        cover.top + y + _wobble(y) * 1.5,
      ]);
    }
    canvas.drawRawPoints(
      PointMode.lines,
      Float32List.fromList(creases),
      Paint()
        ..strokeWidth = .8
        ..color = Colors.black.withValues(alpha: .28),
    );
    // Raised cords under the leather, each a little uneven.
    final bands = cover.height > 120 ? 4 : 2;
    for (var i = 1; i <= bands; i++) {
      final y = cover.top + cover.height * i / (bands + 1) + _wobble(i * 7.0);
      final height = 6 * s + 2 + _wobble(i * 5.0) * .8;
      final band = Rect.fromLTWH(spine.left, y - height / 2, w, height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(band, Radius.circular(height / 2)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.rubbed, palette.leather, palette.board],
            stops: const [0, .45, 1],
          ).createShader(band),
      );
      final fillet = _Tooling()
        ..line(
          Offset(spine.left, band.top - 2.2),
          Offset(spine.right, band.top - 2.2),
          seed: i * 5.0,
        )
        ..line(
          Offset(spine.left, band.bottom + 2.2),
          Offset(spine.right, band.bottom + 2.2),
          seed: i * 9.0,
        );
      fillet.paint(canvas, width: .9);
    }
  }

  /// Leather rubs pale and thin where hands hold it: the rim and corners.
  void _paintWear(Canvas canvas, Rect cover, Path outline, double s) {
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    rim
      ..strokeWidth = 9 * s + 4
      ..color = palette.rubbed.withValues(alpha: .10);
    canvas.drawPath(outline, rim);
    rim
      ..strokeWidth = 3.4
      ..color = palette.rubbed.withValues(alpha: .26);
    canvas.drawPath(outline, rim);
    rim
      ..strokeWidth = 1.2
      ..color = Colors.black.withValues(alpha: .5);
    canvas.drawPath(outline, rim);
    final radius = 34 * s + 8;
    for (final corner in [
      cover.topLeft,
      cover.topRight,
      cover.bottomLeft,
      cover.bottomRight,
    ]) {
      canvas.drawCircle(
        corner,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              palette.rubbed.withValues(alpha: .34),
              palette.rubbed.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: corner, radius: radius)),
      );
    }
  }

  /// Tarnished bronze corner pieces, cut with a cusped inner edge and nailed
  /// through the leather.
  void _paintCorners(Canvas canvas, Rect cover, double s) {
    final c = 22 * s + 6;
    final metal = Paint();
    final grime = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = palette.bronzeDark;
    final rivet = Paint()..color = palette.bronzeDark;
    final dull = Paint()..color = palette.bronzeLight.withValues(alpha: .55);
    var seed = 0.0;
    for (final (corner, sx, sy) in [
      (cover.topLeft, 1.0, 1.0),
      (cover.topRight, -1.0, 1.0),
      (cover.bottomLeft, 1.0, -1.0),
      (cover.bottomRight, -1.0, -1.0),
    ]) {
      Offset at(double x, double y) =>
          Offset(corner.dx + sx * x * c, corner.dy + sy * y * c);
      seed += 3;
      final nick = _wobble(seed * 4) * .05;
      final path = Path()
        ..moveTo(corner.dx - sx * 2, corner.dy - sy * 2)
        ..lineTo(at(1, 0).dx, at(1, 0).dy)
        ..lineTo(at(.94, .2 + nick).dx, at(.94, .2 + nick).dy)
        ..quadraticBezierTo(
          at(.68, .3).dx,
          at(.68, .3).dy,
          at(.52, .52).dx,
          at(.52, .52).dy,
        )
        ..quadraticBezierTo(
          at(.3, .68).dx,
          at(.3, .68).dy,
          at(.2 - nick, .94).dx,
          at(.2 - nick, .94).dy,
        )
        ..lineTo(at(0, 1).dx, at(0, 1).dy)
        ..close();
      final bounds = Rect.fromPoints(at(0, 0), at(1, 1));
      metal.shader = RadialGradient(
        center: Alignment(-.4 * sx, -.4 * sy),
        radius: 1.2,
        colors: [palette.bronzeLight, palette.bronze, palette.bronzeDark],
        stops: const [0, .45, 1],
      ).createShader(bounds);
      // A soft shadow where the plate sits proud of the leather.
      canvas.drawPath(
        path.shift(Offset(sx * .8 + .4, sy * .8 + 1)),
        Paint()..color = Colors.black.withValues(alpha: .45),
      );
      canvas.drawPath(path, metal);
      // Verdigris and grime gather in the plate's hollows.
      canvas.drawCircle(
        at(.34, .34),
        c * .22,
        Paint()..color = const Color(0xff4e5a43).withValues(alpha: .22),
      );
      canvas.drawPath(path, grime);
      for (final (x, y) in [(.2, .2), (.7, .1), (.1, .7)]) {
        final p = at(x, y);
        canvas.drawCircle(p, 1.9 * s + .7, rivet);
        canvas.drawCircle(p.translate(-.5, -.6), .8 * s + .3, dull);
      }
    }
  }

  void _paintClasp(Canvas canvas, Rect cover, Size size, double s) {
    final cy = cover.center.dy + _wobble(cover.height) * 2;
    final half = 7 * s + 2.5;
    final strapLeft = cover.right - 34 * s - 6;
    // Across the cover to its edge, then round the fore-edge to the back.
    final strap = Path()
      ..moveTo(strapLeft, cy - half + .6)
      ..lineTo(cover.right + .5, cy - half - .4)
      ..lineTo(cover.right + .5, cy + half + .3)
      ..lineTo(strapLeft, cy + half - .5)
      ..close();
    final v = depthOf(thickness);
    final wrap = Path()
      ..moveTo(cover.right, cy - half - .4)
      ..lineTo(cover.right + v.dx, cy - half + v.dy - .4)
      ..lineTo(cover.right + v.dx, cy + half + v.dy + .3)
      ..lineTo(cover.right, cy + half + .3)
      ..close();
    canvas.drawPath(
      wrap,
      Paint()..color = Color.lerp(palette.board, palette.leather, .25)!,
    );
    canvas.drawLine(
      Offset(cover.right + .6, cy - half),
      Offset(cover.right + .6, cy + half),
      Paint()
        ..strokeWidth = 1
        ..color = palette.rubbed.withValues(alpha: .35),
    );
    canvas.drawPath(
      strap.shift(const Offset(0, 1.6)),
      Paint()..color = Colors.black.withValues(alpha: .4),
    );
    canvas.drawPath(
      strap,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.rubbed, palette.leatherDeep, palette.board],
              stops: const [0, .5, 1],
            ).createShader(
              Rect.fromLTRB(strapLeft, cy - half, cover.right, cy + half),
            ),
    );
    // Stitch holes rather than thread: the thread rotted long ago.
    final holes = <double>[];
    for (var x = strapLeft + 4; x < cover.right - 2; x += 3.6) {
      holes.addAll([x, cy - half + 2.2, x + 1.2, cy + half - 2.2]);
    }
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.fromList(holes),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.1
        ..color = Colors.black.withValues(alpha: .55),
    );
    // A tapered bronze catch nailed over the strap.
    final w = 15 * s + 4;
    final h = half * 2 + 7 * s;
    final x0 = cover.right - 24 * s - 4;
    final cat = Path()
      ..moveTo(x0 - w * .55, cy)
      ..quadraticBezierTo(x0 - w * .3, cy - h * .48, x0, cy - h / 2)
      ..lineTo(x0 + w * .5, cy - h * .42)
      ..lineTo(x0 + w * .5, cy + h * .42)
      ..lineTo(x0, cy + h / 2)
      ..quadraticBezierTo(x0 - w * .3, cy + h * .48, x0 - w * .55, cy)
      ..close();
    final bounds = Rect.fromLTRB(
      x0 - w * .55,
      cy - h / 2,
      x0 + w * .5,
      cy + h / 2,
    );
    canvas.drawPath(
      cat.shift(const Offset(.6, 1.4)),
      Paint()..color = Colors.black.withValues(alpha: .5),
    );
    canvas.drawPath(
      cat,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.5),
          colors: [palette.bronzeLight, palette.bronze, palette.bronzeDark],
          stops: const [0, .5, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      cat,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.bronzeDark,
    );
    final rivet = Paint()..color = palette.bronzeDark;
    final dull = Paint()..color = palette.bronzeLight.withValues(alpha: .5);
    for (final dy in [-h * .25, h * .25]) {
      final p = Offset(x0 + w * .18, cy + dy);
      canvas.drawCircle(p, 1.7 * s + .7, rivet);
      canvas.drawCircle(p.translate(-.4, -.5), .7 * s + .3, dull);
    }
  }

  @override
  bool shouldRepaint(TomePainter oldDelegate) =>
      clasp != oldDelegate.clasp ||
      shadow != oldDelegate.shadow ||
      thickness != oldDelegate.thickness ||
      bare != oldDelegate.bare ||
      stained != oldDelegate.stained ||
      palette.leather != oldDelegate.palette.leather ||
      palette.gilt != oldDelegate.palette.gilt ||
      palette.pages != oldDelegate.palette.pages;
}

/// A bronze boss set into the cover, the owner's initials pressed into the
/// leather at its heart.
class TomeMedallion extends StatelessWidget {
  const TomeMedallion({super.key, required this.size, required this.initials});

  final double size;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final palette = TomePalette.of(context);
    return CustomPaint(
      painter: _BossPainter(palette),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            initials,
            textScaler: TextScaler.noScaling,
            style: palette.stamped(
              fontSize: size * .34,
              letterSpacing: size * .02,
            ),
          ),
        ),
      ),
    );
  }
}

class _BossPainter extends CustomPainter {
  const _BossPainter(this.palette);
  final TomePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final ring = (r * .14).clamp(2.0, 9.0);
    final outer = Path();
    for (var i = 0; i <= 48; i++) {
      final a = i / 48 * math.pi * 2;
      final rr = r + _wobble(a * 40) * r * .018;
      final p = center + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? outer.moveTo(p.dx, p.dy) : outer.lineTo(p.dx, p.dy);
    }
    outer.close();
    final bounds = Rect.fromCircle(center: center, radius: r);
    canvas.drawPath(
      outer.shift(const Offset(.5, 1.6)),
      Paint()..color = Colors.black.withValues(alpha: .5),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.45),
          radius: .95,
          colors: [palette.bronzeLight, palette.bronze, palette.bronzeDark],
          stops: const [0, .55, 1],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      center.translate(r * .2, r * .25),
      r * .5,
      Paint()..color = const Color(0xff4e5a43).withValues(alpha: .16),
    );
    final inner = r - ring;
    canvas.drawCircle(
      center,
      inner,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.2, -.3),
          colors: [palette.leatherLight, palette.leather, palette.leatherDeep],
          stops: const [0, .5, 1],
        ).createShader(Rect.fromCircle(center: center, radius: inner)),
    );
    // The leather sinks where it meets the metal.
    canvas.drawCircle(
      center,
      inner - .5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.black.withValues(alpha: .55),
    );
    canvas.drawCircle(
      center,
      r - .6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.bronzeDark,
    );
    if (r > 24) {
      final rivet = Paint()..color = palette.bronzeDark;
      final dull = Paint()..color = palette.bronzeLight.withValues(alpha: .5);
      for (var i = 0; i < 4; i++) {
        final a = i / 4 * math.pi * 2 + math.pi / 4;
        final p = center + Offset(math.cos(a), math.sin(a)) * (r - ring / 2);
        canvas.drawCircle(p, ring * .22 + .5, rivet);
        canvas.drawCircle(p.translate(-.4, -.4), ring * .1 + .2, dull);
      }
    }
  }

  @override
  bool shouldRepaint(_BossPainter oldDelegate) =>
      palette.leather != oldDelegate.palette.leather;
}

/// A vellum leaf and the inks written on it. The page is its own world
/// with its own light, so it is the same warm vellum in either theme.
class Parchment {
  Parchment.of(BuildContext context) {
    vellum = const Color(0xffeee2c3);
    aged = const Color(0xffc8ac7b);
    ink = const Color(0xff2a1d12);
    faded = const Color(0xff4b3826);
    rubric = const Color(0xff8e2617);
    fiber = const Color(0xff5e4529);
    rust = const Color(0xff9a5f2c);
    under = const Color(0xffd6c39b);
    pillow = Color.lerp(vellum, Colors.white, .38)!;
    shadow = const Color(0xff4a3420);
  }

  late final Color vellum,
      aged,
      ink,
      faded,
      rubric,
      fiber,
      rust,
      under,
      pillow,
      shadow;

  /// The app's theme as written on this leaf: sepia ink, red rubrics and a
  /// book face, so stock widgets on the page share its look.
  ThemeData theme(ThemeData base) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: rubric,
          brightness: Brightness.light,
        ).copyWith(
          surface: vellum,
          onSurface: ink,
          onSurfaceVariant: faded,
          primary: rubric,
          onPrimary: const Color(0xfff4e7c9),
          error: rubric,
          onError: const Color(0xfff4e7c9),
          outline: faded,
          outlineVariant: ink.withValues(alpha: .2),
        );
    return base.copyWith(
      colorScheme: scheme,
      textTheme: base.textTheme.apply(
        fontFamily: 'serif',
        bodyColor: ink,
        displayColor: ink,
      ),
      iconTheme: IconThemeData(color: faded),
      splashColor: fiber.withValues(alpha: .10),
      highlightColor: fiber.withValues(alpha: .06),
      hoverColor: fiber.withValues(alpha: .04),
      focusColor: rubric.withValues(alpha: .12),
      dividerColor: ink.withValues(alpha: .18),
    );
  }
}

/// An old leaf of vellum, cut by hand: deckled edges with a few leaves
/// beneath, fibres and mottling in the skin, edges browned by age and
/// candle-smoke. [child] is clipped to the leaf.
class TomeLeaf extends StatelessWidget {
  const TomeLeaf({super.key, required this.child});

  final Widget child;

  /// Room on the right and bottom for the leaves beneath.
  static const _under = 4.0;

  static Path _outline(Size size) => _roughOutline(
    Rect.fromLTWH(0, 0, size.width - _under, size.height - _under),
    radius: 4,
    amplitude: 1.4,
    seed: 7,
  );

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Painted once: the leaf never changes size while it shows.
      RepaintBoundary(
        child: CustomPaint(painter: _LeafPainter(Parchment.of(context))),
      ),
      ClipPath(clipper: const _LeafClipper(), child: child),
    ],
  );
}

class _LeafClipper extends CustomClipper<Path> {
  const _LeafClipper();

  @override
  Path getClip(Size size) => TomeLeaf._outline(size);

  @override
  bool shouldReclip(_LeafClipper oldClipper) => false;
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter(this.parchment);

  final Parchment parchment;

  /// Fixed fibres (x, y, angle, length, tone) in the skin.
  static final List<(double, double, double, double, double)> _fibres = () {
    final random = math.Random(5);
    return List.generate(
      900,
      (_) => (
        random.nextDouble(),
        random.nextDouble(),
        (random.nextDouble() - .5) * 1.1,
        2 + random.nextDouble() * 9,
        random.nextDouble(),
      ),
    );
  }();

  /// Fixed mottling (x, y, size, darker) in the skin.
  static const _mottle = [
    (.20, .14, .22, true),
    (.74, .30, .30, false),
    (.36, .52, .26, true),
    (.82, .66, .20, true),
    (.14, .74, .28, false),
    (.56, .88, .24, true),
    (.60, .06, .16, false),
    (.92, .94, .18, true),
  ];

  /// Fixed foxing spots (x, y, size).
  static const _foxing = [
    (.88, .05, .022),
    (.91, .07, .010),
    (.94, .40, .014),
    (.07, .94, .026),
    (.11, .96, .012),
    (.68, .97, .016),
    (.96, .80, .02),
    (.04, .30, .01),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const under = TomeLeaf._under;
    final top = Rect.fromLTWH(0, 0, size.width - under, size.height - under);
    for (var i = 2; i >= 1; i--) {
      canvas.drawPath(
        _roughOutline(
          top.shift(Offset(i * 2.0, i * 2.0)),
          radius: 4,
          amplitude: 1.5,
          seed: i * 53.0,
        ),
        Paint()
          ..color = Color.lerp(parchment.under, Colors.black, .14 * i - .1)!,
      );
    }
    final leaf = TomeLeaf._outline(size);
    // Brighter where the candle stands, browning towards every edge.
    canvas.drawPath(
      leaf,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.1, -.25),
          radius: 1.05,
          colors: [
            Color.lerp(parchment.vellum, Colors.white, .06)!,
            parchment.vellum,
            Color.lerp(parchment.vellum, parchment.aged, .55)!,
            parchment.aged,
          ],
          stops: const [0, .45, .82, 1],
        ).createShader(top),
    );
    canvas.save();
    canvas.clipPath(leaf);
    final unit = math.max(top.width, top.height);
    for (final (x, y, r, darker) in _mottle) {
      final center = Offset(x * top.width, y * top.height);
      final radius = r * unit;
      final tone = darker
          ? parchment.aged.withValues(alpha: .20)
          : Colors.white.withValues(alpha: .10);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [tone, tone.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    final dark = <double>[], light = <double>[];
    for (final (x, y, angle, length, tone) in _fibres) {
      final from = Offset(x * top.width, y * top.height);
      final to = from + Offset(math.cos(angle), math.sin(angle)) * length;
      (tone < .7 ? dark : light).addAll([from.dx, from.dy, to.dx, to.dy]);
    }
    final pen = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = .7;
    pen.color = parchment.fiber.withValues(alpha: .09);
    canvas.drawRawPoints(PointMode.lines, Float32List.fromList(dark), pen);
    pen
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: .16);
    canvas.drawRawPoints(PointMode.lines, Float32List.fromList(light), pen);
    final shortest = size.shortestSide;
    for (final (x, y, r) in _foxing) {
      final center = Offset(x * top.width, y * top.height);
      final radius = r * shortest;
      final spot = parchment.rust.withValues(alpha: .26);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              spot,
              spot.withValues(alpha: .08),
              spot.withValues(alpha: 0),
            ],
            stops: const [0, .6, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    // The very edge browns and frays first.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    edge
      ..strokeWidth = 26
      ..color = parchment.aged.withValues(alpha: .22);
    canvas.drawPath(leaf, edge);
    edge
      ..strokeWidth = 7
      ..color = parchment.fiber.withValues(alpha: .22);
    canvas.drawPath(leaf, edge);
    edge
      ..strokeWidth = 1.6
      ..color = parchment.fiber.withValues(alpha: .45);
    canvas.drawPath(leaf, edge);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LeafPainter oldDelegate) =>
      parchment.vellum != oldDelegate.parchment.vellum;
}

/// A patch of the binding's leather, rough-cut, for buttons on the page.
class LeatherPatch extends StatelessWidget {
  const LeatherPatch({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: TomePainter(
      palette: TomePalette.of(context),
      shadow: false,
      thickness: 0,
      bare: true,
      stained: false,
    ),
    foregroundPainter: const _StitchPainter(),
    child: child,
  );
}

/// Linen thread stitched round a leather patch, slightly uneven.
class _StitchPainter extends CustomPainter {
  const _StitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(6);
    if (rect.width < 12 || rect.height < 12) return;
    // Polished leather: a soft sheen across the crown.
    final h = size.height;
    final band = RRect.fromLTRBR(
      h * .35,
      3,
      size.width - h * .35,
      h * .44,
      Radius.circular(h * .2),
    );
    if (band.width > 0) {
      canvas.drawRRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xfff1d9b0).withValues(alpha: .22),
              const Color(0xfff1d9b0).withValues(alpha: 0),
            ],
          ).createShader(band.outerRect),
      );
    }
    final metric =
        (Path()..addRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            ))
            .computeMetrics()
            .first;
    final stitches = <double>[];
    final holes = <double>[];
    var i = 0;
    for (var d = 0.0; d + 4 < metric.length; d += 7, i++) {
      final a = metric.getTangentForOffset(d)!.position;
      final b = metric.getTangentForOffset(d + 4)!.position;
      final jitter = _wobble(i * 17.0) * .5;
      stitches.addAll([a.dx, a.dy + jitter, b.dx, b.dy - jitter]);
      holes.addAll([a.dx, a.dy + jitter, b.dx, b.dy - jitter]);
    }
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.fromList(holes),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: .45),
    );
    canvas.drawRawPoints(
      PointMode.lines,
      Float32List.fromList(stitches),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.3
        ..color = const Color(0xffcdb88e).withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(_StitchPainter oldDelegate) => false;
}

/// A tooled rule: two lines meeting at a diamond around [label].
class TomeRule extends StatelessWidget {
  const TomeRule({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget line(bool leading) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: leading
                ? [color.withValues(alpha: 0), color.withValues(alpha: .55)]
                : [color.withValues(alpha: .55), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
    Widget diamond() => Transform.rotate(
      angle: math.pi / 4,
      child: Container(width: 5, height: 5, color: color),
    );
    return Semantics(
      header: true,
      child: Row(
        children: [
          line(true),
          const SizedBox(width: 8),
          diamond(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                color: color,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          diamond(),
          const SizedBox(width: 8),
          line(false),
        ],
      ),
    );
  }
}
