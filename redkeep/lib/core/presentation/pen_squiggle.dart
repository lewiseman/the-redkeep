import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The pen underline, drawn out to [drawn] of its length.
class PenSquiggle extends CustomPainter {
  const PenSquiggle(this.colour, this.drawn);
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
  bool shouldRepaint(PenSquiggle old) =>
      old.colour != colour || old.drawn != drawn;
}
