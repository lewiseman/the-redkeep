import 'dart:math' as math;

import '../../../core/presentation/rendering_policy.dart';
import '../domain/diary_period.dart';
import '../domain/diary_timeline.dart';
import 'diary_calendar.dart';
import 'diary_style.dart';

/// Pulling the diary page down draws the date thread down with it. The page
/// hangs from its date tab, and everything above the stretched thread is the
/// calendar, unrolling from the top as the page drops away.
///
/// [pull] runs from the resting reader (0) to the open calendar (1). At 1 the
/// thread and page have left the bottom of the screen.
class DiaryCalendarCurtain extends StatelessWidget {
  const DiaryCalendarCurtain({
    super.key,
    required this.pull,
    required this.calendarTop,
    required this.distance,
    required this.selectedDate,
    required this.timeline,
    required this.lastDate,
    required this.open,
    required this.calendar,
  });

  final Animation<double> pull;

  /// The resting thread's top edge, and how far the page travels to leave.
  final double calendarTop, distance;
  final DiaryPeriod selectedDate;
  final DiaryTimeline timeline;
  final DateTime lastDate;

  /// Whether the calendar has settled open and takes touches.
  final bool open;
  final Widget calendar;

  /// The page and its date tab follow the finger exactly.
  static double midDrop(double pull, double distance) => distance * pull;

  /// The thread's ends lag, so a short pull stretches it into a deep curve
  /// before the whole thread follows the page off screen.
  static double edgeDrop(double pull, double distance) =>
      distance * Curves.easeInCubic.transform(pull.clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stripWidth = math.min(constraints.maxWidth, 700.0);
        return AnimatedBuilder(
          animation: pull,
          child: RepaintBoundary(child: calendar),
          builder: (context, calendar) {
            final p = pull.value.clamp(0.0, 1.0);
            final edge = edgeDrop(p, distance);
            final mid = midDrop(p, distance);
            final region = _CurtainRegion(
              stripLeft: (constraints.maxWidth - stripWidth) / 2,
              stripWidth: stripWidth,
              top: calendarTop,
              edgeDrop: edge,
              midDrop: mid,
            );
            final reveal = Curves.easeOut.transform((p / .4).clamp(0.0, 1.0));
            Widget layer = calendar!;
            if (p < 1) {
              if (!simple) layer = Opacity(opacity: reveal, child: layer);
              layer = ClipPath(
                clipper: _CurtainClipper(region),
                clipBehavior: simple ? Clip.hardEdge : Clip.antiAlias,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -56 * (1 - Curves.easeOutCubic.transform(p)),
                  ),
                  child: layer,
                ),
              );
            }
            final moving = p > 0 && p < 1;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (moving && !simple)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _CurtainShadowPainter(
                        region: region,
                        color: context.colors.shadow,
                        strength: reveal * reveal * (1 - p),
                      ),
                    ),
                  ),
                IgnorePointer(
                  ignoring: !open,
                  child: ExcludeSemantics(excluding: !open, child: layer),
                ),
                if (moving)
                  Positioned(
                    key: const ValueKey('diary-pulled-thread'),
                    top: calendarTop,
                    left: 0,
                    right: 0,
                    height: 108,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: DiaryCalendar(
                          selectedDate: selectedDate,
                          timeline: timeline,
                          lastDate: lastDate,
                          enabled: false,
                          onDateChanged: (_) {},
                          edgeDrop: edge,
                          midDrop: mid,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Everything above the stretched thread, in the reader's coordinates.
class _CurtainRegion {
  const _CurtainRegion({
    required this.stripLeft,
    required this.stripWidth,
    required this.top,
    required this.edgeDrop,
    required this.midDrop,
  });

  final double stripLeft, stripWidth, top, edgeDrop, midDrop;

  Path pathFor(Size size) {
    final curve = diaryCalendarThreadCurve(
      edgeDrop: edgeDrop,
      midDrop: midDrop,
    );
    final edge = top + curve.edge;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, edge)
      ..lineTo(stripLeft + stripWidth, edge)
      ..quadraticBezierTo(
        stripLeft + stripWidth / 2,
        top + curve.control,
        stripLeft,
        edge,
      )
      ..lineTo(0, edge)
      ..close();
  }

  @override
  bool operator ==(Object other) =>
      other is _CurtainRegion &&
      other.stripLeft == stripLeft &&
      other.stripWidth == stripWidth &&
      other.top == top &&
      other.edgeDrop == edgeDrop &&
      other.midDrop == midDrop;

  @override
  int get hashCode =>
      Object.hash(stripLeft, stripWidth, top, edgeDrop, midDrop);
}

class _CurtainClipper extends CustomClipper<Path> {
  const _CurtainClipper(this.region);
  final _CurtainRegion region;

  @override
  Path getClip(Size size) => region.pathFor(size);

  @override
  bool shouldReclip(_CurtainClipper oldClipper) => oldClipper.region != region;
}

/// A soft shade the unrolling calendar casts on the page below its edge.
class _CurtainShadowPainter extends CustomPainter {
  const _CurtainShadowPainter({
    required this.region,
    required this.color,
    required this.strength,
  });

  final _CurtainRegion region;
  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    canvas.drawPath(
      region.pathFor(size).shift(const Offset(0, 5)),
      Paint()
        ..color = color.withValues(alpha: .14 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(_CurtainShadowPainter oldDelegate) =>
      oldDelegate.region != region ||
      oldDelegate.color != color ||
      oldDelegate.strength != strength;
}
