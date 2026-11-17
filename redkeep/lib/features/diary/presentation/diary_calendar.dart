import 'package:intl/intl.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../domain/diary_period.dart';
import '../domain/diary_raven.dart';
import '../domain/diary_timeline.dart';
import 'diary_raven_perch.dart';

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'diary_style.dart';
import 'diary_paper_stamp.dart';

/// How far a resting tab hangs below the cord, on a short loop of it.
const _tabHang = 12.0;

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
    this.written = const {},
    this.raven = false,
    this.ravenLetter,
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

  /// Days with writing: their tabs are sealed in red wax.
  final Set<DiaryPeriod> written;

  /// Whether the raven perches on the cord, and the letter it holds, if any.
  /// Tapping a raven with a letter opens the day the letter came from.
  final bool raven;
  final DiaryRavenLetter? ravenLetter;

  /// Where the raven perches, as a fraction of the cord's width, and how
  /// large it is. It sits in the gap beside the day after the selected one.
  static const _ravenPerch = .765;
  static const _ravenSize = 40.0;

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
                final ravenOpacity = raven
                    ? (1 - collapse * 2.5).clamp(0.0, 1.0)
                    : 0.0;
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
                                perch: ravenOpacity > 0 ? _ravenPerch : null,
                                perchWeight: ravenOpacity,
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
                        if (ravenOpacity > 0)
                          _buildRaven(context, width, ravenOpacity),
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

  /// The raven on the cord, its feet on the cord as it sags, stretches and
  /// dips a little under the bird's weight.
  Widget _buildRaven(BuildContext context, double width, double opacity) {
    final x = width * _ravenPerch;
    final dip = _CalendarThreadPainter.perchDip * opacity;
    final y =
        _CalendarThreadPainter.heightAt(x, width) +
        (_pulled ? _dropAt(x, width) : 0) +
        dip;
    // Leaning a little with the cord, as a bird balances on it.
    final sag = 268 + 4 * (midDrop - edgeDrop);
    final lean = math.atan(sag * (1 - 2 * _ravenPerch) / width) * .3;
    final letter = ravenLetter;
    final canOpen = letter != null && enabled;
    final animate =
        context
            .dependOnInheritedWidgetOfExactType<RenderingPolicyScope>()
            ?.policy
            .animate ??
        true;
    const size = _ravenSize;
    // A 48px target around the bird, the letter included.
    const target = 52.0;
    Widget bird = Transform.rotate(
      angle: lean,
      alignment: const Alignment(DiaryRaven.footX * 2 - 1, 1),
      child: DiaryRaven(
        key: const ValueKey('diary-raven'),
        size: size,
        letter: letter != null,
        animate: animate,
      ),
    );
    if (opacity < 1) bird = Opacity(opacity: opacity, child: bird);
    return Positioned(
      left: x - size * DiaryRaven.footX - (target - size) / 2 - 4,
      top: y - size - (target - size) / 2 + 1,
      width: target,
      height: target,
      child: Semantics(
        button: canOpen,
        excludeSemantics: true,
        label: letter == null ? null : _letterLabel(context, letter),
        onTap: canOpen ? () => onDateChanged(letter.from) : null,
        child: GestureDetector(
          behavior: canOpen
              ? HitTestBehavior.opaque
              : HitTestBehavior.deferToChild,
          onTap: canOpen ? () => onDateChanged(letter.from) : null,
          child: IgnorePointer(
            ignoring: !canOpen,
            child: Center(child: bird),
          ),
        ),
      ),
    );
  }

  static String _letterLabel(BuildContext context, DiaryRavenLetter letter) {
    final locale = Localizations.localeOf(context).toString();
    final weekday = DateFormat.EEEE(locale).format(letter.from.calendarDate);
    final when = switch (letter.echo) {
      DiaryEcho.year => 'a year ago today',
      DiaryEcho.month => 'a month ago today',
      DiaryEcho.week => 'last $weekday',
    };
    return 'A raven brings your page from $when, '
        '${letter.from.label(locale)}. Open it';
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
    final date = _at(day);
    if (date == null) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final isToday = date.isDay && date.isCurrent(today);
    const hang = _tabHang;
    final expandedPointY = _CalendarThreadPainter.heightAt(expandedX, width);
    final drop = _pulled ? _dropAt(x, width) : 0.0;
    final centerY =
        drop +
        ui.lerpDouble(
          ui.lerpDouble(expandedPointY + 24 + hang, 62, prominence),
          _CalendarThreadPainter.compactCenterY,
          collapse,
        )! -
        lift;
    final targetWidth = ui.lerpDouble(76, compactDayWidth, collapse)!;
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
    final numberCenterY =
        drop +
        ui.lerpDouble(
          ui.lerpDouble(expandedPointY + 16 + hang, 50, prominence),
          24,
          collapse,
        )! -
        lift;
    final numberSize = ui.lerpDouble(
      ui.lerpDouble(13, date.isDay ? 23 : 14, prominence),
      ui.lerpDouble(12.5, 17, prominence),
      collapse,
    )!;
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
                          cordY: drop + expandedPointY,
                          prominence: prominence,
                          collapse: collapse,
                          sealed: written.contains(date),
                        ),
                      ),
                    ),
                    // Today's date is circled in ink, as by hand.
                    if (isToday)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: const ValueKey('diary-calendar-today'),
                            painter: _TodayCirclePainter(
                              center: numberCenterY,
                              size: textScaler.scale(numberSize),
                              weight: prominence,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                      ),
                    _dateLabel(
                      text: date.shortLabel(
                        Localizations.localeOf(context).toString(),
                      ),
                      centerY: numberCenterY,
                      style: TextStyle(
                        color: ink,
                        fontSize: numberSize,
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
                            ui.lerpDouble(
                              expandedPointY + 33 + hang,
                              71,
                              prominence,
                            ),
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
    this.perch,
    this.perchWeight = 0,
  });
  final ColorScheme colors;
  final double collapse, edgeDrop, midDrop;

  /// Where a raven perches, as a fraction of the width, and how much of its
  /// weight the cord bears there (it fades in and out with the bird).
  final double? perch;
  final double perchWeight;
  static const compactCenterY = 33.0;

  /// How far the cord dips under a perched raven.
  static const perchDip = 2.6;

  double _dip(double x, double width) {
    final at = perch;
    if (at == null || perchWeight <= 0) return 0;
    final d = (x - width * at) / 15;
    return perchDip * perchWeight * math.exp(-d * d);
  }

  static double heightAt(double x, double width, {double collapse = 0}) {
    final inset = 48 * collapse;
    final fraction = (x - inset) / (width - 2 * inset);
    return ui.lerpDouble(-15, compactCenterY, collapse)! +
        268 * (1 - collapse) * fraction * (1 - fraction);
  }

  /// The cord's colour: the accent, deepened with ink.
  static Color cordColor(ColorScheme colors) =>
      Color.lerp(colors.primary, colors.onSurface, .3)!;

  @override
  void paint(Canvas canvas, Size size) {
    final curve = diaryCalendarThreadCurve(
      collapse: collapse,
      edgeDrop: edgeDrop,
      midDrop: midDrop,
    );
    final inset = 48 * collapse;
    final x0 = inset, x1 = size.width - inset, xc = size.width / 2;
    Offset at(double t) {
      final u = 1 - t;
      final x = u * u * x0 + 2 * u * t * xc + t * t * x1;
      return Offset(
        x,
        (u * u + t * t) * curve.edge +
            2 * u * t * curve.control +
            _dip(x, size.width),
      );
    }

    final Path path;
    if (perch == null || perchWeight <= 0) {
      path = diaryCalendarThreadPath(
        size.width,
        collapse: collapse,
        edgeDrop: edgeDrop,
        midDrop: midDrop,
      );
    } else {
      // Traced point by point, so the cord can give under the raven.
      const samples = 96;
      final start = at(0);
      path = Path()..moveTo(start.dx, start.dy);
      for (var i = 1; i <= samples; i++) {
        final point = at(i / samples);
        path.lineTo(point.dx, point.dy);
      }
    }
    final visibility = 1 - collapse;
    final cord = cordColor(colors);
    // A soft shadow on the sky beneath the cord.
    if (visibility > 0) {
      canvas.drawPath(
        path.shift(Offset(0, 1.6 * visibility)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = colors.shadow.withValues(alpha: .07 * visibility),
      );
    }
    // The cord fades a little towards the screen's edges, as if strung from
    // somewhere out of sight, rather than cut off by them.
    final fade = Rect.fromLTWH(0, 0, size.width, 1);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ui.lerpDouble(1.5, .75, collapse)!
        ..shader = LinearGradient(
          stops: const [0, .14, .86, 1],
          colors: [
            for (final alpha in const [.4, 1.0, 1.0, .4])
              cord.withValues(
                alpha: alpha * ui.lerpDouble(.62, .10, collapse)!,
              ),
          ],
        ).createShader(fade),
    );
    if (visibility <= 0) return;
    // The twist: short, light, slanted strokes along the cord. They are
    // spaced along the curve, so a stretched cord's twist opens out.
    final steps = ((x1 - x0) / 5.5).round().clamp(8, 160);
    final points = Float32List(steps * 4);
    for (var i = 0; i < steps; i++) {
      final t = (i + .5) / steps;
      final u = 1 - t;
      final point = at(t);
      final x = point.dx, y = point.dy;
      final dx = 2 * u * (xc - x0) + 2 * t * (x1 - xc);
      final dy = 2 * (curve.control - curve.edge) * (1 - 2 * t);
      final length = math.sqrt(dx * dx + dy * dy);
      if (length == 0) continue;
      // Along the cord, and a little across it.
      final ax = dx / length, ay = dy / length;
      final sx = ax * 1.1 - ay * .6, sy = ay * 1.1 + ax * .6;
      points
        ..[i * 4] = x - sx
        ..[i * 4 + 1] = y - sy
        ..[i * 4 + 2] = x + sx
        ..[i * 4 + 3] = y + sy;
    }
    canvas.drawRawPoints(
      ui.PointMode.lines,
      points,
      Paint()
        ..strokeWidth = .6
        ..strokeCap = StrokeCap.round
        ..color = colors.surface.withValues(alpha: .55 * visibility),
    );
  }

  @override
  bool shouldRepaint(_CalendarThreadPainter oldDelegate) =>
      collapse != oldDelegate.collapse ||
      edgeDrop != oldDelegate.edgeDrop ||
      midDrop != oldDelegate.midDrop ||
      perch != oldDelegate.perch ||
      perchWeight != oldDelegate.perchWeight ||
      colors != oldDelegate.colors;
}

class _DatePaperPainter extends CustomPainter {
  const _DatePaperPainter({
    required this.colors,
    required this.date,
    required this.centerY,
    required this.cordY,
    required this.prominence,
    required this.collapse,
    this.sealed = false,
  });

  final ColorScheme colors;
  final DateTime date;

  /// Whether the day has writing, shown by a wax seal on the tab's corner.
  final bool sealed;
  final double centerY, prominence, collapse;

  /// Where the cord crosses this tab's column, in the tab's own coordinates.
  final double cordY;

  /// How surely the tab's eyelet sits on the cord: only the resting tabs
  /// beside the selected one hang from it by a loop.
  double get threaded => math.pow(1 - prominence, 2).toDouble();

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
      final eyelet = Offset(size.width / 2, bounds.top + 9);
      canvas.drawCircle(
        eyelet,
        1.2,
        Paint()
          ..color = colors.onSurfaceVariant.withValues(alpha: .3 * visibility),
      );
      canvas.drawCircle(
        eyelet,
        2.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .55
          ..color = colors.onSurfaceVariant.withValues(alpha: .24 * visibility),
      );
      // A resting tab hangs below the cord from a short loop of it,
      // tied through its eyelet.
      final looped = threaded * visibility;
      if (looped > 0 && cordY < eyelet.dy - 2) {
        canvas.drawPath(
          Path()
            ..moveTo(eyelet.dx - .4, eyelet.dy)
            ..quadraticBezierTo(
              eyelet.dx - 1.8,
              (eyelet.dy + cordY) / 2,
              eyelet.dx,
              cordY,
            )
            ..moveTo(eyelet.dx + .4, eyelet.dy)
            ..quadraticBezierTo(
              eyelet.dx + 1.8,
              (eyelet.dy + cordY) / 2,
              eyelet.dx,
              cordY,
            ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.05
            ..strokeCap = StrokeCap.round
            ..color = _CalendarThreadPainter.cordColor(colors)
                .withValues(alpha: .7 * looped),
        );
      }
    }
    // A day with writing carries a small seal of red wax on its corner.
    if (sealed && visibility > 0) {
      final radius = ui.lerpDouble(4.2, 5.4, prominence)!;
      diaryPaintWaxSeal(
        canvas,
        Offset(bounds.right - radius * .55, bounds.bottom - radius * .7),
        radius,
        opacity: visibility,
      );
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
      cordY != oldDelegate.cordY ||
      prominence != oldDelegate.prominence ||
      collapse != oldDelegate.collapse ||
      sealed != oldDelegate.sealed;
}

/// A loop of ink drawn around today's date, a little uneven and overrunning
/// its start, the way a pen circles a day on a paper calendar.
class _TodayCirclePainter extends CustomPainter {
  const _TodayCirclePainter({
    required this.center,
    required this.size,
    required this.weight,
    required this.color,
  });

  /// The date's vertical centre and its scaled font size.
  final double center, size;

  /// The tab's prominence: the centre tab's circle is drawn a touch bolder.
  final double weight;
  final Color color;

  @override
  void paint(Canvas canvas, Size box) {
    final radius = size * .72 + 2;
    final rx = radius * 1.15, ry = radius * .8;
    final c = Offset(box.width / 2, center);
    const steps = 48;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      // Just over one turn, closing a little inside where it began.
      final a = -2.0 + t * 2 * math.pi * 1.1;
      final wobble = (1 + .05 * math.sin(3 * a + .7)) * (1 - .07 * t);
      final x = rx * math.cos(a) * wobble, y = ry * math.sin(a) * wobble;
      // Tilted slightly, as a hand would draw it.
      final point = c + Offset(x - y * .12, y + x * .12);
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = ui.lerpDouble(1.1, 1.5, weight)!
        ..color = color.withValues(alpha: ui.lerpDouble(.6, .85, weight)!),
    );
  }

  @override
  bool shouldRepaint(_TodayCirclePainter oldDelegate) =>
      center != oldDelegate.center ||
      size != oldDelegate.size ||
      weight != oldDelegate.weight ||
      color != oldDelegate.color;
}
