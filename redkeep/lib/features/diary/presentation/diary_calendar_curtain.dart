import 'dart:math' as math;

import '../../../core/presentation/rendering_policy.dart';
import '../domain/diary_period.dart';
import '../domain/diary_timeline.dart';
import 'diary_calendar.dart';
import 'diary_style.dart';

/// How far the thread travels between the reader and the open calendar.
///
/// At rest in the reader the thread hangs below the month. In the calendar
/// it hangs across the bottom, a gentler sag holding the day's tab, with the
/// calendar above it and the diary page waiting just below the screen.
@immutable
class DiaryThreadTravel {
  const DiaryThreadTravel({required this.mid, required this.edge});

  /// Lays the calendar's resting thread out on a reader of [height], whose
  /// thread starts at [calendarTop], above a system gesture inset of [inset].
  factory DiaryThreadTravel.of({
    required double height,
    required double calendarTop,
    required double inset,
  }) {
    // The day's tab hangs this far above the system inset; the thread's ends
    // rise a gentle sag above its lowest point.
    final restMid = height - inset - restLift;
    final mid = math.max(120.0, restMid - (calendarTop + 52));
    final edge = math.max(
      mid,
      calendarTop + 52 + mid - restSag - (calendarTop - 15),
    );
    return DiaryThreadTravel(mid: mid, edge: edge);
  }

  static const restLift = 86.0;
  static const restSag = 30.0;

  /// How far the lowest point of the thread (and the page with it) and the
  /// thread's ends move between the reader and the open calendar.
  final double mid, edge;

  /// Distance from the bottom of the reader to the resting thread's ends:
  /// the calendar's content keeps above it.
  double bottomInset(double height, double calendarTop) =>
      math.max(0, height - (calendarTop - 15 + edge));

  @override
  bool operator ==(Object other) =>
      other is DiaryThreadTravel && other.mid == mid && other.edge == edge;

  @override
  int get hashCode => Object.hash(mid, edge);
}

/// Pulling the diary page down draws the date thread down with it. The page
/// hangs from its date tab, and everything above the stretched thread is the
/// calendar, unrolling from the top as the page drops.
///
/// [pull] runs from the resting reader (0) to the open calendar (1), where the
/// thread hangs across the calendar's bottom. Whichever way it moves, the tab
/// leads and the thread's ends trail: pulled down from the reader they stay
/// high, so the thread stretches deep; lifted up from the calendar they stay
/// low, so the thread arches, then springs back into its sag as it arrives.
class DiaryCalendarCurtain extends StatelessWidget {
  const DiaryCalendarCurtain({
    super.key,
    required this.pull,
    required this.calendarTop,
    required this.travel,
    required this.fromCalendar,
    required this.selectedDate,
    required this.timeline,
    required this.lastDate,
    required this.open,
    required this.calendar,
    required this.onDateChosen,
    required this.onReturn,
    required this.onLiftStart,
    required this.onLiftUpdate,
    required this.onLiftEnd,
    required this.onLiftCancel,
  });

  final Animation<double> pull;

  /// The reader's resting thread's top edge.
  final double calendarTop;
  final DiaryThreadTravel travel;

  /// Whether this motion began in the open calendar, so the thread trails a
  /// rising tab rather than a falling one.
  final bool fromCalendar;
  final DiaryPeriod selectedDate;
  final DiaryTimeline timeline;
  final DateTime lastDate;

  /// Whether the calendar has settled open and takes touches.
  final bool open;
  final Widget calendar;

  /// A tab on the resting thread: another day, or the day's own tab.
  final ValueChanged<DiaryPeriod> onDateChosen;
  final VoidCallback onReturn;

  /// Lifting the resting thread, in physical pixels and pixels per second.
  final VoidCallback onLiftStart, onLiftCancel;
  final ValueChanged<double> onLiftUpdate, onLiftEnd;

  /// The page and its date tab follow the finger exactly.
  static double midDrop(double pull, DiaryThreadTravel travel) =>
      travel.mid * pull;

  static double edgeDrop(
    double pull,
    DiaryThreadTravel travel, {
    required bool fromCalendar,
  }) =>
      travel.edge *
      (fromCalendar ? Curves.easeOutCubic : Curves.easeInCubic).transform(
        pull.clamp(0.0, 1.0),
      );

  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    Widget lift(Widget child, {required HitTestBehavior behavior}) =>
        GestureDetector(
          behavior: behavior,
          onVerticalDragStart: open ? (_) => onLiftStart() : null,
          onVerticalDragUpdate: open
              ? (details) => onLiftUpdate(details.delta.dy)
              : null,
          onVerticalDragEnd: open
              ? (details) => onLiftEnd(details.primaryVelocity ?? 0)
              : null,
          onVerticalDragCancel: open ? onLiftCancel : null,
          child: child,
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stripWidth = math.min(constraints.maxWidth, 700.0);
        return AnimatedBuilder(
          animation: pull,
          child: RepaintBoundary(child: calendar),
          builder: (context, calendar) {
            final p = pull.value.clamp(0.0, 1.0);
            final edge = edgeDrop(p, travel, fromCalendar: fromCalendar);
            final mid = midDrop(p, travel);
            final region = _CurtainRegion(
              stripLeft: (constraints.maxWidth - stripWidth) / 2,
              stripWidth: stripWidth,
              top: calendarTop,
              edgeDrop: edge,
              midDrop: mid,
            );
            final reveal = Curves.easeOut.transform((p / .4).clamp(0.0, 1.0));
            Widget layer = calendar!;
            if (!simple && reveal < 1) {
              layer = Opacity(opacity: reveal, child: layer);
            }
            if (p < 1) {
              layer = Transform.translate(
                offset: Offset(0, -56 * (1 - Curves.easeOutCubic.transform(p))),
                child: layer,
              );
            }
            layer = ClipPath(
              clipper: _CurtainClipper(region),
              clipBehavior: simple ? Clip.hardEdge : Clip.antiAlias,
              child: layer,
            );
            // The strip's box starts at the thread's highest drop, so the
            // tabs hanging from it stay inside their own touch targets.
            final shift = math.min(edge, mid);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (p > 0 && !simple)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _CurtainShadowPainter(
                        region: region,
                        color: context.colors.shadow,
                        strength: reveal * reveal * (1 - .7 * p),
                      ),
                    ),
                  ),
                // Below the thread is the page: lifting anywhere there
                // raises it, as lifting the thread itself does.
                lift(const SizedBox.expand(), behavior: HitTestBehavior.opaque),
                IgnorePointer(
                  ignoring: !open,
                  child: ExcludeSemantics(excluding: !open, child: layer),
                ),
                if (p > 0)
                  Positioned(
                    key: const ValueKey('diary-pulled-thread'),
                    top: calendarTop + shift,
                    left: 0,
                    right: 0,
                    height: 108 + math.max(edge, mid) - shift,
                    child: IgnorePointer(
                      ignoring: !open,
                      child: ExcludeSemantics(
                        excluding: !open,
                        child: lift(
                          behavior: HitTestBehavior.deferToChild,
                          DiaryCalendar(
                            key: const ValueKey('diary-resting-thread'),
                            selectedDate: selectedDate,
                            timeline: timeline,
                            lastDate: lastDate,
                            enabled: open,
                            onDateChanged: onDateChosen,
                            onSelectedTap: onReturn,
                            edgeDrop: edge - shift,
                            midDrop: mid - shift,
                          ),
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
