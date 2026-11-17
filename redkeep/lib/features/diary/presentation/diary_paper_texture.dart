import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Logical size of one seamless tile, and the pixels painted per point.
const _extent = 300.0;
const _density = 2.0;

final _textures = <bool, ui.ImageShader?>{};

/// A seamless, repeating paper texture: cloudy formation where the pulp
/// settled thicker or thinner, fine grain, loose fibres and the odd fleck.
///
/// It holds only lightening and darkening, never a colour of its own, so it
/// lies over any stock. Each brightness is drawn once, on first use, and kept
/// as a single image; painting a sheet is then one tiled shader fill.
/// Returns null where images cannot be rasterised.
ui.ImageShader? diaryPaperTexture({required bool dark}) {
  if (_textures.containsKey(dark)) return _textures[dark];
  ui.ImageShader? shader;
  try {
    shader = ui.ImageShader(
      _paintTile(dark),
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.diagonal3Values(1 / _density, 1 / _density, 1).storage,
      filterQuality: FilterQuality.medium,
    );
  } catch (_) {
    shader = null;
  }
  return _textures[dark] = shader;
}

ui.Image _paintTile(bool dark) {
  const side = _extent * _density;
  const tile = Rect.fromLTWH(0, 0, side, side);
  final random = math.Random(dark ? 0x6e696768 : 0x64617921);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, tile);
  const light = Color(0xffffffff);
  final shade = dark ? const Color(0xff000000) : const Color(0xff5e4a2e);
  double next() => random.nextDouble();

  // Anything crossing an edge is drawn again on the opposite side.
  void wrapped(Rect bounds, void Function(Offset shift) draw) {
    for (final dx in const [-side, 0.0, side]) {
      for (final dy in const [-side, 0.0, side]) {
        final shift = Offset(dx, dy);
        if (bounds.shift(shift).overlaps(tile)) draw(shift);
      }
    }
  }

  // Formation: broad, soft clouds.
  for (var i = 0; i < 90; i++) {
    final center = Offset(next() * side, next() * side);
    final radius = 24 + next() * 110;
    final up = next() < .5;
    final strength = .35 + next() * .65;
    final color = (up ? light : shade).withValues(
      alpha: strength * (dark ? (up ? .03 : .07) : (up ? .16 : .045)),
    );
    wrapped(Rect.fromCircle(center: center, radius: radius), (shift) {
      final at = center + shift;
      canvas.drawCircle(
        at,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: at, radius: radius)),
      );
    });
  }

  // Grain: single specks of light and shade.
  final raised = <Offset>[], sunk = <Offset>[];
  for (var i = 0; i < 26000; i++) {
    (next() < .5 ? raised : sunk).add(Offset(next() * side, next() * side));
  }
  canvas.drawPoints(
    ui.PointMode.points,
    raised,
    Paint()
      ..color = light.withValues(alpha: dark ? .035 : .2)
      ..strokeWidth = 1.3,
  );
  canvas.drawPoints(
    ui.PointMode.points,
    sunk,
    Paint()
      ..color = shade.withValues(alpha: dark ? .09 : .05)
      ..strokeWidth = 1.3,
  );

  // Fibres: short, slightly bent hairs in every direction.
  for (var i = 0; i < 300; i++) {
    final start = Offset(next() * side, next() * side);
    final angle = next() * math.pi * 2;
    final length = 8 + next() * next() * 46;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final end = start + direction * length;
    final control =
        start +
        direction * (length / 2) +
        normal * ((next() * 2 - 1) * length * .3);
    final up = next() < (dark ? .55 : .4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = .7 + next() * 1.2
      ..color = (up ? light : shade).withValues(
        alpha:
            (.45 + next() * .55) * (dark ? (up ? .05 : .08) : (up ? .5 : .08)),
      );
    wrapped(Rect.fromPoints(start, end).inflate(length * .3), (shift) {
      canvas.drawPath(
        Path()
          ..moveTo(start.dx + shift.dx, start.dy + shift.dy)
          ..quadraticBezierTo(
            control.dx + shift.dx,
            control.dy + shift.dy,
            end.dx + shift.dx,
            end.dy + shift.dy,
          ),
        paint,
      );
    });
  }

  // Inclusions: a few flecks pressed into the sheet.
  for (var i = 0; i < 14; i++) {
    canvas.drawCircle(
      Offset(next() * side, next() * side),
      .8 + next() * 1.4,
      Paint()..color = shade.withValues(alpha: dark ? .3 : .2),
    );
  }

  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(side.toInt(), side.toInt());
  } finally {
    picture.dispose();
  }
}
