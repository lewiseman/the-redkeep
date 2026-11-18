import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/rendering_policy.dart';
import '../features/diary/application/diary_reader_day.dart';
import 'bottom_navbar.dart';
import 'main_tabs.dart';

/// Asks for the bottom bar to slide away (or back) while the tab that
/// dispatched it shows. Pages only report changes, so this stays cheap to
/// send; [MainTabs] keeps each tab's request.
class BottomNavbarVisibilityNotification extends Notification {
  const BottomNavbarVisibilityNotification({required this.hidden});
  final bool hidden;
}

class WritingShell extends ConsumerStatefulWidget {
  const WritingShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  /// Tab roots where the floating bar can slide away while reading, or
  /// while More's journal lies open. The app's home is the diary reader too.
  static const hidingLocations = {'/', '/diary', '/notes', '/more'};

  static const _tabRoots = {'/', ...mainTabLocations};

  static int selectedTabFor(String location) => location.startsWith('/notes')
      ? 1
      : location == '/more' || location.startsWith('/settings')
      ? 2
      : 0;

  @override
  ConsumerState<WritingShell> createState() => _WritingShellState();
}

class _WritingShellState extends ConsumerState<WritingShell> {
  /// The tab the pager shows, which leads the address while a swipe is
  /// under way, and whether that tab has sent the bar away.
  late int _tab = WritingShell.selectedTabFor(widget.location);
  bool _tabHidden = false;

  @override
  void didUpdateWidget(WritingShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final location = widget.location;
    if (location != oldWidget.location &&
        WritingShell._tabRoots.contains(location)) {
      _tab = WritingShell.selectedTabFor(location);
    }
  }

  bool _tabChanged(MainTabNotification notification) {
    if (notification.tab == _tab && notification.hidden == _tabHidden) {
      return true;
    }
    // Pages can report during build or layout; rebuild after that frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _tab = notification.tab;
      _tabHidden = notification.hidden;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {
        _tab = notification.tab;
        _tabHidden = notification.hidden;
      });
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
    final tabRoot = WritingShell._tabRoots.contains(location);
    final hidden =
        WritingShell.hidingLocations.contains(location) && _tabHidden;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      // The bar floats over every tab, so pages keep one body size: hiding or
      // showing it only translates the bar and never relayouts the page.
      extendBody: true,
      body: NotificationListener<MainTabNotification>(
        onNotification: _tabChanged,
        child: widget.child,
      ),
      bottomNavigationBar: showBar
          ? _SlidingNavbar(
              hidden: hidden,
              child: RedkeepBottomNavbar(
                selectedIndex: tabRoot
                    ? _tab
                    : WritingShell.selectedTabFor(location),
                onSelected: (index) {
                  // The diary tab opens today, as the reader's own address.
                  if (index == 0) {
                    ref.read(diaryReaderDayProvider.notifier).showToday();
                  }
                  setState(() => _tab = index);
                  context.go(mainTabLocations[index]);
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
