import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/rendering_policy.dart';
import '../features/diary/application/diary_reader_day.dart';
import 'bottom_navbar.dart';

/// Asks the shell to slide its bottom bar away (or back) for the page that
/// dispatched it. Pages only report changes, so this stays cheap to send.
class BottomNavbarVisibilityNotification extends Notification {
  const BottomNavbarVisibilityNotification({required this.hidden});
  final bool hidden;
}

class WritingShell extends ConsumerStatefulWidget {
  const WritingShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  static const _paths = ['/diary', '/notes', '/more'];

  /// Tab roots where the floating bar can slide away while reading.
  /// The app's home is the diary reader too.
  static const hidingLocations = {'/', '/diary', '/notes'};

  static int selectedTabFor(String location) => location.startsWith('/notes')
      ? 1
      : location == '/more' || location.startsWith('/settings')
      ? 2
      : 0;

  @override
  ConsumerState<WritingShell> createState() => _WritingShellState();
}

class _WritingShellState extends ConsumerState<WritingShell> {
  /// The location whose page hid the bar. Pages pushed above it within the
  /// same tab keep the request; another tab's pages start with the bar shown.
  String? _hiddenAt;

  @override
  void didUpdateWidget(WritingShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (WritingShell.selectedTabFor(oldWidget.location) !=
        WritingShell.selectedTabFor(widget.location)) {
      _hiddenAt = null;
    }
  }

  bool _visibilityChanged(BottomNavbarVisibilityNotification notification) {
    final hiddenAt = notification.hidden ? widget.location : null;
    if (hiddenAt == _hiddenAt) return true;
    // Scroll metrics can report during layout; rebuild after that frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _hiddenAt = hiddenAt;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() => _hiddenAt = hiddenAt);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final focusedDiary =
        location == '/diary/search' ||
        location.startsWith('/diary/calendar/') ||
        (location.startsWith('/diary/') &&
            (location.endsWith('/title') || location.endsWith('/talk'))) ||
        (location.startsWith('/diary/') && location.contains('/entries/'));
    final showBar =
        !focusedDiary &&
        !location.startsWith('/notes/') &&
        MediaQuery.viewInsetsOf(context).bottom <= 0;
    final canHide = WritingShell.hidingLocations.contains(location);
    final hidden = canHide && _hiddenAt == location;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      // The bar floats over every tab, so pages keep one body size: hiding or
      // showing it only translates the bar and never relayouts the page.
      extendBody: true,
      body: NotificationListener<BottomNavbarVisibilityNotification>(
        onNotification: _visibilityChanged,
        child: widget.child,
      ),
      bottomNavigationBar: showBar
          ? _SlidingNavbar(
              hidden: hidden,
              child: RedkeepBottomNavbar(
                selectedIndex: WritingShell.selectedTabFor(location),
                onSelected: (index) {
                  // The diary tab opens today, as the reader's own address.
                  if (index == 0) {
                    ref.read(diaryReaderDayProvider.notifier).showToday();
                  }
                  context.go(WritingShell._paths[index]);
                },
              ),
            )
          : null,
    );
  }
}

class _SlidingNavbar extends StatelessWidget {
  const _SlidingNavbar({required this.hidden, required this.child});
  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: AnimatedSlide(
          offset: hidden ? const Offset(0, 1.1) : Offset.zero,
          duration: policy.animate
              ? Duration(milliseconds: hidden ? 220 : 260)
              : Duration.zero,
          curve: hidden ? Curves.easeInCubic : Curves.easeOutCubic,
          // The bar's shadows use blurs; slide its cached layer instead of
          // repainting it on every frame of the move.
          child: RepaintBoundary(
            key: const ValueKey('bottom-navbar-slide'),
            child: child,
          ),
        ),
      ),
    );
  }
}
