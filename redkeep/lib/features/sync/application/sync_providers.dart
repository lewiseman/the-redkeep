import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_wise/google_drive.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../app/background/backup_dispatcher.dart';
import '../../../app/storage_providers.dart';
import '../../ai/application/ai_lifecycle.dart';
import '../../diary/application/diary_providers.dart';
import '../../notes/application/notes_providers.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../watchlist/application/watchlist_providers.dart';
import '../data/backup_identity.dart';
import '../data/drift_account_reset_data.dart';
import '../data/redkeep_backup.dart';

final writingSessionEpochProvider = NotifierProvider<WritingSessionEpoch, int>(
  WritingSessionEpoch.new,
);

class WritingSessionEpoch extends Notifier<int> {
  @override
  int build() => 0;
  void reset() => state++;
}

// Tests replace this consumed boundary to keep ordinary widget suites offline.
final syncEnabledProvider = Provider<bool>((ref) => true);
final syncClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final deviceIdentityProvider = FutureProvider<DeviceIdentityService>(
  (ref) => DeviceIdentityService.load(),
  retry: (_, _) => null,
);
final networkServiceProvider = Provider<NetworkService>(
  (ref) => NetworkService(),
);

final syncBackendProvider = Provider<BackupBackend>((ref) {
  final backend = GoogleDriveBackend(appId: backupAppId);
  ref.onDispose(backend.dispose);
  return backend;
});
final syncAuthProvider = Provider<SyncAuth>(
  (ref) => ref.watch(syncBackendProvider).auth,
);
final authStateProvider = StreamProvider<SyncAccount?>((ref) {
  final auth = ref.watch(syncAuthProvider);
  return Stream.multi((events) {
    final sub = auth.onAuthStateChanged.listen(
      events.add,
      onError: events.addError,
    );
    events.add(auth.currentUser);
    events.onCancel = sub.cancel;
  });
});
final syncAccountProvider = Provider<SyncAccount?>(
  (ref) =>
      ref.watch(authStateProvider).value ??
      ref.watch(syncAuthProvider).currentUser,
);
final accountResetStorageProvider = Provider<AccountResetStorage>(
  (ref) => AccountResetStorage(),
);

/// Registers the overnight job. Tests replace it; WorkManager is a plugin.
abstract interface class BackupSchedule {
  Future<void> apply(BackupSettings settings, {required bool signedIn});
}

class _WorkManagerSchedule implements BackupSchedule {
  @override
  Future<void> apply(BackupSettings settings, {required bool signedIn}) async {
    await initializeBackgroundBackups();
    final config = await redkeepBackupConfig();
    await redkeepBackupScheduler(config.stateDirectory)
        .apply(settings, signedIn: signedIn);
  }
}

final backupScheduleProvider = Provider<BackupSchedule>(
  (ref) => _WorkManagerSchedule(),
);

final backupEngineProvider = FutureProvider<BackupEngine>((ref) async {
  final device = await ref.watch(deviceIdentityProvider.future);
  final engine = await createRedkeepBackupEngine(
    backend: ref.watch(syncBackendProvider),
    network: ref.watch(networkServiceProvider),
    deviceName: device.deviceName,
    canRun: ref.watch(accountResetStorageProvider).canSync,
  );
  ref.onDispose(engine.dispose);
  await engine.load();
  return engine;
}, retry: (_, _) => null);

/// The engine's progress and last result, for the UI.
final backupStateProvider = NotifierProvider<BackupStateNotifier, BackupState>(
  BackupStateNotifier.new,
);

class BackupStateNotifier extends Notifier<BackupState> {
  @override
  BackupState build() {
    final engine = ref.watch(backupEngineProvider).value;
    if (engine == null) return const BackupState();
    final subscription = engine.states.listen((next) => state = next);
    ref.onDispose(subscription.cancel);
    return engine.state;
  }
}

/// A restore's photos and files are still downloading (or waiting to).
final mediaRestorePendingProvider = Provider<bool>((ref) {
  final state = ref.watch(backupStateProvider);
  return state.filesPending || state.activity == BackupActivity.restoringFiles;
});

/// Media paths (e.g. `diary_photos/…`) as a restore brings them back, so
/// placeholders can load the file the moment it lands.
final restoredMediaProvider = StreamProvider<String>((ref) async* {
  final engine = await ref.watch(backupEngineProvider.future);
  yield* engine.restoredFiles;
});

final backupSettingsProvider =
    AsyncNotifierProvider<BackupSettingsController, BackupSettings>(
      BackupSettingsController.new,
      retry: (_, _) => null,
    );

class BackupSettingsController extends AsyncNotifier<BackupSettings> {
  @override
  Future<BackupSettings> build() async =>
      (await ref.watch(backupEngineProvider.future)).readSettings();

  Future<void> save(BackupSettings next) async {
    final engine = await ref.read(backupEngineProvider.future);
    await engine.writeSettings(next);
    state = AsyncData(next);
    try {
      await ref
          .read(backupScheduleProvider)
          .apply(next, signedIn: ref.read(syncAuthProvider).isSignedIn);
    } on Object {
      // The foreground due check still backs up on schedule.
    }
  }
}

final backupActionsProvider = Provider<BackupActions>(BackupActions.new);

class BackupActions {
  BackupActions(this.ref);
  final Ref ref;

  Future<BackupState> backUpNow() async =>
      (await ref.read(backupEngineProvider.future)).backUpNow();

  /// Backs up after connecting an account, unless this phone has no writing
  /// yet: an empty journal never replaces a backup already in the cloud.
  Future<void> backUpIfWriting() async {
    final engine = await ref.read(backupEngineProvider.future);
    if (await engine.isEmpty?.call() ?? false) return;
    await engine.backUpNow();
  }

  Future<void> pause() async =>
      (await ref.read(backupEngineProvider.future)).cancel();

  /// Downloads photos and files a restore left for later, in the background.
  /// Returns null when nothing ran because nothing is pending or a run in
  /// this app is already busy (backups finish pending media first).
  Future<BackupState?> restoreMedia() async {
    final engine = await ref.read(backupEngineProvider.future);
    if (engine.state.busy || !await engine.filesPending()) return null;
    return engine.restoreFiles();
  }

  /// Downloads [path] (e.g. `diary_photos/…`) next in the running or next
  /// media restore. Never starts one: widgets call this while building.
  Future<void> prioritizeMedia(String path) async =>
      (await ref.read(backupEngineProvider.future)).prioritize(path);

  /// Replaces this phone's journal with [backup]. Restores happen only during
  /// onboarding, before any writing exists, so the screen stays in place; the
  /// generation still stops any late write reaching the replaced database.
  Future<RestoreResult> restore(RemoteBackup backup) async {
    final engine = await ref.read(backupEngineProvider.future);
    final db = ref.read(appDatabaseProvider);
    db.writingBlocked = true;
    db.writingGeneration++;
    var reopened = false;
    try {
      final result = await engine.restore(
        backup,
        closeDatabase: db.closeConnection,
        reopenDatabase: () async {
          reopened = true;
          ref.invalidate(appDatabaseProvider);
          ref.invalidate(notesRepositoryProvider);
          ref.invalidate(diaryRepositoryProvider);
          ref.invalidate(watchlistRepositoryProvider);
        },
      );
      // The journal is usable now; media follows with its own progress.
      if (result.filesPending) unawaited(restoreMedia());
      return result;
    } finally {
      if (!reopened) db.writingBlocked = false;
      ref.read(aiResumeAfterResetProvider)();
    }
  }
}

/// How long to wait before retrying a media restore that found another run
/// holding the backup lock (e.g. one the app was closed during, whose lock
/// goes stale after two minutes).
final mediaRestoreRetryDelayProvider = Provider<Duration>(
  (_) => const Duration(seconds: 30),
);

final accountResetProvider =
    NotifierProvider<AccountResetController, AccountResetState>(
      () => AccountResetController(
        (ref) => AccountResetConfig(
          storage: ref.watch(accountResetStorageProvider),
          engine: ref.watch(backupEngineProvider).requireValue,
          backend: ref.watch(syncBackendProvider),
          network: ref.watch(networkServiceProvider),
          // Read lazily: a restore swaps the database, and rebuilding this
          // controller would briefly report a reset check over the app.
          localData: _CurrentDatabaseReset(ref),
        ),
      ),
      retry: (_, _) => null,
    );

class _CurrentDatabaseReset implements AccountResetLocalData {
  _CurrentDatabaseReset(this.ref);
  final Ref ref;
  @override
  Future<void> clear() => DriftAccountResetData(
    ref.read(appDatabaseProvider),
    beforeClear: () => ref.read(aiResetProvider)(),
  ).clear();
}

/// Starts backups: silent sign-in, the overnight schedule, and a backup when
/// one is due (on launch and whenever the app goes to the background, in case
/// the background job was delayed). Restoring belongs to onboarding.
final backupCoordinatorProvider = FutureProvider<void>((ref) async {
  final engine = await ref.watch(backupEngineProvider.future);
  final reset = ref.watch(accountResetProvider.notifier);
  final auth = ref.watch(syncAuthProvider);
  ref.listen(accountResetProvider, (previous, next) {
    final db = ref.read(appDatabaseProvider);
    if (next.blocksDataAccess && previous?.blocksDataAccess != true) {
      db.writingBlocked = true;
      db.writingGeneration++;
      ref.read(writingSessionEpochProvider.notifier).reset();
    }
    if (!next.blocksDataAccess && previous?.blocksDataAccess == true) {
      db.writingBlocked = false;
      ref.invalidate(notesRepositoryProvider);
      ref.invalidate(diaryRepositoryProvider);
      ref.invalidate(watchlistRepositoryProvider);
      ref.read(aiResumeAfterResetProvider)();
    }
  }, fireImmediately: true);
  bool canRun() =>
      ref.mounted && !ref.read(accountResetProvider).blocksDataAccess;
  Future<void> applySchedule() async {
    try {
      await ref
          .read(backupScheduleProvider)
          .apply(await engine.readSettings(), signedIn: auth.isSignedIn);
    } on Object {
      // Without WorkManager the foreground due check below still runs.
    }
  }

  Future<void> backUpIfDue() async {
    // Nothing is backed up until onboarding, and any restore in it, is done.
    if (!canRun() ||
        !auth.isSignedIn ||
        engine.state.busy ||
        ref.read(onboardingControllerProvider).complete != true) {
      return;
    }
    if (await engine.isDue()) {
      await engine.backUpNow(trigger: BackupTrigger.automatic);
    }
  }

  Timer? mediaRetry;
  Future<void> restoreMediaIfPending() async {
    mediaRetry?.cancel();
    mediaRetry = null;
    if (!canRun() || !auth.isSignedIn) return;
    final result = await ref.read(backupActionsProvider).restoreMedia();
    // Another run holds the lock, often one killed when the app was closed.
    // Try again rather than leaving media waiting until the next resume.
    if (ref.mounted &&
        result != null &&
        result.filesPending &&
        result.error?.kind == BackupErrorKind.busy) {
      mediaRetry = Timer(
        ref.read(mediaRestoreRetryDelayProvider),
        () => unawaited(restoreMediaIfPending()),
      );
    }
  }

  final accounts = auth.onAuthStateChanged.listen((account) async {
    // Sign-out during a reset must still cancel the overnight job.
    if (ref.mounted) await applySchedule();
    if (account != null && canRun()) {
      await restoreMediaIfPending();
      await backUpIfDue();
    }
  });
  final lifecycle = AppLifecycleListener(
    onPause: () => unawaited(backUpIfDue()),
    onResume: () => unawaited(restoreMediaIfPending()),
  );
  ref.onDispose(accounts.cancel);
  ref.onDispose(lifecycle.dispose);
  ref.onDispose(() => mediaRetry?.cancel());
  await reset.ready;
  if (!canRun()) return;
  await auth.trySilentSignIn();
  if (!canRun()) return;
  await applySchedule();
  if (auth.isSignedIn && ref.mounted) {
    await restoreMediaIfPending();
    await backUpIfDue();
  }
}, retry: (_, _) => null);
