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
import 'pillow_material.dart';
import 'tome_material.dart';

/// The opened tome: your journal's flight to Google Drive, when it backs up,
/// and the account's permanent actions. Shown on the first page when the
/// account card opens; [onClose] shuts the book again.
class BackupPanel extends ConsumerStatefulWidget {
  const BackupPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<BackupPanel> createState() => _BackupPanelState();
}

class _Notice {
  const _Notice(this.text, {this.error = false});
  final String text;
  final bool error;
}

String _intervalName(BackupInterval interval) => switch (interval) {
  BackupInterval.daily => 'Daily',
  BackupInterval.weekly => 'Weekly',
  BackupInterval.monthly => 'Monthly',
  BackupInterval.manual => 'Manual',
};

String _intervalDetail(BackupInterval interval, String cloud) =>
    switch (interval) {
      BackupInterval.daily => 'Backs up to $cloud every night.',
      BackupInterval.weekly => 'Backs up to $cloud once a week, overnight.',
      BackupInterval.monthly => 'Backs up to $cloud once a month, overnight.',
      BackupInterval.manual => backupIntervalLabel(interval),
    };

class _BackupPanelState extends ConsumerState<BackupPanel> {
  bool _working = false;
  bool _loggingOut = false;
  _Notice? _notice;

  // Messages stay on the page, beside what they are about.
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
      widget.onClose();
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

  void _openReset(SyncAccount account) {
    Navigator.of(context, rootNavigator: true).push(
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
    const buttonText = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: .4,
    );

    return DefaultTextStyle.merge(
      style: TextStyle(color: palette.ink),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 6, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _Header(
                onClose: widget.onClose,
                subtitle: account?.email ?? cloud,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
            sliver: SliverToBoxAdapter(
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
                      const SizedBox(height: 18),
                      if (running && state.activity == BackupActivity.uploading)
                        OutlinedButton.icon(
                          key: const ValueKey('backup-pause'),
                          onPressed: () =>
                              ref.read(backupActionsProvider).pause(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: palette.ink,
                            side: BorderSide(
                              color: palette.ink.withValues(alpha: .45),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          icon: const Icon(Icons.pause_rounded),
                          label: const Text('Pause', style: buttonText),
                        )
                      else
                        _LeatherButton(
                          key: const ValueKey('backup-now'),
                          onPressed: busy ? null : _backUp,
                          icon: running ? null : Icons.cloud_upload_outlined,
                          label: running
                              ? status.label
                              : state.resumable
                              ? 'Continue backup'
                              : status.error
                              ? 'Try again'
                              : 'Back up now',
                        ),
                      const SizedBox(height: 40),
                      TomeRule(label: 'Schedule', color: palette.accent),
                      const SizedBox(height: 18),
                      Pillow(
                        padding: const EdgeInsets.fromLTRB(11, 11, 11, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GelSelector<BackupInterval>(
                              values: BackupInterval.values,
                              selected: settings.interval,
                              enabled: account != null,
                              labelOf: _intervalName,
                              keyOf: (interval) =>
                                  ValueKey('backup-interval-${interval.name}'),
                              onSelected: (interval) {
                                if (interval == settings.interval) return;
                                ref
                                    .read(backupSettingsProvider.notifier)
                                    .save(
                                      settings.copyWith(interval: interval),
                                    );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                              child: Text(
                                _intervalDetail(settings.interval, cloud),
                                key: const ValueKey('backup-interval-detail'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const _Seam(),
                            _GelRow(
                              key: const ValueKey('backup-cellular'),
                              icon: Icons.signal_cellular_alt_rounded,
                              title: 'Use mobile data',
                              subtitle: 'Scheduled backups wait for Wi-Fi unless this is on.',
                              value: settings.allowCellular,
                              onChanged:
                                  account == null ||
                                      settings.interval == BackupInterval.manual
                                  ? null
                                  : (value) => ref
                                        .read(backupSettingsProvider.notifier)
                                        .save(
                                          settings.copyWith(
                                            allowCellular: value,
                                          ),
                                        ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Backups run overnight while your phone has battery. ',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12.5,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 40),
                      TomeRule(label: 'Account', color: palette.accent),
                      const SizedBox(height: 18),
                      _Seamed(
                        children: [
                          if (account != null)
                            ListTile(
                              contentPadding: const EdgeInsetsDirectional.only(
                                start: 4,
                                end: 4,
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
                          _ActionRow(
                            key: const ValueKey('account-log-out'),
                            enabled: !busy,
                            icon: Icons.logout_rounded,
                            title: 'Log out',
                            subtitle: 'Your journal stays on this device.',
                            onTap: _logout,
                          ),
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
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose, required this.subtitle});

  final VoidCallback onClose;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Squishy(
            child: Pillow(
              radius: 22,
              stitched: false,
              padding: EdgeInsets.zero,
              child: IconButton(
                key: const ValueKey('backup-close'),
                tooltip: 'Close',
                onPressed: onClose,
                icon: Icon(Icons.arrow_back_rounded, color: palette.ink),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Backups',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'serif',
                    color: palette.accent,
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .6,
                  ),
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: palette.muted,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rows on a stitched pillow, a seam sewn between each.
class _Seamed extends StatelessWidget {
  const _Seamed({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Pillow(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const _Seam(),
          child,
        ],
      ],
    ),
  );
}

/// A running stitch across a pillow, where two rows are sewn apart.
class _Seam extends StatelessWidget {
  const _Seam();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 12),
    child: SizedBox(
      height: 3,
      width: double.infinity,
      child: CustomPaint(painter: _SeamPainter()),
    ),
  );
}

class _SeamPainter extends CustomPainter {
  const _SeamPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final thread = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width - 2; x += 8) {
      final end = math.min(x + 4.5, size.width);
      canvas.drawLine(
        Offset(x, y + .8),
        Offset(end, y + .8),
        thread..color = Colors.white.withValues(alpha: .7),
      );
      canvas.drawLine(
        Offset(x, y),
        Offset(end, y),
        thread..color = const Color(0xff4b3826).withValues(alpha: .45),
      );
    }
  }

  @override
  bool shouldRepaint(_SeamPainter oldDelegate) => false;
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
    // The seal is red wax; the route and stations are drawn in ink.
    final tone = route == _Route.broken ? colors.error : palette.accent;
    final status = widget.status;
    final headline = widget.loggingOut ? 'Logging out' : status.label;
    final detail = widget.loggingOut
        ? 'Your journal stays on this device.'
        : status.detail;
    final stamp = status.active || route == _Route.synced ? null : status.stamp;
    final reduced = !_animate;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 4),
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
          const SizedBox(height: 22),
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: route == _Route.broken ? colors.error : palette.ink,
                    fontFamily: 'serif',
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .2,
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
                  // A glass tube sunk into a pillow, filling with red.
                  Pillow(
                    radius: 99,
                    stitched: false,
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Stack(
                        children: [
                          LinearProgressIndicator(
                            key: const ValueKey('backup-progress'),
                            minHeight: 8,
                            // Reduced motion: a still bar instead of a sweep.
                            value: status.fraction ?? (reduced ? .5 : null),
                            color: tone.withValues(alpha: .85),
                            backgroundColor: palette.ink.withValues(alpha: .08),
                          ),
                          // The glass's specular streak over the liquid.
                          Positioned(
                            left: 4,
                            right: 4,
                            top: 1,
                            height: 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .45),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ],
                      ),
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
    final ends = route == _Route.offline
        ? palette.muted
        : palette.ink.withValues(alpha: .85);
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
                tone: route == _Route.broken
                    ? colors.error
                    : palette.ink.withValues(alpha: .8),
                rule: palette.ink.withValues(alpha: .3),
                glow: !simpler,
                raven: palette.ink,
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
            child: CustomPaint(
              key: const ValueKey('backup-seal'),
              painter: _SealPainter(
                color: route == _Route.offline ? palette.muted : tone,
                paper: palette.ground,
                wax: sealFilled,
                shadow: sealFilled && !simpler,
              ),
              child: SizedBox.square(
                dimension: 40,
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
          ),
      ],
    );
  }

  Widget _station(Offset center, IconData icon, Color tone) {
    const r = _ArcGeometry.stationRadius;
    return Positioned(
      left: center.dx - r,
      top: center.dy - r,
      // A stitched paper button, like the pillows below it.
      child: SizedBox.square(
        dimension: r * 2,
        child: Pillow(
          radius: r,
          padding: EdgeInsets.zero,
          child: Center(child: Icon(icon, size: 22, color: tone)),
        ),
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
    required this.raven,
    this.inbound = false,
  }) : super(repaint: courier);

  final _ArcGeometry geometry;
  final _Route route;
  final Animation<double>? courier;
  final Color tone;
  final Color rule;
  final bool glow;
  final bool inbound;
  final Color raven;

  /// A raven facing +x, about 22 wide, its wings at [flap] (-1 down, 1 up).
  static void _paintRaven(Canvas canvas, Color color, double flap) {
    final body = Paint()..color = color;
    final far = Paint()..color = color.withValues(alpha: .55);
    Path wing(double lift, double reach) => Path()
      ..moveTo(3, -1)
      ..quadraticBezierTo(-1, -7 * lift, -6 * reach, -11 * lift)
      ..quadraticBezierTo(-3, -4 * lift, -4, 0)
      ..close();
    canvas.drawPath(wing(flap * .8, .8), far);
    canvas.drawPath(
      Path()
        ..addOval(Rect.fromLTRB(-7, -2.4, 6, 2.6))
        ..addOval(Rect.fromCircle(center: const Offset(6.5, -1.2), radius: 2.6))
        ..moveTo(8.6, -2)
        ..lineTo(12, -.8)
        ..lineTo(8.6, .2)
        ..close()
        ..moveTo(-6, -.6)
        ..lineTo(-11, -3)
        ..lineTo(-10, 1)
        ..lineTo(-11, 3.2)
        ..lineTo(-6, 1.2)
        ..close(),
      body,
    );
    canvas.drawPath(wing(flap, 1), body);
  }

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
        final tangent = metric.getTangentForOffset(at)!;
        final head = tangent.position;
        if (glow) {
          canvas.drawCircle(
            head,
            14,
            Paint()..color = tone.withValues(alpha: .10),
          );
        }
        // A raven carries the journal, beating its wings as it goes.
        final flap = math.sin(courier.value * math.pi * 2 * 5);
        canvas.save();
        canvas.translate(head.dx, head.dy);
        canvas.rotate(-tangent.angle + (inbound ? math.pi : 0));
        if (inbound) canvas.scale(1, -1);
        _paintRaven(canvas, raven, flap);
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      route != oldDelegate.route ||
      courier != oldDelegate.courier ||
      tone != oldDelegate.tone ||
      rule != oldDelegate.rule ||
      glow != oldDelegate.glow ||
      raven != oldDelegate.raven ||
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
    final tone = notice.error ? colors.error : palette.ink;
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
      contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 4),
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

/// A seal at the route's crest. Pressed wax with a ragged rim once the
/// journal is safe (or broken); a plain stamped ring otherwise.
class _SealPainter extends CustomPainter {
  const _SealPainter({
    required this.color,
    required this.paper,
    required this.wax,
    required this.shadow,
  });

  final Color color;
  final Color paper;
  final bool wax;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (!wax) {
      canvas.drawCircle(center, radius, Paint()..color = paper);
      canvas.drawCircle(
        center,
        radius - .7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: .6),
      );
      return;
    }
    const lobes = 11;
    final rim = Path();
    for (var i = 0; i <= lobes * 4; i++) {
      final a = i / (lobes * 4) * math.pi * 2;
      final r = radius + 3 + math.sin(a * lobes) * 1.4 + math.sin(a * 3) * .8;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? rim.moveTo(p.dx, p.dy) : rim.lineTo(p.dx, p.dy);
    }
    rim.close();
    if (shadow) {
      canvas.drawPath(
        rim.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: .22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawPath(
      rim,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.4),
          colors: [Color.lerp(color, Colors.white, .22)!, color],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 4)),
    );
    // The pressed face, a ring sunk into the wax.
    canvas.drawCircle(
      center,
      radius - 5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: .18),
    );
    canvas.drawCircle(
      center.translate(.6, .8),
      radius - 5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = Colors.white.withValues(alpha: .18),
    );
    if (!shadow) return;
    // Fresh wax has a wet, glassy shine across its crown.
    final shine = Rect.fromLTWH(
      center.dx - radius * .62,
      center.dy - radius * .88,
      radius * 1.1,
      radius * .62,
    );
    canvas.drawOval(
      shine,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .55),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(shine),
    );
  }

  @override
  bool shouldRepaint(_SealPainter oldDelegate) =>
      color != oldDelegate.color ||
      paper != oldDelegate.paper ||
      wax != oldDelegate.wax ||
      shadow != oldDelegate.shadow;
}

/// The page's main action: a rough-cut patch of the binding's leather with
/// its words stamped in worn gilt.
class _LeatherButton extends StatelessWidget {
  const _LeatherButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tome = TomePalette.of(context);
    final enabled = onPressed != null;
    final style = tome.stamped(fontSize: 15.5, letterSpacing: .8);
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : .6,
        duration: RenderingPolicyScope.of(context).duration,
        child: Squishy(
          enabled: enabled,
          child: LeatherPatch(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(6),
                splashColor: tome.gilt.withValues(alpha: .14),
                highlightColor: Colors.black.withValues(alpha: .12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: style.color),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: style,
                          ),
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

/// A setting with a gel switch; the whole row takes the tap.
class _GelRow extends StatelessWidget {
  const _GelRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final enabled = onChanged != null;
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        enabled: enabled,
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 14, 6, 14),
            child: Row(
              children: [
                Icon(icon, color: palette.muted),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enabled ? palette.ink : palette.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GelSwitch(value: value, enabled: enabled),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
