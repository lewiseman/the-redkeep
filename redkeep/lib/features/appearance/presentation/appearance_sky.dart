import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../assets/presentation/local_artwork.dart';
import '../domain/appearance_preferences.dart';

/// Where a theme sits between day (0) and night (1). Following the device is
/// dusk: the moment that belongs to neither.
double skyPhaseFor(AppTheme theme) => switch (theme) {
  AppTheme.light => 0,
  AppTheme.system => .5,
  AppTheme.dark => 1,
};

abstract final class SkyColors {
  static const _dayTop = Color(0xFF8FC7E8), _dayBottom = Color(0xFFFCE8C8);
  static const _duskTop = Color(0xFF45458A), _duskBottom = Color(0xFFF0A27A);
  static const _nightTop = Color(0xFF0B1030), _nightBottom = Color(0xFF2A2A5E);

  static Color _between(double phase, Color day, Color dusk, Color night) =>
      phase < .5
      ? Color.lerp(day, dusk, phase * 2)!
      : Color.lerp(dusk, night, (phase - .5) * 2)!;

  static Color top(double phase) =>
      _between(phase, _dayTop, _duskTop, _nightTop);
  static Color bottom(double phase) =>
      _between(phase, _dayBottom, _duskBottom, _nightBottom);

  /// Readable title and back button color over the top of the sky.
  static Color foreground(double phase) => Color.lerp(
    const Color(0xFF14203A),
    Colors.white,
    ((phase - .2) / .15).clamp(0.0, 1.0),
  )!;
}

/// A living preview of the current appearance: the theme turns a wheel of sun
/// and moon above the keep, and the accent color is the banner it flies.
class AppearanceSky extends StatefulWidget {
  const AppearanceSky({
    super.key,
    required this.phase,
    required this.accent,
    required this.height,
    required this.collapse,
    required this.solid,
  });

  final double phase;
  final AppAccent accent;

  /// Full height of the open scene, including the status bar and toolbar.
  final double height;

  /// How far the page has collapsed the scene, from 0 to 1.
  final double collapse;

  /// How far the surface color has covered the scene, from 0 to 1.
  final double solid;

  @override
  State<AppearanceSky> createState() => _AppearanceSkyState();
}

class _AppearanceSkyState extends State<AppearanceSky>
    with SingleTickerProviderStateMixin {
  // Runs only after an accent change, so the page never animates at rest.
  late final _flutter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = RenderingPolicyScope.of(context).animate;
    if (!_animate) _flutter.value = 0;
  }

  @override
  void didUpdateWidget(AppearanceSky oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_animate && widget.accent != oldWidget.accent) {
      _flutter.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flutter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final phase = widget.phase;
    final height = widget.height;
    final topInset = MediaQuery.paddingOf(context).top;
    final scale = ((height - topInset - kToolbarHeight) / 200).clamp(.6, 1.0);
    final art = 104 * scale;
    final zenith = topInset + kToolbarHeight + art / 2 + 2;
    final radius = height * .9;

    return ExcludeSemantics(
      child: IgnorePointer(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Anchored to the bottom, so the scene travels with the page.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: SkyColors.top(phase),
                    gradient: simple
                        ? null
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              SkyColors.top(phase),
                              SkyColors.bottom(phase),
                            ],
                          ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Sun and keep stand side by side, so neither hides the other.
                      final center = constraints.maxWidth * .28;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (!simple)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _NightSkyPainter(
                                  phase: phase,
                                  zenith: Offset(center, zenith),
                                  glowRadius: art * 1.3,
                                ),
                              ),
                            ),
                          for (final (index, theme) in const [
                            AppTheme.light,
                            AppTheme.system,
                            AppTheme.dark,
                          ].indexed)
                            _celestial(
                              theme: theme,
                              // Light, device and dark sit one step apart.
                              step: index - phase * 2,
                              center: center,
                              zenith: zenith,
                              radius: radius,
                              art: art,
                            ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _KeepPainter(
                                phase: phase,
                                scale: scale,
                                banner: colors.primary,
                                ground: colors.surface,
                                dark: colors.brightness == Brightness.dark,
                                flutter: _flutter,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (widget.solid > 0)
                ColoredBox(
                  color: colors.surface.withValues(alpha: widget.solid),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _celestial({
    required AppTheme theme,
    required double step,
    required double center,
    required double zenith,
    required double radius,
    required double art,
  }) {
    final angle = step * 68 * math.pi / 180;
    return Positioned(
      left: center + radius * math.sin(angle) - art / 2,
      top: zenith + radius * (1 - math.cos(angle)) - art / 2,
      width: art,
      height: art,
      child: Opacity(
        key: ValueKey('appearance-sky-${theme.name}'),
        // Gone before it can drift through the title as the scene collapses.
        opacity:
            (1 - step.abs() * 1.1).clamp(0.0, 1.0) *
            (1 - widget.collapse / .35).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: angle * .5,
          child: LocalArtwork(
            assetKey: 'appearance.theme.${theme.name}',
            dimension: art,
            highResolution: true,
          ),
        ),
      ),
    );
  }
}

final _stars = () {
  final random = math.Random(7);
  return [
    for (var i = 0; i < 34; i++)
      (
        Offset(random.nextDouble(), random.nextDouble()),
        .6 + random.nextDouble() * .9,
        .35 + random.nextDouble() * .65,
      ),
  ];
}();

class _NightSkyPainter extends CustomPainter {
  const _NightSkyPainter({
    required this.phase,
    required this.zenith,
    required this.glowRadius,
  });

  final double phase, glowRadius;
  final Offset zenith;

  @override
  void paint(Canvas canvas, Size size) {
    final night = ((phase - .35) / .65).clamp(0.0, 1.0);
    final star = Paint();
    for (final (position, radius, brightness) in _stars) {
      star.color = Colors.white.withValues(alpha: night * brightness);
      canvas.drawCircle(
        Offset(position.dx * size.width, position.dy * size.height * .68),
        radius,
        star,
      );
    }
    final glow = Color.lerp(
      const Color(0xFFFFEDB8),
      const Color(0xFFC9C6FF),
      phase,
    )!;
    canvas.drawCircle(
      zenith,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: .55 - phase * .25),
            glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: zenith, radius: glowRadius)),
    );
  }

  @override
  bool shouldRepaint(_NightSkyPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      zenith != oldDelegate.zenith ||
      glowRadius != oldDelegate.glowRadius;
}

class _KeepPainter extends CustomPainter {
  _KeepPainter({
    required this.phase,
    required this.scale,
    required this.banner,
    required this.ground,
    required this.dark,
    required this.flutter,
  }) : super(repaint: flutter);

  final double phase, scale;
  final Color banner, ground;
  final bool dark;
  final Animation<double> flutter;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width * .66;
    final base = size.height - 20 * scale;

    // Coordinates are measured up and out from the keep's base center.
    Rect block(double left, double right, double top, [double bottom = 0]) =>
        Rect.fromLTRB(
          center + left * scale,
          base - top * scale,
          center + right * scale,
          base - bottom * scale,
        );

    final walls = Path();
    void tower(double left, double right, double top) {
      walls.addRect(block(left, right, top));
      for (var x = left; x < right - 1; x += 9) {
        walls.addRect(block(x, math.min(x + 5, right), top + 5, top));
      }
    }

    tower(-104, 104, 24);
    tower(-68, -40, 46);
    tower(40, 68, 40);
    tower(-36, 36, 60);
    tower(-11, 11, 84);
    canvas.drawPath(
      walls,
      Paint()..color = Color.lerp(banner, Colors.black, dark ? .42 : .12)!,
    );

    final window = Paint()
      ..color = const Color(0xFFFFD98A).withValues(alpha: phase);
    for (final (x, y) in const [
      (-56.0, 32.0),
      (52.0, 28.0),
      (-22.0, 40.0),
      (0.0, 64.0),
      (22.0, 40.0),
      (-84.0, 12.0),
      (84.0, 12.0),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          block(x - 2, x + 2, y + 7, y),
          const Radius.circular(2),
        ),
        window,
      );
    }

    // The banner settles after each change of accent.
    final poleTop = Offset(center, base - 112 * scale);
    canvas.drawLine(
      Offset(center, base - 88 * scale),
      poleTop,
      Paint()
        ..color = Color.lerp(banner, Colors.black, dark ? .42 : .12)!
        ..strokeWidth = 1.6 * scale,
    );
    final length = 34 * scale, depth = 17 * scale;
    final swing = math.sin(flutter.value * math.pi);
    final amplitude = (1 + swing * 3) * scale;
    double wave(double x) =>
        math.sin(x / length * math.pi * 2 - flutter.value * math.pi * 8) *
        amplitude *
        (x / length);
    final pennant = Path()..moveTo(poleTop.dx, poleTop.dy);
    for (var x = 2.0; x <= length; x += 2) {
      pennant.lineTo(poleTop.dx + x, poleTop.dy + wave(x));
    }
    pennant.lineTo(
      poleTop.dx + length * .74,
      poleTop.dy + depth / 2 + wave(length * .74),
    );
    pennant.lineTo(poleTop.dx + length, poleTop.dy + depth + wave(length));
    for (var x = length - 2; x >= 0; x -= 2) {
      pennant.lineTo(poleTop.dx + x, poleTop.dy + depth + wave(x));
    }
    pennant.close();
    canvas.drawPath(pennant, Paint()..color = banner);

    // The hill is the page's own color, so the page grows out of the scene.
    final hillHeight = 30 * scale;
    final hill = Path()
      ..moveTo(0, size.height - hillHeight * .62)
      ..cubicTo(
        size.width * .3,
        size.height - hillHeight * 1.1,
        size.width * .62,
        size.height - hillHeight * .3,
        size.width,
        size.height - hillHeight * .92,
      )
      ..lineTo(size.width, size.height + 1)
      ..lineTo(0, size.height + 1)
      ..close();
    canvas.drawPath(hill, Paint()..color = ground);
  }

  @override
  bool shouldRepaint(_KeepPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      scale != oldDelegate.scale ||
      banner != oldDelegate.banner ||
      ground != oldDelegate.ground ||
      dark != oldDelegate.dark;
}
