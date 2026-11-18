import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';

/// One destination on the shelf.
@immutable
class MoreShelfItem {
  const MoreShelfItem({
    required this.title,
    required this.artworkBuilder,
    required this.onTap,
    required this.tint,
    this.status,
    this.ready = false,
  });

  final String title;
  final Widget Function(double dimension) artworkBuilder;
  final VoidCallback onTap;

  /// The colour of this cushion's liquid glass.
  final Color tint;

  /// Live state, spoken to assistive tech and shown as a glass rivet.
  final String? status;
  final bool ready;
}

/// The More page's destinations as stuffed cushions sitting low on the page,
/// within easy reach of the thumb. Each character is tucked into a liquid-
/// glass pocket stitched across its cushion: a press pushes it down into the
/// pocket and letting go springs it back out with a wobble.
///
/// Narrow screens and large text get one full-width cushion per row instead.
///
/// The cushions and pockets never repaint after layout: each sits in its own
/// cached layer, and every movement is a transform of those layers.
class MoreShelf extends StatefulWidget {
  const MoreShelf({super.key, required this.items});

  final List<MoreShelfItem> items;

  static const _gap = 10.0;
  static const _maxWidth = 480.0;

  @override
  State<MoreShelf> createState() => _MoreShelfState();
}

class _MoreShelfState extends State<MoreShelf>
    with SingleTickerProviderStateMixin {
  /// Cushions settle onto the shelf, then their characters pop up, once.
  late final _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (RenderingPolicyScope.of(context).animate) {
      _rise.forward();
    } else {
      _rise.value = 1;
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _rise,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, MoreShelf._maxWidth);
        final count = items.length;
        final tileWidth = (width - MoreShelf._gap * (count - 1)) / count;
        final pockets = tileWidth >= 84 && scaler.scale(15) <= 19.5;
        if (!pockets) {
          return Column(
            key: const ValueKey('more-shelf-rows'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(height: MoreShelf._gap),
                _Cushion(
                  item: items[i],
                  settle: _interval(i * .1, .45 + i * .1, Curves.easeOutCubic),
                  pop: _interval(.3 + i * .1, .8 + i * .1, Curves.easeOut),
                  layout: _RowLayout(width: constraints.maxWidth),
                ),
              ],
            ],
          );
        }

        final layout = _PocketLayout.of(context, tileWidth, items);
        return Center(
          child: SizedBox(
            key: const ValueKey('more-shelf-pockets'),
            width: width,
            child: Padding(
              // Room for the characters standing up out of their pockets.
              padding: EdgeInsets.only(top: layout.headroom),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) const SizedBox(width: MoreShelf._gap),
                    _Cushion(
                      item: items[i],
                      settle: _interval(
                        i * .08,
                        .42 + i * .08,
                        Curves.easeOutCubic,
                      ),
                      pop: _interval(
                        .3 + i * .1,
                        .8 + i * .1,
                        const ElasticOutCurve(.55),
                      ),
                      layout: layout,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

sealed class _Layout {
  const _Layout();
}

/// A full-width cushion per destination.
final class _RowLayout extends _Layout {
  const _RowLayout({required this.width});
  final double width;
}

/// Tall cushions side by side, each with a pocket.
final class _PocketLayout extends _Layout {
  const _PocketLayout({
    required this.size,
    required this.art,
    required this.seam,
    required this.fontSize,
  });

  factory _PocketLayout.of(
    BuildContext context,
    double tileWidth,
    List<MoreShelfItem> items,
  ) {
    final height = (tileWidth * 1.5).clamp(150.0, 200.0);
    final art = math.min(tileWidth * .95, 132.0);
    // Shrink the labels together until the longest single word fits.
    final base = DefaultTextStyle.of(context).style
        .merge(_PocketLayout.labelStyle(15));
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final item in items) {
      for (final word in item.title.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: base),
          textScaler: scaler,
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
    }
    final room = tileWidth - 2 * _labelInset;
    final fontSize = widest <= room ? 15.0 : math.max(11.0, 15 * room / widest);
    return _PocketLayout(
      size: Size(tileWidth, height),
      art: art,
      seam: height * .4,
      fontSize: fontSize,
    );
  }

  static const _labelInset = 8.0;

  static TextStyle labelStyle(double size) => TextStyle(
    fontSize: size,
    height: 1.15,
    letterSpacing: -.2,
    fontWeight: FontWeight.w600,
  );

  final Size size;
  final double art;

  /// Where the pocket's mouth crosses the cushion, from its top.
  final double seam;
  final double fontSize;

  /// The character's top edge at rest, in the cushion's coordinates.
  double get artTop => seam + art * .22 - art;

  /// How far the characters stand above the cushions, plus their spring.
  double get headroom => math.max(0, -artTop) + 8;

  @override
  bool operator ==(Object other) =>
      other is _PocketLayout &&
      other.size == size &&
      other.art == art &&
      other.seam == seam &&
      other.fontSize == fontSize;

  @override
  int get hashCode => Object.hash(size, art, seam, fontSize);
}

class _Cushion extends StatefulWidget {
  const _Cushion({
    required this.item,
    required this.settle,
    required this.pop,
    required this.layout,
  });

  final MoreShelfItem item;

  /// The cushion settling onto the shelf.
  final Animation<double> settle;

  /// The character rising out of its pocket.
  final Animation<double> pop;
  final _Layout layout;

  @override
  State<_Cushion> createState() => _CushionState();
}

class _CushionState extends State<_Cushion>
    with SingleTickerProviderStateMixin {
  /// 1 is pressed fully in; below 0 is the spring overshooting on release.
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
    HapticFeedback.selectionClick();
    if (!RenderingPolicyScope.of(context).animate) return;
    _press.animateTo(1, curve: Curves.easeOut);
  }

  void _up() {
    if (!RenderingPolicyScope.of(context).animate) return;
    _press.animateTo(
      0,
      duration: const Duration(milliseconds: 620),
      curve: const ElasticOutCurve(.42),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = Theme.of(context).colorScheme;
    final palette = MorePalette.of(context);
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final dark = colors.brightness == Brightness.dark;
    final material = _CushionMaterial(
      back: Color.lerp(colors.surfaceContainerLow, item.tint, dark ? .1 : .07)!,
      front: Color.alphaBlend(
        item.tint.withValues(alpha: dark ? .16 : .1),
        dark ? colors.surfaceContainerHigh : colors.surfaceContainerLowest,
      ),
      tint: item.tint,
      edge: colors.outlineVariant,
      shadow: colors.shadow,
      dark: dark,
      simple: simple,
    );
    final status = item.status;
    final layout = widget.layout;
    final body = switch (layout) {
      _PocketLayout() => _pocket(layout, material, palette),
      _RowLayout() => _row(layout, material, palette),
    };
    return Semantics(
      container: true,
      button: true,
      label: status == null ? item.title : '${item.title}, $status',
      excludeSemantics: true,
      onTap: item.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        onTap: item.onTap,
        child: AnimatedBuilder(
          animation: widget.settle,
          builder: (context, child) {
            final t = widget.settle.value;
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 36),
                child: child,
              ),
            );
          },
          child: body,
        ),
      ),
    );
  }

  Widget _pocket(
    _PocketLayout layout,
    _CushionMaterial material,
    MorePalette palette,
  ) {
    final item = widget.item;
    final size = layout.size;
    final art = layout.art;
    final rivet = item.status == null
        ? null
        : (ready: item.ready, color: item.ready ? item.tint : palette.muted);
    return AnimatedBuilder(
      animation: _press,
      builder: (context, child) {
        final p = _press.value;
        // Squashed into the shelf when pressed, stretched on the rebound.
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(1 + .025 * p, 1 - .045 * p, 1),
          child: child,
        );
      },
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BackPainter(
                    material: material,
                    seam: layout.seam,
                    halo: art,
                  ),
                ),
              ),
            ),
            // The character, cut off below the cushion so it can sink into
            // the pocket without showing underneath.
            Positioned(
              left: -art,
              right: -art,
              top: layout.artTop - 40,
              bottom: 0,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_press, widget.pop]),
                  builder: (context, child) {
                    final hidden = 1 - widget.pop.value;
                    final dip = _press.value;
                    return Transform.translate(
                      offset: Offset(0, hidden * art * .45 + dip * 14),
                      child: Transform.scale(
                        scale: 1 - .04 * dip,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    );
                  },
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: ExcludeSemantics(
                        child: RepaintBoundary(
                          child: SizedBox.square(
                            dimension: art,
                            child: item.artworkBuilder(art),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _PocketPainter(
                    material: material,
                    seam: layout.seam,
                    rivet: rivet,
                  ),
                ),
              ),
            ),
            Positioned(
              left: _PocketLayout._labelInset,
              right: _PocketLayout._labelInset,
              top: layout.seam + 20,
              bottom: 12,
              child: Center(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _PocketLayout.labelStyle(layout.fontSize)
                      .copyWith(color: palette.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(_RowLayout layout, _CushionMaterial material, MorePalette p) {
    final item = widget.item;
    final showArtwork =
        layout.width >= 250 && MediaQuery.textScalerOf(context).scale(14) <= 20;
    const art = 52.0;
    return AnimatedBuilder(
      animation: _press,
      builder: (context, child) {
        final v = _press.value;
        return Transform.scale(
          scaleX: 1 - .015 * v,
          scaleY: 1 - .04 * v,
          child: child,
        );
      },
      child: CustomPaint(
        painter: _BackPainter(material: material),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                if (showArtwork) ...[
                  ExcludeSemantics(
                    child: RepaintBoundary(
                      child: SizedBox.square(
                        dimension: art,
                        child: item.artworkBuilder(art),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _PocketLayout.labelStyle(17).copyWith(color: p.ink),
                  ),
                ),
                if (item.status != null) ...[
                  const SizedBox(width: 10),
                  CustomPaint(
                    size: const Size.square(12),
                    painter: _RivetPainter(
                      material: material,
                      ready: item.ready,
                      color: item.ready ? item.tint : p.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _CushionMaterial {
  const _CushionMaterial({
    required this.back,
    required this.front,
    required this.tint,
    required this.edge,
    required this.shadow,
    required this.dark,
    required this.simple,
  });

  final Color back, front, tint, edge, shadow;
  final bool dark, simple;

  static const radius = 28.0;

  RRect body(Size size) => RRect.fromRectAndRadius(
    Offset.zero & size,
    Radius.circular(math.min(radius, size.shortestSide / 2)),
  );

  @override
  bool operator ==(Object other) =>
      other is _CushionMaterial &&
      other.back == back &&
      other.front == front &&
      other.tint == tint &&
      other.edge == edge &&
      other.shadow == shadow &&
      other.dark == dark &&
      other.simple == simple;

  @override
  int get hashCode =>
      Object.hash(back, front, tint, edge, shadow, dark, simple);

  /// A running stitch, with a light catch on each thread.
  void stitch(Canvas canvas, Path stitches) {
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1;
    canvas.drawPath(
      stitches.shift(const Offset(0, .8)),
      thread..color = Colors.white.withValues(alpha: dark ? .05 : .7),
    );
    canvas.drawPath(
      stitches,
      thread..color = edge.withValues(alpha: dark ? .7 : .85),
    );
  }

  static Path dashes(Path outline, {bool Function(Offset at)? where}) {
    final stitches = Path();
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        final at = metric.getTangentForOffset(d + 2.25)?.position;
        if (where != null && (at == null || !where(at))) continue;
        stitches.addPath(metric.extractPath(d, d + 4.5), Offset.zero);
      }
    }
    return stitches;
  }

  void hairline(Canvas canvas, RRect body) => canvas.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = edge.withValues(alpha: dark ? .85 : .7),
  );
}

/// The cushion behind the pocket: lofted, stitched, with a pool of the
/// destination's colour glowing where its character stands.
class _BackPainter extends CustomPainter {
  const _BackPainter({required this.material, this.seam, this.halo});

  final _CushionMaterial material;
  final double? seam;
  final double? halo;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final m = material;
    final rect = Offset.zero & size;
    final body = m.body(size);
    if (m.simple) {
      canvas.drawRRect(body, Paint()..color = m.back);
      m.hairline(canvas, body);
      return;
    }

    // Crisp, stacked offsets read as a soft settle with no blur.
    canvas.drawRRect(
      body.shift(const Offset(0, 5)),
      Paint()..color = m.shadow.withValues(alpha: m.dark ? .26 : .06),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 1.6)),
      Paint()..color = m.shadow.withValues(alpha: m.dark ? .4 : .12),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(m.back, Colors.white, m.dark ? .07 : .55)!,
            m.back,
            Color.lerp(m.back, Colors.black, m.dark ? .22 : .06)!,
          ],
          stops: const [0, .5, 1],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRRect(body);
    final halo = this.halo;
    if (halo != null) {
      final centre = Offset(size.width / 2, (this.seam ?? size.height / 2) - 6);
      final reach = math.max(halo * .75, size.width * .6);
      canvas.drawCircle(
        centre,
        reach,
        Paint()
          ..shader = RadialGradient(
            colors: [
              m.tint.withValues(alpha: m.dark ? .34 : .2),
              m.tint.withValues(alpha: m.dark ? .12 : .07),
              m.tint.withValues(alpha: 0),
            ],
            stops: const [0, .5, 1],
          ).createShader(Rect.fromCircle(center: centre, radius: reach)),
      );
    }
    // Loft: light pooling high on the cushion.
    final loft = math.min(size.height, 120.0);
    canvas.translate(size.width / 2, size.height * .08);
    canvas.scale(size.width * .6 / loft, 1);
    canvas.drawCircle(
      Offset.zero,
      loft,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: m.dark ? .06 : .4),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: loft)),
    );
    canvas.restore();

    final seam = this.seam;
    final hem = body.deflate(7);
    m.stitch(
      canvas,
      _CushionMaterial.dashes(
        Path()..addRRect(hem),
        where: seam == null ? null : (at) => at.dy < seam,
      ),
    );

    // Glassy lip: a bright top edge, bounce light underneath.
    canvas.drawRRect(
      body.deflate(.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: m.dark ? .22 : .95),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            m.tint.withValues(alpha: m.dark ? .35 : .3),
          ],
          stops: const [0, .3, .8, 1],
        ).createShader(rect),
    );
    m.hairline(canvas, body);
  }

  @override
  bool shouldRepaint(_BackPainter old) =>
      material != old.material || seam != old.seam || halo != old.halo;
}

/// The pocket sewn across the cushion's lower half: a slab of tinted liquid
/// glass with a sagging mouth, a specular band under its lip, and a shadow
/// falling into it over the character.
class _PocketPainter extends CustomPainter {
  const _PocketPainter({
    required this.material,
    required this.seam,
    required this.rivet,
  });

  final _CushionMaterial material;
  final double seam;
  final ({bool ready, Color color})? rivet;

  static const _sag = 12.0;

  Path _mouth(Size size, [double dy = 0]) => Path()
    ..moveTo(0, seam + dy)
    ..quadraticBezierTo(
      size.width / 2,
      seam + _sag * 2 + dy,
      size.width,
      seam + dy,
    );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final m = material;
    final rect = Offset.zero & size;
    final body = m.body(size);
    final below = _mouth(size)
      ..lineTo(size.width, size.height + 1)
      ..lineTo(0, size.height + 1)
      ..close();

    // Darkness inside the pocket, over the character's lower edge.
    if (!m.simple) {
      canvas.save();
      canvas.clipRRect(body);
      final depth = Rect.fromLTRB(0, seam - 22, size.width, seam + _sag + 2);
      canvas.drawRect(
        depth,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              m.shadow.withValues(alpha: 0),
              m.shadow.withValues(alpha: m.dark ? .4 : .16),
            ],
          ).createShader(depth),
      );
      canvas.restore();
    }

    canvas.save();
    canvas.clipPath(below);
    final pocket = Rect.fromLTRB(0, seam, size.width, size.height);
    if (m.simple) {
      canvas.drawRRect(body, Paint()..color = m.front);
    } else {
      canvas.drawRRect(
        body,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.3, -1),
            radius: 1.3,
            colors: [
              Color.lerp(m.front, Colors.white, m.dark ? .1 : .6)!,
              m.front,
              Color.lerp(m.front, m.tint, m.dark ? .18 : .14)!,
            ],
            stops: const [0, .55, 1],
          ).createShader(pocket),
      );
      // The specular band: light caught under the glass lip.
      final band = Rect.fromLTRB(0, seam, size.width, seam + _sag + 18);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: m.dark ? .16 : .55),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(band),
      );
      m.stitch(
        canvas,
        _CushionMaterial.dashes(
          Path()
            ..addPath(_mouth(size, 9), Offset.zero)
            ..addRRect(body.deflate(7)),
          where: (at) =>
              at.dy > seam + _sag + 4 || at.dx > 9 && at.dx < size.width - 9,
        ),
      );
    }
    m.hairline(canvas, body);
    canvas.restore();

    // The lip: a dark line where it meets the character, a bright rim above.
    final lip = _mouth(size);
    canvas.drawPath(
      lip.shift(const Offset(0, -.6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = m.shadow.withValues(alpha: m.dark ? .5 : .18),
    );
    if (!m.simple) {
      canvas.drawPath(
        lip.shift(const Offset(0, .8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: m.dark ? .35 : .95),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    final rivet = this.rivet;
    if (rivet != null) {
      canvas.save();
      canvas.translate(size.width - 22, seam + 8);
      _RivetPainter(
        material: m,
        ready: rivet.ready,
        color: rivet.color,
      ).paint(canvas, const Size.square(10));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PocketPainter old) =>
      material != old.material || seam != old.seam || rivet != old.rivet;
}

/// A glass bead: lit with the cushion's colour when its destination is ready,
/// an empty socket when it still needs setting up.
class _RivetPainter extends CustomPainter {
  const _RivetPainter({
    required this.material,
    required this.ready,
    required this.color,
  });

  final _CushionMaterial material;
  final bool ready;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final m = material;
    final centre = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (!ready) {
      canvas.drawCircle(
        centre,
        r - .7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color,
      );
      return;
    }
    if (!m.simple) {
      canvas.drawCircle(
        centre,
        r * 1.9,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .45), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: r * 1.9)),
      );
    }
    canvas.drawCircle(centre, r, Paint()..color = color);
    if (!m.simple) {
      canvas.drawCircle(
        centre.translate(-r * .3, -r * .35),
        r * .38,
        Paint()..color = Colors.white.withValues(alpha: .7),
      );
    }
  }

  @override
  bool shouldRepaint(_RivetPainter old) =>
      material != old.material || ready != old.ready || color != old.color;
}
