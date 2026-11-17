import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../backup/backup_engine.dart';

/// Shows backup progress as an ongoing, silent Android notification.
///
/// [icon] is a drawable resource name such as `ic_notifications` (a white
/// silhouette). Works from the UI isolate and from WorkManager isolates.
class LocalNotificationsBackupNotifier implements BackupNotifier {
  final FlutterLocalNotificationsPlugin plugin;
  final String icon;
  final String channelId;
  final String channelName;
  final String channelDescription;
  final int progressId;
  final int failureId;
  Future<void>? _initialized;

  LocalNotificationsBackupNotifier({
    required this.icon,
    FlutterLocalNotificationsPlugin? plugin,
    this.channelId = 'backup',
    this.channelName = 'Backups',
    this.channelDescription = 'Backup and restore progress.',
    this.progressId = 41000,
    this.failureId = 41001,
  }) : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> _ready() => _initialized ??= plugin
      .initialize(
        settings: InitializationSettings(
          android: AndroidInitializationSettings('@drawable/$icon'),
        ),
      )
      .then((_) {});

  AndroidNotificationDetails _details({
    required bool ongoing,
    double? fraction,
    bool progress = false,
  }) => AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: channelDescription,
    icon: icon,
    importance: Importance.low,
    priority: Priority.low,
    ongoing: ongoing,
    autoCancel: !ongoing,
    onlyAlertOnce: true,
    silent: ongoing,
    showProgress: progress,
    maxProgress: 100,
    progress: ((fraction ?? 0) * 100).round().clamp(0, 100),
    indeterminate: progress && fraction == null,
    category: AndroidNotificationCategory.progress,
  );

  @override
  Future<void> progress({required String title, double? fraction}) async {
    await _ready();
    await plugin.show(
      id: progressId,
      title: title,
      body: fraction == null ? null : '${(fraction * 100).round()}%',
      notificationDetails: NotificationDetails(
        android: _details(ongoing: true, fraction: fraction, progress: true),
      ),
    );
  }

  @override
  Future<void> clear() async {
    await _ready();
    await plugin.cancel(id: progressId);
  }

  @override
  Future<void> failed({required String title, required String body}) async {
    await _ready();
    await plugin.cancel(id: progressId);
    await plugin.show(
      id: failureId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: _details(ongoing: false),
      ),
    );
  }
}
