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
import '../../watchlist/application/watchlist_providers.dart';
import '../data/backup_identity.dart';
import '../data/drift_account_reset_data.dart';
import '../data/redkeep_backup.dart';
import '../legacy/legacy_import.dart';

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
  final backend = GoogleDriveBackend(
    appId: backupAppId,
    legacyNamespaces: const [legacySyncNamespace],
  );
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
    await redkeepBackupScheduler(
      config.stateDirectory,
    ).apply(settings, signedIn: signedIn);
  }
}

final backupScheduleProvider = Provider<BackupSchedule>(
  (ref) => _WorkManagerSchedule(),
);

/// Before the first backup, copies anything that exists only in the old
/// per-document Drive sync. Null for providers other than Google Drive.
final legacyImportHookProvider = Provider<BackupHook?>((ref) {
  final backend = ref.watch(syncBackendProvider);
  if (backend is! GoogleDriveBackend) return null;
  return () => runLegacyImport(ref, backend.auth);
});

Future<int> runLegacyImport(Ref ref, GoogleAuthService auth) async {
  final account = auth.currentUser;
  if (account == null) return 0;
  final import = LegacyImport(
    db: ref.read(appDatabaseProvider),
    marker: await LegacyImport.markerFile(await appSupportDirectory()),
  );
  if (await import.isDone(account.id)) return 0;
  final client = await auth.authenticatedClient();
  if (client == null) {
    throw const BackupException(BackupErrorKind.auth, 'Sign in to back up.');
  }
  try {
    return await import.run(accountId: account.id, client: client);
  } finally {
    client.close();
  }
}

final backupEngineProvider = FutureProvider<BackupEngine>((ref) async {
  final device = await ref.watch(deviceIdentityProvider.future);
  final hook = ref.watch(legacyImportHookProvider);
  final engine = await createRedkeepBackupEngine(
    backend: ref.watch(syncBackendProvider),
    network: ref.watch(networkServiceProvider),
    deviceName: device.deviceName,
    beforeBackup: [?hook],
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

/// A backup that can be restored because this phone has no writing yet.
class RestoreOffer {
  /// The newest backup, or null when only the old per-document sync exists.
  final RemoteBackup? backup;
  const RestoreOffer.backup(RemoteBackup this.backup);
  const RestoreOffer.legacy() : backup = null;
  bool get legacy => backup == null;
}

final restoreOfferProvider =
    NotifierProvider<RestoreOfferController, RestoreOffer?>(
      RestoreOfferController.new,
    );

class RestoreOfferController extends Notifier<RestoreOffer?> {
  var _declined = false;
  @override
  RestoreOffer? build() => null;

  /// Looks for a backup when signed in on a phone without writing.
  Future<RestoreOffer?> check() async {
    if (_declined || !ref.read(syncAuthProvider).isSignedIn) return null;
    try {
      final engine = await ref.read(backupEngineProvider.future);
      if (!await engine.isEmpty!()) {
        if (ref.mounted) state = null;
        return null;
      }
      final backup = await engine.latestBackup();
      RestoreOffer? offer;
      if (backup != null) {
        offer = RestoreOffer.backup(backup);
      } else {
        final backend = ref.read(syncBackendProvider);
        if (backend is GoogleDriveBackend) {
          final client = await backend.auth.authenticatedClient();
          if (client != null) {
            try {
              if (await LegacyDriveReader(client).hasData()) {
                offer = const RestoreOffer.legacy();
              }
            } finally {
              client.close();
            }
          }
        }
      }
      if (ref.mounted && !_declined) state = offer;
      return offer;
    } on Object {
      // Offline or signed out: offered again on the next sign-in or launch.
      return null;
    }
  }

  /// "Skip": not offered again until the app restarts.
  void decline() {
    _declined = true;
    state = null;
  }

  void clear() => state = null;
}

/// True while a restore replaces the database; the app shows progress only.
final restoringProvider = NotifierProvider<RestoringFlag, bool>(
  RestoringFlag.new,
);

class RestoringFlag extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final backupActionsProvider = Provider<BackupActions>(BackupActions.new);

class BackupActions {
  BackupActions(this.ref);
  final Ref ref;

  Future<BackupState> backUpNow() async =>
      (await ref.read(backupEngineProvider.future)).backUpNow();

  Future<void> pause() async =>
      (await ref.read(backupEngineProvider.future)).cancel();

  /// Replaces this phone's (empty) journal with [backup].
  Future<RestoreResult> restore(RemoteBackup backup) async {
    final engine = await ref.read(backupEngineProvider.future);
    final db = ref.read(appDatabaseProvider);
    final restoring = ref.read(restoringProvider.notifier);
    // Removing the Navigator disposes editors; the generation stops any
    // late write from reaching the database being replaced.
    restoring.set(true);
    db.writingBlocked = true;
    db.writingGeneration++;
    ref.read(writingSessionEpochProvider.notifier).reset();
    var reopened = false;
    try {
      return await engine.restore(
        backup,
        closeDatabase: db.close,
        reopenDatabase: () async {
          reopened = true;
          ref.invalidate(appDatabaseProvider);
          ref.invalidate(notesRepositoryProvider);
          ref.invalidate(diaryRepositoryProvider);
          ref.invalidate(watchlistRepositoryProvider);
        },
      );
    } finally {
      if (!reopened) db.writingBlocked = false;
      ref.read(restoreOfferProvider.notifier).clear();
      ref.read(aiResumeAfterResetProvider)();
      restoring.set(false);
    }
  }

  /// Copies the old per-document sync into this phone, then backs up.
  Future<int> restoreLegacy() async {
    final backend = ref.read(syncBackendProvider);
    if (backend is! GoogleDriveBackend) return 0;
    final added = await runLegacyImport(ref, backend.auth);
    ref.read(restoreOfferProvider.notifier).clear();
    unawaited(backUpNow());
    return added;
  }
}

final accountResetProvider =
    NotifierProvider<AccountResetController, AccountResetState>(
      () => AccountResetController(
        (ref) => AccountResetConfig(
          storage: ref.watch(accountResetStorageProvider),
          engine: ref.watch(backupEngineProvider).requireValue,
          backend: ref.watch(syncBackendProvider),
          network: ref.watch(networkServiceProvider),
          localData: DriftAccountResetData(
            ref.watch(appDatabaseProvider),
            beforeClear: () => ref.read(aiResetProvider)(),
          ),
        ),
      ),
      retry: (_, _) => null,
    );

/// Starts backups: silent sign-in, the overnight schedule, a backup when one
/// is due (on launch and whenever the app goes to the background, in case the
/// background job was delayed), and the restore offer on an empty phone.
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
      ref.mounted &&
      !ref.read(accountResetProvider).blocksDataAccess &&
      !ref.read(restoringProvider);
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
    if (!canRun() || !auth.isSignedIn || engine.state.busy) return;
    if (await engine.isDue()) {
      await engine.backUpNow(trigger: BackupTrigger.automatic);
    }
  }

  Future<void> signedIn() async {
    await ref.read(restoreOfferProvider.notifier).check();
    if (ref.mounted) await backUpIfDue();
  }

  final accounts = auth.onAuthStateChanged.listen((account) async {
    // Sign-out during a reset must still cancel the overnight job.
    if (ref.mounted) await applySchedule();
    if (account != null && canRun()) await signedIn();
  });
  final lifecycle = AppLifecycleListener(
    onPause: () => unawaited(backUpIfDue()),
  );
  ref.onDispose(accounts.cancel);
  ref.onDispose(lifecycle.dispose);
  await reset.ready;
  if (!canRun()) return;
  await auth.trySilentSignIn();
  if (!canRun()) return;
  await applySchedule();
  if (auth.isSignedIn && ref.mounted) await signedIn();
}, retry: (_, _) => null);
