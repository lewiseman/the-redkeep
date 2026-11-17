import '../../../core/presentation/directional_drag.dart';
import 'diary_style.dart';
import '../domain/diary_period.dart';
import '../domain/diary_raven.dart';
import '../domain/diary_timeline.dart';
import 'diary_calendar.dart';

/// A pinned header whose geometry follows the same scroll offset as the feed.
/// Keeping it inside the sliver layout avoids offset feedback as it contracts.
class DiaryHeaderDelegate extends SliverPersistentHeaderDelegate {
  const DiaryHeaderDelegate({
    required this.topInset,
    required this.selectedDate,
    required this.timeline,
    this.lastDate,
    this.enabled = true,
    required this.controlsHeight,
    required this.onDateChanged,
    required this.onPickDate,
    this.turn = kAlwaysDismissedAnimation,
    this.pull = kAlwaysDismissedAnimation,
    this.turnDirection = 1,
    this.turning = false,
    this.onDayDragStart,
    this.onDayDragUpdate,
    this.onDayDragEnd,
    this.onDayDragCancel,
    this.allowDayDrag,
    this.written = const {},
    this.ravenLetter,
  });

  final double topInset;
  final DiaryPeriod selectedDate;
  final DiaryTimeline timeline;
  final DateTime? lastDate;
  final bool enabled;
  final double controlsHeight;
  final ValueChanged<DiaryPeriod> onDateChanged;
  final VoidCallback onPickDate;
  final Animation<double> turn;

  /// The pull towards the calendar. While it runs, the reader draws the
  /// stretched thread itself, so this header's own thread steps aside.
  final Animation<double> pull;
  final int turnDirection;
  final bool turning;
  final VoidCallback? onDayDragStart, onDayDragCancel;
  final ValueChanged<double>? onDayDragUpdate, onDayDragEnd;
  final HorizontalDragGate? allowDayDrag;

  /// Days with writing, and the letter the cord's raven brings, if any.
  final Set<DiaryPeriod> written;
  final DiaryRavenLetter? ravenLetter;

  @override
  double get maxExtent => topInset + controlsHeight + 118;

  @override
  double get minExtent => topInset + 82;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final foreground = AnimatedBuilder(
      animation: Listenable.merge([turn, pull]),
      builder: (context, _) {
        final offset = turning
            ? -turnDirection * turn.value.clamp(0.0, 1.0)
            : 0.0;
        final incoming = timeline.neighbor(selectedDate, -turnDirection);
        final displayDate = offset.abs() >= .5 && incoming != null
            ? incoming
            : selectedDate;
        final pulling = pull.value > 0;
        // The month fades as the header collapses or the thread is pulled.
        final labelOpacity =
            (1 - progress / .45).clamp(0.0, 1.0) *
            (1 - pull.value * 12).clamp(0.0, 1.0);
        return ClipRect(
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(height: topInset + 6),
                  SizedBox(height: controlsHeight * (1 - progress)),
                  SizedBox(height: 4 * (1 - progress)),
                  Opacity(
                    opacity: pulling ? 0 : 1,
                    child: DiaryCalendar(
                      selectedDate: selectedDate,
                      timeline: timeline,
                      lastDate: lastDate,
                      enabled: enabled && !pulling,
                      onDateChanged: onDateChanged,
                      collapseProgress: progress,
                      dayOffset: offset,
                      onDayDragStart: onDayDragStart,
                      onDayDragUpdate: onDayDragUpdate,
                      onDayDragEnd: onDayDragEnd,
                      onDayDragCancel: onDayDragCancel,
                      allowDayDrag: allowDayDrag,
                      written: written,
                      raven: true,
                      ravenLetter: ravenLetter,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: topInset + 2 - 6 * progress,
                left: 0,
                right: 0,
                height: controlsHeight + 8,
                child: Center(
                  child: DiaryMonthPull(
                    key: const ValueKey('diary-date-control'),
                    date: displayDate.calendarDate,
                    opacity: labelOpacity,
                    onTap: enabled && labelOpacity > .5 ? onPickDate : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom:
              -_DiaryHeaderGradient.fadeExtent *
              Curves.easeOutCubic.transform(progress),
          child: IgnorePointer(child: _DiaryHeaderGradient(progress: progress)),
        ),
        foreground,
      ],
    );
  }

  @override
  bool shouldRebuild(DiaryHeaderDelegate oldDelegate) =>
      oldDelegate.topInset != topInset ||
      oldDelegate.selectedDate != selectedDate ||
      oldDelegate.timeline != timeline ||
      oldDelegate.lastDate != lastDate ||
      oldDelegate.enabled != enabled ||
      oldDelegate.turn != turn ||
      oldDelegate.pull != pull ||
      oldDelegate.turnDirection != turnDirection ||
      oldDelegate.turning != turning ||
      oldDelegate.onDayDragStart != onDayDragStart ||
      oldDelegate.onDayDragUpdate != onDayDragUpdate ||
      oldDelegate.onDayDragEnd != onDayDragEnd ||
      oldDelegate.onDayDragCancel != onDayDragCancel ||
      oldDelegate.allowDayDrag != allowDayDrag ||
      oldDelegate.controlsHeight != controlsHeight ||
      oldDelegate.onDateChanged != onDateChanged ||
      oldDelegate.onPickDate != onPickDate ||
      oldDelegate.written != written ||
      oldDelegate.ravenLetter != ravenLetter;
}

/// A tinted surface that blends into the diary below the pinned header.
class _DiaryHeaderGradient extends StatelessWidget {
  const _DiaryHeaderGradient({required this.progress});

  final double progress;
  static const fadeExtent = 56.0;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.expand();

    final color = context.colors.surface;
    final visibility = Curves.easeOutCubic.transform(progress);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tailFraction = fadeExtent * visibility / constraints.maxHeight;
        final coreFraction = 1 - tailFraction;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [
                0,
                coreFraction * .65,
                coreFraction,
                coreFraction + tailFraction * .25,
                coreFraction + tailFraction * .5,
                coreFraction + tailFraction * .75,
                1,
              ],
              colors: [
                color.withValues(alpha: visibility),
                color.withValues(alpha: visibility),
                color.withValues(alpha: .98 * visibility),
                color.withValues(alpha: .84 * visibility),
                color.withValues(alpha: .50 * visibility),
                color.withValues(alpha: .16 * visibility),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The month above the thread, with a small fold beneath it: the cue that the
/// paper can be pulled down to the calendar, and the accessible way there.
class DiaryMonthPull extends StatelessWidget {
  const DiaryMonthPull({
    super.key,
    required this.date,
    required this.onTap,
    this.opacity = 1,
  });

  final DateTime date;
  final VoidCallback? onTap;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final month = MaterialLocalizations.of(context).formatMonthYear(date);
    final ink = context.colors.onSurface.withValues(alpha: .78);
    return IgnorePointer(
      ignoring: onTap == null,
      child: Opacity(
        opacity: opacity,
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: 'Choose date, $month',
          hint: 'Or pull the page down',
          onTap: onTap,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(18),
              splashColor: context.colors.primary.withValues(alpha: .16),
              highlightColor: context.colors.primary.withValues(alpha: .08),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 96),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          month,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            color: ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.1,
                            height: 1.1,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 15,
                          color: ink.withValues(alpha: .5),
                        ),
                      ],
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
