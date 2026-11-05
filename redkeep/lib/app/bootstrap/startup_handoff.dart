import 'package:flutter/material.dart';

import '../../core/presentation/media_motion.dart';

/// Carries first launch from the startup page into onboarding as one screen.
///
/// Both routes share a page key, so the navigator never plays a transition or
/// drops the startup page. Their identical backgrounds stay still while the
/// new content fades in over the old and the logo moves to its new place.
class StartupHandoff extends StatefulWidget {
  const StartupHandoff({
    super.key,
    required this.child,
    this.animateIn = false,
  });

  final Widget child;

  /// Whether arriving at [child] from another page plays the handoff.
  final bool animateIn;

  static const pageKey = ValueKey('startup-handoff');
  static const duration = Duration(milliseconds: 560);

  @override
  State<StartupHandoff> createState() => _StartupHandoffState();
}

class _StartupHandoffState extends State<StartupHandoff>
    with SingleTickerProviderStateMixin {
  late final _progress = AnimationController(
    vsync: this,
    duration: StartupHandoff.duration,
  )..value = 1;
  // The old content clears before the new arrives, so their text never overlaps.
  late final _exit = CurvedAnimation(
    parent: _progress,
    curve: const Interval(0, .35, curve: Curves.easeIn),
  );
  late final _fade = CurvedAnimation(
    parent: _progress,
    curve: const Interval(.35, 1, curve: Curves.easeOut),
  );
  late final _travel = CurvedAnimation(
    parent: _progress,
    curve: Curves.easeInOutCubic,
  );
  final _logoKeys = <Type, GlobalKey>{};

  Widget? _previous;
  Widget? _logo;
  Rect? _logoStart, _logoEnd;

  GlobalKey _keyFor(Widget page) =>
      _logoKeys.putIfAbsent(page.runtimeType, GlobalKey.new);

  Rect? _rectOf(GlobalKey key) {
    final logo = key.currentContext?.findRenderObject();
    final shell = context.findRenderObject();
    if (logo is! RenderBox || shell is! RenderBox || !logo.hasSize) return null;
    return logo.localToGlobal(Offset.zero, ancestor: shell) & logo.size;
  }

  void _settle() {
    _progress.value = 1;
    _previous = _logo = _logoStart = _logoEnd = null;
  }

  @override
  void didUpdateWidget(StartupHandoff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.runtimeType == widget.child.runtimeType) return;
    _settle();
    if (!widget.animateIn || mediaMotionDisabled(context)) return;
    final key = _keyFor(oldWidget.child);
    final start = _rectOf(key);
    final logo = key.currentWidget;
    _previous = oldWidget.child;
    _progress.value = 0;
    // The logo already on screen is reused, so the flight needs no new decode.
    if (start != null && logo is KeyedSubtree) {
      _logoStart = start;
      _logo = logo.child;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    if (!mounted || _previous == null) return;
    final end = _rectOf(_keyFor(widget.child));
    final start = _logoStart;
    setState(() {
      if (end == null || start == null || start.height == 0) {
        // No logo on the destination layout: the old one fades with its page.
        _logo = _logoStart = null;
      } else {
        // The destination image may not be decoded yet, so only its height and
        // center are reliable. Both are the same artwork, so keep the ratio.
        _logoEnd = Rect.fromCenter(
          center: end.center,
          width: start.width * end.height / start.height,
          height: end.height,
        );
      }
    });
    await _progress.forward().orCancel.catchError((_) {});
    if (mounted) setState(_settle);
  }

  @override
  void dispose() {
    _exit.dispose();
    _fade.dispose();
    _travel.dispose();
    _progress.dispose();
    super.dispose();
  }

  Widget _page(Widget page, {required bool leaving}) => KeyedSubtree(
    key: ValueKey(page.runtimeType),
    child: FadeTransition(
      opacity: leaving ? kAlwaysCompleteAnimation : _fade,
      child: IgnorePointer(
        ignoring: leaving,
        child: ExcludeSemantics(
          excluding: leaving,
          child: _HandoffScope(
            logoKey: _keyFor(page),
            hidden: _logo != null,
            exit: leaving ? _exit : kAlwaysDismissedAnimation,
            child: page,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final start = _logoStart;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_previous case final previous?) _page(previous, leaving: true),
        _page(widget.child, leaving: false),
        if (_logo case final logo? when start != null)
          AnimatedBuilder(
            animation: _travel,
            builder: (context, child) => Positioned.fromRect(
              rect: Rect.lerp(start, _logoEnd ?? start, _travel.value)!,
              child: child!,
            ),
            child: IgnorePointer(child: logo),
          ),
      ],
    );
  }
}

class _HandoffScope extends InheritedWidget {
  const _HandoffScope({
    required this.logoKey,
    required this.hidden,
    required this.exit,
    required super.child,
  });

  final GlobalKey logoKey;
  final bool hidden;
  final Animation<double> exit;

  @override
  bool updateShouldNotify(_HandoffScope oldWidget) =>
      logoKey != oldWidget.logoKey ||
      hidden != oldWidget.hidden ||
      exit != oldWidget.exit;
}

/// Marks a page's logo so [StartupHandoff] can move it between pages.
class StartupHandoffLogo extends StatelessWidget {
  const StartupHandoffLogo({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_HandoffScope>();
    if (scope == null) return child;
    return Opacity(
      opacity: scope.hidden ? 0 : 1,
      child: KeyedSubtree(key: scope.logoKey, child: child),
    );
  }
}

/// Marks content that should clear away early when its page is being replaced.
class StartupHandoffExit extends StatelessWidget {
  const StartupHandoffExit({super.key, required this.child});

  final Widget child;

  static final _slide = Tween(begin: Offset.zero, end: const Offset(0, .15));

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_HandoffScope>();
    if (scope == null) return child;
    return SlideTransition(
      position: _slide.animate(scope.exit),
      child: FadeTransition(
        opacity: ReverseAnimation(scope.exit),
        child: child,
      ),
    );
  }
}
