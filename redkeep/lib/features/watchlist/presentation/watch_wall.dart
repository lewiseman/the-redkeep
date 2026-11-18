import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../domain/watch_title.dart';
import 'watch_widgets.dart';

/// A number of a title's own, steady across launches, for its tilt and tape.
int wallSeed(String id) {
  if (isWatchId(id)) return int.parse(id.substring(0, 7), radix: 16);
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

/// The handwriting on the wall: the reader's own diary title face.
TextStyle wallHand(BuildContext context, {double size = 20, Color? color}) =>
    DiaryTypography.of(context).title.copyWith(
      fontSize: size,
      height: 1.05,
      color: color ?? MorePalette.of(context).ink,
    );

/// How each status marks a polaroid.
enum WallMark {
  none,
  pin,
  watched,
  paused,
  dropped;

  static WallMark of(WatchStatus? status) => switch (status) {
    WatchStatus.watching => pin,
    WatchStatus.completed => watched,
    WatchStatus.paused => paused,
    WatchStatus.dropped => dropped,
    WatchStatus.planned || null => none,
  };

  String? get stamp => switch (this) {
    watched => 'WATCHED',
    paused => 'PAUSED',
    dropped => 'DROPPED',
    _ => null,
  };

  Color get ink => switch (this) {
    paused => const Color(0xff4f6a8f),
    dropped => const Color(0xff5d5a55),
    _ => const Color(0xffbf3a2c),
  };
}

/// A title pinned to the wall as a polaroid: taped up (or pushed through
/// with a glass pin while it is on the go), its name in handwriting, and an
/// ink stamp once it has a verdict.
class WallPolaroid extends StatefulWidget {
  const WallPolaroid({
    super.key,
    required this.title,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.doubleTapLabel,
  });

  final WatchTitle title;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  /// What a double tap does, offered to screen readers as an action.
  final String? doubleTapLabel;

  @override
  State<WallPolaroid> createState() => _WallPolaroidState();
}

class _WallPolaroidState extends State<WallPolaroid>
    with SingleTickerProviderStateMixin {
  /// 1 when a stamp is resting; runs from 0 when a new one comes down.
  late final _slam = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(WallPolaroid old) {
    super.didUpdateWidget(old);
    final was = WallMark.of(old.title.status);
    final now = WallMark.of(widget.title.status);
    if (was != now && RenderingPolicyScope.of(context).animate) {
      _slam.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final cushion = CushionColors.of(context);
    final title = widget.title;
    final mark = WallMark.of(title.status);
    final seed = wallSeed(title.id);
    final tilt = ((seed % 97) / 96 - .5) * .075;
    final drop = (seed >> 8) % 16;
    final kind = title.media == WatchMedia.tv ? 'Series' : 'Film';
    final frame = Color.lerp(
      palette.paper,
      Colors.white,
      cushion.dark ? 0 : .5,
    )!;
    final doubleTap = widget.onDoubleTap;

    final poster = AspectRatio(
      aspectRatio: 2 / 3,
      child: mark == WallMark.dropped
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                .3, .55, .1, 0, 20, //
                .3, .55, .1, 0, 20,
                .3, .55, .1, 0, 20,
                0, 0, 0, .7, 0,
              ]),
              child: WatchPoster(
                path: title.posterPath,
                media: title.media,
                radius: 2,
              ),
            )
          : WatchPoster(path: title.posterPath, media: title.media, radius: 2),
    );

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: frame,
        borderRadius: BorderRadius.circular(3),
        boxShadow: cushion.simple
            ? null
            : [
                BoxShadow(
                  color: cushion.shadow.withValues(
                    alpha: cushion.dark ? .45 : .16,
                  ),
                  blurRadius: 10,
                  offset: const Offset(2, 6),
                ),
                BoxShadow(
                  color: cushion.shadow.withValues(
                    alpha: cushion.dark ? .5 : .12,
                  ),
                  blurRadius: 1.5,
                  offset: const Offset(0, 1),
                ),
              ],
        border: cushion.simple ? Border.all(color: palette.rule) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                poster,
                if (mark.stamp case final stamp?)
                  Positioned(
                    right: -6,
                    bottom: 14,
                    child: _SlammedStamp(
                      slam: _slam,
                      label: stamp,
                      ink: mark.ink,
                      tilt: -.32 + ((seed >> 4) % 10) / 60,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: wallHand(context, size: 21).copyWith(
                decoration: mark == WallMark.dropped
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: mark.ink,
                decorationThickness: 2,
                color: mark == WallMark.dropped ? palette.muted : palette.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              [
                ?title.year?.toString(),
                kind,
                if (mark == WallMark.pin) 'watching',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mark == WallMark.pin ? palette.accent : palette.muted,
                fontSize: 11.5,
                fontWeight: mark == WallMark.pin
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: [
        title.title,
        ?title.year?.toString(),
        kind,
        ?title.status?.label,
      ].join(', '),
      excludeSemantics: true,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      customSemanticsActions: {
        if (doubleTap != null && widget.doubleTapLabel != null)
          CustomSemanticsAction(label: widget.doubleTapLabel!): doubleTap,
      },
      child: Padding(
        padding: EdgeInsets.only(top: 12.0 + drop),
        child: Transform.rotate(
          angle: tilt,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onDoubleTap: doubleTap,
            onLongPress: widget.onLongPress == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    widget.onLongPress!();
                  },
            child: Springy(
              depth: .035,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  card,
                  Positioned(
                    top: -11,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: mark == WallMark.pin
                          ? _GlassPin(colors: cushion)
                          : _Tape(seed: seed, colors: cushion),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An ink stamp that comes down hard: large and faint, then flat and dark,
/// with a small bounce as it lands.
class _SlammedStamp extends StatelessWidget {
  const _SlammedStamp({
    required this.slam,
    required this.label,
    required this.ink,
    required this.tilt,
  });

  final Animation<double> slam;
  final String label;
  final Color ink;
  final double tilt;

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 2.6, end: .9).chain(CurveTween(curve: Curves.easeIn)),
      weight: 62,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: .9,
        end: 1.04,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 20,
    ),
    TweenSequenceItem(tween: Tween(begin: 1.04, end: 1), weight: 18),
  ]);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: slam,
    builder: (context, child) {
      final t = slam.value;
      return Opacity(
        opacity: Curves.easeOut.transform((t / .5).clamp(0.0, 1.0)),
        child: Transform.scale(
          scale: _scale.transform(t),
          child: Transform.rotate(angle: tilt, child: child),
        ),
      );
    },
    child: InkStamp(label: label, ink: ink),
  );
}

/// A rubber-stamp impression: a double ring of ink round spaced capitals,
/// a little uneven where the stamp met the paper.
class InkStamp extends StatelessWidget {
  const InkStamp({super.key, required this.label, required this.ink});

  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final stamp = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xfffffbf0).withValues(alpha: .72),
        border: Border.all(color: ink, width: 3),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: ink, width: 1.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 7, 3),
            child: Text(
              label,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: ink,
                fontSize: 15,
                height: 1.1,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
    if (simple) return stamp;
    // Speckle where the ink did not take.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => RadialGradient(
        center: const Alignment(.6, -.4),
        radius: 1.4,
        colors: const [Colors.white, Colors.white, Color(0xccffffff)],
        stops: const [0, .55, 1],
      ).createShader(bounds),
      child: CustomPaint(
        foregroundPainter: _Speckle(label.hashCode),
        child: stamp,
      ),
    );
  }
}

class _Speckle extends CustomPainter {
  const _Speckle(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()..blendMode = BlendMode.dstOut;
    for (var i = 0; i < 14; i++) {
      paint.color = Colors.black.withValues(
        alpha: .25 + random.nextDouble() * .4,
      );
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        .5 + random.nextDouble() * 1.3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Speckle old) => old.seed != seed;
}

/// A strip of washi tape in a colour of the title's own, a little askew.
class _Tape extends StatelessWidget {
  const _Tape({required this.seed, required this.colors});
  final int seed;
  final CushionColors colors;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform.rotate(
      angle: ((seed >> 3) % 21 - 10) / 120,
      child: CustomPaint(
        size: const Size(58, 20),
        painter: _TapePainter(
          HSLColor.fromAHSL(
            .82,
            (seed % 360).toDouble(),
            colors.dark ? .3 : .42,
            colors.dark ? .52 : .74,
          ).toColor(),
          simple: colors.simple,
        ),
      ),
    ),
  );
}

class _TapePainter extends CustomPainter {
  const _TapePainter(this.colour, {required this.simple});
  final Color colour;
  final bool simple;

  @override
  void paint(Canvas canvas, Size size) {
    // Torn, zig-zag ends.
    final path = Path()..moveTo(0, 0);
    path.lineTo(size.width, 0);
    for (var y = 0.0; y < size.height; y += 4) {
      path.lineTo(size.width - ((y ~/ 4).isOdd ? 2.5 : 0), y + 2);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    for (var y = size.height; y > 0; y -= 4) {
      path.lineTo((y ~/ 4).isOdd ? 2.5 : 0, y - 2);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = colour);
    if (simple) return;
    final weave = Paint()
      ..color = Colors.white.withValues(alpha: .25)
      ..strokeWidth = 1;
    for (var x = 5.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x - 3, size.height), weave);
    }
  }

  @override
  bool shouldRepaint(_TapePainter old) =>
      old.colour != colour || old.simple != simple;
}

/// A red glass-headed push-pin: this one is on the go.
class _GlassPin extends StatelessWidget {
  const _GlassPin({required this.colors});
  final CushionColors colors;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: const Size(26, 30), painter: _PinPainter(colors)),
  );
}

class _PinPainter extends CustomPainter {
  const _PinPainter(this.colors);
  final CushionColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final head = Offset(size.width / 2, 11);
    canvas.drawLine(
      head.translate(1, 5),
      head.translate(4, 17),
      Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: .4),
    );
    paintGlass(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromCircle(center: head, radius: 10),
        const Radius.circular(10),
      ),
      colors: colors,
      tint: const Color(0xffc9473c),
      fill: .9,
      lift: 1,
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.colors != colors;
}

/// Polaroids drop onto the wall one after another when a filter changes;
/// still with reduced motion.
class WallEntrance extends StatelessWidget {
  const WallEntrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!RenderingPolicyScope.of(context).animate) return child;
    final delay = index.clamp(0, 8) * 45;
    final total = 340 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutBack),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -18 * (1 - t)),
          child: Transform.scale(scale: 1.06 - .06 * t, child: child),
        ),
      ),
    );
  }
}

/// Columns of polaroids: fewer when space is narrow or text is large.
int wallColumns(BuildContext context, double width) {
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
  return (width / (150 * scale)).floor().clamp(2, 5);
}
