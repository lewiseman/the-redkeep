import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';
import 'package:sync_wise/notifications.dart';
import 'package:sync_wise/sync_wise.dart';
import 'package:sync_wise/workmanager.dart';

import '../../../core/notifications/app_notifications.dart';
import '../../../core/storage/app_database.dart';
import 'backup_identity.dart';

/// The WorkManager job name; also used by the background dispatcher.
const backupTaskName = 'redkeep.backup';

/// Text for backup notifications.
const redkeepBackupNotices = BackupNotices(
  preparing: 'Preparing backup',
  uploading: 'Backing up your journal',
  downloading: 'Downloading your backup',
  restoring: 'Restoring your journal',
  failedTitle: "Backup didn't finish",
  failedBody: 'Open Redkeep to back up your journal.',
);

Future<BackupConfig> redkeepBackupConfig() async => BackupConfig(
  appId: backupAppId,
  stateDirectory: await BackupConfig.defaultStateDirectory(backupAppId),
);

/// One engine definition for the app and the WorkManager isolate.
Future<BackupEngine> createRedkeepBackupEngine({
  required BackupBackend backend,
  required SyncNetwork network,
  required String deviceName,
  List<BackupHook> beforeBackup = const [],
  BackupNotifier? notifier,
  Future<bool> Function()? canRun,
  BackupConfig? config,
}) async {
  final database = await appDatabaseFile();
  return BackupEngine(
    config: config ?? await redkeepBackupConfig(),
    source: SqliteBackupSource(
      databasePath: database.path,
      schemaVersion: AppDatabase.currentSchemaVersion,
    ),
    backend: backend,
    network: network,
    notifier: notifier ?? redkeepBackupNotifier(),
    notices: redkeepBackupNotices,
    deviceName: deviceName,
    beforeBackup: beforeBackup,
    canRun: canRun,
    isEmpty: () => redkeepDatabaseIsEmpty(database.path),
  );
}

BackupNotifier redkeepBackupNotifier() =>
    LocalNotificationsBackupNotifier(icon: appNotificationIcon);

BackupScheduler redkeepBackupScheduler(Directory state) => BackupScheduler(
  uniqueName: backupTaskName,
  taskName: backupTaskName,
  stateFile: File('${state.path}/schedule.json'),
);

/// True when the journal holds no writing: no notes, diary entries or
/// watchlist titles and lists. Reads with its own read-only connection.
Future<bool> redkeepDatabaseIsEmpty(String path) async {
  if (!await File(path).exists()) return true;
  return Isolate.run(() {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      db.execute('PRAGMA busy_timeout = 10000');
      for (final table in [
        'notes',
        'diary_entries',
        'watch_titles',
        'watch_lists',
      ]) {
        final exists = db.select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          [table],
        );
        if (exists.isEmpty) continue;
        if (db.select('SELECT 1 FROM $table LIMIT 1').isNotEmpty) return false;
      }
      return true;
    } finally {
      db.close();
    }
  });
}
