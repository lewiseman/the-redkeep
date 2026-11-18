import 'package:flutter/widgets.dart';
import 'package:sync_wise/google_drive.dart';
import 'package:sync_wise/sync_wise.dart';
import 'package:sync_wise/workmanager.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/sync/data/backup_identity.dart';
import '../../features/sync/data/redkeep_backup.dart';

Future<void>? _initialized;

/// Registers [backupDispatcher] with WorkManager once per process.
Future<void> initializeBackgroundBackups() =>
    _initialized ??= Workmanager().initialize(backupDispatcher);

/// WorkManager entry point for the overnight backup. Runs in its own isolate,
/// so it builds everything itself and never opens the app's Drift database:
/// the snapshot is read through a separate read-only SQLite connection.
@pragma('vm:entry-point')
void backupDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != backupTaskName) return true;
    WidgetsFlutterBinding.ensureInitialized();
    final auth = GoogleAuthService();
    final backend = GoogleDriveBackend(appId: backupAppId, auth: auth);
    try {
      return await runScheduledBackup(() async {
        final device = await DeviceIdentityService.load();
        return createRedkeepBackupEngine(
          backend: backend,
          network: NetworkService(),
          deviceName: device.deviceName,
          canRun: AccountResetStorage().canSync,
        );
      });
    } finally {
      backend.dispose();
      auth.dispose();
    }
  });
}
