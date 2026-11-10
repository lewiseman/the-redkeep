import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../application/diary_providers.dart';
import '../application/diary_paper_providers.dart';
import '../application/diary_reader_day.dart';
import '../domain/diary_period.dart';
import '../domain/diary_timeline.dart';
import 'diary_style.dart';
import 'diary_artwork.dart';
import 'diary_header.dart';
import 'diary_scene.dart';

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

  @override
  void initState() {
    super.initState();
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
      _replaceDate(date, fade: true, publish: false);
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
    if (_busy || !date.hasStarted(_today)) return;
    final previous = _timeline.neighbor(_selectedDate, -1);
    final next = _timeline.neighbor(_selectedDate, 1);
    if (_atTop && (date == previous || date == next) && !_reduced) {
      _direction = date == previous ? 1 : -1;
      _settle(commit: true);
    } else {
      _replaceDate(date, fade: true);
    }
  }

  Future<void> _pickDate() async {
    if (_busy) return;
    final date = await context.push<DiaryPeriod>(
      diaryCalendarLocation(_selectedDate),
      extra: true,
    );
    if (date != null && mounted) _selectDate(date);
  }

  void _openSearch() {
    if (!_busy) context.push('/diary/search');
  }

  void _dragStart(DragStartDetails details) {
    if (!_atTop) return;
    _beginDrag();
  }

  void _calendarDragStart() => _beginDrag(reading: !_atTop);

  void _beginDrag({bool reading = false}) {
    if (_busy) return;
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
    final width = MediaQuery.sizeOf(context).width;
    final artworkWidth = diaryHeaderArtworkWidth(width);
    final artworkTop = 60 - artworkWidth * .41;
    final page = Stack(
      children: [
        Positioned(
          top: artworkTop,
          left: (width - artworkWidth) / 2,
          width: artworkWidth,
          child: AnimatedBuilder(
            animation: _outer,
            child: RepaintBoundary(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                // Boost only the top edge and month controls, returning to the
                // existing image opacity before reaching the calendar tabs.
                shaderCallback: (_) =>
                    LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, .25, 1],
                      colors: [
                        Colors.white.withValues(
                          alpha: context.isDark ? .94 : .82,
                        ),
                        Colors.white.withValues(
                          alpha: context.isDark ? .94 : .82,
                        ),
                        Colors.white.withValues(
                          alpha: context.isDark ? .68 : .24,
                        ),
                      ],
                    ).createShader(
                      Rect.fromLTWH(
                        0,
                        -artworkTop,
                        artworkWidth,
                        top + _controlsHeight + 20,
                      ),
                    ),
                child: DiaryArtwork(
                  key: const ValueKey('diary-header-artwork'),
                  assetKey: diaryHeaderArtworkKey,
                  width: artworkWidth,
                  color: context.colors.primary,
                  colorBlendMode: BlendMode.color,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                -28 *
                    Curves.easeOutCubic.transform(
                      (_outerOffset / 120).clamp(0, 1),
                    ),
              ),
              child: child,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, .13, .27, .42, 1],
                colors: [
                  context.colors.surface.withValues(alpha: .50),
                  context.colors.surface.withValues(alpha: .094),
                  context.colors.surface.withValues(alpha: .863),
                  context.colors.surface,
                  context.colors.surface,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: NestedScrollView(
                key: _nested,
                controller: _outer,
                physics: _busy
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
                        onSearch: _openSearch,
                        onPickDate: _pickDate,
                        enabled: !_busy,
                        turn: _turn,
                        turnDirection: _direction,
                        turning: _busy,
                        onDayDragStart: _settling ? null : _calendarDragStart,
                        onDayDragUpdate: _settling ? null : _updateTurn,
                        onDayDragEnd: _settling ? null : _endTurn,
                        onDayDragCancel: _dragging
                            ? () => _settle(commit: false)
                            : null,
                      ),
                    ),
                  ),
                ],
                body: Builder(
                  builder: (context) => AnimatedBuilder(
                    animation: Listenable.merge([_outer, _turn]),
                    builder: (context, _) => DiaryScene(
                      day: _day,
                      previous: _previous,
                      next: () => _next ?? _day,
                      today: _today,
                      collapse: (_outerOffset / _collapseExtent).clamp(0, 1),
                      headerHeight: top + 82,
                      collapseExtent: _collapseExtent,
                      turn: _readingTurn ? 0 : _turn.value.clamp(0, 1),
                      direction: _direction,
                      busy: _busy,
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
      ],
    );
    return Listener(
      // An accepted Flutter drag can report a pointer cancellation as an end.
      // Catch it before the gesture recognizer so neither surface commits it.
      onPointerCancel: (_) {
        if (_dragging) _settle(commit: false);
      },
      child: DiaryTypographyScope(value: _paperTypography!, child: page),
    );
  }
}
