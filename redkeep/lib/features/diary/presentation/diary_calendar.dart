import 'diary_artwork.dart';
import '../domain/diary_period.dart';
import '../domain/diary_timeline.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'diary_style.dart';
import 'diary_paper_stamp.dart';

const diaryCalendarPinArtworkKey = 'diary.calendar.pin';
const diaryCalendarPinSize = 24.0;
const _calendarPinOverhang = 13.0;
const _calendarPinHorizontalOffset = 8.0;

/// Paper date tabs on a fine ink curve. The page owns their motion, so the
/// calendar follows a sheet's drag, cancellation and settling frame for frame.
class DiaryCalendar extends StatelessWidget {
  const DiaryCalendar({
    super.key,
    required this.selectedDate,
    this.timeline,
    required this.onDateChanged,
    this.lastDate,
    this.enabled = true,
    this.collapseProgress = 0,
    this.dayOffset = 0,
    this.edgeDrop = 0,
    this.midDrop = 0,
    this.onSelectedTap,
    this.onDayDragStart,
    this.onDayDragUpdate,
    this.onDayDragEnd,
    this.onDayDragCancel,
  });

  final DiaryPeriod selectedDate;
  final DiaryTimeline? timeline;
  final ValueChanged<DiaryPeriod> onDateChanged;
  final DateTime? lastDate;
  final bool enabled;
  final double collapseProgress;

  /// Fractional calendar days from [selectedDate], driven by the sheet turn.
  /// There is no second controller or delayed animation after a date commits.
  final double dayOffset;

  /// How far a downward pull has drawn the thread's ends and its lowest point.
  /// The tabs ride the stretched thread and may hang below the calendar.
  final double edgeDrop, midDrop;

  bool get _pulled => edgeDrop != 0 || midDrop != 0;

  /// Tapping the selected day's own tab; other tabs choose their day.
  final VoidCallback? onSelectedTap;

  /// Tabs hanging below the calendar's own height stay inside their boxes.
  double get _hangExtent =>
      _pulled ? math.max(0, math.max(edgeDrop, midDrop)) : 0;

  /// Extra drop of the thread at [x], following the stretched curve.
  double _dropAt(double x, double width) {
    final fraction = (x / width).clamp(0.0, 1.0);
    return edgeDrop + (midDrop - edgeDrop) * 4 * fraction * (1 - fraction);
  }

  final VoidCallback? onDayDragStart, onDayDragCancel;

  /// Physical horizontal movement and velocity, normalized to one date tab.
  final ValueChanged<double>? onDayDragUpdate, onDayDragEnd;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  DiaryTimeline get _timeline =>
      timeline ?? DiaryTimeline(today: lastDate ?? DateTime.now());
  DiaryPeriod? _at(int offset) => _timeline.offset(selectedDate, offset);
  bool _available(DiaryPeriod? period) =>
      period != null && period.hasStarted(lastDate ?? DateTime.now());
  void _selectDay(int offset) {
    if (offset == 0) {
      if (enabled) onSelectedTap?.call();
      return;
    }
    final date = _at(offset);
    if (enabled && offset != 0 && _available(date)) onDateChanged(date!);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final today = TimeHelper.dateOnly(lastDate ?? DateTime.now());
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: 1.3);
    final collapse = collapseProgress.clamp(0.0, 1.0);
    final height = ui.lerpDouble(108, 76, collapse)!;
    final contentInset = 48 * collapse;
    return RepaintBoundary(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SizedBox(
            height: height + _hangExtent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final compactDayWidth = (width - 96) / 5;
                final dayWidth = ui.lerpDouble(
                  width * .18,
                  compactDayWidth,
                  collapse,
                )!;
                final middleDay = dayOffset.round();
                final previous = _at(-1);
                final next = _at(1);
                return Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'Diary calendar',
                  value: selectedDate.label(
                    Localizations.localeOf(context).toString(),
                  ),
                  increasedValue: _available(next)
                      ? next!.label(Localizations.localeOf(context).toString())
                      : null,
                  decreasedValue: _available(previous)
                      ? previous!.label(
                          Localizations.localeOf(context).toString(),
                        )
                      : null,
                  onIncrease: enabled && _available(next)
                      ? () => _selectDay(1)
                      : null,
                  onDecrease: enabled && _available(previous)
                      ? () => _selectDay(-1)
                      : null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: onDayDragStart == null
                        ? null
                        : (_) => onDayDragStart!(),
                    onHorizontalDragUpdate: onDayDragUpdate == null
                        ? null
                        : (details) =>
                              onDayDragUpdate!(details.delta.dx / dayWidth),
                    onHorizontalDragEnd: onDayDragEnd == null
                        ? null
                        : (details) => onDayDragEnd!(
                            (details.primaryVelocity ?? 0) / dayWidth,
                          ),
                    onHorizontalDragCancel: onDayDragCancel,
                    child: Stack(
                      clipBehavior: _pulled ? Clip.none : Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CalendarThreadPainter(
                                colors: context.colors,
                                collapse: collapse,
                                edgeDrop: edgeDrop,
                                midDrop: midDrop,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: ClipRect(
                            clipBehavior: _pulled ? Clip.none : Clip.hardEdge,
                            clipper: _CalendarContentClipper(contentInset),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (
                                  var day = middleDay - 3;
                                  day <= middleDay + 3;
                                  day++
                                )
                                  _buildDay(
                                    context: context,
                                    day: day,
                                    width: width,
                                    height: height,
                                    collapse: collapse,
                                    compactDayWidth: compactDayWidth,
                                    textScaler: textScaler,
                                    localizations: localizations,
                                    today: today,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDay({
    required BuildContext context,
    required int day,
    required double width,
    required double height,
    required double collapse,
    required double compactDayWidth,
    required TextScaler textScaler,
    required MaterialLocalizations localizations,
    required DateTime today,
  }) {
    final relativeDay = day - dayOffset;
    final distance = relativeDay.abs();
    final opacity = ((2.65 - distance) / .55).clamp(0.0, 1.0);
    final prominence = Curves.easeInOut.transform(
      (1 - distance).clamp(0.0, 1.0),
    );
    final lift = 8 * (1 - prominence) * (1 - collapse);
    final expandedX =
        width / 2 +
        relativeDay.sign *
            width *
            (.195 * distance - .015 * distance * distance);
    final x = ui.lerpDouble(
      expandedX,
      width / 2 + relativeDay * compactDayWidth,
      collapse,
    )!;
    final expandedPointY = _CalendarThreadPainter.heightAt(expandedX, width);
    final drop = _pulled ? _dropAt(x, width) : 0.0;
    final centerY =
        drop +
        ui.lerpDouble(
          ui.lerpDouble(expandedPointY + 24, 62, prominence),
          _CalendarThreadPainter.compactCenterY,
          collapse,
        )! -
        lift;
    final targetWidth = ui.lerpDouble(76, compactDayWidth, collapse)!;
    final date = _at(day);
    if (date == null) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final pinned = date.isDay && date.isCurrent(today);
    final available = _available(date);
    final canSelect =
        enabled && available && (day != 0 || onSelectedTap != null);
    final box = height + _hangExtent;
    final inactiveInk = Color.lerp(
      context.colors.onSurfaceVariant,
      context.colors.surface,
      available ? .18 : .50,
    )!;
    final ink = Color.lerp(inactiveInk, context.colors.primary, prominence)!;
    final sway = math.sin(dayOffset.abs() * math.pi);
    final tilt =
        (relativeDay.sign * .035 * (1 - prominence) + dayOffset * .065 * sway) *
        (1 - collapse);
    return Positioned(
      key: ValueKey(
        'diary-calendar-date-${date.isDay ? date.calendarDate.toIso8601String() : date.key}',
      ),
      left: x - targetWidth / 2,
      top: 0,
      width: targetWidth,
      height: box,
      child: IgnorePointer(
        ignoring: !canSelect || opacity < .3,
        child: Opacity(
          opacity: opacity,
          child: Semantics(
            excludeSemantics: true,
            hidden: opacity < .3,
            button: true,
            enabled: canSelect,
            selected: day == 0,
            label: date.label(Localizations.localeOf(context).toString()),
            onTap: canSelect ? () => _selectDay(day) : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canSelect ? () => _selectDay(day) : null,
              child: Transform.rotate(
                angle: tilt,
                alignment: Alignment(0, centerY / box * 2 - 1),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DatePaperPainter(
                          colors: context.colors,
                          date: date.calendarDate,
                          centerY: centerY,
                          prominence: prominence,
                          collapse: collapse,
                          pinned: pinned,
                        ),
                      ),
                    ),
                    if (pinned && collapse < 1)
                      Positioned(
                        top:
                            centerY -
                            _DatePaperPainter.heightFor(prominence, collapse) /
                                2 -
                            _calendarPinOverhang,
                        left: _calendarPinHorizontalOffset,
                        right: -_calendarPinHorizontalOffset,
                        height: diaryCalendarPinSize,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 1 - collapse,
                            child: Center(
                              child: DiaryArtwork(
                                assetKey: diaryCalendarPinArtworkKey,
                                key: const ValueKey('diary-calendar-pin'),
                                width: diaryCalendarPinSize,
                                height: diaryCalendarPinSize,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    _dateLabel(
                      text: date.shortLabel(
                        Localizations.localeOf(context).toString(),
                      ),
                      centerY:
                          drop +
                          ui.lerpDouble(
                            ui.lerpDouble(expandedPointY + 16, 50, prominence),
                            24,
                            collapse,
                          )! -
                          lift,
                      style: TextStyle(
                        color: ink,
                        fontSize: ui.lerpDouble(
                          ui.lerpDouble(13, date.isDay ? 23 : 14, prominence),
                          ui.lerpDouble(12.5, 17, prominence),
                          collapse,
                        ),
                        fontWeight: FontWeight.lerp(
                          FontWeight.w400,
                          FontWeight.w600,
                          prominence,
                        ),
                        height: 1,
                      ),
                      textScaler: textScaler,
                    ),
                    _dateLabel(
                      text: date.isDay
                          ? _weekdays[date.weekday - 1]
                          : date.kind == DiaryPeriodKind.week
                          ? '${date.day}–${date.end.day}'
                          : date.kind.name,
                      centerY:
                          drop +
                          ui.lerpDouble(
                            ui.lerpDouble(expandedPointY + 33, 71, prominence),
                            42,
                            collapse,
                          )! -
                          lift,
                      style: TextStyle(
                        color: ink,
                        fontSize: ui.lerpDouble(
                          ui.lerpDouble(10.5, 11.5, prominence),
                          10,
                          collapse,
                        ),
                        height: 1,
                      ),
                      textScaler: textScaler,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateLabel({
    required String text,
    required double centerY,
    required TextStyle style,
    required TextScaler textScaler,
  }) => Positioned(
    top: centerY - 18,
    left: 0,
    right: 0,
    height: 36,
    child: Center(
      child: Text(text, style: style, textScaler: textScaler, maxLines: 1),
    ),
  );
}

class _CalendarContentClipper extends CustomClipper<Rect> {
  const _CalendarContentClipper(this.inset);
  final double inset;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(inset, 0, size.width - inset, size.height);

  @override
  bool shouldReclip(_CalendarContentClipper oldClipper) =>
      inset != oldClipper.inset;
}

/// The thread's ends and quadratic control point, in calendar coordinates.
/// A pull lowers its ends by [edgeDrop] and its lowest point by [midDrop], so
/// the reader can reveal what lies above the very line it draws.
({double edge, double control}) diaryCalendarThreadCurve({
  double collapse = 0,
  double edgeDrop = 0,
  double midDrop = 0,
}) {
  const compact = _CalendarThreadPainter.compactCenterY;
  // A quadratic's midpoint lies halfway between its ends and control point.
  return (
    edge: ui.lerpDouble(-15, compact, collapse)! + edgeDrop,
    control: ui.lerpDouble(119, compact, collapse)! + 2 * midDrop - edgeDrop,
  );
}

/// The calendar's thread across [width]; see [diaryCalendarThreadCurve].
Path diaryCalendarThreadPath(
  double width, {
  double collapse = 0,
  double edgeDrop = 0,
  double midDrop = 0,
}) {
  final inset = 48 * collapse;
  final curve = diaryCalendarThreadCurve(
    collapse: collapse,
    edgeDrop: edgeDrop,
    midDrop: midDrop,
  );
  return Path()
    ..moveTo(inset, curve.edge)
    ..quadraticBezierTo(width / 2, curve.control, width - inset, curve.edge);
}

class _CalendarThreadPainter extends CustomPainter {
  const _CalendarThreadPainter({
    required this.collapse,
    required this.colors,
    this.edgeDrop = 0,
    this.midDrop = 0,
  });
  final ColorScheme colors;
  final double collapse, edgeDrop, midDrop;
  static const compactCenterY = 33.0;

  static double heightAt(double x, double width, {double collapse = 0}) {
    final inset = 48 * collapse;
    final fraction = (x - inset) / (width - 2 * inset);
    return ui.lerpDouble(-15, compactCenterY, collapse)! +
        268 * (1 - collapse) * fraction * (1 - fraction);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = diaryCalendarThreadPath(
      size.width,
      collapse: collapse,
      edgeDrop: edgeDrop,
      midDrop: midDrop,
    );
    canvas.drawPath(
      path.shift(Offset(0, .8 * (1 - collapse))),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = colors.onSurface.withValues(alpha: .045 * (1 - collapse)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .75
        ..color = colors.primary.withValues(
          alpha: ui.lerpDouble(.32, .10, collapse)!,
        ),
    );
  }

  @override
  bool shouldRepaint(_CalendarThreadPainter oldDelegate) =>
      collapse != oldDelegate.collapse ||
      edgeDrop != oldDelegate.edgeDrop ||
      midDrop != oldDelegate.midDrop ||
      colors != oldDelegate.colors;
}

class _DatePaperPainter extends CustomPainter {
  const _DatePaperPainter({
    required this.colors,
    required this.date,
    required this.centerY,
    required this.prominence,
    required this.collapse,
    required this.pinned,
  });

  final ColorScheme colors;
  final DateTime date;
  final double centerY, prominence, collapse;
  final bool pinned;

  static double heightFor(double prominence, double collapse) =>
      ui.lerpDouble(ui.lerpDouble(50, 80, prominence), 52, collapse)!;

  @override
  void paint(Canvas canvas, Size size) {
    final width = ui.lerpDouble(
      ui.lerpDouble(44, 64, prominence),
      math.min(46, size.width - 4),
      collapse,
    )!;
    final height = heightFor(prominence, collapse);
    final bounds = Rect.fromCenter(
      center: Offset(size.width / 2, centerY),
      width: width,
      height: height,
    );
    final visibility = 1 - collapse;
    if (visibility > 0) {
      DiaryPaperStamp(
        paper: colors.surface,
        ink: colors.onSurface,
        shadowColor: colors.shadow,
        variant: date.weekday,
        edgeScale: .35,
        opacity: visibility,
      ).paintRect(canvas, bounds);
      if (!pinned) {
        canvas.drawCircle(
          Offset(size.width / 2, bounds.top + 9),
          1.15,
          Paint()
            ..color = colors.onSurfaceVariant.withValues(
              alpha: .28 * visibility,
            ),
        );
      }
    }
    if (prominence > 0) {
      final y = ui.lerpDouble(centerY + 26, 54, collapse)!;
      canvas.drawLine(
        Offset(size.width / 2 - 6 * prominence, y),
        Offset(size.width / 2 + 6 * prominence, y - .5 * (1 - collapse)),
        Paint()
          ..color = colors.primary.withValues(alpha: .65 * prominence)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DatePaperPainter oldDelegate) =>
      colors != oldDelegate.colors ||
      date != oldDelegate.date ||
      centerY != oldDelegate.centerY ||
      prominence != oldDelegate.prominence ||
      collapse != oldDelegate.collapse ||
      pinned != oldDelegate.pinned;
}
