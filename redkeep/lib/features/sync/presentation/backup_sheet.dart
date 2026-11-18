import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../core/notifications/app_notifications.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../application/sync_providers.dart';
import 'backup_status.dart';
import 'reset_account_page.dart';
import 'sync_material.dart';

/// The backup sheet: your journal's flight to Google Drive, when it backs up,
/// and the account's permanent actions.
class BackupSheet extends ConsumerStatefulWidget {
  const BackupSheet({super.key, this.scrollController});

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
        builder: (_, controller) => BackupSheet(scrollController: controller),
      ),
    );
  }

  @override
  ConsumerState<BackupSheet> createState() => _BackupSheetState();
}

class _Notice {
  const _Notice(this.text, {this.error = false});
  final String text;
  final bool error;
}

class _BackupSheetState extends ConsumerState<BackupSheet> {
  bool _working = false;
  bool _loggingOut = false;
  bool _choosing = false;
  _Notice? _notice;

  // Messages stay inside the sheet: a snackbar would land behind it.
  void _say(String text, {bool error = false}) {
    if (mounted) setState(() => _notice = _Notice(text, error: error));
  }

  Future<void> _backUp() async {
    if (_working || ref.read(backupStateProvider).busy) return;
    unawaited(requestNotificationPermission());
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      final result = await ref.read(backupActionsProvider).backUpNow();
      final error = result.error;
      if (error == null) {
        _say('Backed up to ${ref.read(syncBackendProvider).displayName}.');
      } else if (error.kind != BackupErrorKind.cancelled) {
        _say(error.message, error: true);
      }
    } catch (error) {
      _say(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _logout() async {
    if (_working || ref.read(backupStateProvider).busy) return;
    setState(() {
      _working = true;
      _loggingOut = true;
      _notice = null;
    });
    try {
      await ref.read(syncAuthProvider).signOut();
      if (!mounted) return;
      ref.invalidate(authStateProvider);
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

  Future<void> _chooseInterval(BackupSettings settings) async {
    if (_choosing) return;
    _choosing = true;
    final palette = MorePalette.of(context);
    final picked = await showDialog<BackupInterval>(
      context: context,
      animationStyle: RenderingPolicyScope.of(context).reducedMotion
          ? AnimationStyle.noAnimation
          : null,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        backgroundColor: palette.paper,
        title: const Text('Back up to Google Drive'),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        content: RadioGroup<BackupInterval>(
          groupValue: settings.interval,
          onChanged: (value) => Navigator.pop(dialog, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final interval in BackupInterval.values)
                RadioListTile<BackupInterval>(
                  key: ValueKey('backup-interval-${interval.name}'),
                  value: interval,
                  activeColor: palette.accent,
                  title: Text(backupIntervalLabel(interval)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    _choosing = false;
    if (picked == null || picked == settings.interval || !mounted) return;
    await ref
        .read(backupSettingsProvider.notifier)
        .save(settings.copyWith(interval: picked));
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
    final state = ref.watch(backupStateProvider);
    final account = ref.watch(syncAccountProvider);
    final cloud = ref.watch(syncBackendProvider).displayName;
    final settings =
        ref.watch(backupSettingsProvider).value ?? const BackupSettings();
    final deviceName = ref.watch(deviceIdentityProvider).value?.deviceName;
    final palette = MorePalette.of(context);
    final status = describeBackup(
      state,
      signedIn: account != null,
      cloudName: cloud,
    );
    final running = _working || state.busy;
    final busy = running || account == null;
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: palette.accent,
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
    const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

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
                    status: status,
                    loggingOut: _loggingOut,
                    cloudName: cloud,
                    deviceName: deviceName,
                  ),
                  _NoticeSlot(notice: _notice),
                  const SizedBox(height: 14),
                  if (running && state.activity == BackupActivity.uploading)
                    OutlinedButton.icon(
                      key: const ValueKey('backup-pause'),
                      onPressed: () => ref.read(backupActionsProvider).pause(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: palette.accent,
                        side: BorderSide(color: palette.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('Pause', style: buttonText),
                    )
                  else
                    FilledButton(
                      key: const ValueKey('backup-now'),
                      onPressed: busy ? null : _backUp,
                      style: buttonStyle,
                      child: Text(
                        running
                            ? status.label
                            : state.resumable
                            ? 'Continue backup'
                            : status.error
                            ? 'Try again'
                            : 'Back up now',
                        textAlign: TextAlign.center,
                        style: buttonText,
                      ),
                    ),
                  const SizedBox(height: 32),
                  const _Eyebrow('Schedule'),
                  const SizedBox(height: 10),
                  _Panel(
                    children: [
                      _ActionRow(
                        key: const ValueKey('backup-interval'),
                        enabled: account != null,
                        icon: Icons.schedule_rounded,
                        title: 'Back up to $cloud',
                        subtitle: backupIntervalLabel(settings.interval),
                        trailing: Icons.chevron_right_rounded,
                        onTap: () => _chooseInterval(settings),
                      ),
                      Divider(height: 1, indent: 56, color: palette.rule),
                      SwitchListTile(
                        key: const ValueKey('backup-cellular'),
                        contentPadding: const EdgeInsetsDirectional.only(
                          start: 16,
                          end: 12,
                        ),
                        secondary: Icon(
                          Icons.signal_cellular_alt_rounded,
                          color: palette.muted,
                        ),
                        activeThumbColor: palette.accent,
                        title: const Text(
                          'Use mobile data',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Scheduled backups wait for Wi-Fi unless this is on.',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        value: settings.allowCellular,
                        onChanged:
                            account == null ||
                                settings.interval == BackupInterval.manual
                            ? null
                            : (value) => ref
                                  .read(backupSettingsProvider.notifier)
                                  .save(
                                    settings.copyWith(allowCellular: value),
                                  ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Backups run overnight while your phone has battery. '
                    '$cloud keeps the two newest in a hidden folder only '
                    'Redkeep can open.',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _Eyebrow('Account'),
                  const SizedBox(height: 10),
                  _Panel(
                    children: [
                      if (account != null) ...[
                        ListTile(
                          contentPadding: const EdgeInsetsDirectional.only(
                            start: 16,
                            end: 12,
                          ),
                          leading: Icon(
                            Icons.account_circle_outlined,
                            color: palette.muted,
                          ),
                          title: Text(
                            account.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Google account',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Divider(height: 1, indent: 56, color: palette.rule),
                      ],
                      _ActionRow(
                        key: const ValueKey('account-log-out'),
                        enabled: !busy,
                        icon: Icons.logout_rounded,
                        title: 'Log out',
                        subtitle: 'Your journal stays on this device.',
                        onTap: _logout,
                      ),
                      Divider(height: 1, indent: 56, color: palette.rule),
                      _ActionRow(
                        key: const ValueKey('reset-account-data'),
                        enabled: !busy,
                        danger: true,
                        icon: Icons.delete_forever_outlined,
                        title: 'Reset account data',
                        subtitle: running
                            ? 'Wait for the backup to finish before resetting account data.'
                            : 'Permanently delete your journal and backups.',
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

/// Your journal's flight between this device and the cloud. A courier
/// crosses the arc while backing up (or back, while restoring); at rest a
/// seal at its crest gives the state.
class _Flight extends StatefulWidget {
  const _Flight({
    required this.status,
    required this.loggingOut,
    required this.cloudName,
    required this.deviceName,
  });

  final BackupStatusView status;
  final bool loggingOut;
  final String cloudName;
  final String? deviceName;

  static const arcHeight = 132.0;

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

  // One way: to the cloud while backing up, home while restoring.
  void _drive() {
    if (widget.status.active && _animate) {
      if (!_courier.isAnimating) _courier.repeat();
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
    final status = widget.status;
    if (status.active) return _Route.travelling;
    if (status.error) return _Route.broken;
    if (status.waiting) return _Route.offline;
    if (status.never) return _Route.waiting;
    return _Route.synced;
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final simpler = RenderingPolicyScope.of(context).simplerEffects;
    final route = _route;
    final tone = route == _Route.broken ? colors.error : palette.accent;
    final status = widget.status;
    final headline = widget.loggingOut ? 'Logging out' : status.label;
    final detail = widget.loggingOut
        ? 'Your journal stays on this device.'
        : status.detail;
    final stamp = status.active || route == _Route.synced ? null : status.stamp;
    final reduced = !_animate;

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
              label: 'Backups from this device to ${widget.cloudName}',
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
                        title: widget.cloudName,
                        caption: 'Backup',
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
                  if (status.active && !widget.loggingOut) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        key: const ValueKey('backup-progress'),
                        minHeight: 5,
                        // Reduced motion: a still bar instead of a sweep.
                        value: status.fraction ?? (reduced ? .5 : null),
                        color: tone,
                        backgroundColor: palette.rule,
                      ),
                    ),
                  ],
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
      _Route.travelling => (Icons.arrow_upward_rounded, false),
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
                inbound: widget.status.inbound,
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
    this.inbound = false,
  }) : super(repaint: courier);

  final _ArcGeometry geometry;
  final _Route route;
  final Animation<double>? courier;
  final Color tone;
  final Color rule;
  final bool glow;
  final bool inbound;

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
        final at = from + (to - from) * (inbound ? 1 - t : t);
        final heading = inbound ? -1 : 1;
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
      inbound != oldDelegate.inbound ||
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
