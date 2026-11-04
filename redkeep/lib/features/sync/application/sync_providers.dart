import '../../ai/application/ai_lifecycle.dart';

import 'package:drift/drift.dart' show TableUpdateQuery;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_wise/google_drive.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../app/storage_providers.dart';
import '../../brain/application/brain_providers.dart';
import '../../notes/application/notes_providers.dart';
import '../../diary/application/diary_providers.dart';
import '../../flow/application/flow_providers.dart';
import '../data/drift_sync_store.dart';
import '../data/drift_account_reset_data.dart';
import '../data/drift_sync_collection.dart';

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
final syncBackendProvider = Provider<SyncBackend>((ref) {
  final backend = GoogleDriveBackend(
    documentIdFields: const {'note': 'id', 'diary': 'id', 'thought': 'id'},
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
final syncConfigurationProvider = FutureProvider<SyncEngineConfig>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final device = await ref.watch(deviceIdentityProvider.future);
  final storage = DriftSyncStateStore(
    db,
    deviceId: device.deviceId,
    now: ref.watch(syncClockProvider),
  );
  await storage.initialize();
  await storage.storage.write('deviceId', device.deviceId);
  return SyncEngineConfig(
    backend: ref.watch(syncBackendProvider),
    deviceId: device.deviceId,
    deviceName: device.deviceName,
    network: ref.watch(networkServiceProvider),
    collections: [
      for (final type in ['note', 'diary', 'thought'])
        DriftSyncCollection(db, type),
    ],
    storage: storage,
    canSync: ref.watch(accountResetStorageProvider).canSync,
  );
}, retry: (_, _) => null);
final syncEngineProvider = NotifierProvider<SyncEngine, SyncEngineState>(
  () => SyncEngine((ref) => ref.watch(syncConfigurationProvider).requireValue),
  retry: (_, _) => null,
);

final accountResetProvider =
    NotifierProvider<AccountResetController, AccountResetState>(
      () => AccountResetController(
        (ref) => AccountResetConfig(
          storage: ref.watch(accountResetStorageProvider),
          engine: ref.watch(syncEngineProvider.notifier),
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

final syncCoordinatorProvider = FutureProvider<void>((ref) async {
  final config = await ref.watch(syncConfigurationProvider.future);
  final db = ref.watch(appDatabaseProvider);
  final engine = ref.watch(syncEngineProvider.notifier);
  final reset = ref.watch(accountResetProvider.notifier);
  var resetGeneration = 0;
  ref.listen(accountResetProvider, (previous, next) {
    if (next.blocksDataAccess && previous?.blocksDataAccess != true) {
      db.writingBlocked = true;
      db.writingGeneration++;
      resetGeneration++;
      ref.read(writingSessionEpochProvider.notifier).reset();
      ref.invalidate(brainExecutorProvider);
    }
    if (!next.blocksDataAccess && previous?.blocksDataAccess == true) {
      db.writingBlocked = false;
      ref.invalidate(notesRepositoryProvider);
      ref.invalidate(diaryRepositoryProvider);
      ref.invalidate(flowRepositoryProvider);
      ref.read(aiResumeAfterResetProvider)();
    }
  }, fireImmediately: true);
  bool canSchedule() =>
      ref.mounted && !ref.read(accountResetProvider).blocksDataAccess;
  final changes = db
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          db.notes,
          db.noteTags,
          db.diaryEntries,
          db.diaryDays,
          db.flowThoughts,
        ]),
      )
      .listen((_) {
        if (canSchedule()) engine.scheduleSync();
      });
  final network = ref
      .watch(networkServiceProvider)
      .onConnectivityChanged
      .listen((type) {
        if (type != NetworkType.none && canSchedule()) engine.scheduleSync();
      });
  final auth = config.backend.auth.onAuthStateChanged.listen((account) {
    if (account != null && canSchedule()) engine.scheduleSync();
  });
  ref.onDispose(changes.cancel);
  ref.onDispose(network.cancel);
  ref.onDispose(auth.cancel);
  await engine.ready;
  await reset.ready;
  if (!canSchedule()) return;
  final generation = resetGeneration;
  await config.backend.auth.trySilentSignIn();
  if (!ref.mounted) return;
  if (generation != resetGeneration) {
    if (ref.read(accountResetProvider).completed &&
        config.backend.auth.isSignedIn) {
      await config.backend.auth.signOut();
    }
    return;
  }
  if (canSchedule()) engine.scheduleSync();
}, retry: (_, _) => null);

final syncCanEditProvider = Provider<bool>((ref) {
  if (!ref.watch(syncEnabledProvider) ||
      !ref.watch(syncConfigurationProvider).hasValue) {
    return true;
  }
  return ref.watch(
    syncEngineProvider.select((s) => s.role != SyncDeviceRole.secondary),
  );
});
