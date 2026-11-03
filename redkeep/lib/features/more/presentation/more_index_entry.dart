import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';

/// An illustrated entry, with its purpose and live status kept in one place.
class MoreIndexEntry extends StatelessWidget {
  const MoreIndexEntry({
    super.key,
    required this.title,
    this.description,
    required this.artworkBuilder,
    required this.onTap,
    this.status,
    this.ready = false,
    this.showDivider = true,
  });

  final String title;
  final String? description;
  final Widget Function(double dimension) artworkBuilder;
  final VoidCallback onTap;
  final String? status;
  final bool ready;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showArtwork =
            constraints.maxWidth >= 250 &&
            MediaQuery.textScalerOf(context).scale(14) <= 20;
        final artworkSize = constraints.maxWidth < 310 ? 88.0 : 104.0;
        return Semantics(
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: palette.accent.withValues(alpha: .06),
              highlightColor: palette.accent.withValues(alpha: .04),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: showDivider
                      ? Border(bottom: BorderSide(color: palette.rule))
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 20,
                                height: 1.2,
                                letterSpacing: -.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (description != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                description!,
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            if (status != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      right: 6,
                                    ),
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: ready
                                            ? palette.accent
                                            : palette.muted,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      status!,
                                      style: TextStyle(
                                        color: ready
                                            ? palette.accent
                                            : palette.muted,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (showArtwork) ...[
                        const SizedBox(width: 12),
                        ExcludeSemantics(
                          child: SizedBox(
                            width: artworkSize,
                            height: artworkSize,
                            child: CustomPaint(
                              painter:
                                  RenderingPolicyScope.of(context)
                                      .simplerEffects
                                  ? null
                                  : _EntryWashPainter(palette),
                              child: artworkBuilder(artworkSize),
                            ),
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: palette.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EntryWashPainter extends CustomPainter {
  const _EntryWashPainter(this.palette);

  final MorePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 64, size.height / 64);
    _paintWash(canvas);
  }

  void _paintWash(Canvas canvas) {
    final dark = palette.ground.computeLuminance() < .2;
    final wash = Path()
      ..moveTo(6, 29)
      ..cubicTo(2, 14, 22, 3, 36, 6)
      ..cubicTo(52, 3, 65, 18, 60, 33)
      ..cubicTo(64, 48, 48, 59, 33, 56)
      ..cubicTo(16, 62, 1, 47, 6, 29)
      ..close();
    canvas.drawPath(
      wash,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.1, -.1),
          radius: .75,
          colors: [
            palette.accent.withValues(alpha: dark ? .10 : .055),
            palette.accent.withValues(alpha: dark ? .045 : .025),
            palette.accent.withValues(alpha: 0),
          ],
          stops: const [0, .55, 1],
        ).createShader(const Rect.fromLTWH(1, 2, 62, 60))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_EntryWashPainter oldDelegate) =>
      palette.accent != oldDelegate.palette.accent ||
      palette.ground != oldDelegate.palette.ground;
}
