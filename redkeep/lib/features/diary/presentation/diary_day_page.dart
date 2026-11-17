import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../app/writing_shell.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../application/diary_providers.dart';
import '../application/diary_paper_providers.dart';
import '../application/diary_reader_day.dart';
import '../domain/diary_period.dart';
import '../domain/diary_raven.dart';
import '../domain/diary_timeline.dart';
import 'diary_style.dart';
import 'diary_calendar_curtain.dart';
import 'diary_calendar_page.dart';
import 'diary_header.dart';
import 'diary_scene.dart';
import 'diary_sky.dart';

export '../application/diary_reader_day.dart' show DiaryDaySelection;

/// Opens the reader at `/diary` on [date]. The day is reader state, not part
/// of the route, so the reader keeps one page while its days change.
/// With [push], back returns to the caller.
void openDiaryDay(
  BuildContext context,
  DiaryPeriod date, {
  DiaryDaySelection? selection,
  bool push = false,
}) {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(diaryReaderDayProvider.notifier).show(date, selection: selection);
  final location = AppDestination.diary.location;
  push ? context.push(location) : context.go(location);
}

/// The reader shows [diaryReaderDayProvider]'s day.
class DiaryDayPage extends ConsumerStatefulWidget {
  const DiaryDayPage({super.key});
  @override
  ConsumerState<DiaryDayPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryDayPage>
    with TickerProviderStateMixin {
  DiaryTypography? _paperTypography;
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 310,
    damping: 29,
  );
  static const _pullSpring = SpringDescription(
    mass: 1,
    stiffness: 190,
    damping: 27,
  );

  /// A pull past this fraction of its travel, or a downward fling, opens the
  /// calendar when the finger lifts.
  static const _pullCommit = .2;
  final _outer = ScrollController();
  final _nested = GlobalKey<NestedScrollViewState>();
  late final _turn = AnimationController.unbounded(vsync: this);
  late final _fade = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: 1,
    duration: const Duration(milliseconds: 150),
  );
  late DiaryPeriod _selectedDate = _requestedDate(
    ref.read(diaryReaderDayProvider),
  );
  late DiaryTimeline _timeline = DiaryTimeline(today: _today);
  late DiaryPaperDay _day = _dayFor(_selectedDate);
  late DiaryPaperDay _previous = _dayFor(
    _timeline.neighbor(_selectedDate, -1) ?? _selectedDate,
  );
  DiaryPaperDay? _next;
  DiaryPaperDay? _fadingFrom;
  double _fadingOffset = 0;
  double _cardWidth = 320;
  double _dragDistance = 0;
  int _direction = 1;
  bool _dragging = false;
  bool _settling = false;
  bool _commitTurn = false;
  bool _readingTurn = false;
  bool _immersive = false;

  /// The reader's pull down to the calendar; see [DiaryCalendarCurtain].
  late final _pull = AnimationController(vsync: this);
  final _pointers = <int>{};
  VelocityTracker? _pointerVelocity;
  int? _pullPointer;

  /// Only a touch that began on the resting page may pull it. Swiping down
  /// from the immersive reader restores the page and stops there.
  bool _downAtRest = false;
  DiaryThreadTravel _travel = const DiaryThreadTravel(mid: 600, edge: 637);

  /// A finger lifting the calendar's resting thread back up to the page.
  bool _lifting = false;

  /// Whether the current motion began in the open calendar; see
  /// [DiaryCalendarCurtain.fromCalendar].
  bool _fromCalendar = false;
  bool _calendarShown = false;
  bool _calendarOpen = false;

  /// Where the calendar is headed once no finger holds the pull.
  bool _calendarTarget = false;
  bool _navbarHidden = false;

  DateTime get _today => TimeHelper.dateOnly(ref.read(diaryClockProvider)());
  DiaryPeriod _requestedDate(DiaryReaderDay request) =>
      request.date ?? DiaryPeriod.fromComponents(_today);
  DiaryPaperDay _dayFor(DiaryPeriod date) =>
      ref.read(diaryPaperDayProvider(date));

  bool get _busy => _dragging || _settling;
  bool get _reduced =>
      !RenderingPolicyScope.of(context).animate ||
      RenderingPolicyScope.of(context).simplerEffects;
  double get _controlsHeight =>
      (MediaQuery.textScalerOf(context).scale(13) + 26).clamp(
        44.0,
        double.infinity,
      );
  double get _collapseExtent => _controlsHeight + 36;
  double get _outerOffset => _outer.hasClients ? _outer.offset : 0;
  double get _innerOffset {
    final controller = _nested.currentState?.innerController;
    return controller != null && controller.hasClients ? controller.offset : 0;
  }

  bool get _atTop => _outerOffset.abs() < .5 && _innerOffset.abs() < .5;
  bool get _blocked => _timeline.neighbor(_selectedDate, -_direction) == null;

  /// A fully collapsed header is the immersive reader: the paper fills the
  /// screen, so the shell slides its bottom bar away until the header returns.
  void _outerScrolled() {
    // A little hysteresis: the clamped outer edge can settle a pixel short.
    final immersive = _immersive
        ? _outerOffset > _collapseExtent - 12
        : _outerOffset >= _collapseExtent - .5;
    if (immersive == _immersive) return;
    _immersive = immersive;
    _syncNavbar();
  }

  /// The immersive reader and the calendar both send the bottom bar away.
  /// A pull hides it once letting go would open the calendar, so the bar's
  /// exit says what release will do, and returns it if the finger retreats.
  void _syncNavbar() {
    final calendar = _pullPointer != null
        ? _pull.value >= _pullCommit
        : _lifting
        ? _pull.value > 1 - _pullCommit
        : _calendarTarget;
    final hidden = _immersive || calendar;
    if (hidden == _navbarHidden) return;
    _navbarHidden = hidden;
    BottomNavbarVisibilityNotification(hidden: hidden).dispatch(context);
  }

  @override
  void initState() {
    super.initState();
    _outer.addListener(_outerScrolled);
    _turn.value = 0;
    _fade.addStatusListener((status) {
      if (status == AnimationStatus.completed && _fadingFrom != null) {
        setState(() => _fadingFrom = null);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settling && _reduced) {
      _turn.stop(canceled: false);
      _turn.value = _commitTurn ? 1 : 0;
    }
  }

  /// Days chosen elsewhere (calendar, search, entries) arrive as reader state.
  /// This reader's own turns publish first, so they arrive already selected.
  void _readerDayChanged(DiaryReaderDay? previous, DiaryReaderDay next) {
    final date = _requestedDate(next);
    if (date != _selectedDate ||
        (next.selection != null && next.selection != previous?.selection)) {
      // A day chosen elsewhere (search) lands on its page, not the calendar.
      if (_calendarShown) _dismissCalendar();
      _replaceDate(date, fade: !_calendarShown, publish: false);
    }
  }

  void _replaceDate(
    DiaryPeriod date, {
    bool fade = false,
    bool publish = true,
  }) {
    final crossfade = fade && !_reduced;
    final oldDay = _day;
    final neighbors = [_day, _previous, ?_next];
    DiaryPaperDay findDay(DiaryPeriod value) => neighbors.firstWhere(
      (day) => day.date == value,
      orElse: () => _dayFor(value),
    );
    final oldOffset = _innerOffset;
    // The outer nested controller resets the inner offset while retaining
    // exactly the current header expansion. Jumping the inner one would also
    // collapse the header, even for a short replacement day.
    // Readers covered by another page also follow the day, unlaid out.
    if (_outer.hasClients && _outer.position.hasContentDimensions) {
      _outer.jumpTo(_outerOffset.clamp(0, _collapseExtent));
    }
    setState(() {
      _selectedDate = date;
      _day = findDay(date);
      _previous = findDay(_timeline.neighbor(date, -1) ?? date);
      final next = _timeline.neighbor(date, 1);
      _next = next == null ? null : findDay(next);
      _fadingFrom = crossfade ? oldDay : null;
      _fadingOffset = oldOffset;
    });
    if (ModalRoute.isCurrentOf(context) ?? true) {
      HapticFeedback.selectionClick();
    }
    if (crossfade) _fade.forward(from: 0);
    if (publish) ref.read(diaryReaderDayProvider.notifier).show(date);
  }

  void _selectDate(DiaryPeriod date) {
    if (_busy || _calendarShown || !date.hasStarted(_today)) return;
    final previous = _timeline.neighbor(_selectedDate, -1);
    final next = _timeline.neighbor(_selectedDate, 1);
    if (_atTop && (date == previous || date == next) && !_reduced) {
      _direction = date == previous ? 1 : -1;
      _settle(commit: true);
    } else {
      _replaceDate(date, fade: true);
    }
  }

  void _openCalendar() {
    if (_busy || _calendarShown) return;
    setState(() {
      _calendarShown = true;
      _fromCalendar = false;
    });
    _calendarTarget = true;
    _syncNavbar();
    _afterNextFrame(() => _settlePull(open: true));
  }

  /// Building the calendar or a newly chosen day is the heaviest frame of
  /// the motion. Let it land before the spring starts, so none of the
  /// spring's travel is spent inside that frame.
  void _afterNextFrame(VoidCallback start) {
    final shown = _calendarShown;
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted &&
          _calendarShown == shown &&
          _pullPointer == null &&
          !_lifting) {
        start();
      }
    });
  }

  /// Returns to the reader, on [date] when the calendar chose one. The page
  /// is replaced while hidden, so it rises on the thread already turned.
  void _closeCalendar([DiaryPeriod? date]) {
    if (!_calendarShown || _pullPointer != null || _lifting) return;
    setState(() => _fromCalendar = true);
    if (date != null && date != _selectedDate) {
      _replaceDate(date);
      _calendarTarget = false;
      _syncNavbar();
      setState(() => _calendarOpen = false);
      _afterNextFrame(() => _settlePull(open: false));
    } else {
      _settlePull(open: false);
    }
  }

  void _dismissCalendar() {
    _pull.stop();
    _pull.value = 0;
    _pullPointer = null;
    _lifting = false;
    _calendarTarget = false;
    _syncNavbar();
    setState(() {
      _calendarShown = false;
      _calendarOpen = false;
    });
  }

  /// A downward overscroll at the very top of the resting page starts the
  /// pull. From then on the raw pointer drives it, so the finger can also
  /// push the page back up without the scroll view taking over.
  bool _scrolled(ScrollNotification notification) {
    if (notification is OverscrollNotification &&
        notification.metrics.axis == Axis.vertical &&
        notification.dragDetails != null &&
        notification.overscroll < 0 &&
        _pointers.length == 1 &&
        _downAtRest &&
        _pullPointer == null &&
        !_calendarShown &&
        !_busy &&
        _atTop) {
      _pullPointer = _pointers.single;
      _pull.value = (-notification.overscroll / _travel.mid).clamp(0, 1);
      setState(() {
        _calendarShown = true;
        _fromCalendar = false;
      });
    }
    return false;
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length == 1) {
      _downAtRest = _atTop && !_busy && !_calendarShown;
      _pointerVelocity = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, event.position);
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_pointers.length == 1 && _pointers.contains(event.pointer)) {
      _pointerVelocity?.addPosition(event.timeStamp, event.position);
    }
    if (event.pointer != _pullPointer) return;
    final before = _pull.value;
    _pull.value = (before + event.delta.dy / _travel.mid).clamp(0, 1);
    if ((before < _pullCommit) != (_pull.value < _pullCommit)) {
      HapticFeedback.selectionClick();
      _syncNavbar();
    }
  }

  void _pointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer != _pullPointer) return;
    final velocity = _pointerVelocity?.getVelocity().pixelsPerSecond.dy ?? 0;
    final open =
        velocity > 700 || (_pull.value >= _pullCommit && velocity > -300);
    _settlePull(open: open, velocity: velocity / _travel.mid);
  }

  void _pointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer == _pullPointer) _settlePull(open: false);
    // An accepted Flutter drag can report a pointer cancellation as an end.
    // Catch it before the gesture recognizer so neither surface commits it.
    if (_dragging) _settle(commit: false);
  }

  /// The open calendar's thread, lifted by its tab or the page below it.
  void _liftStart() {
    if (!_calendarOpen || _lifting) return;
    _pull.stop();
    _lifting = true;
    setState(() => _fromCalendar = true);
  }

  void _liftUpdate(double dy) {
    if (!_lifting) return;
    final before = _pull.value;
    _pull.value = (before + dy / _travel.mid).clamp(0, 1);
    final threshold = 1 - _pullCommit;
    if ((before > threshold) != (_pull.value > threshold)) {
      HapticFeedback.selectionClick();
      _syncNavbar();
    }
  }

  void _liftEnd(double velocity) {
    if (!_lifting) return;
    final close =
        velocity < -700 || (_pull.value <= 1 - _pullCommit && velocity < 300);
    _settlePull(open: !close, velocity: velocity / _travel.mid);
  }

  Future<void> _settlePull({required bool open, double velocity = 0}) async {
    _pullPointer = null;
    _lifting = false;
    _calendarTarget = open;
    _syncNavbar();
    final target = open ? 1.0 : 0.0;
    if (_calendarOpen) setState(() => _calendarOpen = false);
    try {
      if (!_reduced && _pull.value != target) {
        await _pull
            .animateWith(
              SpringSimulation(
                _pullSpring,
                _pull.value,
                target,
                velocity.clamp(-8.0, 8.0),
                tolerance: const Tolerance(distance: .001, velocity: .01),
              ),
            )
            .orCancel;
      }
    } on TickerCanceled {
      // Another pull, a dismissal or disposal took over.
      return;
    }
    if (!mounted) return;
    _pull.value = target;
    setState(() {
      _calendarOpen = open;
      _calendarShown = open;
    });
  }

  void _dragStart(DragStartDetails details) {
    if (!_atTop) return;
    _beginDrag();
  }

  void _calendarDragStart() => _beginDrag(reading: !_atTop);

  void _beginDrag({bool reading = false}) {
    if (_busy || _calendarShown) return;
    _dragDistance = 0;
    _fade.value = 1;
    setState(() {
      _dragging = true;
      _readingTurn = reading;
    });
  }

  void _dragUpdate(DragUpdateDetails details) =>
      _updateTurn(details.delta.dx / _cardWidth);

  // Both gestures use fractions of their own surface: one paper width or one
  // calendar tab. They then drive exactly the same turn and spring simulation.
  void _updateTurn(double delta) {
    if (!_dragging) return;
    _dragDistance += delta;
    final direction = _dragDistance < 0 ? -1 : 1;
    if (direction != _direction) setState(() => _direction = direction);
    final progress = _dragDistance.abs();
    _turn.value = _blocked
        ? math.min(.12, progress * .16)
        : progress.clamp(0, 1);
  }

  void _dragEnd(DragEndDetails details) =>
      _endTurn((details.primaryVelocity ?? 0) / _cardWidth);

  void _endTurn(double signedVelocity) {
    if (!_dragging) return;
    final velocity = signedVelocity * _direction;
    final commit =
        !_blocked && (_turn.value >= .25 || velocity >= 700 / _cardWidth);
    _settle(commit: commit, velocity: velocity);
  }

  Future<void> _settle({required bool commit, double velocity = 0}) async {
    if (_settling) return;
    setState(() {
      _dragging = false;
      _settling = true;
      _commitTurn = commit;
    });
    void finishAtEdge() {
      if (commit ? _turn.value >= 1 : _turn.value <= 0) {
        _turn.stop(canceled: false);
      }
    }

    _turn.addListener(finishAtEdge);
    try {
      if (!_reduced && _turn.value != (commit ? 1 : 0)) {
        await _turn
            .animateWith(
              SpringSimulation(
                _spring,
                _turn.value,
                commit ? 1 : 0,
                velocity.clamp(-8.0, 8.0),
                tolerance: const Tolerance(distance: .001, velocity: .001),
              ),
            )
            .orCancel;
      }
      if (!mounted) return;
      if (commit) {
        _replaceDate(
          _timeline.neighbor(_selectedDate, -_direction)!,
          fade: _readingTurn,
        );
      }
      _turn.value = 0;
      setState(() {
        _settling = false;
        _readingTurn = false;
      });
    } on TickerCanceled {
      // Disposing the page never commits an unfinished turn.
    } finally {
      _turn.removeListener(finishAtEdge);
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    _fade.dispose();
    _pull.dispose();
    _outer.removeListener(_outerScrolled);
    _outer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(diaryReaderDayProvider, _readerDayChanged);
    final saved = ref.watch(diaryCalendarDatesProvider);
    if (!_busy) {
      _timeline = DiaryTimeline(today: _today, saved: saved.value ?? const {});
    }
    for (final date in [
      _selectedDate,
      _timeline.neighbor(_selectedDate, -1),
      _timeline.neighbor(_selectedDate, 1),
    ].whereType<DiaryPeriod>()) {
      ref.watch(diaryPaperDayProvider(date));
    }
    if (!_busy) {
      _day = _dayFor(_selectedDate);
      _previous = _dayFor(
        _timeline.neighbor(_selectedDate, -1) ?? _selectedDate,
      );
      final next = _timeline.neighbor(_selectedDate, 1);
      _next = next == null ? null : _dayFor(next);
    }
    final requestedTypography =
        Theme.of(context).extension<DiaryTypography>() ??
        const DiaryTypography();
    if (!_busy || _paperTypography == null) {
      _paperTypography = requestedTypography;
    }
    final top = MediaQuery.paddingOf(context).top;
    // The shell's bar floats over this page; at rest the paper ends above it.
    final navbarInset = MediaQuery.paddingOf(context).bottom;
    final systemInset = MediaQuery.viewPaddingOf(context).bottom;
    // The resting thread hangs below the month; the page travels until it,
    // the thread and the hanging date tab have all left the screen.
    final calendarTop = top + 10 + _controlsHeight;
    final height = MediaQuery.sizeOf(context).height;
    _travel = DiaryThreadTravel.of(
      height: height,
      calendarTop: calendarTop,
      inset: systemInset,
    );
    final calendarActive = _calendarShown || _pullPointer != null;
    final written = saved.value ?? const <DiaryPeriod>{};
    final ravenLetter = diaryRavenLetter(_selectedDate, written);
    final page = Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: diarySkyExtent(context),
          child: IgnorePointer(
            // The sky drifts up a little slower than the header collapses.
            child: AnimatedBuilder(
              animation: _outer,
              child: const DiarySky(),
              builder: (context, sky) => Transform.translate(
                offset: Offset(
                  0,
                  -28 *
                      Curves.easeOutCubic.transform(
                        (_outerOffset / 120).clamp(0, 1),
                      ),
                ),
                child: sky,
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          bottom: false,
          child: ExcludeSemantics(
            excluding: _calendarOpen,
            child: IgnorePointer(
              ignoring: _calendarShown,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: NestedScrollView(
                    key: _nested,
                    controller: _outer,
                    physics: _busy || calendarActive
                        ? const NeverScrollableScrollPhysics()
                        : const ClampingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                    headerSliverBuilder: (context, innerScrolled) => [
                      SliverOverlapAbsorber(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                          context,
                        ),
                        sliver: SliverPersistentHeader(
                          pinned: true,
                          delegate: DiaryHeaderDelegate(
                            topInset: top,
                            selectedDate: _selectedDate,
                            timeline: _timeline,
                            lastDate: _today,
                            controlsHeight: _controlsHeight,
                            onDateChanged: _selectDate,
                            onPickDate: _openCalendar,
                            enabled: !_busy && !calendarActive,
                            turn: _turn,
                            pull: _pull,
                            turnDirection: _direction,
                            turning: _busy,
                            onDayDragStart: _settling
                                ? null
                                : _calendarDragStart,
                            onDayDragUpdate: _settling ? null : _updateTurn,
                            onDayDragEnd: _settling ? null : _endTurn,
                            onDayDragCancel: _dragging
                                ? () => _settle(commit: false)
                                : null,
                            written: written,
                            ravenLetter: ravenLetter,
                          ),
                        ),
                      ),
                    ],
                    body: Builder(
                      builder: (context) => AnimatedBuilder(
                        animation: _pull,
                        builder: (context, scene) => Transform.translate(
                          offset: Offset(
                            0,
                            DiaryCalendarCurtain.midDrop(_pull.value, _travel),
                          ),
                          child: scene,
                        ),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_outer, _turn]),
                          builder: (context, _) => DiaryScene(
                            day: _day,
                            previous: _previous,
                            next: () => _next ?? _day,
                            today: _today,
                            collapse: (_outerOffset / _collapseExtent).clamp(
                              0,
                              1,
                            ),
                            headerHeight: top + 82,
                            collapseExtent: _collapseExtent,
                            navbarInset: navbarInset,
                            systemInset: systemInset,
                            turn: _readingTurn ? 0 : _turn.value.clamp(0, 1),
                            direction: _direction,
                            busy: _busy || calendarActive,
                            blocked: _blocked,
                            reduced: _reduced,
                            fade: _fade,
                            fadingFrom: _fadingFrom,
                            fadingOffset: _fadingOffset,
                            onCardWidth: (width) => _cardWidth = width,
                            onDateChanged: _selectDate,
                            onDragStart: (_dragging || (!_settling && _atTop))
                                ? _dragStart
                                : null,
                            onDragUpdate: (_dragging || (!_settling && _atTop))
                                ? _dragUpdate
                                : null,
                            onDragEnd: (_dragging || (!_settling && _atTop))
                                ? _dragEnd
                                : null,
                            onDragCancel: _dragging
                                ? () => _settle(commit: false)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_calendarShown)
          Positioned.fill(
            child: DiaryCalendarCurtain(
              pull: _pull,
              calendarTop: calendarTop,
              travel: _travel,
              fromCalendar: _fromCalendar,
              onDateChosen: _closeCalendar,
              onReturn: _closeCalendar,
              onLiftStart: _liftStart,
              onLiftUpdate: _liftUpdate,
              onLiftEnd: _liftEnd,
              onLiftCancel: () {
                if (_lifting) _settlePull(open: true);
              },
              written: written,
              ravenLetter: ravenLetter,
              selectedDate: _selectedDate,
              timeline: _timeline,
              lastDate: _today,
              open: _calendarOpen,
              // The bar has left; the calendar's content ends where the
              // resting thread meets the screen's edges.
              calendar: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: MediaQuery.paddingOf(
                    context,
                  ).copyWith(bottom: _travel.bottomInset(height, calendarTop)),
                ),
                child: DiaryCalendarPage(
                  key: const ValueKey('diary-embedded-calendar'),
                  selected: _selectedDate,
                  onSelected: _closeCalendar,
                ),
              ),
            ),
          ),
      ],
    );
    return PopScope(
      canPop: !_calendarShown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeCalendar();
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        onPointerUp: _pointerUp,
        onPointerCancel: _pointerCancel,
        child: NotificationListener<ScrollNotification>(
          onNotification: _scrolled,
          child: DiaryTypographyScope(value: _paperTypography!, child: page),
        ),
      ),
    );
  }
}
