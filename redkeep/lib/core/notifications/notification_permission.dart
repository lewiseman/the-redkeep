import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_notifications.dart';

/// Whether Redkeep may show notifications, and the ways to change it.
/// An app cannot turn its own notifications off, so that goes through
/// Android's settings.
abstract interface class NotificationPermission {
  Future<bool> enabled();

  /// Shows Android's prompt when it still can. True when allowed afterwards.
  Future<bool> request();

  /// Opens this app's notification settings in Android.
  Future<void> openSettings();
}

class PluginNotificationPermission implements NotificationPermission {
  static const _channel = MethodChannel('redkeep/notifications');
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<AndroidFlutterLocalNotificationsPlugin?>? _android;

  Future<AndroidFlutterLocalNotificationsPlugin?> _ready() =>
      _android ??= () async {
        await _plugin.initialize(settings: appNotificationSettings);
        return _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
      }();

  @override
  Future<bool> enabled() async {
    try {
      return await (await _ready())?.areNotificationsEnabled() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> request() async {
    try {
      return await (await _ready())?.requestNotificationsPermission() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<bool>('openSettings');
    } on Object {
      // Unavailable outside Android.
    }
  }
}

final notificationPermissionProvider = Provider<NotificationPermission>(
  (ref) => PluginNotificationPermission(),
);

/// Read again whenever the app comes back, since it changes in Android.
final notificationsEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationPermissionProvider).enabled(),
);
