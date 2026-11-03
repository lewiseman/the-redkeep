import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Manages persistent device identity for persistent sync device roles.
class DeviceIdentityService {
  static const String _deviceIdFileName = 'device_identity.id';
  final String deviceId;
  final String deviceName;

  DeviceIdentityService._({required this.deviceId, required this.deviceName});

  /// Loads an identity independently of the singleton, e.g. for another storage
  /// scope or tests. Existing installations retain their device_identity.id.
  static Future<DeviceIdentityService> load({
    Future<Directory> Function()? directory,
    Future<String> Function()? resolveDeviceName,
  }) async {
    final docsDir = await (directory ?? getApplicationDocumentsDirectory)();
    await docsDir.create(recursive: true);

    final idFile = File('${docsDir.path}/$_deviceIdFileName');

    String id;
    if (await idFile.exists()) {
      id = (await idFile.readAsString()).trim();
      if (id.isEmpty) {
        id = const Uuid().v4();
        await idFile.writeAsString(id, flush: true);
      }
    } else {
      id = const Uuid().v4();
      await idFile.writeAsString(id, flush: true);
    }

    var name = 'Device';
    try {
      final resolved = await (resolveDeviceName ?? _resolveDeviceName)();
      if (resolved.trim().isNotEmpty) name = resolved;
    } catch (_) {
      // Sync must remain usable when platform device metadata is unavailable.
    }
    return DeviceIdentityService._(deviceId: id, deviceName: name);
  }

  static Future<String> _resolveDeviceName() async {
    if (Platform.isAndroid) return 'Android device';
    if (Platform.isIOS) return 'iPhone / iPad';
    return Platform.localHostname;
  }
}
