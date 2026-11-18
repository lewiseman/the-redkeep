import 'package:flutter/services.dart';

/// Hands the widget snapshot to Android, which stores it and redraws the
/// home screen widgets.
abstract interface class HomeWidgetBridge {
  Future<void> publish(String snapshot);
}

class PlatformHomeWidgetBridge implements HomeWidgetBridge {
  const PlatformHomeWidgetBridge();
  static const _channel = MethodChannel('redkeep/home_widgets');

  @override
  Future<void> publish(String snapshot) async {
    try {
      await _channel.invokeMethod<void>('publish', snapshot);
    } on MissingPluginException {
      // No widget host (tests, other platforms): nothing to update.
    } on PlatformException {
      // A widget that misses one update catches up on the next change.
    }
  }
}
