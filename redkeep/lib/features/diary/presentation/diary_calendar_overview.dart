import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../domain/diary_day_details.dart';
import '../domain/diary_period.dart';
import 'diary_paper_stamp.dart';
import 'diary_style.dart';

/// Which kind of page a calendar tap opens. The lens makes the choice
/// explicit instead of scattering add buttons through every week and month.
enum DiaryCalendarLens {
  day('Day', 'Tap a day to write it'),
  week('Week', 'Tap a week to write about all seven days'),
  month('Month', 'Tap a month to write its page'),
  year('Year', 'One page for the whole year');

  const DiaryCalendarLens(this.label, this.hint);
  final String label, hint;

  static DiaryCalendarLens of(DiaryPeriodKind? kind) => switch (kind) {
    DiaryPeriodKind.week => week,
    DiaryPeriodKind.month => month,
    DiaryPeriodKind.year => year,
    _ => day,
  };

  bool get isGrid => this == day || this == week;
}

int _ordinal(int year, int month, int day) => year * 10000 + month * 100 + day;

/// Saved pages and moods indexed once per data change, so every cell lookup
/// is an integer hash instead of building a period key string.
class DiaryCalendarMarks {
  DiaryCalendarMarks(
    Set<DiaryPeriod> saved,
    Map<DiaryPeriod, DiaryMood> moods, [
    Map<DiaryPeriod, String> headings = const {},
  ]) : _pages = {for (final period in saved) period.key},
       _headings = {
         for (final MapEntry(:key, :value) in headings.entries) key.key: value,
       } {
    for (final period in saved) {
      switch (period.kind) {
        case DiaryPeriodKind.day:
          _days.add(_ordinal(period.year, period.month, period.day));
          final month = period.year * 100 + period.month;
          _monthDays[month] = (_monthDays[month] ?? 0) + 1;
          _yearDays[period.year] = (_yearDays[period.year] ?? 0) + 1;
        case DiaryPeriodKind.week:
          _yearWeeks[period.year] = (_yearWeeks[period.year] ?? 0) + 1;
        case DiaryPeriodKind.month:
          _yearMonths[period.year] = (_yearMonths[period.year] ?? 0) + 1;
        case DiaryPeriodKind.year:
          break;
      }
    }
    for (final MapEntry(key: period, value: mood) in moods.entries) {
      if (period.isDay) {
        _moods[_ordinal(period.year, period.month, period.day)] = mood;
      }
    }
  }

  static final empty = DiaryCalendarMarks(const {}, const {});

  final Set<String> _pages;
  final Map<String, String> _headings;
  final _days = <int>{};
  final _moods = <int, DiaryMood>{};
  final _monthDays = <int, int>{};
  final _yearDays = <int, int>{}, _yearWeeks = <int, int>{};
  final _yearMonths = <int, int>{};

  bool hasEntry(DateTime date) =>
      _days.contains(_ordinal(date.year, date.month, date.day));
  DiaryMood? mood(DateTime date) =>
      _moods[_ordinal(date.year, date.month, date.day)];
  bool hasPage(DiaryPeriod period) => _pages.contains(period.key);
  String? heading(DiaryPeriod period) => _headings[period.key];
  int daysInMonth(int year, int month) => _monthDays[year * 100 + month] ?? 0;
  int daysInYear(int year) => _yearDays[year] ?? 0;
  int weeksInYear(int year) => _yearWeeks[year] ?? 0;
  int monthsInYear(int year) => _yearMonths[year] ?? 0;
  int daysInRange(DateTime from, int days) {
    var count = 0;
    for (var i = 0; i < days; i++) {
      if (hasEntry(TimeHelper.addDays(from, i))) count++;
    }
    return count;
  }
}

String plural(int count, String noun) => '$count $noun${count == 1 ? '' : 's'}';

/// Fades a freshly mounted lens in. No outgoing copy is kept alive, so keyed
/// calendar pages can never be mounted twice during a quick switch.
class DiaryCalendarFadeIn extends StatelessWidget {
  const DiaryCalendarFadeIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    if (!policy.animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// A paper-tab segmented control: Day · Week · Month · Year.
class DiaryCalendarLensBar extends StatelessWidget {
  const DiaryCalendarLensBar({
    super.key,
    required this.lens,
    required this.onChanged,
  });

  final DiaryCalendarLens lens;
  final ValueChanged<DiaryCalendarLens> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Large text keeps every label readable by wrapping the tabs instead of
        // shrinking them into a fixed track.
        final fits = constraints.maxWidth / 4 >= scaler.scale(14) * 4.2 + 16;
        final segments = [
          for (final value in DiaryCalendarLens.values)
            _LensSegment(
              lens: value,
              selected: value == lens,
              simple: simple,
              onTap: () => onChanged(value),
            ),
        ];
        if (!fits) {
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: segments,
          );
        }
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(
              alpha: context.isDark ? .06 : .04,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [for (final s in segments) Expanded(child: s)]),
        );
      },
    );
  }
}

class _LensSegment extends StatelessWidget {
  const _LensSegment({
    required this.lens,
    required this.selected,
    required this.simple,
    required this.onTap,
  });

  final DiaryCalendarLens lens;
  final bool selected, simple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '${lens.label} pages',
      hint: lens.hint,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('calendar-lens-${lens.name}'),
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(10),
          child: CustomPaint(
            painter: selected
                ? DiaryPaperStamp(
                    paper: colors.surface,
                    ink: colors.primary,
                    shadowColor: colors.shadow,
                    variant: lens.index,
                    edgeScale: simple ? 0 : .4,
                    shadow: !simple,
                  )
                : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Center(
                  child: Text(
                    lens.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The verb on every tappable period: "+ Add" until it has writing, then
/// "Open". Icon and wording carry the state without relying on color.
class DiaryPeriodAction extends StatelessWidget {
  const DiaryPeriodAction({
    super.key,
    required this.kind,
    required this.saved,
    this.enabled = true,
  });

  final DiaryPeriodKind kind;
  final bool saved, enabled;

  static String label(DiaryPeriodKind kind, bool saved) =>
      '${saved ? 'Open' : 'Add'} ${kind.name}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = enabled
        ? colors.primary
        : colors.onSurfaceVariant.withValues(alpha: .5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          !enabled
              ? Icons.schedule_rounded
              : saved
              ? Icons.edit_note_rounded
              : Icons.add_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            enabled ? label(kind, saved) : 'Not yet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Twelve month cards, each with a dot portrait of the days written.
class DiaryCalendarMonths extends StatelessWidget {
  const DiaryCalendarMonths({
    super.key,
    required this.year,
    required this.lastDate,
    required this.marks,
    required this.selected,
    required this.inset,
    required this.onSelect,
  });

  final int year;
  final DateTime lastDate;
  final DiaryCalendarMarks marks;
  final DiaryPeriod? selected;
  final double inset;
  final ValueChanged<DiaryPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = math.max(148.0, scaler.scale(14) * 10);
        final columns = ((constraints.maxWidth - inset * 2) / tileWidth)
            .floor()
            .clamp(1, 4);
        final rows = (12 / columns).ceil();
        return ListView.builder(
          key: ValueKey('calendar-months-$year'),
          padding: EdgeInsets.fromLTRB(inset, 12, inset, 32),
          itemCount: rows,
          itemBuilder: (context, row) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < columns; column++)
                  Expanded(
                    child: row * columns + column < 12
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: _MonthTile(
                              period: DiaryPeriod.month(
                                year,
                                row * columns + column + 1,
                              ),
                              lastDate: lastDate,
                              marks: marks,
                              selected: selected,
                              onSelect: onSelect,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.period,
    required this.lastDate,
    required this.marks,
    required this.selected,
    required this.onSelect,
  });

  final DiaryPeriod period;
  final DateTime lastDate;
  final DiaryCalendarMarks marks;
  final DiaryPeriod? selected;
  final ValueChanged<DiaryPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final locale = Localizations.localeOf(context).toString();
    final started = period.hasStarted(lastDate);
    final saved = marks.hasPage(period);
    final current = period.isCurrent(lastDate);
    final count = marks.daysInMonth(period.year, period.month);
    final isSelected = selected == period;
    final name = TimeHelper.format(
      period.calendarDate,
      pattern: TimeFormat.month,
      locale: locale,
    );
    final action = DiaryPeriodAction.label(period.kind, saved);
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: -.3,
                    color: started
                        ? (saved || current ? colors.primary : colors.onSurface)
                        : colors.onSurfaceVariant.withValues(alpha: .5),
                  ),
                ),
              ),
              if (count > 0)
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    color: colors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: CustomPaint(
              painter: _MonthDotsPainter(
                states: _dayStates(period.year, period.month, lastDate, marks),
                lead: DateTime(period.year, period.month).weekday - 1,
                ink: colors.primary,
                faint: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          DiaryPeriodAction(kind: period.kind, saved: saved, enabled: started),
        ],
      ),
    );
    return Semantics(
      key: ValueKey('calendar-month-tile-${period.key}'),
      button: started,
      enabled: started,
      selected: isSelected,
      label: [
        started ? action : 'Not started',
        period.label(locale),
        '${plural(count, 'day')} written',
      ].join(', '),
      onTap: started ? () => onSelect(period) : null,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('calendar-period-${period.key}'),
          onTap: started ? () => onSelect(period) : null,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: saved
                ? DiaryPaperStamp(
                    paper: colors.primaryContainer,
                    ink: colors.primary,
                    shadowColor: colors.shadow,
                    variant: period.month,
                    edgeScale: simple ? 0 : .45,
                    shadow: !simple,
                  )
                : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: saved && !isSelected
                    ? null
                    : Border.all(
                        width: isSelected ? 1.6 : 1,
                        color: isSelected
                            ? colors.primary
                            : colors.outlineVariant.withValues(
                                alpha: started ? .7 : .3,
                              ),
                      ),
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

/// 0 = no day, 1 = past empty day, 2 = written, 3 = future, 4 = today empty,
/// 5 = today written.
List<int> _dayStates(
  int year,
  int month,
  DateTime lastDate,
  DiaryCalendarMarks marks,
) {
  final days = DateTime(year, month + 1, 0).day;
  return [
    for (var day = 1; day <= days; day++)
      () {
        final date = DateTime(year, month, day);
        final today = date == lastDate;
        if (date.isAfter(lastDate)) return 3;
        final written = marks.hasEntry(date);
        if (today) return written ? 5 : 4;
        return written ? 2 : 1;
      }(),
  ];
}

class _MonthDotsPainter extends CustomPainter {
  const _MonthDotsPainter({
    required this.states,
    required this.lead,
    required this.ink,
    required this.faint,
  });

  final List<int> states;
  final int lead;
  final Color ink, faint;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / 7, size.height / 6);
    final left = (size.width - cell * 7) / 2;
    final r = cell * .36;
    final written = Paint()..color = ink;
    final empty = Paint()..color = faint.withValues(alpha: .2);
    final future = Paint()..color = faint.withValues(alpha: .08);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = ink;
    for (var i = 0; i < states.length; i++) {
      final slot = i + lead;
      final center = Offset(
        left + (slot % 7 + .5) * cell,
        (slot ~/ 7 + .5) * cell,
      );
      switch (states[i]) {
        case 1:
          canvas.drawCircle(center, r * .5, empty);
        case 2:
          canvas.drawCircle(center, r, written);
        case 3:
          canvas.drawCircle(center, r * .4, future);
        case 4:
          canvas.drawCircle(center, r, ring);
        case 5:
          canvas.drawCircle(center, r, written);
          canvas.drawCircle(center, r + 1.8, ring);
      }
    }
  }

  @override
  bool shouldRepaint(_MonthDotsPainter oldDelegate) =>
      lead != oldDelegate.lead ||
      ink != oldDelegate.ink ||
      faint != oldDelegate.faint ||
      !listEquals(states, oldDelegate.states);
}

/// The year as a single page: a 12 × 31 ribbon of days, totals, and one
/// clear action for the year's own page.
class DiaryCalendarYearOverview extends StatelessWidget {
  const DiaryCalendarYearOverview({
    super.key,
    required this.year,
    required this.lastDate,
    required this.marks,
    required this.selected,
    required this.inset,
    required this.onSelect,
  });

  final int year;
  final DateTime lastDate;
  final DiaryCalendarMarks marks;
  final DiaryPeriod? selected;
  final double inset;
  final ValueChanged<DiaryPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final locale = Localizations.localeOf(context).toString();
    final period = DiaryPeriod.year(year);
    final saved = marks.hasPage(period);
    final action = DiaryPeriodAction.label(period.kind, saved);
    final days = marks.daysInYear(year);
    final stats = [
      (marks.daysInYear(year), 'day'),
      (marks.weeksInYear(year), 'week'),
      (marks.monthsInYear(year), 'month'),
    ];
    final button = Semantics(
      label: '$action, ${period.label(locale)}',
      button: true,
      excludeSemantics: true,
      onTap: () => onSelect(period),
      child: saved
          ? FilledButton.tonalIcon(
              key: ValueKey('calendar-period-${period.key}'),
              style: FilledButton.styleFrom(minimumSize: const Size(44, 52)),
              onPressed: () => onSelect(period),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(action),
            )
          : FilledButton.icon(
              key: ValueKey('calendar-period-${period.key}'),
              style: FilledButton.styleFrom(minimumSize: const Size(44, 52)),
              onPressed: () => onSelect(period),
              icon: const Icon(Icons.add_rounded),
              label: Text(action),
            ),
    );
    return ListView(
      key: ValueKey('calendar-year-overview-$year'),
      padding: EdgeInsets.fromLTRB(inset + 4, 16, inset + 4, 32),
      children: [
        CustomPaint(
          painter: DiaryPaperStamp(
            paper: saved ? colors.primaryContainer : colors.surface,
            ink: colors.primary,
            shadowColor: colors.shadow,
            variant: year,
            edgeScale: simple ? 0 : .6,
            shadow: !simple,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  saved ? 'YEAR PAGE · WRITTEN' : 'YEAR PAGE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$year',
                  style: TextStyle(
                    fontSize: 56,
                    height: 1.1,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -2,
                    color: colors.primary,
                  ),
                ),
                if (marks.heading(period) case final heading?)
                  Text(
                    heading,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: colors.onSurface.withValues(alpha: .8),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    for (final (count, noun) in stats)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$noun${count == 1 ? '' : 's'} written',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: '${plural(days, 'day')} written in $year',
                  excludeSemantics: true,
                  child: _YearRibbon(
                    year: year,
                    lastDate: lastDate,
                    marks: marks,
                  ),
                ),
                const SizedBox(height: 20),
                button,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _YearRibbon extends StatelessWidget {
  const _YearRibbon({
    required this.year,
    required this.lastDate,
    required this.marks,
  });

  final int year;
  final DateTime lastDate;
  final DiaryCalendarMarks marks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6);
    final labelWidth = scaler.scale(11) * 1.6 + 6;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - labelWidth) / 31;
        final rowHeight = math.max(cell, scaler.scale(11) * 1.3);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Column(
                children: [
                  for (var month = 1; month <= 12; month++)
                    SizedBox(
                      height: rowHeight,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          TimeHelper.format(
                            DateTime(year, month),
                            pattern: 'MMMMM',
                            locale: locale,
                          ),
                          textScaler: scaler,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SizedBox(
                height: rowHeight * 12,
                child: CustomPaint(
                  painter: _YearRibbonPainter(
                    states: [
                      for (var month = 1; month <= 12; month++)
                        _dayStates(year, month, lastDate, marks),
                    ],
                    rowHeight: rowHeight,
                    ink: colors.primary,
                    faint: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _YearRibbonPainter extends CustomPainter {
  const _YearRibbonPainter({
    required this.states,
    required this.rowHeight,
    required this.ink,
    required this.faint,
  });

  final List<List<int>> states;
  final double rowHeight;
  final Color ink, faint;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 31;
    final r = math.min(cell, rowHeight) * .34;
    final written = Paint()..color = ink;
    final empty = Paint()..color = faint.withValues(alpha: .18);
    final future = Paint()..color = faint.withValues(alpha: .07);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = ink;
    for (var month = 0; month < states.length; month++) {
      final row = states[month];
      final y = (month + .5) * rowHeight;
      for (var day = 0; day < row.length; day++) {
        final center = Offset((day + .5) * cell, y);
        switch (row[day]) {
          case 1:
            canvas.drawCircle(center, r * .55, empty);
          case 2:
            canvas.drawCircle(center, r, written);
          case 3:
            canvas.drawCircle(center, r * .45, future);
          case 4:
            canvas.drawCircle(center, r + .6, ring);
          case 5:
            canvas.drawCircle(center, r, written);
            canvas.drawCircle(center, r + 1.8, ring);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_YearRibbonPainter oldDelegate) {
    if (rowHeight != oldDelegate.rowHeight ||
        ink != oldDelegate.ink ||
        faint != oldDelegate.faint ||
        states.length != oldDelegate.states.length) {
      return true;
    }
    for (var i = 0; i < states.length; i++) {
      if (!listEquals(states[i], oldDelegate.states[i])) return true;
    }
    return false;
  }
}

/// ISO-8601 week number of the week starting on [monday].
int isoWeekNumber(DateTime monday) {
  final thursday = TimeHelper.addDays(monday, 3);
  return TimeHelper.daysBetween(DateTime(thursday.year), thursday) ~/ 7 + 1;
}

/// A week as its own page: number, range and title on top, then seven day
/// pips that show at a glance which days were written and how they felt.
class DiaryCalendarWeekCard extends StatelessWidget {
  const DiaryCalendarWeekCard({
    super.key,
    required this.monday,
    required this.month,
    required this.lastDate,
    required this.marks,
    required this.selected,
    required this.onSelect,
  });

  final DateTime monday, month, lastDate;
  final DiaryCalendarMarks marks;
  final DiaryPeriod? selected;
  final ValueChanged<DiaryPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final locale = Localizations.localeOf(context).toString();
    final period = DiaryPeriod.week(DiaryPeriod.fromComponents(monday).start);
    final sunday = TimeHelper.addDays(monday, 6);
    final saved = marks.hasPage(period);
    final heading = marks.heading(period);
    final current = period.isCurrent(lastDate);
    final isSelected = selected == period;
    final week = isoWeekNumber(monday);
    final elapsed = math.min(7, TimeHelper.daysBetween(monday, lastDate) + 1);
    final count = marks.daysInRange(monday, elapsed);
    final range =
        '${TimeHelper.format(monday, pattern: TimeFormat.localizedMonthDay, locale: locale)} – '
        '${TimeHelper.format(sunday, pattern: sunday.month == monday.month ? 'd' : TimeFormat.localizedMonthDay, locale: locale)}';
    final action = DiaryPeriodAction.label(period.kind, saved);
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    current ? 'WEEK $week · THIS WEEK' : 'WEEK $week',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w600,
                      color: current ? colors.primary : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    range,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.3,
                    ),
                  ),
                ],
              ),
              DiaryPeriodAction(kind: period.kind, saved: saved),
            ],
          ),
          if (heading != null) ...[
            const SizedBox(height: 6),
            Text(
              heading,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: colors.onSurface.withValues(alpha: .8),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              for (var day = 0; day < 7; day++)
                Expanded(
                  child: _WeekPip(
                    date: TimeHelper.addDays(monday, day),
                    month: month,
                    lastDate: lastDate,
                    marks: marks,
                    locale: locale,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _WeekMeter(written: count, elapsed: elapsed),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: isSelected,
      label: [
        action,
        'Week $week',
        period.label(locale),
        '${plural(count, 'day')} written',
        if (heading != null) 'titled $heading',
        if (current) 'This week',
      ].join(', '),
      onTap: () => onSelect(period),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('calendar-period-${period.key}'),
          onTap: () => onSelect(period),
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(18),
          child: CustomPaint(
            painter: saved
                ? DiaryPaperStamp(
                    paper: colors.primaryContainer,
                    ink: colors.primary,
                    shadowColor: colors.shadow,
                    variant: week,
                    edgeScale: simple ? 0 : .45,
                    shadow: !simple,
                  )
                : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: saved
                    ? null
                    : colors.onSurface.withValues(
                        alpha: context.isDark ? .03 : .015,
                      ),
                border: saved && !isSelected && !current
                    ? null
                    : Border.all(
                        width: isSelected ? 1.6 : 1,
                        color: isSelected
                            ? colors.primary
                            : current
                            ? colors.primary.withValues(alpha: .45)
                            : colors.outlineVariant.withValues(alpha: .7),
                      ),
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekPip extends StatelessWidget {
  const _WeekPip({
    required this.date,
    required this.month,
    required this.lastDate,
    required this.marks,
    required this.locale,
  });

  final DateTime date, month, lastDate;
  final DiaryCalendarMarks marks;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final future = date.isAfter(lastDate);
    final today = date == lastDate;
    final written = !future && marks.hasEntry(date);
    final mood = future ? null : marks.mood(date);
    // Days from the neighbouring month stay visible but step back.
    final outside = date.month != month.month;
    final textColor = written
        ? colors.onPrimary
        : future
        ? colors.onSurfaceVariant.withValues(alpha: .35)
        : today
        ? colors.primary
        : colors.onSurfaceVariant;
    final pip = AspectRatio(
      aspectRatio: 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: written ? colors.primary : null,
                border: today
                    ? Border.all(
                        color: written
                            ? colors.primaryContainer
                            : colors.primary,
                        width: written ? 2.5 : 1.6,
                        strokeAlign: BorderSide.strokeAlignInside,
                      )
                    : future || written
                    ? null
                    : Border.all(
                        color: colors.outlineVariant.withValues(alpha: .8),
                      ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: written || today
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (mood != null)
            Positioned(
              right: -5,
              bottom: -5,
              child: Text(
                mood.emoji,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1,
                  fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji'],
                ),
              ),
            ),
        ],
      ),
    );
    return Opacity(
      opacity: outside ? .55 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            TimeHelper.format(date, pattern: 'EEEEE', locale: locale),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: today ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 38),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: pip,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seven short segments, one per day, filled for written days.
class _WeekMeter extends StatelessWidget {
  const _WeekMeter({required this.written, required this.elapsed});
  final int written, elapsed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Flexible(
          flex: 3,
          child: Text(
            elapsed == 0
                ? 'Not started'
                : '$written of $elapsed ${elapsed == 1 ? 'day' : 'days'} written',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: colors.onSurfaceVariant.withValues(alpha: .14),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: (written / 7).clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: colors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
