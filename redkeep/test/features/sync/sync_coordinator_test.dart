import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_cloud.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/onboarding/application/onboarding_controller.dart';
import 'package:redkeep/features/onboarding/application/onboarding_restore.dart';
import 'package:redkeep/features/onboarding/data/drift_onboarding_repository.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/sync/data/redkeep_backup.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../packages/sync_wise/test/support/fake_drive.dart'
    show FakeDrive, FakeDriveBackend;
import '../../support/fake_ai_provider.dart';
import '../../support/fake_backup.dart';

Future<void> _note(AppDatabase db, String id, String body) =>
    DriftNotesRepository(db, clock: DateTime.now).saveNote(
      id: id,
      text: PlainTextDocument(body: body),
      expectedRevision: 0,
      details: const NoteDetails(),
    );

/// One phone: a database file, backup state, and the app's providers.
class _Onboarded extends OnboardingController {
  @override
  OnboardingState build() =>
      const OnboardingState(complete: true, name: 'Tester');
}

class Phone {
  Phone(
    this.root,
    this.backend, {
    RecordingSchedule? schedule,
    this.onboarded = true,
  }) : schedule = schedule ?? RecordingSchedule();
  final Directory root;

  /// A fresh install is still in onboarding.
  final bool onboarded;
  final BackupBackend backend;
  final RecordingSchedule schedule;
  late final file = File(p.join(root.path, 'redkeep.sqlite'));
  late final engine = testBackupEngine(
    Directory(p.join(root.path, 'state')),
    backend,
    databasePath: file.path,
    isEmpty: () => redkeepDatabaseIsEmpty(file.path),
  );
  late final container = ProviderContainer(
    overrides: [
      protectedAiProvidersProvider.overrideWithValue(
        MemoryAiProviders(saved: testAiSettings),
      ),
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase(file));
        ref.onDispose(db.close);
        return db;
      }),
      syncBackendProvider.overrideWithValue(backend),
      networkServiceProvider.overrideWithValue(QuietNetwork()),
      accountResetStorageProvider.overrideWithValue(
        AccountResetStorage(directory: () async => root),
      ),
      backupEngineProvider.overrideWithValue(AsyncData(engine)),
      backupScheduleProvider.overrideWithValue(schedule),
      if (onboarded) onboardingControllerProvider.overrideWith(_Onboarded.new),
    ],
  );
  AppDatabase get db => container.read(appDatabaseProvider);
  Future<void> dispose() async {
    container.dispose();
    await engine.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A restore reopens the same file as a new database on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Account reset also clears AI keys kept in secure storage.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('redkeep-');
    // Reset clears app-owned media folders under app support.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => p.join(root.path, 'support'),
        );
  });
  tearDown(() => root.delete(recursive: true));

  Directory dir(String name) =>
      Directory(p.join(root.path, name))..createSync(recursive: true);

  test(
    'launch signs in, schedules overnight backups and backs up when due',
    () async {
      final drive = FakeDrive();
      final phone = Phone(dir('a'), FakeDriveBackend(drive, appId: 'redkeep'));
      addTearDown(phone.dispose);
      await _note(phone.db, 'a' * 32, 'Written before the upgrade');
      await phone.container.read(backupCoordinatorProvider.future);
      expect(phone.schedule.applied.single, (const BackupSettings(), true));
      final snapshots = drive.files.values.where(
        (f) =>
            f.properties['swKind'] == 'snapshot' &&
            f.properties['swState'] == 'committed',
      );
      expect(snapshots, hasLength(1));
      expect(phone.container.read(backupStateProvider).lastSuccess, isNotNull);
    },
  );

  test(
    'a fresh install restores during onboarding and keeps the screen',
    () async {
      final drive = FakeDrive();
      final old = Phone(dir('old'), FakeDriveBackend(drive, appId: 'redkeep'));
      addTearDown(old.dispose);
      await DriftOnboardingRepository(old.db).complete('Lewis');
      await _note(old.db, 'a' * 32, 'Kept safe');
      expect((await old.engine.backUpNow()).error, isNull);

      final phone = Phone(
        dir('new'),
        FakeDriveBackend(drive, appId: 'redkeep'),
        onboarded: false,
      );
      addTearDown(phone.dispose);
      final container = phone.container;
      // Nothing is backed up during onboarding, so the cloud copy is safe.
      await container.read(backupCoordinatorProvider.future);
      expect(
        drive.files.values.where((f) => f.properties['swKind'] == 'snapshot'),
        hasLength(1),
      );

      final restore = container.read(onboardingRestoreProvider.notifier);
      await restore.connect();
      expect(
        container.read(onboardingRestoreProvider).phase,
        OnboardingRestorePhase.found,
      );

      final before = phone.db;
      final oldRepository = container.read(notesRepositoryProvider);
      // Like a page that was open: a database stream that is now unwatched,
      // so Riverpod pauses it. Restoring must not wait for it.
      final watched = StreamProvider(
        (ref) => ref
            .watch(appDatabaseProvider)
            .select(ref.watch(appDatabaseProvider).notes)
            .watch(),
      );
      final listener = container.listen(watched, (_, _) {});
      await container.read(watched.future);
      listener.close();
      await Future<void>.delayed(Duration.zero);
      await restore.restore().timeout(const Duration(seconds: 10));

      final restored = container.read(onboardingRestoreProvider);
      expect(restored.phase, OnboardingRestorePhase.restored);
      expect(restored.name, 'Lewis');
      expect(restored.holdsOnboarding, isTrue);
      expect(identical(phone.db, before), isFalse);
      expect(phone.db.writingBlocked, isFalse);
      final notes = container.read(notesRepositoryProvider);
      expect((await notes.openDocument('a' * 32)).note!.text.body, 'Kept safe');
      // Editors opened before the restore cannot write into the new journal.
      await expectLater(
        oldRepository.saveNote(
          id: 'b' * 32,
          text: const PlainTextDocument(body: 'late'),
          expectedRevision: 0,
          details: const NoteDetails(),
        ),
        throwsA(anything),
      );

      // The startup checks rerun on the restored journal, but onboarding stays
      // open until the person continues from the cover.
      final onboarding = container.read(onboardingControllerProvider.notifier);
      await onboarding.load();
      expect(container.read(onboardingControllerProvider).complete, isFalse);
      expect(container.read(onboardingControllerProvider).name, 'Lewis');
      onboarding.confirmRestored('Lewis');
      restore.dismiss();
      expect(container.read(onboardingControllerProvider).complete, isTrue);
      expect(
        container.read(onboardingRestoreProvider).holdsOnboarding,
        isFalse,
      );
    },
  );

  test(
    'signing in during onboarding without a backup leads to the name',
    () async {
      final phone = Phone(
        dir('fresh'),
        FakeDriveBackend(FakeDrive(), appId: 'redkeep'),
        onboarded: false,
      );
      addTearDown(phone.dispose);
      await phone.container.read(onboardingRestoreProvider.notifier).connect();
      expect(
        phone.container.read(onboardingRestoreProvider).phase,
        OnboardingRestorePhase.none,
      );
    },
  );

  test(
    'interrupted resets block writing, resume and clear local data',
    () async {
      final backend = FakeBackupBackend();
      final phone = Phone(dir('reset'), backend);
      addTearDown(phone.dispose);
      await _note(phone.db, 'a' * 32, 'erase');
      final container = phone.container;
      await container.read(backupCoordinatorProvider.future);
      final oldRepo = container.read(notesRepositoryProvider);
      backend.failDeleteAll = true;
      await container
          .read(accountResetProvider.notifier)
          .reset(expectedAccountId: 'owner');
      expect(container.read(accountResetProvider).pending, true);
      expect(phone.db.writingBlocked, true);
      await expectLater(
        oldRepo.saveNote(
          id: 'b' * 32,
          text: const PlainTextDocument(body: 'late'),
          expectedRevision: 0,
          details: const NoteDetails(),
        ),
        throwsStateError,
      );
      container.invalidate(accountResetProvider);
      await container.read(accountResetProvider.notifier).ready;
      expect(container.read(accountResetProvider).blocksDataAccess, true);
      backend.failDeleteAll = false;
      await container.read(accountResetProvider.notifier).reset();
      expect(
        container.read(accountResetProvider).completed,
        true,
        reason: container.read(accountResetProvider).error,
      );
      expect(backend.deletedAll, 1);
      expect(backend.auth.isSignedIn, false);
      expect(phone.db.writingBlocked, false);
      expect(await phone.db.select(phone.db.notes).get(), isEmpty);
      final current = container.read(notesRepositoryProvider);
      await current.saveNote(
        id: 'c' * 32,
        text: const PlainTextDocument(body: 'fresh'),
        expectedRevision: 0,
        details: const NoteDetails(),
      );
      expect((await current.openDocument('c' * 32)).note!.text.body, 'fresh');
    },
  );
}
