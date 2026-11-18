import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/notifications/app_notifications.dart';

/// The Watchlist once scheduled reminders for Discover matches and watch
/// nights. Cancels any still pending, and removes their channel, so none
/// fires after the update. Never throws.
Future<void> clearRetiredWatchReminders({
  FlutterLocalNotificationsPlugin? plugin,
}) async {
  try {
    final notifications = plugin ?? FlutterLocalNotificationsPlugin();
    await notifications.initialize(settings: appNotificationSettings);
    for (final request in await notifications.pendingNotificationRequests()) {
      if (request.payload?.startsWith('watchlist-reminders') == true) {
        await notifications.cancel(id: request.id);
      }
    }
    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.deleteNotificationChannel(channelId: 'watchlist');
  } on Object {
    // Unavailable (tests, other platforms): nothing was scheduled.
  }
}
