import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../sync/presentation/sync_material.dart';
import 'watch_host.dart';
import 'watch_wall.dart';

/// Where everything in the Watchlist's header sits, open and collapsed,
/// measured once for the screen's width and text size.
@immutable
class WallHeaderMetrics {
  factory WallHeaderMetrics.of(BuildContext context, {String? ask}) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final top = media.padding.top;
    final scaler = media.textScaler;
    final host = scaler.scale(1) > 1.5 ? 104.0 : 132.0;

    final title = TextPainter(
      text: TextSpan(text: 'Watchlist', style: wallHand(context, size: 52)),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // Open, it gives way to Tyrion; collapsed, to the back button and him.
    final openRoom = width - _titleLeft - host - _side - 8;
    final openScale = math.min(1.0, openRoom / title.width);
    final barRoom = width - _barTitleLeft - _bead - _side - 12;
    final barScale = math.min(
      openScale * _barTitleSize / 52,
      barRoom / title.width,
    );

    double bubble = 0;
    if (ask != null) {
      final words = TextPainter(
        text: TextSpan(text: ask, style: bubbleHand(context)),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - _titleLeft - _side - 36);
      bubble = words.height + 28 + SpeechBubble.tail;
    }
    return WallHeaderMetrics._(
      width: width,
      top: top,
      host: host,
      titleSize: title.size,
      openScale: openScale,
      barScale: barScale,
      bubble: bubble,
    );
  }

  const WallHeaderMetrics._({
    required this.width,
    required this.top,
    required this.host,
    required this.titleSize,
    required this.openScale,
    required this.barScale,
    required this.bubble,
  });

  final double width, top, host;
  final Size titleSize;
  final double openScale, barScale;

  /// The bubble's height, tail included; 0 when Tyrion has nothing to say.
  final double bubble;

  static const _side = 14.0;
  static const _titleLeft = 20.0;
  static const _barTitleLeft = 66.0;
  static const _barTitleSize = 30.0;
  static const _bead = 44.0;
  static const _bar = 64.0;
  static const _tuck = 8.0;
  static const _squiggle = 16.0;

  double get _backTop => top + 8;
  double get _barCentre => _backTop + 24;

  double get _rowBottom {
    final column = 48 + 10 + titleSize.height * openScale + _squiggle;
    return _backTop + math.max(column, host);
  }

  double get maxExtent =>
      bubble == 0 ? _rowBottom + 12 : _rowBottom - _tuck + bubble + 14;
  double get minExtent => top + _bar;

  /// How far the wall scrolls before the header is fully collapsed.
  double get travel => maxExtent - minExtent;

  @override
  bool operator ==(Object other) =>
      other is WallHeaderMetrics &&
      other.width == width &&
      other.top == top &&
      other.host == host &&
      other.titleSize == titleSize &&
      other.bubble == bubble;

  @override
  int get hashCode => Object.hash(width, top, host, titleSize, bubble);
}

/// The handwriting in Tyrion's bubble.
TextStyle bubbleHand(BuildContext context) =>
    DiaryTypography.of(context).title.copyWith(fontSize: 22, height: 1.12);

/// The Watchlist's header. Open, it is the way back, the name in
/// handwriting and Tyrion standing over it with his offer in a bubble. As
/// the wall scrolls up, the name floats up into a bar beside the back
/// button while its underline un-draws, the bubble is drawn back into
/// Tyrion's mouth, and he flies up in a little arc to settle in a glass
/// porthole at the bar's end. As it closes the bar thins away along a long
/// eased curve below its edge, so the wall passes under seamlessly.
class WallHeaderDelegate extends SliverPersistentHeaderDelegate {
  const WallHeaderDelegate({required this.metrics, this.ask, this.onAsk});

  final WallHeaderMetrics metrics;
  final String? ask;
  final VoidCallback? onAsk;

  @override
  double get maxExtent => metrics.maxExtent;

  @override
  double get minExtent => metrics.minExtent;

  @override
  bool shouldRebuild(WallHeaderDelegate old) =>
      old.metrics != metrics || old.ask != ask || old.onAsk != onAsk;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final m = metrics;
    final t = m.travel <= 0 ? 0.0 : (shrinkOffset / m.travel).clamp(0.0, 1.0);
    return _CollapsingHeader(metrics: m, t: t, ask: ask, onAsk: onAsk);
  }
}

class _CollapsingHeader extends StatelessWidget {
  const _CollapsingHeader({
    required this.metrics,
    required this.t,
    this.ask,
    this.onAsk,
  });

  final WallHeaderMetrics metrics;

  /// 0 open, 1 collapsed into the bar.
  final double t;
  final String? ask;
  final VoidCallback? onAsk;

  static double _in(double t, double from, double to, [Curve? curve]) {
    final local = ((t - from) / (to - from)).clamp(0.0, 1.0);
    return curve == null ? local : curve.transform(local);
  }

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final palette = MorePalette.of(context);
    final cushion = CushionColors.of(context);
    final ask = this.ask;
    final onAsk = this.onAsk;
    final rowBottom = m._rowBottom;

    // Tyrion: across fast, up slow, so he travels in an arc.
    final across = Curves.easeInOutCubic.transform(t);
    final rise = Curves.easeOutQuart.transform(t);
    final size = lerpDouble(m.host, WallHeaderMetrics._bead - 6, across)!;
    final openLeft = m.width - WallHeaderMetrics._side - m.host;
    final barLeft =
        m.width - WallHeaderMetrics._side - WallHeaderMetrics._bead + 3;
    final left = lerpDouble(openLeft, barLeft, across)!;
    final top = lerpDouble(rowBottom - m.host, m._barCentre - size / 2, rise)!;
    final tilt = -math.sin(math.pi * t) * .16;
    final porthole = _in(t, .6, 1, Curves.easeOutBack);

    // The title floats up into the bar and shrinks to fit beside the back.
    final float = Curves.easeInOutCubic.transform(t);
    final titleScale = lerpDouble(m.openScale, m.barScale, float)!;
    final titleH = m.titleSize.height * titleScale;
    final titleLeft = lerpDouble(
      WallHeaderMetrics._titleLeft,
      WallHeaderMetrics._barTitleLeft,
      float,
    )!;
    final titleTop = lerpDouble(
      rowBottom -
          WallHeaderMetrics._squiggle -
          m.titleSize.height * m.openScale,
      m._barCentre - titleH / 2 - 2,
      float,
    )!;
    final drawn = 1 - _in(t, 0, .45, Curves.easeIn);

    // The bubble follows him up, shrinking into his mouth.
    final swallow = _in(t, 0, .55, Curves.easeInCubic);
    final bubbleLeft = WallHeaderMetrics._titleLeft;
    final bubbleWidth =
        m.width - WallHeaderMetrics._titleLeft - WallHeaderMetrics._side;
    final tailX = bubbleWidth - m.host / 2;
    final hem = _in(t, .6, 1, Curves.easeInOut);

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        // The bar: the page's ground, solid at the top and thinning away
        // past its lower edge as it closes, blurring what slips beneath.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -_EdgeFade.reach * hem,
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, box) => _EdgeFade(
                ground: palette.ground,
                amount: hem,
                // Solid to the middle of the title row; the curve starts so
                // softly that nothing shows behind the title itself.
                solid: box.maxHeight <= 0
                    ? 0
                    : ((m._barCentre - 4) / box.maxHeight).clamp(0.0, 1.0),
              ),
            ),
          ),
        ),
        if (ask != null && swallow < 1)
          Positioned(
            left: bubbleLeft + (left + size / 2 - (openLeft + m.host / 2)),
            top: top + size - WallHeaderMetrics._tuck,
            width: bubbleWidth,
            height: m.bubble,
            child: IgnorePointer(
              ignoring: swallow > .3,
              child: Opacity(
                opacity: 1 - _in(t, .05, .45),
                child: Transform.scale(
                  scale: 1 - .8 * swallow,
                  alignment: Alignment(tailX / bubbleWidth * 2 - 1, -1),
                  child: SpeechBubble(
                    text: ask,
                    stretch: true,
                    speaker: SpeakerSide.above,
                    tailFromEnd: m.host / 2,
                    semanticLabel: 'Tyrion: $ask',
                    onTap: onAsk,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: titleLeft,
          top: titleTop,
          child: Transform.scale(
            scale: titleScale,
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Watchlist',
                    maxLines: 1,
                    softWrap: false,
                    style: wallHand(context, size: 52),
                  ),
                ),
                if (drawn > 0)
                  ExcludeSemantics(
                    child: CustomPaint(
                      size: Size(
                        156 / math.max(m.openScale, .01),
                        WallHeaderMetrics._squiggle,
                      ),
                      painter: _Squiggle(palette.accent, drawn),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // The porthole he settles into.
        if (porthole > 0)
          Positioned(
            left: barLeft - 3 + WallHeaderMetrics._bead * (1 - porthole) / 2,
            top:
                m._barCentre -
                WallHeaderMetrics._bead / 2 +
                WallHeaderMetrics._bead * (1 - porthole) / 2,
            width: WallHeaderMetrics._bead * porthole,
            height: WallHeaderMetrics._bead * porthole,
            child: IgnorePointer(
              child: CustomPaint(painter: _PortholePainter(cushion)),
            ),
          ),
        Positioned(
          left: left,
          top: top,
          width: size,
          height: size,
          child: Transform.rotate(
            angle: tilt,
            child: Tooltip(
              message: ask == null ? '' : 'Pick something to watch',
              excludeFromSemantics: true,
              child: Semantics(
                button: onAsk != null && ask != null,
                label: ask == null ? null : 'Ask Tyrion to pick something',
                onTap: ask == null ? null : onAsk,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: ask == null || onAsk == null
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          onAsk();
                        },
                  child: Springy(
                    depth: .06,
                    alignment: Alignment.bottomCenter,
                    // Clipped round once he is in the porthole.
                    child: ClipOval(
                      clipper: _Porthole(porthole),
                      child: WatchlistMascot(dimension: size),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(left: 8, top: m._backTop, child: const GlassBackButton()),
      ],
    );
  }
}

/// No clip while he stands free; a circle once he has settled in.
class _Porthole extends CustomClipper<Rect> {
  const _Porthole(this.amount);
  final double amount;

  @override
  Rect getClip(Size size) {
    final grow = (1 - amount) * size.longestSide;
    return (Offset.zero & size).inflate(grow);
  }

  @override
  bool shouldReclip(_Porthole old) => old.amount != amount;
}

class _PortholePainter extends CustomPainter {
  const _PortholePainter(this.colors);
  final CushionColors colors;

  @override
  void paint(Canvas canvas, Size size) => paintGlass(
    canvas,
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide / 2),
    ),
    colors: colors,
    tint: colors.tint,
    fill: .22,
    lift: .8,
  );

  @override
  bool shouldRepaint(_PortholePainter old) => old.colors != colors;
}

/// The bar's ground, faded the way iOS fades its bars: solid where the
/// title sits, then thinning along a long, eased curve well past the edge,
/// so the wall passes under without any line. Open, it is just the page;
/// as the bar closes the fade reaches further down.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.ground, required this.amount, this.solid = 0});

  final Color ground;

  /// 0 open, 1 closed.
  final double amount;

  /// How far down, as a fraction of the height, it stays fully solid.
  final double solid;

  /// How far below the bar the fade reaches once closed.
  static const reach = 64.0;

  static final _stops = [for (var i = 0; i <= 24; i++) i / 24];

  double _alpha(double y) {
    if (y <= solid) return 1;
    final u = ((y - solid) / (1 - solid)).clamp(0.0, 1.0);
    // Smootherstep: no visible start or end to the fall.
    final eased = u * u * u * (u * (u * 6 - 15) + 10);
    return 1 - eased;
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: _stops,
        colors: [
          for (final y in _stops)
            ground.withValues(alpha: lerpDouble(1, _alpha(y), amount)!),
        ],
      ),
    ),
  );
}

/// The pen underline, drawn out to [drawn] of its length.
class _Squiggle extends CustomPainter {
  const _Squiggle(this.colour, this.drawn);
  final Color colour;
  final double drawn;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * .4;
    final end = size.width * drawn;
    final path = Path()..moveTo(0, y);
    for (var x = 0.0; x <= end; x += 2) {
      final rise = math.sin(x / 9) * 2.2 - x / size.width * 2.5;
      path.lineTo(x, y + rise);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = colour.withValues(alpha: .75 * drawn.clamp(.4, 1)),
    );
  }

  @override
  bool shouldRepaint(_Squiggle old) =>
      old.colour != colour || old.drawn != drawn;
}
