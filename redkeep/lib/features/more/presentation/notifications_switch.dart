import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_permission.dart';
import '../../sync/presentation/sync_material.dart';

/// Notifications on or off, as Android has them for Redkeep. Turning them on
/// asks first; anything Android will no longer ask about, and turning them
/// off, opens Android's settings. The switch catches up when the app returns.
class NotificationsSwitch extends ConsumerStatefulWidget {
  const NotificationsSwitch({super.key});

  @override
  ConsumerState<NotificationsSwitch> createState() =>
      _NotificationsSwitchState();
}

class _NotificationsSwitchState extends ConsumerState<NotificationsSwitch> {
  late final _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(notificationsEnabledProvider),
  );
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _change(bool on) async {
    final permission = ref.read(notificationPermissionProvider);
    setState(() => _busy = true);
    try {
      if (!on || !await permission.request()) await permission.openSettings();
    } finally {
      if (mounted) {
        ref.invalidate(notificationsEnabledProvider);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final enabled = ref.watch(notificationsEnabledProvider).value;
    final detail = switch (enabled) {
      null => 'Checking…',
      true => 'On. Backup progress and watchlist reminders can reach you.',
      false => 'Off. Redkeep can’t show backup progress or reminders.',
    };
    // Its own Material so the ink shows on a card's painted background.
    return Material(
      type: MaterialType.transparency,
      child: _tile(palette, enabled, detail),
    );
  }

  Widget _tile(MorePalette palette, bool? enabled, String detail) {
    return SwitchListTile(
      key: const ValueKey('notifications-switch'),
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        enabled == true
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        color: enabled == true ? palette.accent : palette.muted,
      ),
      title: Text('Notifications', style: TextStyle(color: palette.ink)),
      subtitle: Text(detail, style: TextStyle(color: palette.muted)),
      value: enabled ?? false,
      onChanged: enabled == null || _busy ? null : _change,
    );
  }
}
