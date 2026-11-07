import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../domain/ai_provider.dart';

/// The capabilities shown as links of the Maestar's chain, in chain order.
const maestarLinks = [
  AiCapability.chat,
  AiCapability.vision,
  AiCapability.embeddings,
  AiCapability.transcription,
  AiCapability.image,
];

/// Each link of the chain is forged from its own metal.
Color maestarMetal(AiCapability capability) => switch (capability) {
  AiCapability.chat => const Color(0xFFD4A84B), // gold
  AiCapability.vision => const Color(0xFFB9C0C8), // silver
  AiCapability.embeddings => const Color(0xFF7F8A96), // iron
  AiCapability.transcription => const Color(0xFFC46A3C), // copper
  AiCapability.image => const Color(0xFFA97B3F), // bronze
};

String maestarMetalName(AiCapability capability) => switch (capability) {
  AiCapability.chat => 'gold',
  AiCapability.vision => 'silver',
  AiCapability.embeddings => 'iron',
  AiCapability.transcription => 'copper',
  AiCapability.image => 'bronze',
};

IconData maestarIcon(AiCapability capability) => switch (capability) {
  AiCapability.chat => Icons.edit_note_rounded,
  AiCapability.vision => Icons.image_search_rounded,
  AiCapability.embeddings => Icons.auto_awesome_rounded,
  AiCapability.transcription => Icons.graphic_eq_rounded,
  AiCapability.image => Icons.palette_outlined,
};

/// The open header of Grand Maestar: a candlelit study with the Maestar's
/// portrait and the chain whose links are forged by the chosen models.
///
/// Every animation here settles: the candle is lit once when the page opens,
/// a link glows once when it is forged, and a tilted portrait springs back.
class MaestarStudy extends StatefulWidget {
  const MaestarStudy({
    super.key,
    required this.portrait,
    required this.forged,
    required this.selected,
    required this.onLink,
    this.collapse = 0,
  });

  final ImageProvider portrait;
  final Set<AiCapability> forged;
  final AiCapability? selected;
  final ValueChanged<AiCapability> onLink;

  /// How far the page has scrolled the study away, from 0 to 1.
  final double collapse;

  @override
  State<MaestarStudy> createState() => _MaestarStudyState();
}

class _MaestarStudyState extends State<MaestarStudy>
    with TickerProviderStateMixin {
  late final _light = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Offset _tilt = Offset.zero;
  Offset _released = Offset.zero;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (RenderingPolicyScope.of(context).animate) {
      _light.forward();
    } else {
      _light.value = 1;
    }
  }

  @override
  void initState() {
    super.initState();
    _spring.addListener(() {
      final t = Curves.elasticOut.transform(_spring.value);
      setState(() => _tilt = Offset.lerp(_released, Offset.zero, t)!);
    });
  }

  @override
  void dispose() {
    _light.dispose();
    _spring.dispose();
    super.dispose();
  }

  void _lean(Offset local, Size size) {
    if (!RenderingPolicyScope.of(context).animate) return;
    _spring.stop();
    final dx = (local.dx / size.width - .5) * 2;
    final dy = (local.dy / size.height - .5) * 2;
    setState(() => _tilt = Offset(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0)));
  }

  void _settle() {
    if (_tilt == Offset.zero) return;
    _released = _tilt;
    _spring.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final policy = RenderingPolicyScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final portrait = math.min(size.height * .5, 176.0);
        final portraitCenter = Offset(size.width / 2, size.height * .38);
        final chainWidth = math.min(size.width - 56, 300.0);
        final chainY = portraitCenter.dy + portrait * .5 + 26;
        return Opacity(
          opacity: (1 - widget.collapse * 1.35).clamp(0.0, 1.0),
          // Raw pointers, so leaning the portrait never competes with scrolling.
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _lean(e.localPosition, size),
            onPointerMove: (e) => _lean(e.localPosition, size),
            onPointerUp: (_) => _settle(),
            onPointerCancel: (_) => _settle(),
            child: AnimatedBuilder(
              animation: _light,
              builder: (context, _) {
                final light = Curves.easeOutCubic.transform(_light.value);
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: ExcludeSemantics(
                        child: CustomPaint(
                          painter: _StudyPainter(
                            palette: palette,
                            dark: dark,
                            light: light,
                            tilt: _tilt,
                            focus: portraitCenter,
                            simpler: policy.simplerEffects,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: portraitCenter.dx - portrait / 2,
                      top: portraitCenter.dy - portrait / 2,
                      width: portrait,
                      height: portrait,
                      child: ExcludeSemantics(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .0016)
                            ..rotateX(-_tilt.dy * .22)
                            ..rotateY(_tilt.dx * .28),
                          child: Transform.translate(
                            offset: Offset(0, (1 - light) * 12),
                            child: Opacity(
                              opacity: (.25 + light * .75).clamp(0.0, 1.0),
                              child: Image(
                                image: widget.portrait,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final (i, capability) in maestarLinks.indexed)
                      _positionedLink(
                        i,
                        capability,
                        chainWidth: chainWidth,
                        centerX: size.width / 2,
                        baseY: chainY,
                        light: light,
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _positionedLink(
    int i,
    AiCapability capability, {
    required double chainWidth,
    required double centerX,
    required double baseY,
    required double light,
  }) {
    const box = 52.0;
    final u = (i - 2) / 2;
    final x = centerX + u * chainWidth / 2 * .82;
    final sag = 18.0;
    final y = baseY + sag * (1 - u * u);
    final slope = -2 * sag * u / (chainWidth / 2 * .82);
    final appear = ((light - i * .09) / .5).clamp(0.0, 1.0);
    final forged = widget.forged.contains(capability);
    final selected = widget.selected == capability;
    return Positioned(
      left: x - box / 2,
      top: y - box / 2,
      width: box,
      height: box,
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '${capability.label}, ${maestarMetalName(capability)} link, ${forged ? 'forged' : 'not forged'}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onLink(capability),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: forged ? 1 : 0),
            duration: RenderingPolicyScope.of(context).animate
                ? const Duration(milliseconds: 700)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, forging, _) => CustomPaint(
              painter: MaestarLinkPainter(
                metal: maestarMetal(capability),
                forged: forging * appear,
                edgeOn: i.isOdd,
                angle: math.atan(slope),
                selected: selected,
                faint: MorePalette.of(context).ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One link of the chain. [forged] runs from a faint outline (0) to polished
/// metal (1), with a brief glow while it is being forged.
class MaestarLinkPainter extends CustomPainter {
  const MaestarLinkPainter({
    required this.metal,
    required this.forged,
    required this.faint,
    this.edgeOn = false,
    this.angle = 0,
    this.selected = false,
  });

  final Color metal, faint;
  final double forged, angle;
  final bool edgeOn, selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    final w = size.width * .86;
    final h = edgeOn ? size.height * .26 : size.height * .56;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final link = RRect.fromRectAndRadius(rect, Radius.circular(h / 2));
    final stroke = edgeOn ? h * .9 : size.shortestSide * .11;

    if (selected) {
      canvas.drawRRect(
        link.inflate(5),
        Paint()
          ..color = metal.withValues(alpha: .22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // The outline every link has before it is forged.
    final outline = Paint()
      ..style = edgeOn ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = faint.withValues(alpha: .18 * (1 - forged));
    canvas.drawRRect(edgeOn ? link.deflate(h * .2) : link, outline);
    if (forged <= 0) {
      canvas.restore();
      return;
    }

    // A forge glow that peaks halfway through and fades once the metal cools.
    final heat = math.sin(forged * math.pi);
    if (heat > .01) {
      canvas.drawRRect(
        link.inflate(4),
        Paint()
          ..color = Color.lerp(
            metal,
            const Color(0xFFFFB347),
            .6,
          )!.withValues(alpha: .45 * heat)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    final hsl = HSLColor.fromColor(metal);
    final bright = hsl
        .withLightness((hsl.lightness + .28).clamp(0, 1))
        .toColor();
    final deep = hsl.withLightness((hsl.lightness - .24).clamp(0, 1)).toColor();
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [bright, metal, deep, metal, bright],
      stops: const [0, .3, .55, .8, 1],
    ).createShader(rect.inflate(stroke));
    final body = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.saveLayer(
      rect.inflate(stroke + 8),
      Paint()..color = Colors.white.withValues(alpha: forged.clamp(0, 1)),
    );
    if (edgeOn) {
      canvas.drawLine(
        Offset(-w / 2 + stroke / 2, 0),
        Offset(w / 2 - stroke / 2, 0),
        body,
      );
    } else {
      canvas.drawRRect(link, body);
      // A thin specular line along the upper edge.
      canvas.drawRRect(
        link.deflate(stroke * .28),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: .32),
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(MaestarLinkPainter old) =>
      old.metal != metal ||
      old.forged != forged ||
      old.edgeOn != edgeOn ||
      old.angle != angle ||
      old.selected != selected ||
      old.faint != faint;
}

class _StudyPainter extends CustomPainter {
  const _StudyPainter({
    required this.palette,
    required this.dark,
    required this.light,
    required this.tilt,
    required this.focus,
    required this.simpler,
  });

  final MorePalette palette;
  final bool dark, simpler;

  /// The candle being lit, from 0 to 1.
  final double light;
  final Offset tilt, focus;

  static const _flame = Color(0xFFFFB347);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // The page's own surface, so the study runs on into the toolbar above.
    canvas.drawRect(rect, Paint()..color = palette.ground);

    _window(canvas, size);

    // Candlelight warms the whole study.
    final glowRadius = size.shortestSide * (.35 + .4 * light);
    canvas.drawCircle(
      focus,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(
              palette.accent,
              _flame,
              .55,
            )!.withValues(alpha: (dark ? .30 : .20) * light),
            palette.accent.withValues(alpha: (dark ? .10 : .06) * light),
            palette.accent.withValues(alpha: 0),
          ],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: focus, radius: glowRadius)),
    );

    _shelf(canvas, size);
    _candle(canvas, size);
  }

  /// A pointed arch window behind the Maestar, with stars after dark.
  void _window(Canvas canvas, Size size) {
    final w = math.min(size.width * .58, 260.0);
    final left = focus.dx - w / 2 - tilt.dx * 6, right = left + w;
    final top = size.height * .04 - tilt.dy * 4;
    final bottom = size.height * .80;
    final spring = top + w * .62;
    final cx = (left + right) / 2;
    final arch = Path()
      ..moveTo(left, bottom)
      ..lineTo(left, spring)
      ..quadraticBezierTo(left, top + w * .12, cx, top)
      ..quadraticBezierTo(right, top + w * .12, right, spring)
      ..lineTo(right, bottom)
      ..close();
    final bounds = arch.getBounds();
    canvas.drawPath(
      arch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [const Color(0xFF0E1433), const Color(0xFF262552)]
              : [
                  Color.lerp(const Color(0xFFBFDCEF), palette.ground, .35)!,
                  Color.lerp(const Color(0xFFFCE8C8), palette.ground, .3)!,
                ],
        ).createShader(bounds)
        ..color = Colors.white.withValues(alpha: .4 + .6 * light),
    );
    canvas.save();
    canvas.clipPath(arch);
    if (dark) {
      final rng = math.Random(7);
      final star = Paint()..color = Colors.white;
      for (var i = 0; i < 46; i++) {
        final p = Offset(
          left + rng.nextDouble() * w,
          top + rng.nextDouble() * (bottom - top) * .7,
        );
        star.color = Colors.white.withValues(
          alpha: (.25 + rng.nextDouble() * .6) * light,
        );
        canvas.drawCircle(p, .5 + rng.nextDouble() * 1.1, star);
      }
    } else if (!simpler) {
      // Soft clouds drifting with the tilt.
      final cloud = Paint()
        ..color = Colors.white.withValues(alpha: .55 * light)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (final (dx, dy, r) in [
        (.25, .3, 22.0),
        (.4, .28, 18.0),
        (.7, .45, 20.0),
      ]) {
        canvas.drawCircle(
          Offset(left + w * dx + tilt.dx * 10, top + (bottom - top) * dy),
          r,
          cloud,
        );
      }
    }
    canvas.restore();

    // Leading and frame.
    final lead = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = palette.ink.withValues(alpha: dark ? .30 : .20);
    canvas.drawPath(arch, lead);
    lead.strokeWidth = 1.2;
    canvas.drawLine(Offset(cx, top + 8), Offset(cx, bottom), lead);
    canvas.drawLine(Offset(left, spring), Offset(right, spring), lead);
    canvas.drawLine(
      Offset(left, (spring + bottom) / 2),
      Offset(right, (spring + bottom) / 2),
      lead,
    );
    // The sill.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left - 10, bottom - 1, right + 10, bottom + 6),
        const Radius.circular(2),
      ),
      Paint()..color = palette.ink.withValues(alpha: dark ? .22 : .12),
    );
  }

  /// A short shelf of books on the left.
  void _shelf(Canvas canvas, Size size) {
    final baseY = size.height * .80 + 5;
    var x = math.max(16.0, focus.dx - size.width * .46) + tilt.dx * 3;
    final spines = [
      (14.0, 54.0, const Color(0xFF7A2E2A)),
      (10.0, 46.0, const Color(0xFF2F4A5C)),
      (16.0, 60.0, const Color(0xFF5C4A2F)),
      (9.0, 42.0, const Color(0xFF3F5A3A)),
      (12.0, 50.0, const Color(0xFF6B3A55)),
    ];
    final scale = (size.height / 340).clamp(.65, 1.0);
    for (final (i, (bw, bh, color)) in spines.indexed) {
      final w = bw * scale, h = bh * scale;
      final book = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - h, w, h),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(
        book,
        Paint()
          ..color = Color.lerp(
            color,
            palette.ground,
            dark ? .25 : .1,
          )!.withValues(alpha: .35 + .65 * light),
      );
      canvas.drawLine(
        Offset(x + 1.5, baseY - h * .78),
        Offset(x + w - 1.5, baseY - h * .78),
        Paint()
          ..color = const Color(0xFFD4A84B).withValues(alpha: .5 * light)
          ..strokeWidth = 1,
      );
      x += w + (i == 2 ? 2 : .8);
    }
    // A last book, leaning.
    canvas.save();
    canvas.translate(x + 2, baseY);
    canvas.rotate(.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, -48 * scale, 12 * scale, 48 * scale),
        const Radius.circular(1.5),
      ),
      Paint()
        ..color = Color.lerp(
          const Color(0xFF8A5A2B),
          palette.ground,
          .2,
        )!.withValues(alpha: .35 + .65 * light),
    );
    canvas.restore();
  }

  /// A candle on the right whose flame leans away from the reader's touch.
  void _candle(Canvas canvas, Size size) {
    final baseY = size.height * .80 + 5;
    final x = math.min(size.width - 28, focus.dx + size.width * .40);
    final scale = (size.height / 340).clamp(.65, 1.0);
    final h = 44 * scale, w = 12 * scale;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - w / 2, baseY - h, w, h),
        const Radius.circular(2),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF3E6CC), Color(0xFFD9C8A6)],
        ).createShader(Rect.fromLTWH(x - w / 2, baseY - h, w, h)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, baseY + 1), width: w * 2.6, height: 6),
      Paint()..color = palette.ink.withValues(alpha: .18),
    );
    if (light <= 0) return;
    final tip = Offset(x - tilt.dx * 6, baseY - h - 22 * scale * light);
    final flameBase = Offset(x, baseY - h - 2);
    canvas.drawCircle(
      tip.translate(0, 8),
      34 * scale * light,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _flame.withValues(alpha: .45 * light),
                _flame.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: tip.translate(0, 8), radius: 34 * scale),
            ),
    );
    final flame = Path()
      ..moveTo(flameBase.dx - 5 * scale, flameBase.dy)
      ..quadraticBezierTo(
        flameBase.dx - 6 * scale,
        tip.dy + 10 * scale,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        flameBase.dx + 6 * scale,
        tip.dy + 10 * scale,
        flameBase.dx + 5 * scale,
        flameBase.dy,
      )
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [const Color(0xFFFFF4D6), _flame, const Color(0xFFE2572B)],
          stops: const [0, .55, 1],
        ).createShader(flame.getBounds()),
    );
  }

  @override
  bool shouldRepaint(_StudyPainter old) =>
      old.light != light ||
      old.tilt != tilt ||
      old.focus != focus ||
      old.dark != dark ||
      old.simpler != simpler ||
      old.palette.accent != palette.accent ||
      old.palette.ground != palette.ground ||
      old.palette.ink != palette.ink;
}
