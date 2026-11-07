import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../application/recall_coverage.dart';

/// The color each kind of writing burns with in the Library sky.
Color recallStarColor(String kind) => switch (kind) {
  'note' => const Color(0xFFF4D58D),
  'diary' => const Color(0xFFF2A7B6),
  _ => const Color(0xFF9FD3F5),
};

String recallKindLabel(String kind) => switch (kind) {
  'note' => 'Notes',
  'diary' => 'Diary entries',
  _ => 'Flow thoughts',
};

IconData recallKindIcon(String kind) => switch (kind) {
  'note' => Icons.sticky_note_2_outlined,
  'diary' => Icons.menu_book_rounded,
  _ => Icons.water_rounded,
};

/// Each saved piece of writing is a star in its kind's constellation. Indexed
/// writing is lit; writing still waiting is dim. A finger is a lantern that
/// draws threads to nearby lit stars, the way a search draws meaning.
///
/// Stars twinkle only while indexing runs; everything else settles.
class RecallSky extends StatefulWidget {
  const RecallSky({
    super.key,
    required this.coverage,
    required this.enabled,
    required this.running,
    required this.dormant,
    required this.onConstellation,
    this.collapse = 0,
  });

  final Map<String, RecallCoverage> coverage;
  final Set<String> enabled;
  final bool running;

  /// No embedding model: the sky is drawn, but nothing can be lit.
  final bool dormant;
  final ValueChanged<String> onConstellation;
  final double collapse;

  /// Most stars drawn for one kind; beyond this each star stands for several.
  static const maxStars = 90;

  @override
  State<RecallSky> createState() => _RecallSkyState();
}

class _RecallSkyState extends State<RecallSky> with TickerProviderStateMixin {
  late final _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Offset? _lantern;
  Offset? _down;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTwinkle();
  }

  @override
  void didUpdateWidget(RecallSky oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTwinkle();
  }

  void _syncTwinkle() {
    final animate = RenderingPolicyScope.of(context).animate;
    if (widget.running && animate) {
      if (!_twinkle.isAnimating) _twinkle.repeat();
    } else if (_twinkle.isAnimating) {
      _twinkle.stop();
      _twinkle.value = 0;
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    _fade.dispose();
    super.dispose();
  }

  static List<Offset> centers(Size size) => [
    Offset(size.width * .2, size.height * .5),
    Offset(size.width * .52, size.height * .3),
    Offset(size.width * .8, size.height * .56),
  ];

  void _hold(Offset p) {
    setState(() => _lantern = p);
    _fade.value = 1;
  }

  void _release(Size size) {
    final down = _down, at = _lantern;
    _down = null;
    if (down != null && at != null && (at - down).distance < 12) {
      final all = centers(size);
      var best = -1;
      var bestDistance = double.infinity;
      for (var i = 0; i < all.length; i++) {
        final d = (all[i] - at).distance;
        if (d < bestDistance) {
          best = i;
          bestDistance = d;
        }
      }
      if (best >= 0 && bestDistance < size.shortestSide * .32) {
        widget.onConstellation(recallKinds[best]);
      }
    }
    if (RenderingPolicyScope.of(context).animate) {
      _fade.reverse(from: 1);
    } else {
      _fade.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            _down = e.localPosition;
            _hold(e.localPosition);
          },
          onPointerMove: (e) => _hold(e.localPosition),
          onPointerUp: (_) => _release(size),
          onPointerCancel: (_) {
            _down = null;
            _release(size);
          },
          // Newly indexed writing ignites star by star.
          child: _LitStars(
            coverage: widget.coverage,
            animate: policy.animate,
            builder: (lit) => AnimatedBuilder(
              animation: Listenable.merge([_twinkle, _fade]),
              builder: (context, _) => CustomPaint(
                size: size,
                painter: _SkyPainter(
                  coverage: widget.coverage,
                  lit: lit,
                  enabled: widget.enabled,
                  dormant: widget.dormant,
                  twinkle: widget.running ? _twinkle.value : null,
                  lantern: _lantern,
                  lanternStrength: Curves.easeOut.transform(_fade.value),
                  simpler: policy.simplerEffects,
                  collapse: widget.collapse,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animates how many stars of each kind are lit, so newly indexed writing
/// ignites one star after another.
class _LitStars extends StatelessWidget {
  const _LitStars({
    required this.coverage,
    required this.animate,
    required this.builder,
  });
  final Map<String, RecallCoverage> coverage;
  final bool animate;
  final Widget Function(Map<String, double> lit) builder;

  @override
  Widget build(BuildContext context) {
    Widget build(int i, Map<String, double> lit) {
      if (i == recallKinds.length) return builder(lit);
      final kind = recallKinds[i];
      final c = coverage[kind] ?? const RecallCoverage();
      final shown = math.min(c.saved, RecallSky.maxStars);
      final target = c.saved == 0 ? 0.0 : shown * c.indexed / c.saved;
      return TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: animate ? const Duration(milliseconds: 1400) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => build(i + 1, {...lit, kind: value}),
      );
    }

    return build(0, const {});
  }
}

class _Star {
  const _Star(this.position, this.size, this.phase);
  final Offset position;
  final double size, phase;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.coverage,
    required this.lit,
    required this.enabled,
    required this.dormant,
    required this.twinkle,
    required this.lantern,
    required this.lanternStrength,
    required this.simpler,
    required this.collapse,
  });

  final Map<String, RecallCoverage> coverage;
  final Map<String, double> lit;
  final Set<String> enabled;
  final bool dormant, simpler;
  final double? twinkle;
  final Offset? lantern;
  final double lanternStrength, collapse;

  static const _top = Color(0xFF0A0F2C), _bottom = Color(0xFF2A2756);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_top, _bottom],
        ).createShader(rect),
    );
    final fade = (1 - collapse * 1.3).clamp(0.0, 1.0);
    if (fade <= 0) return;

    // Far background dust and a soft river of light.
    final dust = math.Random(3);
    final speck = Paint();
    for (var i = 0; i < 120; i++) {
      speck.color = Colors.white.withValues(
        alpha: (.05 + dust.nextDouble() * .18) * fade,
      );
      canvas.drawCircle(
        Offset(dust.nextDouble() * size.width, dust.nextDouble() * size.height),
        .4 + dust.nextDouble() * .6,
        speck,
      );
    }
    if (!simpler) {
      final river = Path()
        ..moveTo(-20, size.height * .85)
        ..quadraticBezierTo(
          size.width * .5,
          size.height * .25,
          size.width + 20,
          size.height * .1,
        );
      canvas.drawPath(
        river,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * .22
          ..color = const Color(0xFF8C8CD8).withValues(alpha: .07 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
      );
    }

    final centers = _RecallSkyState.centers(size);
    final radius = math.min(size.width * .15, size.height * .26);
    final allLit = <(Offset, Color)>[];
    for (final (i, kind) in recallKinds.indexed) {
      allLit.addAll(_constellation(canvas, kind, centers[i], radius, fade));
    }

    final at = lantern;
    if (at != null && lanternStrength > 0) {
      final reach = size.shortestSide * .38;
      canvas.drawCircle(
        at,
        reach * .5,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFE2A8).withValues(alpha: .28 * lanternStrength),
              const Color(0xFFFFE2A8).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: at, radius: reach * .5)),
      );
      final near = [
        for (final star in allLit)
          if ((star.$1 - at).distance < reach) star,
      ]..sort((a, b) => (a.$1 - at).distance.compareTo((b.$1 - at).distance));
      for (final (p, color) in near.take(7)) {
        final closeness = 1 - (p - at).distance / reach;
        canvas.drawLine(
          at,
          p,
          Paint()
            ..strokeWidth = .6 + closeness
            ..shader = LinearGradient(
              colors: [
                const Color(0xFFFFE2A8).withValues(alpha: .7 * lanternStrength),
                color.withValues(alpha: .15 * lanternStrength),
              ],
            ).createShader(Rect.fromPoints(at, p)),
        );
        canvas.drawCircle(
          p,
          2.5 + 3 * closeness,
          Paint()
            ..color = color.withValues(alpha: .35 * closeness * lanternStrength)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawCircle(
        at,
        3,
        Paint()
          ..color = const Color(0xFFFFF4D6).withValues(alpha: lanternStrength),
      );
    }
  }

  /// Draws one kind's stars and returns where its lit stars are.
  List<(Offset, Color)> _constellation(
    Canvas canvas,
    String kind,
    Offset center,
    double radius,
    double fade,
  ) {
    final c = coverage[kind] ?? const RecallCoverage();
    final on = enabled.contains(kind);
    final tint = recallStarColor(kind);
    final presence = (on ? 1.0 : .28) * fade;
    final count = math.min(c.saved, RecallSky.maxStars);
    _label(canvas, kind, c, center, radius, on, presence);
    if (count == 0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tint.withValues(alpha: .22 * presence);
      for (var a = 0.0; a < math.pi * 2; a += math.pi / 10) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius * .55),
          a,
          math.pi / 20,
          false,
          ring,
        );
      }
      return const [];
    }

    final rng = math.Random(kind.hashCode & 0xffff);
    final stars = <_Star>[];
    for (var i = 0; i < count; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      // The brightest, earliest stars gather near the heart of the shape.
      final spread = .25 + .75 * math.sqrt((i + 1) / count);
      final r = radius * spread * (.35 + .65 * rng.nextDouble());
      stars.add(
        _Star(
          center + Offset(math.cos(a) * r * 1.15, math.sin(a) * r * .85),
          .7 + rng.nextDouble() * 1.5,
          rng.nextDouble() * math.pi * 2,
        ),
      );
    }

    final litCount = dormant ? 0.0 : (lit[kind] ?? 0);
    final full = litCount.floor();

    // Constellation lines between the first lit stars.
    final thread = Paint()
      ..strokeWidth = .8
      ..color = tint.withValues(alpha: .28 * presence);
    final linked = math.min(full, 9);
    for (var i = 1; i < linked; i++) {
      var nearest = 0;
      for (var j = 1; j < i; j++) {
        if ((stars[j].position - stars[i].position).distance <
            (stars[nearest].position - stars[i].position).distance) {
          nearest = j;
        }
      }
      canvas.drawLine(stars[nearest].position, stars[i].position, thread);
    }

    final shining = <(Offset, Color)>[];
    final glow = Paint();
    final core = Paint();
    for (final (i, star) in stars.indexed) {
      final ignition = (litCount - i).clamp(0.0, 1.0);
      final twinkling = twinkle == null
          ? 1.0
          : .7 + .3 * math.sin(twinkle! * math.pi * 2 + star.phase);
      if (ignition <= 0) {
        core.color = Colors.white.withValues(alpha: .16 * presence);
        canvas.drawCircle(star.position, star.size * .6, core);
        continue;
      }
      shining.add((star.position, tint));
      // A newly lit star flares, then settles.
      final flare = math.sin(ignition * math.pi);
      final size = star.size * (1 + .8 * flare);
      if (!simpler) {
        glow
          ..color = tint.withValues(
            alpha: (.22 + .3 * flare) * presence * twinkling * ignition,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 2.2);
        canvas.drawCircle(star.position, size * 2, glow);
      }
      core.color = Color.lerp(
        Colors.white,
        tint,
        .35,
      )!.withValues(alpha: (.55 + .45 * ignition) * presence * twinkling);
      canvas.drawCircle(star.position, size, core);
      if (star.size > 1.8 && !simpler) {
        final spike = Paint()
          ..strokeWidth = .6
          ..color = Colors.white.withValues(alpha: .45 * presence * ignition);
        canvas.drawLine(
          star.position.translate(-size * 3, 0),
          star.position.translate(size * 3, 0),
          spike,
        );
        canvas.drawLine(
          star.position.translate(0, -size * 3),
          star.position.translate(0, size * 3),
          spike,
        );
      }
    }
    return on ? shining : const [];
  }

  void _label(
    Canvas canvas,
    String kind,
    RecallCoverage c,
    Offset center,
    double radius,
    bool on,
    double presence,
  ) {
    final name = switch (kind) {
      'note' => 'NOTES',
      'diary' => 'DIARY',
      _ => 'FLOW',
    };
    final detail = !on
        ? 'off'
        : c.saved == 0
        ? 'none yet'
        : '${c.indexed}/${c.saved}';
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$name\n',
            style: TextStyle(
              color: recallStarColor(kind).withValues(alpha: .85 * presence),
              fontSize: 9.5,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: detail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .55 * presence),
              fontSize: 10,
            ),
          ),
        ],
      ),
    )..layout();
    painter.paint(
      canvas,
      center.translate(-painter.width / 2, radius * .95 + 8),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(_SkyPainter old) => true;
}
