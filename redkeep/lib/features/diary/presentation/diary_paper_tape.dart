import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'diary_paper_texture.dart';

/// Strips of washi tape holding a resting diary page to the desk. Each day
/// tapes its page its own way, in the accent family, and the tape lifts away
/// with the page's [detail] as the reader becomes immersive.
class DiaryPaperTape extends CustomPainter {
  const DiaryPaperTape({
    required this.seed,
    required this.color,
    required this.dark,
    required this.detail,
  });

  factory DiaryPaperTape.forDate(
    DateTime date, {
    required ColorScheme colors,
    required double detail,
  }) {
    final seed =
        DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final family = [colors.primary, colors.tertiary, colors.secondary];
    return DiaryPaperTape(
      seed: seed,
      color: family[seed % family.length],
      dark: colors.brightness == Brightness.dark,
      detail: detail.clamp(0.0, 1.0),
    );
  }

  final int seed;
  final Color color;
  final bool dark;
  final double detail;

  @override
  void paint(Canvas canvas, Size size) {
    if (detail <= 0 || size.shortestSide < 120) return;
    final random = math.Random(seed ^ 0x77617368);
    // Corners across their diagonals: top right alone, or a pair.
    final corners = switch (seed % 3) {
      0 => const [(1.0, 0.0)],
      1 => const [(0.0, 0.0), (1.0, 1.0)],
      _ => const [(1.0, 0.0), (0.0, 1.0)],
    };
    final striped = seed % 2 == 0;
    final alpha = detail * detail;
    for (final (x, y) in corners) {
      final inset = 9 + random.nextDouble() * 4;
      final center = Offset(
        x == 0 ? inset : size.width - inset,
        y == 0 ? inset : size.height - inset,
      );
      final across = (x == y ? -1 : 1) * math.pi / 4;
      _strip(
        canvas,
        center: center,
        angle: across + (random.nextDouble() - .5) * .3,
        length: 56 + random.nextDouble() * 14,
        width: 18 + random.nextDouble() * 4,
        random: random,
        striped: striped,
        alpha: alpha,
      );
    }
  }

  void _strip(
    Canvas canvas, {
    required Offset center,
    required double angle,
    required double length,
    required double width,
    required math.Random random,
    required bool striped,
    required double alpha,
  }) {
    final half = length / 2, hw = width / 2;
    // Torn ends: a fine, uneven zigzag across the width.
    final path = Path()
      ..moveTo(-half, -hw)
      ..lineTo(half, -hw);
    for (var j = 1; j < 7; j++) {
      path.lineTo(
        half + (j.isOdd ? 1 : -1) * (.6 + random.nextDouble() * 1.4),
        -hw + width * j / 7,
      );
    }
    path
      ..lineTo(half, hw)
      ..lineTo(-half, hw);
    for (var j = 6; j > 0; j--) {
      path.lineTo(
        -half + (j.isOdd ? 1 : -1) * (.6 + random.nextDouble() * 1.4),
        -hw + width * j / 7,
      );
    }
    path.close();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawShadow(
      path,
      const Color(0xff000000).withValues(alpha: (dark ? .45 : .22) * alpha),
      1,
      true,
    );
    final tape = dark
        ? color
        : Color.lerp(color, const Color(0xffffffff), .45)!;
    canvas.drawPath(
      path,
      Paint()..color = tape.withValues(alpha: (dark ? .52 : .72) * alpha),
    );
    canvas.save();
    canvas.clipPath(path);
    // Washi is itself a thin paper: let its fibres show through the colour.
    final fibres = diaryPaperTexture(dark: true);
    if (fibres != null) {
      canvas.drawRect(
        Rect.fromLTRB(-half - 3, -hw, half + 3, hw),
        Paint()
          ..shader = fibres
          ..color = const Color(0xff000000).withValues(alpha: alpha),
      );
    }
    final pattern = Paint()
      ..color = const Color(0xffffffff)
          .withValues(alpha: (dark ? .07 : .2) * alpha);
    if (striped) {
      pattern
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      for (var x = -half - width; x < half; x += 6) {
        canvas.drawLine(Offset(x, -hw), Offset(x + width * .7, hw), pattern);
      }
    } else {
      for (var x = -half + 4; x < half; x += 7) {
        for (var row = 0; row < 3; row++) {
          canvas.drawCircle(
            Offset(x + (row.isOdd ? 4 : 0), -hw + width * (row + 1) / 4),
            .9,
            pattern,
          );
        }
      }
    }
    // A sheen across the width, and a crease where it was smoothed down.
    final bounds = Rect.fromLTRB(-half - 3, -hw, half + 3, hw);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xffffffff).withValues(alpha: .2 * alpha),
            const Color(0x00ffffff),
            const Color(0xff000000).withValues(alpha: .08 * alpha),
          ],
        ).createShader(bounds),
    );
    final crease = -half * .3 + random.nextDouble() * half * .6;
    canvas.drawLine(
      Offset(crease, -hw),
      Offset(crease + 3, hw),
      Paint()
        ..color = const Color(0xffffffff).withValues(alpha: .16 * alpha)
        ..strokeWidth = .8,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(DiaryPaperTape oldDelegate) =>
      seed != oldDelegate.seed ||
      color != oldDelegate.color ||
      dark != oldDelegate.dark ||
      detail != oldDelegate.detail;
}
