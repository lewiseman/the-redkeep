import 'dart:io';

import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/recall/application/recall_controller.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';

import '../../support/fake_ai.dart';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:sync_wise/sync_wise.dart';

import 'drift_sync_test.dart' show Harness;

import 'package:redkeep/features/sync/data/drift_sync_collection.dart';

import '../../../packages/sync_wise/test/support/memory_backend.dart'
    show MemoryDrive;

class QuietNetwork extends Fake implements NetworkService {
  @override
  Stream<NetworkType> get onConnectivityChanged => const Stream.empty();
  @override
  Future<bool> isOnline() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('root coordinator blocks interrupted resets, keeps account binding, and renews repository generations', () async {
    final directory = await Directory.systemTemp.createTemp('redkeep-reset-');
    final h = Harness(AppDatabase(NativeDatabase.memory()), MemoryDrive());
    final resetStorage = AccountResetStorage(directory: () async => directory);
    await h.saveNote('a' * 32, 'erase');
    final vectors = MemoryVectors();
    final tasks = MemoryAiTasks()..value = 'protected synthetic snapshot';
    final container = ProviderContainer(
      overrides: [
        recallVectorsProvider.overrideWith((ref) async => vectors),
        protectedAiTasksProvider.overrideWithValue(tasks),
        companionControllerProvider.overrideWith(
          () => TestConnection(readyComputer()),
        ),
        appDatabaseProvider.overrideWithValue(h.db),
        syncBackendProvider.overrideWithValue(h.backend),
        networkServiceProvider.overrideWithValue(QuietNetwork()),
        accountResetStorageProvider.overrideWithValue(resetStorage),
        syncConfigurationProvider.overrideWith(
          (ref) async => SyncEngineConfig(
            backend: h.backend,
            deviceId: h.device,
            deviceName: h.device,
            network: h.network,
            storage: h.storage,
            collections: [
              for (final type in ['note', 'diary', 'thought'])
                DriftSyncCollection(h.db, type),
            ],
            canSync: resetStorage.canSync,
          ),
        ),
      ],
    );
    try {
      await container.read(syncCoordinatorProvider.future);
      final engine = container.read(syncEngineProvider.notifier);
      await engine.syncNow(manual: true);
      final oldRepo = container.read(notesRepositoryProvider);
      h.drive.failDelete = true;
      await container
          .read(accountResetProvider.notifier)
          .reset(expectedAccountId: 'owner');
      expect(container.read(accountResetProvider).pending, true);
      expect(h.db.writingBlocked, true);
      expect(await resetStorage.canSync(), false);
      await expectLater(
        oldRepo.putDraft(
          id: 'b' * 32,
          text: const PlainTextDocument(body: 'late'),
          baseRevision: 0,
          expectedDraftRevision: null,
        ),
        throwsStateError,
      );
      container.invalidate(accountResetProvider);
      await container.read(accountResetProvider.notifier).ready;
      expect(container.read(accountResetProvider).blocksDataAccess, true);
      h.drive.failDelete = false;
      vectors.failReset = true;
      await container.read(accountResetProvider.notifier).reset();
      expect(container.read(accountResetProvider).completed, false);
      expect(await resetStorage.canSync(), false);
      vectors.failReset = false;
      await container.read(accountResetProvider.notifier).reset();
      expect(container.read(accountResetProvider).completed, true);
      expect(tasks.value, isNull);
      expect(vectors.resets, greaterThanOrEqualTo(2));
      expect(
        container.read(companionControllerProvider).computers,
        hasLength(1),
      );
      expect(h.backend.auth.isSignedIn, false);
      expect(h.db.writingBlocked, false);
      expect(await resetStorage.canSync(), true);
      expect(await h.db.select(h.db.notes).get(), isEmpty);
      await expectLater(
        oldRepo.putDraft(
          id: 'b' * 32,
          text: const PlainTextDocument(body: 'late'),
          baseRevision: 0,
          expectedDraftRevision: null,
        ),
        throwsStateError,
      );
      final current = container.read(notesRepositoryProvider);
      await current.putDraft(
        id: 'c' * 32,
        text: const PlainTextDocument(body: 'fresh'),
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      expect((await current.openDocument('c' * 32)).draft!.text.body, 'fresh');
    } finally {
      container.dispose();
      await h.close();
      await directory.delete(recursive: true);
    }
  });
}
