import '../../../core/presentation/rendering_policy.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/sync_providers.dart';
import 'reset_account_page.dart';
import 'sync_material.dart';

import 'package:sync_wise/sync_wise.dart';

/// The account sheet: your data's flight to the cloud, which
/// device may edit existing entries, and the account's permanent actions.
class SyncAccountSheet extends ConsumerStatefulWidget {
  const SyncAccountSheet({super.key, this.scrollController});

  /// Drives the enclosing draggable sheet: scrolling past the top pulls the
  /// sheet down, and releasing low enough closes it.
  final ScrollController? scrollController;

  /// Opens on the root navigator so the sheet covers the app shell.
  static Future<void> show(BuildContext context) {
    final palette = MorePalette.of(context);
    final reducedMotion = RenderingPolicyScope.of(context).reducedMotion;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: palette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      clipBehavior: Clip.antiAlias,
      sheetAnimationStyle: reducedMotion ? AnimationStyle.noAnimation : null,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .94,
        maxChildSize: .94,
        // Reaching the minimum closes the modal sheet.
        minChildSize: .45,
        snap: true,
        snapAnimationDuration: reducedMotion
            ? const Duration(milliseconds: 1)
            : null,
        builder: (_, controller) =>
            SyncAccountSheet(scrollController: controller),
      ),
    );
  }

  @override
  ConsumerState<SyncAccountSheet> createState() => _SyncAccountSheetState();
}

class _Notice {
  const _Notice(this.text, {this.error = false});
  final String text;
  final bool error;
}

class _SyncAccountSheetState extends ConsumerState<SyncAccountSheet> {
  bool _working = false;
  bool _confirming = false;
  bool _loggingOut = false;
  _Notice? _notice;

  // Messages stay inside the sheet: a snackbar would land behind it.
  void _say(String text, {bool error = false}) {
    if (mounted) setState(() => _notice = _Notice(text, error: error));
  }

  Future<void> _sync() async {
    if (_working || ref.read(syncEngineProvider).isSyncing) return;
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      await ref.read(syncEngineProvider.notifier).syncNow(manual: true);
      if (!mounted) return;
      final error = ref.read(syncEngineProvider).lastError;
      if (error != null) _say(error, error: true);
    } catch (error) {
      _say(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _logout() async {
    if (_working || ref.read(syncEngineProvider).isSyncing) return;
    setState(() {
      _working = true;
      _loggingOut = true;
      _notice = null;
    });
    try {
      await ref.read(syncAuthProvider).signOut();
      if (!mounted) return;
      ref.invalidate(authStateProvider);
      ref.invalidate(syncEngineProvider);
      Navigator.of(context).pop();
    } catch (error) {
      _say(error.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _loggingOut = false;
        });
      }
    }
  }

  Future<void> _reclaim() async {
    if (_working || _confirming || ref.read(syncEngineProvider).isSyncing) {
      return;
    }
    final expected = ref.read(syncEngineProvider).primary;
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: RenderingPolicyScope.of(context).reducedMotion
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Reclaim primary role?'),
        content: const Text(
          'This device will become primary and restore your synced data. '
          'The previous primary will become add-only the next time it syncs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-reclaim-primary'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reclaim'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (confirmed != true || !mounted) return;
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      await ref
          .read(syncEngineProvider.notifier)
          .reclaimPrimary(expectedPrimary: expected);
      if (!mounted) return;
      final result = ref.read(syncEngineProvider);
      if (result.role == SyncDeviceRole.primary) {
        _say(
          result.status == EngineSyncState.idle
              ? 'This device is now primary. Your synced data is restored.'
              : 'This device is now primary. Use Sync now to finish restoring your data.',
        );
      }
    } catch (error) {
      _say(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _openReset(SyncAccount account) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ResetAccountPage(account: account),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncEngineProvider);
    final account = ref.watch(syncAccountProvider);
    final backend = ref.watch(syncBackendProvider);
    final deviceName = ref.watch(syncConfigurationProvider).value?.deviceName;
    final palette = MorePalette.of(context);
    final active = _working || sync.isSyncing;
    final busy = active || account == null;

    return DefaultTextStyle.merge(
      style: TextStyle(color: palette.ink),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: MoreSurface.contentWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Flight(
                    sync: sync,
                    active: active,
                    loggingOut: _loggingOut,
                    backend: backend,
                    deviceName: deviceName,
                  ),
                  _NoticeSlot(notice: _notice),
                  const SizedBox(height: 14),
                  FilledButton(
                    key: const ValueKey('account-sync-now'),
                    onPressed: busy ? null : _sync,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      active
                          ? 'Syncing…'
                          : sync.lastError != null ||
                                sync.status == EngineSyncState.error
                          ? 'Try again'
                          : 'Sync now',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _Eyebrow('Devices'),
                  const SizedBox(height: 10),
                  _Devices(
                    sync: sync,
                    deviceName: deviceName,
                    busy: busy,
                    onReclaim: _reclaim,
                  ),
                  const SizedBox(height: 32),
                  const _Eyebrow('Account'),
                  const SizedBox(height: 10),
                  _Panel(
                    children: [
                      _ActionRow(
                        key: const ValueKey('account-log-out'),
                        enabled: !busy,
                        icon: Icons.logout_rounded,
                        title: 'Log out',
                        subtitle: 'Your data stays on this device.',
                        onTap: _logout,
                      ),
                      Divider(height: 1, indent: 56, color: palette.rule),
                      _ActionRow(
                        key: const ValueKey('reset-account-data'),
                        enabled: !busy,
                        danger: true,
                        icon: Icons.delete_forever_outlined,
                        title: 'Reset account data',
                        subtitle: sync.isSyncing
                            ? 'Wait for sync to finish before resetting account data.'
                            : 'Permanently delete your data and backups.',
                        trailing: Icons.chevron_right_rounded,
                        onTap: () {
                          if (account != null) _openReset(account);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: MorePalette.of(context).muted,
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
      ),
    ),
  );
}

enum _Route { synced, waiting, travelling, offline, broken }

/// Your data's flight between this device and the cloud. A single courier
/// crosses the arc while syncing; at rest a seal at its crest gives the state.
class _Flight extends StatefulWidget {
  const _Flight({
    required this.sync,
    required this.active,
    required this.loggingOut,
    required this.backend,
    required this.deviceName,
  });

  final SyncEngineState sync;
  final bool active;
  final bool loggingOut;
  final SyncBackend backend;
  final String? deviceName;

  static const arcHeight = 132.0;

  static String lastSynced(DateTime? time, DateTime now) {
    if (time == null) return 'Not synced yet';
    final local = time.toLocal();
    final age = now.difference(local);
    if (age.inSeconds < 60) return 'Synced just now';
    if (age.inMinutes < 60) return 'Synced ${age.inMinutes} min ago';
    final clock = DateFormat.jm().format(local);
    if (age.inHours < 24 && local.day == now.day) return 'Synced at $clock';
    if (age.inDays < 7) {
      return 'Synced ${DateFormat.EEEE().format(local)} at $clock';
    }
    return 'Synced ${DateFormat.yMMMd().format(local)}';
  }

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _courier = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _animate = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate =
        RenderingPolicyScope.of(context).animate &&
        !MediaQuery.disableAnimationsOf(context);
    _drive();
  }

  @override
  void didUpdateWidget(_Flight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _drive();
  }

  // Out and back: sync sends this device's changes and brings others home.
  void _drive() {
    if (widget.active && _animate) {
      if (!_courier.isAnimating) _courier.repeat(reverse: true);
    } else if (_courier.isAnimating || _courier.value != 0) {
      _courier
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _courier.dispose();
    super.dispose();
  }

  _Route get _route {
    final sync = widget.sync;
    if (widget.active) return _Route.travelling;
    if (sync.lastError != null || sync.status == EngineSyncState.error) {
      return _Route.broken;
    }
    return switch (sync.status) {
      EngineSyncState.offline ||
      EngineSyncState.unauthenticated => _Route.offline,
      EngineSyncState.pending => _Route.waiting,
      _ => _Route.synced,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final simpler = RenderingPolicyScope.of(context).simplerEffects;
    final route = _route;
    final tone = route == _Route.broken ? colors.error : palette.accent;
    final sync = widget.sync;
    final headline = widget.loggingOut ? 'Logging out' : sync.statusLabel;
    final detail = widget.loggingOut
        ? 'Your data stays on this device.'
        : widget.active
        ? (sync.activity ??
              'Exchanging entries with ${widget.backend.displayName}.')
        : sync.descriptionFor(widget.backend);
    final stamp =
        widget.active || (sync.lastSyncTime == null && route != _Route.synced)
        ? null
        : _Flight.lastSynced(sync.lastSyncTime, DateTime.now());

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.rule),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.cloth, palette.paper],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label:
                  'Syncing between this device and '
                  '${widget.backend.displayName}',
              excludeSemantics: true,
              child: SizedBox(
                height: _Flight.arcHeight,
                child: LayoutBuilder(
                  builder: (context, box) => _arc(
                    box.maxWidth,
                    route: route,
                    tone: tone,
                    simpler: simpler,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ExcludeSemantics(
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _StationLabel(
                        title: widget.deviceName ?? 'This device',
                        caption: 'This device',
                        align: TextAlign.start,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StationLabel(
                        title: widget.backend.displayName,
                        caption: 'Cloud copy',
                        align: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1, color: palette.rule),
            ),
            Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: route == _Route.broken
                          ? colors.error
                          : palette.ink,
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  if (stamp != null) ...[
                    const SizedBox(height: 12),
                    _Stamp(text: stamp),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arc(
    double width, {
    required _Route route,
    required Color tone,
    required bool simpler,
  }) {
    final geometry = _ArcGeometry(Size(width, _Flight.arcHeight));
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final moving = route == _Route.travelling && _animate;
    final (IconData sealIcon, bool sealFilled) = switch (route) {
      _Route.synced => (Icons.check_rounded, true),
      _Route.waiting => (Icons.more_horiz_rounded, false),
      _Route.travelling => (Icons.sync_rounded, false),
      _Route.offline => (Icons.cloud_off_rounded, false),
      _Route.broken => (Icons.priority_high_rounded, true),
    };
    final ends = route == _Route.offline ? palette.muted : tone;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ArcPainter(
                geometry: geometry,
                route: route,
                courier: moving ? _courier : null,
                tone: tone,
                rule: palette.rule,
                glow: !simpler,
              ),
            ),
          ),
        ),
        _station(geometry.start, Icons.smartphone_rounded, ends),
        _station(geometry.end, Icons.cloud_queue_rounded, ends),
        if (!moving)
          Positioned(
            left: geometry.crest.dx - 20,
            top: geometry.crest.dy - 20,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sealFilled ? tone : palette.paper,
                border: sealFilled
                    ? Border.all(color: palette.paper, width: 3)
                    : Border.all(
                        color: (route == _Route.offline ? palette.muted : tone)
                            .withValues(alpha: .6),
                        width: 1.4,
                      ),
                boxShadow: sealFilled && !simpler
                    ? [
                        BoxShadow(
                          color: tone.withValues(alpha: .3),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                sealIcon,
                size: 20,
                color: sealFilled
                    ? (route == _Route.broken
                          ? colors.onError
                          : colors.onPrimary)
                    : (route == _Route.offline ? palette.muted : tone),
              ),
            ),
          ),
      ],
    );
  }

  Widget _station(Offset center, IconData icon, Color tone) {
    final palette = MorePalette.of(context);
    const r = _ArcGeometry.stationRadius;
    return Positioned(
      left: center.dx - r,
      top: center.dy - r,
      child: Container(
        width: r * 2,
        height: r * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.paper,
          shape: BoxShape.circle,
          border: Border.all(color: tone.withValues(alpha: .45), width: 1.2),
        ),
        child: Icon(icon, size: 24, color: tone),
      ),
    );
  }
}

class _StationLabel extends StatelessWidget {
  const _StationLabel({
    required this.title,
    required this.caption,
    required this.align,
  });
  final String title;
  final String caption;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Column(
      crossAxisAlignment: align == TextAlign.start
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            color: palette.ink,
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.3),
        ),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: palette.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: palette.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A shallow arch from this device (bottom left) to the cloud (bottom right).
class _ArcGeometry {
  _ArcGeometry(this.size)
    : start = Offset(stationRadius + 2, size.height - stationRadius - 2),
      end = Offset(
        size.width - stationRadius - 2,
        size.height - stationRadius - 2,
      ),
      control = Offset(size.width / 2, -size.height * .42);

  static const stationRadius = 26.0;

  final Size size;
  final Offset start, end, control;

  Offset get crest => (start + control * 2 + end) / 4;

  Path get path => Path()
    ..moveTo(start.dx, start.dy)
    ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.geometry,
    required this.route,
    required this.courier,
    required this.tone,
    required this.rule,
    required this.glow,
  }) : super(repaint: courier);

  final _ArcGeometry geometry;
  final _Route route;
  final Animation<double>? courier;
  final Color tone;
  final Color rule;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final metric = geometry.path.computeMetrics().first;
    final length = metric.length;
    const margin = _ArcGeometry.stationRadius + 6;
    final from = margin, to = length - margin;
    if (to <= from) return;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;

    void solid(double a, double b, Color color) {
      line.color = color;
      canvas.drawPath(metric.extractPath(a, b), line);
    }

    void dashed(double a, double b, Color color, {double dash = 4}) {
      line.color = color;
      for (var d = a; d < b; d += dash + 5) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, b)), line);
      }
    }

    final crest = length / 2;
    const gap = 24.0;
    switch (route) {
      case _Route.synced:
        solid(from, crest - gap, tone.withValues(alpha: .6));
        solid(crest + gap, to, tone.withValues(alpha: .6));
      case _Route.waiting:
        dashed(from, crest - gap, tone.withValues(alpha: .6));
        dashed(crest + gap, to, tone.withValues(alpha: .6));
      case _Route.offline:
        dashed(from, crest - gap, rule, dash: 2);
        dashed(crest + gap, to, rule, dash: 2);
      case _Route.broken:
        solid(from, crest - gap - 10, tone.withValues(alpha: .55));
        solid(crest + gap + 10, to, tone.withValues(alpha: .55));
      case _Route.travelling:
        final courier = this.courier;
        if (courier == null) {
          dashed(from, crest - gap, tone.withValues(alpha: .5));
          dashed(crest + gap, to, tone.withValues(alpha: .5));
          return;
        }
        dashed(from, to, tone.withValues(alpha: .28), dash: 2);
        final t = Curves.easeInOutSine.transform(courier.value);
        final at = from + (to - from) * t;
        final heading = courier.status == AnimationStatus.reverse ? -1 : 1;
        // A fading wake behind the courier shows its direction.
        const wake = 14;
        for (var i = wake; i > 0; i--) {
          final d = (at - heading * i * 5.0).clamp(from, to);
          final p = metric.getTangentForOffset(d)!.position;
          final f = 1 - i / wake;
          canvas.drawCircle(
            p,
            1 + 2.2 * f,
            Paint()..color = tone.withValues(alpha: .5 * f),
          );
        }
        final head = metric.getTangentForOffset(at)!.position;
        if (glow) {
          canvas.drawCircle(
            head,
            12,
            Paint()..color = tone.withValues(alpha: .12),
          );
        }
        canvas.drawCircle(head, 4.5, Paint()..color = tone);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      route != oldDelegate.route ||
      courier != oldDelegate.courier ||
      tone != oldDelegate.tone ||
      rule != oldDelegate.rule ||
      glow != oldDelegate.glow ||
      geometry.size != oldDelegate.geometry.size;
}

class _NoticeSlot extends StatelessWidget {
  const _NoticeSlot({required this.notice});
  final _Notice? notice;

  @override
  Widget build(BuildContext context) {
    final notice = this.notice;
    if (notice == null) return const SizedBox.shrink();
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final tone = notice.error ? colors.error : palette.accent;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tone.withValues(alpha: .35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notice.error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
                color: tone,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  notice.text,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// This device and, when another device is primary, that device too.
class _Devices extends StatelessWidget {
  const _Devices({
    required this.sync,
    required this.deviceName,
    required this.busy,
    required this.onReclaim,
  });

  final SyncEngineState sync;
  final String? deviceName;
  final bool busy;
  final VoidCallback onReclaim;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final role = sync.role;
    final remote = role == SyncDeviceRole.primary ? null : sync.primary;
    final explanation = role == SyncDeviceRole.primary
        ? 'You can edit your existing notes and diary entries here.'
        : remote == null
        ? 'The primary device has not been checked yet. Sync to find it.'
        : 'New entries made here are synced to your data. Reinstalled the '
              'app or replaced your device? Reclaim the primary role to '
              'restore your data and edit existing entries.';
    return _Panel(
      children: [
        _DeviceRow(
          icon: Icons.smartphone_rounded,
          name: deviceName ?? 'This device',
          caption: 'This device',
          role: switch (role) {
            SyncDeviceRole.primary => _RoleBadge.primary,
            SyncDeviceRole.secondary => _RoleBadge.addOnly,
            _ => _RoleBadge.unknown,
          },
        ),
        if (remote != null)
          _DeviceRow(
            icon: Icons.devices_other_rounded,
            name: remote.deviceName,
            caption: 'Another device',
            role: _RoleBadge.primary,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                explanation,
                key: const ValueKey('primary-device-status'),
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              if (role != SyncDeviceRole.primary) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const ValueKey('reclaim-primary-role'),
                  onPressed: busy ? null : onReclaim,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.accent,
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(
                      color: palette.accent.withValues(alpha: .5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('Reclaim primary role'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum _RoleBadge { primary, addOnly, unknown }

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.icon,
    required this.name,
    required this.caption,
    required this.role,
  });

  final IconData icon;
  final String name;
  final String caption;
  final _RoleBadge role;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final primary = role == _RoleBadge.primary;
    final label = switch (role) {
      _RoleBadge.primary => 'Primary',
      _RoleBadge.addOnly => 'Add-only',
      _RoleBadge.unknown => 'Not checked',
    };
    return Semantics(
      label: '$name, $caption, $label',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.cloth,
                shape: BoxShape.circle,
                border: Border.all(color: palette.rule),
              ),
              child: Icon(icon, size: 20, color: palette.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        caption,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primary ? palette.accent : null,
                          borderRadius: BorderRadius.circular(99),
                          border: primary
                              ? null
                              : Border.all(color: palette.rule),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (primary) ...[
                              Icon(
                                Icons.workspace_premium_rounded,
                                size: 12,
                                color: colors.onPrimary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: primary
                                      ? colors.onPrimary
                                      : palette.muted,
                                  fontSize: 11,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: .3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Material(
      color: palette.ground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: palette.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.trailing,
  });

  final bool enabled;
  final bool danger;
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
      minVerticalPadding: 12,
      iconColor: danger ? colors.error : palette.muted,
      textColor: danger ? colors.error : palette.ink,
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: palette.muted, fontSize: 12.5, height: 1.4),
      ),
      trailing: trailing == null ? null : Icon(trailing, color: palette.muted),
      onTap: enabled ? onTap : null,
    );
  }
}
