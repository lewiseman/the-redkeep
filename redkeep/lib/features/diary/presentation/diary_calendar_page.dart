import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../application/diary_providers.dart';
import '../application/diary_paper_providers.dart';
import '../domain/diary_day_details.dart';
import '../domain/diary_period.dart';
import 'diary_style.dart';
import 'diary_artwork.dart';
import 'diary_calendar_overview.dart';
import 'diary_paper_stamp.dart';
import 'diary_day_page.dart';

DateTime _month(DateTime date) => DateTime(date.year, date.month);
int _monthIndex(DateTime date) => date.year * 12 + date.month - 1;
String _dateKey(DateTime date) => date.toIso8601String();

/// A calendar route returns a civil date, or null when dismissed with Back.
class DiaryCalendarPage extends ConsumerStatefulWidget {
  const DiaryCalendarPage({super.key, this.selected});
  final DiaryPeriod? selected;
  @override
  ConsumerState<DiaryCalendarPage> createState() => _DiaryCalendarPageState();
}

class _DiaryCalendarPageState extends ConsumerState<DiaryCalendarPage> {
  late final PageController _pages;
  late int _year;
  late final DateTime _lastDate;
  late DiaryCalendarLens _lens = DiaryCalendarLens.of(widget.selected?.kind);
  final _yearOffsets = <int, double>{};
  final _yearMonths = <int, DateTime>{};
  final _currentYear = GlobalKey<_CalendarYearState>();
  bool _returning = false;
  (Set<DiaryPeriod>?, Map<DiaryPeriod, DiaryMood>?, Map<DiaryPeriod, String>?)?
  _marksSource;
  DiaryCalendarMarks _marks = DiaryCalendarMarks.empty;

  DateTime get _firstDate => DateTime(1);
  DateTime get _selectedDate {
    final selected = widget.selected;
    final value = selected == null
        ? _lastDate
        : DateTime(selected.year, selected.month, selected.day);
    return value.isAfter(_lastDate) ? _lastDate : value;
  }

  /// Only a day selection pins a date; a week or month is outlined instead.
  DateTime? get _selectedDay =>
      widget.selected?.isDay ?? true ? _selectedDate : null;

  bool get _reduced => !RenderingPolicyScope.of(context).animate;

  @override
  void initState() {
    super.initState();
    _lastDate = TimeHelper.dateOnly(ref.read(diaryClockProvider)());
    _year = _selectedDate.year;
    _pages = PageController(initialPage: _year - _firstDate.year);
  }

  void _select(DiaryPeriod date) {
    if (_returning || !date.hasStarted(_lastDate)) {
      return;
    }
    _returning = true;
    if (GoRouterState.of(context).extra == true) {
      context.pop(date);
    } else {
      openDiaryDay(context, date);
    }
  }

  void _showYear(int year, {bool animate = true}) {
    final index = year - _firstDate.year;
    if (_reduced || !animate || (year - _year).abs() > 1) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _today() {
    _yearMonths[_lastDate.year] = _month(_lastDate);
    _yearOffsets[_lastDate.year] = 0;
    _showYear(_lastDate.year, animate: false);
    if (!_lens.isGrid) return;
    final current = _currentYear.currentState;
    if (current != null) {
      current.showMonth(_month(_lastDate));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _currentYear.currentState?.showMonth(_month(_lastDate));
    });
  }

  DiaryCalendarMarks _marksFor(
    Set<DiaryPeriod>? saved,
    Map<DiaryPeriod, DiaryMood>? moods,
    Map<DiaryPeriod, String>? headings,
  ) {
    final source = _marksSource;
    if (source == null ||
        !identical(source.$1, saved) ||
        !identical(source.$2, moods) ||
        !identical(source.$3, headings)) {
      _marksSource = (saved, moods, headings);
      _marks = DiaryCalendarMarks(
        saved ?? const {},
        moods ?? const {},
        headings ?? const {},
      );
    }
    return _marks;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dates = ref.watch(diaryCalendarDatesProvider);
    final moods = ref.watch(diaryCalendarMoodsProvider);
    final headings = ref.watch(diaryCalendarHeadingsProvider);
    final marks = _marksFor(dates.value, moods.value, headings.value);
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            left: 0,
            right: 0,
            height: 420,
            child: IgnorePointer(
              child: Opacity(
                opacity: context.isDark ? .12 : .065,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.transparent],
                  ).createShader(bounds),
                  child: DiaryArtwork(
                    assetKey: 'diary.header',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Seven 44px targets still fit on a 320px-wide phone.
                    final inset = constraints.maxWidth < 350 ? 6.0 : 16.0;
                    return Column(
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: math.max(0, constraints.maxHeight - 140),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _header(context, inset),
                                if (dates.hasError ||
                                    moods.hasError ||
                                    headings.hasError)
                                  TextButton(
                                    onPressed: () {
                                      ref.invalidate(
                                        diaryCalendarDatesProvider,
                                      );
                                      ref.invalidate(
                                        diaryCalendarMoodsProvider,
                                      );
                                      ref.invalidate(
                                        diaryCalendarHeadingsProvider,
                                      );
                                    },
                                    child: const Text(
                                      'Could not load entry markers. Retry',
                                    ),
                                  ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    inset + 4,
                                    8,
                                    inset + 4,
                                    0,
                                  ),
                                  child: DiaryCalendarLensBar(
                                    lens: _lens,
                                    onChanged: (lens) =>
                                        setState(() => _lens = lens),
                                  ),
                                ),
                                if (_lens == DiaryCalendarLens.day)
                                  _weekdays(context, inset),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            key: const ValueKey('calendar-year-pages'),
                            controller: _pages,
                            itemCount: _lastDate.year - _firstDate.year + 1,
                            onPageChanged: (index) =>
                                setState(() => _year = _firstDate.year + index),
                            itemBuilder: (context, index) => DiaryCalendarFadeIn(
                              key: ValueKey(
                                'calendar-lens-page-${_lens.isGrid ? 'grid' : _lens.name}',
                              ),
                              child: _yearPage(
                                _firstDate.year + index,
                                inset,
                                marks,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yearPage(int year, double inset, DiaryCalendarMarks marks) {
    switch (_lens) {
      case DiaryCalendarLens.month:
        return DiaryCalendarMonths(
          year: year,
          lastDate: _lastDate,
          marks: marks,
          selected: widget.selected,
          inset: inset,
          onSelect: _select,
        );
      case DiaryCalendarLens.year:
        return DiaryCalendarYearOverview(
          year: year,
          lastDate: _lastDate,
          marks: marks,
          selected: widget.selected,
          inset: inset,
          onSelect: _select,
        );
      case DiaryCalendarLens.day:
      case DiaryCalendarLens.week:
        final initial = year == _selectedDate.year
            ? _selectedDate
            : year == _lastDate.year
            ? _lastDate
            : DateTime(year, year == _firstDate.year ? _firstDate.month : 1);
        return _CalendarYear(
          key: year == _lastDate.year
              ? _currentYear
              : ValueKey('calendar-year-page-$year'),
          initialMonth: _yearMonths[year] ?? _month(initial),
          firstDate: _firstDate,
          lastDate: _lastDate,
          selectedDay: _selectedDay,
          selected: widget.selected,
          weeks: _lens == DiaryCalendarLens.week,
          inset: inset,
          offset: _yearOffsets[year] ?? 0,
          onOffset: (offset) => _yearOffsets[year] = offset,
          marks: marks,
          onSelect: _select,
        );
    }
  }

  Widget _weekdays(BuildContext context, double inset) {
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 12, inset, 6),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var day = 0; day < 7; day++)
              Expanded(
                child: Text(
                  TimeHelper.format(
                    DateTime(2024, 1, 1 + day),
                    pattern: TimeFormat.shortWeekday,
                    locale: locale,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant.withValues(alpha: .8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The year strip is the app bar: the current year sits at the trailing
  /// edge and earlier years fade away under the back button.
  Widget _header(BuildContext context, double inset) {
    final colors = context.colors;
    final direction = Directionality.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 6, inset, 0),
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: const [Colors.transparent, Colors.white, Colors.white],
              stops: [0, math.min(.45, 120 / bounds.width), 1],
            ).createShader(bounds, textDirection: direction),
            child: _CalendarYearTabs(
              firstYear: _firstDate.year,
              lastYear: _lastDate.year,
              year: _year,
              onSelected: (year) => year == _year && year == _lastDate.year
                  ? _today()
                  : _showYear(year),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface.withValues(alpha: .7),
            ),
            child: BackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/diary'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarYearTabs extends StatefulWidget {
  const _CalendarYearTabs({
    required this.firstYear,
    required this.lastYear,
    required this.year,
    required this.onSelected,
  });

  final int firstYear, lastYear, year;
  final ValueChanged<int> onSelected;

  @override
  State<_CalendarYearTabs> createState() => _CalendarYearTabsState();
}

class _CalendarYearTabsState extends State<_CalendarYearTabs> {
  ScrollController? _scroll;
  double _extent = 76;

  /// The selected year sits at the trailing edge, followed by up to two later
  /// years, so the newest years are never hidden off screen.
  double _offsetFor(int year) =>
      (year - widget.firstYear + math.min(2, widget.lastYear - year)) * _extent;

  void _centerYear() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(_scroll?.hasClients ?? false)) return;
      final offset = _offsetFor(widget.year);
      final reduced = !RenderingPolicyScope.of(context).animate;
      if (reduced) {
        _scroll!.jumpTo(offset);
      } else {
        _scroll!.animateTo(
          offset,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void didUpdateWidget(_CalendarYearTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year) _centerYear();
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final extent = math.max(76.0, scaler.scale(16) * 3 + 24);
    if (_extent != extent) {
      _extent = extent;
      _centerYear();
    }
    _scroll ??= ScrollController(initialScrollOffset: _offsetFor(widget.year));
    return SizedBox(
      height: math.max(52.0, scaler.scale(16) * 1.25 + 24),
      child: LayoutBuilder(
        builder: (context, constraints) => ListView.builder(
          key: const ValueKey('calendar-year-tabs'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemExtent: _extent,
          itemCount: widget.lastYear - widget.firstYear + 1,
          padding: EdgeInsetsDirectional.only(
            start: math.max(0, constraints.maxWidth - _extent - 4),
            end: 4,
          ),
          itemBuilder: (context, index) {
            final year = widget.firstYear + index;
            final selected = year == widget.year;
            final colors = context.colors;
            return Semantics(
              selected: selected,
              button: true,
              label: 'Year $year',
              hint: selected && year == widget.lastYear ? 'Go to today' : null,
              onTap: () => widget.onSelected(year),
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('calendar-year-tab-$year'),
                    onTap: () => widget.onSelected(year),
                    excludeFromSemantics: true,
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      painter: selected
                          ? DiaryPaperStamp(
                              paper: colors.primaryContainer,
                              ink: colors.primary,
                              shadowColor: colors.shadow,
                              edgeScale: .45,
                            )
                          : null,
                      child: Center(
                        child: Text(
                          '$year',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
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
            );
          },
        ),
      ),
    );
  }
}

/// Each horizontal year page retains its own vertical position without keeping
/// an ever-growing collection of offscreen calendar widgets alive.
class _CalendarYear extends StatefulWidget {
  const _CalendarYear({
    super.key,
    required this.initialMonth,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDay,
    required this.selected,
    required this.weeks,
    required this.inset,
    required this.offset,
    required this.onOffset,
    required this.marks,
    required this.onSelect,
  });

  final DateTime initialMonth, firstDate, lastDate;
  final DateTime? selectedDay;
  final DiaryPeriod? selected;
  final bool weeks;
  final double inset, offset;
  final ValueChanged<double> onOffset;
  final DiaryCalendarMarks marks;
  final ValueChanged<DiaryPeriod> onSelect;

  @override
  State<_CalendarYear> createState() => _CalendarYearState();
}

class _CalendarYearState extends State<_CalendarYear> {
  static const _center = ValueKey('calendar-forward-months');
  late DateTime _anchor = widget.initialMonth;
  late final ScrollController _scroll = ScrollController(
    keepScrollOffset: false,
    initialScrollOffset: widget.offset,
  )..addListener(() => widget.onOffset(_scroll.offset));

  void showMonth(DateTime month) {
    final reduced = !RenderingPolicyScope.of(context).animate;
    if (_anchor != month) {
      setState(() => _anchor = month);
      _scroll.jumpTo(0);
    } else if (reduced) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _buildMonth(DateTime month) => _CalendarMonth(
    key: ValueKey('calendar-month-${_dateKey(month)}'),
    month: month,
    firstDate: widget.firstDate,
    lastDate: widget.lastDate,
    selectedDay: widget.selectedDay,
    selected: widget.selected,
    weeks: widget.weeks,
    inset: widget.inset,
    marks: widget.marks,
    onSelect: widget.onSelect,
  );

  @override
  Widget build(BuildContext context) {
    final firstMonth = _anchor.year == widget.firstDate.year
        ? _month(widget.firstDate)
        : DateTime(_anchor.year);
    final lastMonth = _anchor.year == widget.lastDate.year
        ? _month(widget.lastDate)
        : DateTime(_anchor.year, 12);
    return CustomScrollView(
      key: const ValueKey('diary-calendar-scroll'),
      controller: _scroll,
      center: _center,
      slivers: [
        SliverList.builder(
          itemCount: _monthIndex(_anchor) - _monthIndex(firstMonth),
          itemBuilder: (context, index) =>
              _buildMonth(DateTime(_anchor.year, _anchor.month - index - 1)),
        ),
        SliverList.builder(
          key: _center,
          itemCount: _monthIndex(lastMonth) - _monthIndex(_anchor) + 1,
          itemBuilder: (context, index) =>
              _buildMonth(DateTime(_anchor.year, _anchor.month + index)),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _CalendarMonth extends StatelessWidget {
  const _CalendarMonth({
    super.key,
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDay,
    required this.selected,
    required this.weeks,
    required this.inset,
    required this.marks,
    required this.onSelect,
  });

  final DateTime month, firstDate, lastDate;
  final DateTime? selectedDay;
  final DiaryPeriod? selected;
  final bool weeks;
  final double inset;
  final DiaryCalendarMarks marks;
  final ValueChanged<DiaryPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final nextMonth = DateTime(month.year, month.month + 1);
    final end = nextMonth.isAfter(lastDate)
        ? lastDate
        : TimeHelper.addDays(nextMonth, -1);
    final monday = TimeHelper.addDays(month, 1 - month.weekday);
    final weekCount = (TimeHelper.daysBetween(monday, end) + 1 + 6) ~/ 7;
    // The lower inset keeps the sticker's overhang inside the day's tap area.
    final dayHeight =
        math.max(54.0, MediaQuery.textScalerOf(context).scale(16) * 1.25 + 34) +
        16;
    final ownedWeeks = weeks ? _ownedWeeks(end) : const <DateTime>[];
    final written = weeks
        ? ownedWeeks
              .where(
                (start) => marks.hasPage(
                  DiaryPeriod.week(DiaryPeriod.fromComponents(start).start),
                ),
              )
              .length
        : marks.daysInMonth(month.year, month.month);
    final elapsed = weeks ? ownedWeeks.length : end.day;
    final monthPage = DiaryPeriod.month(month.year, month.month);
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (month.month == 1) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 22, 8, 12),
                child: Text(
                  '${month.year}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    color: colors.primary,
                  ),
                ),
              ),
              Divider(color: colors.primary.withValues(alpha: .14), height: 1),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TimeHelper.format(
                            month,
                            pattern: TimeFormat.month,
                            locale: locale,
                          ),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -.9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (marks.hasPage(monthPage))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: Tooltip(
                        message: 'This month has its own page',
                        child: Icon(
                          Icons.bookmark_rounded,
                          size: 20,
                          color: colors.primary,
                          semanticLabel: 'Month page written',
                        ),
                      ),
                    ),
                  _MonthTally(
                    written: written,
                    elapsed: elapsed,
                    unit: weeks ? 'week' : 'day',
                  ),
                ],
              ),
            ),
            if (weeks)
              for (final start in ownedWeeks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DiaryCalendarWeekCard(
                    monday: start,
                    month: month,
                    lastDate: lastDate,
                    marks: marks,
                    selected: selected,
                    onSelect: onSelect,
                  ),
                )
            else
              for (var week = 0; week < weekCount; week++)
                _week(
                  context,
                  TimeHelper.addDays(monday, week * 7),
                  dayHeight,
                  locale,
                ),
          ],
        ),
      ),
    );
  }

  /// Each week is listed once, under the month holding its Thursday (the
  /// ISO rule), so a week spanning two months is never shown twice. The
  /// current week always belongs to the current month.
  List<DateTime> _ownedWeeks(DateTime end) {
    final lastMonth = _month(lastDate);
    final result = <DateTime>[];
    for (
      var start = TimeHelper.addDays(month, 1 - month.weekday);
      !start.isAfter(end);
      start = TimeHelper.addDays(start, 7)
    ) {
      final thursday = _month(TimeHelper.addDays(start, 3));
      final owner = thursday.isAfter(lastMonth) ? lastMonth : thursday;
      if (owner == month && !start.isBefore(firstDate)) result.add(start);
    }
    return result;
  }

  Widget _week(
    BuildContext context,
    DateTime start,
    double dayHeight,
    String locale,
  ) {
    final colors = context.colors;
    final period = DiaryPeriod.week(DiaryPeriod.fromComponents(start).start);
    // Weeks with their own page keep a quiet band in the day lens.
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: marks.hasPage(period)
            ? colors.primary.withValues(alpha: context.isDark ? .09 : .05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: dayHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var day = 0; day < 7; day++)
              Expanded(child: _day(context, TimeHelper.addDays(start, day))),
          ],
        ),
      ),
    );
  }

  Widget _day(BuildContext context, DateTime date) {
    if (date.month != month.month ||
        date.isBefore(firstDate) ||
        date.isAfter(lastDate)) {
      return const SizedBox.expand();
    }
    return _CalendarDate(
      key: ValueKey('calendar-day-${_dateKey(date)}'),
      date: date,
      hasEntry: marks.hasEntry(date),
      mood: marks.mood(date),
      selected: date == selectedDay,
      today: date == lastDate,
      onTap: () => onSelect(DiaryPeriod.fromComponents(date)),
    );
  }
}

/// "9 / 30" with a hairline meter: how much of the month has been written.
class _MonthTally extends StatelessWidget {
  const _MonthTally({
    required this.written,
    required this.elapsed,
    required this.unit,
  });
  final int written, elapsed;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fraction = elapsed == 0 ? 0.0 : (written / elapsed).clamp(0.0, 1.0);
    return Semantics(
      label: '${plural(written, unit)} written of $elapsed',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$written',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: written > 0
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  TextSpan(
                    text: ' / $elapsed',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 64,
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
                      widthFactor: fraction,
                      heightFactor: 1,
                      child: ColoredBox(color: colors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDate extends StatefulWidget {
  const _CalendarDate({
    super.key,
    required this.date,
    required this.hasEntry,
    required this.mood,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime date;
  final bool hasEntry;
  final DiaryMood? mood;
  final bool selected, today;
  final VoidCallback onTap;

  @override
  State<_CalendarDate> createState() => _CalendarDateState();
}

class _CalendarDateState extends State<_CalendarDate> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mood = widget.mood;
    final hasEntry = widget.hasEntry;
    final policy = RenderingPolicyScope.of(context);
    final reduced = !policy.animate;
    final simple = policy.simplerEffects;
    final ink = widget.selected ? colors.primary : colors.onSurface;
    final paper = widget.selected
        ? colors.primaryContainer
        : Color.alphaBlend(
            colors.primary.withValues(alpha: context.isDark ? .06 : .025),
            colors.surfaceContainerLowest,
          );
    final label = [
      MaterialLocalizations.of(context).formatFullDate(widget.date),
      if (widget.today) 'Today',
      hasEntry ? 'Journal entry' : 'No journal entry',
      if (mood != null) '${mood.label} mood',
    ].join(', ');
    final tilt =
        (-8 + (widget.date.day * 13 + widget.date.month * 7) % 5 - 2) *
        math.pi /
        180;
    final dateDiameter = math.max(
      25.0,
      MediaQuery.textScalerOf(context).scale(15) * 1.25 + 4,
    );
    final face = Padding(
      padding: const EdgeInsets.fromLTRB(2, 3, 2, 13),
      child: Center(
        child: AnimatedScale(
          scale: _pressed && !reduced ? .94 : 1,
          duration: reduced
              ? Duration.zero
              : Duration(milliseconds: _pressed ? 70 : 180),
          curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 64),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (hasEntry || widget.selected)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DiaryPaperStamp(
                        paper: paper,
                        ink: ink,
                        shadowColor: colors.shadow,
                        variant: widget.date.day,
                        edgeScale: simple ? 0 : .5,
                        shadow: !simple,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: dateDiameter,
                      height: dateDiameter,
                      decoration: widget.today
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasEntry
                                  ? null
                                  : colors.primary.withValues(alpha: .1),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: .8),
                              ),
                            )
                          : null,
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${widget.date.day}',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: widget.selected || widget.today
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: hasEntry || widget.selected || widget.today
                                ? ink
                                : colors.onSurfaceVariant.withValues(
                                    alpha: .65,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (mood != null)
                  Positioned(
                    bottom: -8,
                    left: 2,
                    width: 22,
                    height: 22,
                    child: Transform.rotate(
                      angle: tilt,
                      child: Text(
                        mood.emoji,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 22,
                          height: 1,
                          shadows: simple
                              ? null
                              : [
                                  Shadow(
                                    color: colors.shadow.withValues(
                                      alpha: context.isDark ? .4 : .2,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                          fontFamilyFallback: const [
                            'Apple Color Emoji',
                            'Noto Color Emoji',
                          ],
                        ),
                      ),
                    ),
                  ),
                if (widget.selected)
                  Positioned(
                    right: -3,
                    top: -6,
                    child: DiaryArtwork(
                      assetKey: 'diary.calendar.pin',
                      width: 20,
                      height: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: label,
      button: true,
      selected: widget.selected,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(10),
          splashColor: colors.primary.withValues(alpha: .08),
          highlightColor: colors.primary.withValues(alpha: .04),
          child: face,
        ),
      ),
    );
  }
}
