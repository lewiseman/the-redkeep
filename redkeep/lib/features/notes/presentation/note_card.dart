import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../domain/note_collection_entry.dart';
import '../domain/note_document.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.entry,
    required this.index,
    required this.onTap,
  });
  final NoteCollectionEntry entry;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final shape = _FoldedPaperBorder(
      side: BorderSide(color: colors.onSurface.withValues(alpha: .09)),
    );
    final paper = colors.surfaceContainerLow;
    return Material(
      color: paper,
      elevation: simple ? 0 : 1,
      shadowColor: colors.shadow.withValues(alpha: .18),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: CustomPaint(
          painter: _PaperDetailsPainter(
            inkColor: colors.onSurface,
            paperColor: paper,
            shape: shape,
            simple: simple,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    noteTitle(entry.title),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      height: 1.25,
                      letterSpacing: -.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (entry.isDraft || entry.pinned) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (entry.isDraft)
                        Text(
                          'Draft',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      if (entry.pinned)
                        Icon(
                          Icons.push_pin_outlined,
                          size: 16,
                          semanticLabel: 'Pinned',
                        ),
                    ],
                  ),
                ],
                if (entry.sourceUnavailable) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Original unavailable',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
                if (entry.excerpt.trim().isNotEmpty) ...[
                  const SizedBox(height: 9),
                  // A bounded, noninteractive excerpt never resolves links or images.
                  Text(
                    entry.excerpt,
                    maxLines: switch (index % 3) {
                      0 => 7,
                      1 => 9,
                      _ => 6,
                    },
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
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

// The paper, border, shadow, and ink share one outline.
class _FoldedPaperBorder extends OutlinedBorder {
  const _FoldedPaperBorder({super.side, this.fold = 26, this.radius = 14});

  final double fold;
  final double radius;

  double foldFor(Size size) => math.min(fold, size.shortestSide / 2);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = math.min(radius, rect.shortestSide / 2);
    final f = foldFor(rect.size);
    return Path()
      ..moveTo(rect.left + r, rect.top)
      ..lineTo(rect.right - f, rect.top)
      ..lineTo(rect.right, rect.top + f)
      ..lineTo(rect.right, rect.bottom - r)
      ..quadraticBezierTo(rect.right, rect.bottom, rect.right - r, rect.bottom)
      ..lineTo(rect.left + r, rect.bottom)
      ..quadraticBezierTo(rect.left, rect.bottom, rect.left, rect.bottom - r)
      ..lineTo(rect.left, rect.top + r)
      ..quadraticBezierTo(rect.left, rect.top, rect.left + r, rect.top)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final inset = side.strokeInset;
    return copyWith(
      fold: math.max(0, fold - inset * (2 - math.sqrt2)),
      radius: math.max(0, radius - inset),
    ).getOuterPath(rect.deflate(inset), textDirection: textDirection);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty || side.style == BorderStyle.none) return;
    // Fill the border inward, keeping its edge inside the clipped paper.
    final border = getOuterPath(rect, textDirection: textDirection)
      ..fillType = PathFillType.evenOdd
      ..addPath(getInnerPath(rect, textDirection: textDirection), Offset.zero);
    canvas.drawPath(border, Paint()..color = side.color);
  }

  @override
  _FoldedPaperBorder copyWith({
    BorderSide? side,
    double? fold,
    double? radius,
  }) => _FoldedPaperBorder(
    side: side ?? this.side,
    fold: fold ?? this.fold,
    radius: radius ?? this.radius,
  );

  @override
  ShapeBorder scale(double t) => _FoldedPaperBorder(
    side: side.scale(t),
    fold: fold * t,
    radius: radius * t,
  );

  @override
  bool operator ==(Object other) =>
      other is _FoldedPaperBorder &&
      other.side == side &&
      other.fold == fold &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(side, fold, radius);
}

class _PaperDetailsPainter extends CustomPainter {
  const _PaperDetailsPainter({
    required this.inkColor,
    required this.paperColor,
    required this.shape,
    required this.simple,
  });

  final bool simple;
  final Color inkColor;
  final Color paperColor;
  final _FoldedPaperBorder shape;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final f = shape.foldFor(size);
    final corner = math.min(5.0, f / 4);
    final fold = Path()
      ..moveTo(size.width - f, 0)
      ..lineTo(size.width - f, f - corner)
      ..quadraticBezierTo(size.width - f, f, size.width - f + corner, f)
      ..lineTo(size.width, f)
      ..close();
    if (!simple) {
      canvas.drawShadow(fold, inkColor.withValues(alpha: .22), 3, false);
    }
    canvas.drawPath(
      fold,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.lerp(paperColor, inkColor, .04)!,
            Color.lerp(paperColor, Colors.white, .16)!,
            Color.lerp(paperColor, inkColor, .13)!,
          ],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromLTWH(size.width - f, 0, f, f)),
    );
  }

  @override
  bool shouldRepaint(_PaperDetailsPainter oldDelegate) =>
      simple != oldDelegate.simple ||
      inkColor != oldDelegate.inkColor ||
      paperColor != oldDelegate.paperColor ||
      shape != oldDelegate.shape;
}
