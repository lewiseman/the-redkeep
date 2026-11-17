import 'dart:math' as math;

import '../domain/diary_raven.dart';
import 'diary_style.dart';

/// A maester's raven perched on the date cord. When an earlier written day
/// echoes the page (see [diaryRavenLetter]) it holds that day's letter, rolled
/// and sealed in red wax, and arrives with a small hop.
class DiaryRaven extends StatelessWidget {
  const DiaryRaven({
    super.key,
    required this.size,
    this.letter = false,
    this.animate = true,
  });

  /// The raven's square box; its feet rest at the bottom edge.
  final double size;

  /// Whether it carries a letter.
  final bool letter;
  final bool animate;

  /// Where the feet grip the cord, as a fraction of [size] from the left.
  static const footX = .56;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = context.isDark;
    // Each new letter arrives with a hop; rebuilding with the same one does
    // nothing, so the cord's motion never replays it.
    return TweenAnimationBuilder<double>(
      key: ValueKey(letter),
      tween: Tween(begin: letter && animate ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 460),
      builder: (context, t, _) {
        final hop = math.sin(math.pi * Curves.easeOut.transform(t));
        return Transform.translate(
          offset: Offset(0, -size * .16 * hop),
          child: CustomPaint(
            size: Size.square(size),
            painter: _RavenPainter(
              ink: dark
                  ? const Color(0xFF0D0B10)
                  : Color.lerp(colors.onSurface, Colors.black, .55)!,
              sheen: Color.lerp(colors.primary, Colors.white, dark ? .25 : .1)!,
              rim: dark ? colors.primary.withValues(alpha: .55) : null,
              letter: letter ? Curves.easeOut.transform(t) : 0,
            ),
          ),
        );
      },
    );
  }
}

class _RavenPainter extends CustomPainter {
  const _RavenPainter({
    required this.ink,
    required this.sheen,
    required this.rim,
    required this.letter,
  });

  final Color ink, sheen;
  final Color? rim;

  /// How far the letter has been taken up, 0 to 1.
  final double letter;

  /// The perched raven, facing left, in a 100 × 100 box with its feet on
  /// the bottom edge.
  static final _body = Path()
    ..moveTo(0, 31)
    ..cubicTo(6, 27, 13, 22, 20, 20)
    ..cubicTo(25, 12, 36, 9, 43, 14)
    ..cubicTo(50, 19, 52, 27, 60, 32)
    ..cubicTo(70, 38, 80, 47, 86, 57)
    ..cubicTo(91, 66, 96, 78, 100, 91)
    ..lineTo(93, 93)
    ..cubicTo(88, 85, 83, 79, 77, 75)
    ..cubicTo(73, 81, 67, 86, 61, 88)
    ..cubicTo(51, 90, 41, 84, 35, 76)
    ..cubicTo(29, 68, 26, 57, 27, 48)
    // The shaggy throat hackles of a raven.
    ..lineTo(24, 46)
    ..lineTo(26, 43)
    ..lineTo(22, 40)
    ..cubicTo(15, 38, 7, 35, 0, 31)
    ..close();

  static final _legs = Path()
    ..moveTo(52, 86)
    ..lineTo(50, 100)
    ..moveTo(59, 86)
    ..lineTo(58, 100)
    ..moveTo(43, 100)
    ..lineTo(54, 100)
    ..moveTo(52, 100)
    ..lineTo(64, 100);

  static final _wing = Path()
    ..moveTo(41, 33)
    ..cubicTo(55, 41, 66, 58, 82, 71);

  static final _beakLine = Path()
    ..moveTo(3, 31.5)
    ..lineTo(17, 31);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas
      ..save()
      ..scale(scale);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (rim case final rim?) {
      canvas.drawPath(
        _body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round
          ..color = rim,
      );
    }
    canvas
      ..drawPath(
        _legs,
        stroke
          ..strokeWidth = 3.2
          ..color = ink,
      )
      ..drawPath(_body, Paint()..color = ink)
      // The blue-violet sheen of raven feathers, along the folded wing.
      ..drawPath(
        _wing,
        stroke
          ..strokeWidth = 2.4
          ..color = sheen.withValues(alpha: .55),
      )
      ..drawPath(
        _beakLine,
        stroke
          ..strokeWidth = 1.4
          ..color = sheen.withValues(alpha: .35),
      )
      ..drawCircle(
        const Offset(25, 25),
        2.6,
        Paint()..color = const Color(0xFFF2E6C8),
      );
    if (letter > 0) _paintLetter(canvas);
    canvas.restore();
  }

  /// A rolled letter held in the beak, its red wax seal outward.
  void _paintLetter(Canvas canvas) {
    canvas
      ..save()
      ..translate(0, 41)
      ..rotate(-.18)
      ..scale(1.45 * (.6 + .4 * letter));
    final parchment = const Color(0xFFEAD8B0).withValues(alpha: letter);
    final roll = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-15, -5, 30, 10),
      const Radius.circular(5),
    );
    canvas
      ..drawRRect(
        roll.shift(const Offset(0, 1.6)),
        Paint()..color = Colors.black.withValues(alpha: .18 * letter),
      )
      ..drawRRect(roll, Paint()..color = parchment)
      ..drawRRect(
        roll,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF9C7D4E).withValues(alpha: letter),
      )
      ..drawLine(
        const Offset(-10, -5),
        const Offset(-10, 5),
        Paint()
          ..strokeWidth = 1
          ..color = const Color(0xFF9C7D4E).withValues(alpha: .7 * letter),
      );
    diaryPaintWaxSeal(canvas, const Offset(3, 0), 6.2, opacity: letter);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RavenPainter oldDelegate) =>
      ink != oldDelegate.ink ||
      sheen != oldDelegate.sheen ||
      rim != oldDelegate.rim ||
      letter != oldDelegate.letter;
}

/// A blot of red sealing wax pressed with a ring, at [center].
void diaryPaintWaxSeal(
  Canvas canvas,
  Offset center,
  double radius, {
  double opacity = 1,
}) {
  if (opacity <= 0) return;
  // A slightly uneven blot, the same every time.
  final blot = Path();
  const lobes = 11;
  for (var i = 0; i <= lobes; i++) {
    final a = 2 * math.pi * i / lobes;
    final r = radius * (1 + .09 * math.sin(i * 2.7) + .05 * math.cos(i * 4.1));
    final point = center + Offset(math.cos(a), math.sin(a)) * r;
    i == 0 ? blot.moveTo(point.dx, point.dy) : blot.lineTo(point.dx, point.dy);
  }
  blot.close();
  final bounds = Rect.fromCircle(center: center, radius: radius * 1.1);
  canvas
    ..drawPath(
      blot.shift(Offset(0, radius * .18)),
      Paint()..color = const Color(0xFF3A0A08).withValues(alpha: .28 * opacity),
    )
    ..drawPath(
      blot,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.4),
          colors: [
            const Color(0xFFD6463A).withValues(alpha: opacity),
            const Color(0xFF9E1B17).withValues(alpha: opacity),
            const Color(0xFF6E100E).withValues(alpha: opacity),
          ],
          stops: const [0, .55, 1],
        ).createShader(bounds),
    )
    ..drawCircle(
      center,
      radius * .58,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .16
        ..color = const Color(0xFF5E0C0B).withValues(alpha: .55 * opacity),
    )
    ..drawCircle(
      center + Offset(-radius * .3, -radius * .32),
      radius * .16,
      Paint()..color = Colors.white.withValues(alpha: .35 * opacity),
    );
}
