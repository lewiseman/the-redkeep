import 'package:flutter/widgets.dart';
import 'package:sync_wise/google_drive.dart';
import 'package:sync_wise/sync_wise.dart';
import 'package:sync_wise/workmanager.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/sync/data/backup_identity.dart';
import '../../features/sync/data/redkeep_backup.dart';
import '../../features/sync/legacy/legacy_import.dart';

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
    final backend = GoogleDriveBackend(
      appId: backupAppId,
      auth: auth,
      legacyNamespaces: const [legacySyncNamespace],
    );
    try {
      return await runScheduledBackup(() async {
        final device = await DeviceIdentityService.load();
        final marker = await LegacyImport.markerFile(
          await appSupportDirectory(),
        );
        return createRedkeepBackupEngine(
          backend: backend,
          network: NetworkService(),
          deviceName: device.deviceName,
          canRun: AccountResetStorage().canSync,
          beforeBackup: [
            // Old sync data is copied in by the app, which owns the database.
            () async {
              final account = auth.currentUser;
              if (account != null &&
                  !await LegacyImport.isDoneAt(marker, account.id) &&
                  await _hasLegacyData(auth)) {
                throw const BackupException(
                  BackupErrorKind.busy,
                  'Open Redkeep once to finish moving to backups.',
                );
              }
            },
          ],
        );
      });
    } finally {
      backend.dispose();
      auth.dispose();
    }
  });
}

Future<bool> _hasLegacyData(GoogleAuthService auth) async {
  final client = await auth.authenticatedClient();
  if (client == null) return false;
  try {
    return await LegacyDriveReader(client).hasData();
  } finally {
    client.close();
  }
}
