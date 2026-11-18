import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/directional_drag.dart';
import '../core/presentation/rendering_policy.dart';
import '../features/diary/presentation/diary_day_page.dart';
import '../features/notes/presentation/notes_list_page.dart';
import 'more_page.dart';
import 'writing_shell.dart';

/// The tab roots, in bar and swipe order.
const mainTabLocations = ['/diary', '/notes', '/more'];

/// Tells the shell which tab the pager shows, and whether that tab has sent
/// the bar away. Sent only when either changes.
class MainTabNotification extends Notification {
  const MainTabNotification({required this.tab, required this.hidden});
  final int tab;
  final bool hidden;
}

/// Whether a page lets the pager take a swipe towards the next tab
/// ([forward]) or the previous one. Read only when a swipe begins.
typedef MainTabSwipeGate = bool Function(bool forward);

/// Handles the system back on a tab after the first, before the pager
/// returns to the diary. Returns whether it used the back.
typedef MainTabBack = bool Function();

/// Placed above each tab's page. A page that has swipes of its own registers
/// a [MainTabSwipeGate] here, and asks it which way is forward.
class MainTabScope extends InheritedWidget {
  const MainTabScope._(
    this._pager, {
    required this.index,
    required super.child,
  });

  final int index;
  final _MainTabsState _pager;

  /// Looks up the scope without depending on it; it never changes.
  static MainTabScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MainTabScope>();

  bool get hasNext => index < mainTabLocations.length - 1;

  /// Whether a drag of [dx] heads to the next tab.
  bool isForward(double dx) => _pager._isForward(dx);

  set gate(MainTabSwipeGate? gate) => _pager._gates[index] = gate;
  MainTabSwipeGate? get gate => _pager._gates[index];

  set back(MainTabBack? back) => _pager._backs[index] = back;
  MainTabBack? get back => _pager._backs[index];

  @override
  bool updateShouldNotify(MainTabScope oldWidget) => false;
}

/// Diary, Notes and More side by side. Swiping moves between them like tabs;
/// the address follows once a swipe settles, and a new address slides the
/// pages there.
///
/// The router keeps this as one page across the tab addresses, so each tab
/// keeps its state. A page is built the first time it comes into view, as a
/// tab tap always built it, and kept from then on. Pages off screen are
/// offstage and do not tick, as covered routes did. The pager is not a
/// scrollable: a page's own scrolling, or a request to reveal something in
/// it, never moves it.
class MainTabs extends StatefulWidget {
  const MainTabs({super.key, required this.index});
  final int index;

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs>
    with SingleTickerProviderStateMixin {
  static const _count = 3;
  static const _pages = <Widget>[DiaryDayPage(), NotesListPage(), MorePage()];
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 32,
  );

  /// Pages per second that make a lifted finger finish the swipe.
  static const _flingPages = .6;

  /// The page shown, fractional mid-swipe.
  late final _position = AnimationController.unbounded(
    vsync: this,
    value: widget.index.toDouble(),
  )..addListener(_moved);
  late final _built = [for (var i = 0; i < _count; i++) i == widget.index];
  final _gates = List<MainTabSwipeGate?>.filled(_count, null);
  final _backs = List<MainTabBack?>.filled(_count, null);
  final _hidden = List<bool>.filled(_count, false);
  late final _visible = [
    for (var i = 0; i < _count; i++) ValueNotifier(i == widget.index),
  ];
  late final _offsets = [
    for (var i = 0; i < _count; i++) _position.drive(_PageOffset(i, this)),
  ];
  double _width = 1;

  /// Where a slide asked for by the address is headed. The bar shows it
  /// throughout, not the tabs passed on the way.
  int? _target;
  bool _dragging = false;
  bool _rtl = false;
  late int _reportedTab = widget.index;
  bool _reportedHidden = false;

  @override
  void didUpdateWidget(MainTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index || _dragging) return;
    if (_position.value == widget.index && _target == null) return;
    _moveTo(widget.index);
  }

  @override
  void dispose() {
    _position.dispose();
    for (final visible in _visible) {
      visible.dispose();
    }
    super.dispose();
  }

  int get _current => _position.value.round();
  int get _displayed => _target ?? _current;
  bool _isForward(double dx) => _rtl ? dx > 0 : dx < 0;

  /// Next to its neighbours the slide reads as a swipe; further, or with
  /// motion reduced, or under another page, the pager jumps.
  void _moveTo(int index) {
    final animate =
        (_position.value - index).abs() <= 1 &&
        RenderingPolicyScope.of(context).animate &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (!animate) {
      _target = null;
      _position.value = index.toDouble();
      _settled();
      return;
    }
    _target = index;
    _report();
    _position
        .animateTo(
          index.toDouble(),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        )
        .then((_) => _settled());
  }

  /// Springs to [page] from the finger's speed, in pages per second.
  void _settleAt(int page, double velocity) {
    if (!RenderingPolicyScope.of(context).animate) {
      _position.value = page.toDouble();
      _settled();
      return;
    }
    _position
        .animateWith(
          SpringSimulation(
            _spring,
            _position.value,
            page.toDouble(),
            velocity,
            tolerance: const Tolerance(distance: .001, velocity: .01),
          ),
        )
        .then((_) {
          _position.value = page.toDouble();
          _settled();
        });
  }

  void _settled() {
    if (!mounted || _dragging) return;
    _target = null;
    _report();
    final page = _current;
    if (page != widget.index) {
      // A tab's focused field must not keep the keyboard over another tab.
      FocusManager.instance.primaryFocus?.unfocus();
      context.go(mainTabLocations[page]);
    }
  }

  void _moved() {
    final page = _position.value;
    final low = page.floor();
    final high = page.ceil();
    var build = false;
    for (var i = 0; i < _count; i++) {
      final visible = i >= low && i <= high;
      _visible[i].value = visible;
      if (visible && !_built[i]) build = _built[i] = true;
    }
    if (build) setState(() {});
    _report();
  }

  void _report() {
    final tab = _displayed;
    final hidden = _hidden[tab];
    if (tab == _reportedTab && hidden == _reportedHidden) return;
    _reportedTab = tab;
    _reportedHidden = hidden;
    MainTabNotification(tab: tab, hidden: hidden).dispatch(context);
  }

  bool _allows(double dx) {
    final forward = _isForward(dx);
    final page = _current;
    if (forward ? page >= _count - 1 : page <= 0) return false;
    return _gates[page]?.call(forward) ?? true;
  }

  /// A finger catches a sliding pager where it is.
  void _down(DragDownDetails details) {
    if (!_position.isAnimating) return;
    _position.stop();
    _target = null;
  }

  void _start(DragStartDetails details) => _dragging = true;

  void _update(DragUpdateDetails details) {
    final pages = details.primaryDelta! / _width * (_rtl ? 1 : -1);
    _position.value = (_position.value + pages).clamp(0, _count - 1);
  }

  void _end(DragEndDetails details) {
    _dragging = false;
    final velocity = (details.primaryVelocity ?? 0) / _width * (_rtl ? 1 : -1);
    final page = _position.value;
    final target = velocity.abs() < _flingPages
        ? page.round()
        : velocity > 0
        ? page.floor() + 1
        : page.ceil() - 1;
    _settleAt(target.clamp(0, _count - 1), velocity);
  }

  /// The finger let go without swiping, or a page's own gesture won.
  void _cancel() {
    _dragging = false;
    if (_position.value != _current) {
      _settleAt(_current, 0);
    } else if (!_position.isAnimating) {
      _settled();
    }
  }

  bool _pageNavbar(int index, BottomNavbarVisibilityNotification notification) {
    _hidden[index] = notification.hidden;
    _report();
    return true;
  }

  Widget _page(int index) => KeyedSubtree(
    key: ValueKey(index),
    child: ValueListenableBuilder<bool>(
      valueListenable: _visible[index],
      builder: (context, visible, page) => Offstage(
        offstage: !visible,
        child: TickerMode(enabled: visible, child: page!),
      ),
      child: SlideTransition(
        position: _offsets[index],
        transformHitTests: true,
        child: RepaintBoundary(
          child: MainTabScope._(
            this,
            index: index,
            child: NotificationListener<BottomNavbarVisibilityNotification>(
              onNotification: (notification) =>
                  _pageNavbar(index, notification),
              child: _pages[index],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    // Back from Notes or More returns to the diary, as it always has.
    canPop: widget.index == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop || (_backs[_current]?.call() ?? false)) return;
      if (widget.index != 0) context.go(mainTabLocations.first);
    },
    child: DirectionalHorizontalDrag(
      allow: _allows,
      onDown: _down,
      onStart: _start,
      onUpdate: _update,
      onEnd: _end,
      onCancel: _cancel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _rtl = Directionality.of(context) == TextDirection.rtl;
          _width = constraints.maxWidth > 0 ? constraints.maxWidth : 1;
          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < _count; i++)
                  if (_built[i]) _page(i),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// Page [index]'s place, in widths, while the pager shows page `t`.
class _PageOffset extends Animatable<Offset> {
  const _PageOffset(this.index, this.pager);
  final int index;
  final _MainTabsState pager;

  @override
  Offset transform(double t) => Offset((index - t) * (pager._rtl ? -1 : 1), 0);
}
