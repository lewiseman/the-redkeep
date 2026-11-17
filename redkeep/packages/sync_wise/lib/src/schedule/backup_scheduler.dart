import 'dart:io';

import 'package:workmanager/workmanager.dart';

import '../backup/backup_engine.dart';
import '../backup/backup_models.dart';
import '../backup/backup_settings.dart';
import '../backup/backup_storage.dart';

/// Registers the periodic background job with Android WorkManager.
///
/// The job runs roughly at [preferredHour] local time, only with enough
/// battery and on Wi-Fi unless mobile data is allowed. The background entry
/// point should call [runScheduledBackup].
class BackupScheduler {
  final String uniqueName;
  final String taskName;
  final int preferredHour;

  /// Remembers what was registered, so app starts do not re-register.
  final File? stateFile;
  final Workmanager _workmanager;
  final DateTime Function() now;

  BackupScheduler({
    this.uniqueName = 'sync_wise.backup',
    this.taskName = 'sync_wise.backup',
    this.preferredHour = 2,
    this.stateFile,
    Workmanager? workmanager,
    DateTime Function()? now,
  }) : _workmanager = workmanager ?? Workmanager(),
       now = now ?? DateTime.now;

  /// Applies [settings]; cancels the job when signed out or manual-only.
  Future<void> apply(BackupSettings settings, {required bool signedIn}) async {
    final period = settings.interval.period;
    final signature = !signedIn || period == null
        ? 'off'
        : '${settings.interval.name}/${settings.allowCellular}';
    final file = stateFile;
    if (file != null && (await readJsonFile(file))?['applied'] == signature) {
      return;
    }
    if (signature == 'off') {
      await _workmanager.cancelByUniqueName(uniqueName);
    } else {
      await _workmanager.registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: period,
        flexInterval: const Duration(hours: 3),
        initialDelay: delayUntilPreferredHour(now(), preferredHour),
        constraints: Constraints(
          networkType: settings.allowCellular
              ? NetworkType.connected
              : NetworkType.unmetered,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
    }
    if (file != null) await writeJsonFile(file, {'applied': signature});
  }

  /// Forgets the registration, e.g. after sign-out, so [apply] runs again.
  Future<void> cancel() async {
    await _workmanager.cancelByUniqueName(uniqueName);
    if (stateFile != null) await deleteIfExists(stateFile!);
  }

  /// Time until the next [hour]:00 local, at least 15 minutes away.
  static Duration delayUntilPreferredHour(DateTime now, int hour) {
    var next = DateTime(now.year, now.month, now.day, hour);
    if (!next.isAfter(now.add(const Duration(minutes: 15)))) {
      next = DateTime(now.year, now.month, now.day + 1, hour);
    }
    return next.difference(now);
  }
}

/// Background entry: runs a backup when one is due.
///
/// Returns false to ask WorkManager to retry later (with backoff) for
/// failures that can resolve on their own; true otherwise, so problems that
/// need the user (sign-in, full storage) do not retry endlessly.
Future<bool> runScheduledBackup(Future<BackupEngine> Function() build) async {
  BackupEngine? engine;
  try {
    engine = await build();
    await engine.load();
    if (!await engine.isDue()) return true;
    final result = await engine.backUpNow(trigger: BackupTrigger.scheduled);
    final error = result.error;
    return error == null || !error.retryable;
  } on Object {
    return false;
  } finally {
    await engine?.dispose();
  }
}
