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
class Phone {
  Phone(this.root, this.backend, {RecordingSchedule? schedule})
    : schedule = schedule ?? RecordingSchedule();
  final Directory root;
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

  test('launch signs in, schedules overnight backups and backs up when due', () async {
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
    expect(phone.container.read(restoreOfferProvider), isNull);
  });

  test('a new, empty phone is offered the backup and restores it', () async {
    final drive = FakeDrive();
    final old = Phone(dir('old'), FakeDriveBackend(drive, appId: 'redkeep'));
    addTearDown(old.dispose);
    await _note(old.db, 'a' * 32, 'Kept safe');
    expect((await old.engine.backUpNow()).error, isNull);

    final phone = Phone(dir('new'), FakeDriveBackend(drive, appId: 'redkeep'));
    addTearDown(phone.dispose);
    // An empty phone never backs up automatically over the cloud copy.
    await phone.container.read(backupCoordinatorProvider.future);
    final offer = phone.container.read(restoreOfferProvider);
    expect(offer?.backup, isNotNull);
    expect(
      drive.files.values.where((f) => f.properties['swKind'] == 'snapshot'),
      hasLength(1),
    );

    final before = phone.db;
    final oldRepository = phone.container.read(notesRepositoryProvider);
    final result = await phone.container
        .read(backupActionsProvider)
        .restore(offer!.backup!);
    expect(result.databaseRestored, isTrue);
    expect(phone.container.read(restoringProvider), isFalse);
    expect(phone.container.read(restoreOfferProvider), isNull);
    expect(identical(phone.db, before), isFalse);
    expect(phone.db.writingBlocked, isFalse);
    final notes = phone.container.read(notesRepositoryProvider);
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
  });

  test('interrupted resets block writing, resume and clear local data', () async {
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
  });
}
