import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Every Redkeep notification uses this small icon: a white silhouette in
/// `android/app/src/main/res/drawable/ic_notifications.xml`.
const appNotificationIcon = 'ic_notifications';

/// Plugin settings shared by every feature and by background isolates, so
/// whichever initializes first sets the same default icon.
const appNotificationSettings = InitializationSettings(
  android: AndroidInitializationSettings('@drawable/$appNotificationIcon'),
);

/// Asks once for Android 13+ notification permission (used for backup
/// progress and reminders). Never throws; denial is fine.
Future<void> requestNotificationPermission() async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: appNotificationSettings);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  } on Object {
    // Unavailable (tests, other platforms) or dismissed.
  }
}
