import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_wise/sync_wise.dart';

import 'support/fake_drive.dart';

void main() {
  late Directory root;
  late String dbPath;
  late FakeDrive drive;
  late FakeDriveBackend backend;
  late FakeNetwork network;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync-wise-engine-');
    dbPath = p.join(root.path, 'app.sqlite');
    drive = FakeDrive();
    backend = FakeDriveBackend(drive);
    network = FakeNetwork();
    _writeDatabase(dbPath, rows: ['first'], version: 3);
  });
  tearDown(() => root.delete(recursive: true));

  BackupEngine engine({
    int schema = 3,
    List<BackupHook> hooks = const [],
    List<BackupFileSet> files = const [],
    DateTime Function()? now,
    BackupNotifier? notifier,
  }) => BackupEngine(
    config: BackupConfig(
      appId: 'app',
      stateDirectory: Directory(p.join(root.path, 'state')),
      chunkSize: 256 * 1024,
    ),
    source: SqliteBackupSource(databasePath: dbPath, schemaVersion: schema),
    backend: backend,
    network: network,
    beforeBackup: hooks,
    fileSets: files,
    deviceName: 'Test phone',
    notifier: notifier,
    now: now,
  );

  List<FakeFile> snapshots({String? state}) => drive.files.values
      .where(
        (f) =>
            f.properties['swKind'] == 'snapshot' &&
            (state == null || f.properties['swState'] == state),
      )
      .toList();

  test('backs up a verified snapshot and restores it', () async {
    final notifier = RecordingNotifier();
    final first = engine(notifier: notifier);
    final result = await first.backUpNow();
    expect(result.error, isNull, reason: '${result.error?.cause}');
    expect(result.lastSuccess, isNotNull);
    expect(snapshots(state: 'committed'), hasLength(1));
    final stored = snapshots().single;
    expect(stored.properties['swApp'], 'app');
    expect(stored.properties['swSchema'], '3');
    expect(stored.properties['swDevice'], 'Test phone');
    expect(stored.properties['swFormat'], '1');
    expect(notifier.events.last, 'clear');
    expect(
      await Directory(p.join(root.path, 'state', 'staging')).exists(),
      isFalse,
    );

    _writeDatabase(dbPath, rows: ['changed'], version: 3);
    final backup = (await first.latestBackup())!;
    var closed = 0, reopened = 0;
    final restored = await first.restore(
      backup,
      closeDatabase: () async => closed++,
      reopenDatabase: () async => reopened++,
    );
    expect(restored.databaseRestored, isTrue);
    expect((closed, reopened), (1, 1));
    expect(_rows(dbPath), ['first']);
    expect(await File('$dbPath.before-restore').exists(), isTrue);

    // The next backup removes the copy kept by the restore.
    await first.backUpNow();
    expect(await File('$dbPath.before-restore').exists(), isFalse);
  });

  test(
    'format 1 reads unmarked backups and leaves newer formats alone',
    () async {
      expect((await engine().backUpNow()).error, isNull);
      final current = snapshots(state: 'committed').single;
      // Backups made before the format marker are format 1.
      current.properties.remove('swFormat');
      final newer = drive.add(
        {...current.properties, 'swFormat': '2'},
        bytes: current.bytes,
        created: DateTime.utc(2030),
      );
      final latest = (await engine().latestBackup())!;
      expect(latest.id, current.id);
      for (var i = 0; i < 3; i++) {
        expect((await engine().backUpNow()).error, isNull);
      }
      expect(drive.files.containsKey(newer.id), isTrue);
    },
  );

  test('a dropped connection resumes from the server offset', () async {
    _writeDatabase(dbPath, rows: ['big'], version: 3, blob: 900 * 1024);
    var drops = 0;
    drive.onChunk = (session, offset, length) {
      if (offset > 0 && drops == 0) {
        drops++;
        return length ~/ 2; // Half the chunk arrives, then the socket dies.
      }
      return null;
    };
    final result = await engine().backUpNow();
    expect(result.error, isNull, reason: '${result.error?.cause}');
    expect(drops, 1);
    expect(drive.sessionsCreated, 1);
    final file = snapshots(state: 'committed').single;
    expect(file.bytes.length, result.lastSize);
  });

  test('a killed run continues with the same snapshot and session', () async {
    _writeDatabase(dbPath, rows: ['big'], version: 3, blob: 900 * 1024);
    drive.onChunk = (session, offset, length) =>
        offset >= 512 * 1024 ? throw const HttpException('killed') : null;
    // Non-transient here: retries are exhausted, so the run stops.
    final first = await engine().backUpNow();
    expect(first.error, isNotNull);
    expect(first.resumable, isTrue);
    expect(snapshots(state: 'committed'), isEmpty);
    final journal = File(p.join(root.path, 'state', 'job.json'));
    final before = await journal.readAsString();

    drive.onChunk = null;
    // A new engine, as after a process restart, with a changed database:
    // the staged snapshot is still the one uploaded.
    _writeDatabase(dbPath, rows: ['later'], version: 3);
    final second = await engine().backUpNow();
    expect(second.error, isNull, reason: '${second.error?.cause}');
    expect(drive.sessionsCreated, 1);
    expect(before, contains('"session":"https://upload.test/session/'));
    final restoredTo = p.join(root.path, 'check.sqlite');
    await File(dbPath).copy(restoredTo);
    final backup = (await engine().latestBackup())!;
    await engine().restore(
      backup,
      closeDatabase: () async {},
      reopenDatabase: () async {},
    );
    expect(_rows(dbPath), ['big']);
  });

  test(
    'a checksum mismatch is never committed and is captured again',
    () async {
      drive.reportWrongMd5 = true;
      final result = await engine().backUpNow();
      expect(result.error?.kind, BackupErrorKind.corrupt);
      expect(snapshots(), isEmpty);
      expect(result.resumable, isFalse);
      drive.reportWrongMd5 = false;
      expect((await engine().backUpNow()).error, isNull);
      expect(snapshots(state: 'committed'), hasLength(1));
    },
  );

  test(
    'keeps the newest generations and clears stale partial uploads',
    () async {
      var clock = DateTime(2026, 11, 1, 2);
      final old = drive.add({
        'swApp': 'app',
        'swKind': 'snapshot',
        'swState': 'uploading',
      }, created: DateTime.utc(2026, 10, 1));
      final foreign = drive.add({
        'swApp': 'other',
        'swKind': 'snapshot',
        'swState': 'committed',
      });
      for (var day = 0; day < 3; day++) {
        clock = clock.add(const Duration(days: 1));
        final result = await engine(now: () => clock).backUpNow();
        expect(result.error, isNull, reason: '${result.error?.cause}');
      }
      final committed = snapshots(state: 'committed')
          .where((f) => f.properties['swApp'] == 'app')
          .toList();
      expect(committed, hasLength(2));
      expect(drive.files.containsKey(old.id), isFalse);
      expect(drive.files.containsKey(foreign.id), isTrue);
      final latest = (await engine().latestBackup())!;
      expect(latest.createdAt, clock);
    },
  );

  test('scheduled runs never upload an empty source', () async {
    final e = BackupEngine(
      config: BackupConfig(
        appId: 'app',
        stateDirectory: Directory(p.join(root.path, 'state')),
      ),
      source: SqliteBackupSource(databasePath: dbPath, schemaVersion: 3),
      backend: backend,
      isEmpty: () async => true,
    );
    final skipped = await e.backUpNow(trigger: BackupTrigger.scheduled);
    expect(skipped.error?.kind, BackupErrorKind.empty);
    expect(drive.sessionsCreated, 0);
    expect((await e.backUpNow()).error, isNull);
  });

  test('a failing hook stops the backup before anything is uploaded', () async {
    final result = await engine(
      hooks: [() async => throw StateError('migration failed')],
    ).backUpNow();
    expect(result.error, isNotNull);
    expect(drive.sessionsCreated, 0);
    expect(result.resumable, isFalse);
  });

  test('scheduled runs wait for Wi-Fi unless mobile data is allowed', () async {
    network.unmetered = false;
    final scheduled = await engine().backUpNow(
      trigger: BackupTrigger.scheduled,
    );
    expect(scheduled.error?.kind, BackupErrorKind.offline);
    expect(drive.sessionsCreated, 0);
    final manual = await engine().backUpNow();
    expect(manual.error, isNull);
    final cellular = engine();
    await cellular.writeSettings(const BackupSettings(allowCellular: true));
    expect(
      (await cellular.backUpNow(trigger: BackupTrigger.scheduled)).error,
      isNull,
    );
  });

  test('a long-failing scheduled backup notifies once', () async {
    var clock = DateTime(2026, 11, 1);
    final notifier = RecordingNotifier();
    network.online = false;
    for (var day = 0; day < 5; day++) {
      await engine(
        now: () => clock,
        notifier: notifier,
      ).backUpNow(trigger: BackupTrigger.scheduled);
      clock = clock.add(const Duration(days: 1));
    }
    expect(notifier.events.where((e) => e == 'failed'), hasLength(1));
  });

  test('refuses backups from a newer schema and damaged downloads', () async {
    expect((await engine(schema: 5).backUpNow()).error, isNull);
    final newer = (await engine().latestBackup())!;
    await expectLater(
      engine(schema: 4).restore(
        newer,
        closeDatabase: () async => fail('must not close'),
        reopenDatabase: () async {},
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.kind,
          'kind',
          BackupErrorKind.incompatible,
        ),
      ),
    );
    final stored = drive.files[newer.id]!;
    stored.content = Uint8List.fromList(List.of(stored.bytes)..[10] ^= 0xff);
    await expectLater(
      engine(schema: 5).restore(
        newer,
        closeDatabase: () async => fail('must not close'),
        reopenDatabase: () async {},
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.kind,
          'kind',
          BackupErrorKind.corrupt,
        ),
      ),
    );
    expect(_rows(dbPath), ['first']);
  });

  test('restore resumes an interrupted download', () async {
    _writeDatabase(dbPath, rows: ['big'], version: 3, blob: 600 * 1024);
    expect((await engine().backUpNow()).error, isNull);
    _writeDatabase(dbPath, rows: [], version: 3);
    final backup = (await engine().latestBackup())!;
    drive.dropDownloadAfter = 100 * 1024;
    final result = await engine().restore(
      backup,
      closeDatabase: () async {},
      reopenDatabase: () async {},
    );
    expect(result.databaseRestored, isTrue);
    expect(_rows(dbPath), ['big']);
    expect(
      drive.requests.where((r) => r.startsWith('GET /drive/v3/files/')).length,
      greaterThan(2),
    );
  });

  test('only one backup runs at a time across engines', () async {
    final lock = BackupLock(File(p.join(root.path, 'state', 'lock.json')));
    expect(await lock.tryAcquire(), isTrue);
    final blocked = await engine().backUpNow();
    expect(blocked.error?.kind, BackupErrorKind.busy);
    await lock.release();
    expect((await engine().backUpNow()).error, isNull);
  });

  test('a lock left by a killed process is taken over', () async {
    var clock = DateTime(2026, 11, 17, 2);
    final file = File(p.join(root.path, 'lock.json'));
    final dead = BackupLock(file, now: () => clock);
    expect(await dead.tryAcquire(), isTrue);
    final other = BackupLock(file, now: () => clock);
    expect(await other.tryAcquire(), isFalse);
    clock = clock.add(const Duration(minutes: 3));
    expect(await other.tryAcquire(), isTrue);
    await other.release();
    await dead.release();
  });

  test('suspended engines refuse to run until reset finishes', () async {
    final e = engine();
    await e.suspendForReset();
    expect((await e.backUpNow()).error?.kind, BackupErrorKind.busy);
    await e.resumeAfterReset(completed: true);
    expect((await e.backUpNow()).error, isNull);
  });

  test('files upload once by content and restore when missing', () async {
    final photos = Directory(p.join(root.path, 'support', 'photos'));
    await photos.create(recursive: true);
    final bytes = List.generate(4000, (i) => Random(i).nextInt(256));
    await File(p.join(photos.path, 'a.jpg')).writeAsBytes(bytes);
    await File(p.join(photos.path, 'b.jpg')).writeAsBytes(bytes);
    await File(p.join(photos.path, 'c.partial')).writeAsBytes([1]);
    final set = BackupFileSet(
      name: 'photos',
      root: Directory(p.join(root.path, 'support')),
      include: const ['photos'],
      filter: (path) => !path.endsWith('.partial'),
    );
    expect((await engine(files: [set]).backUpNow()).error, isNull);
    List<FakeFile> stored() => drive.files.values
        .where((f) => f.properties['swKind'] == 'file')
        .toList();
    expect(stored(), hasLength(1));
    expect((await engine(files: [set]).backUpNow()).error, isNull);
    expect(stored(), hasLength(1));

    await File(p.join(photos.path, 'a.jpg')).delete();
    final backup = (await engine(files: [set]).latestBackup())!;
    expect(backup.filesManifestId, isNotNull);
    final restorer = engine(files: [set]);
    final result = await restorer.restore(
      backup,
      closeDatabase: () async {},
      reopenDatabase: () async {},
    );
    expect(result.filesError, isNull);
    expect(result.filesPending, isTrue);
    expect(await restorer.filesPending(), isTrue);
    expect((await restorer.restoreFiles()).error, isNull);
    expect(await restorer.filesPending(), isFalse);
    expect(await File(p.join(photos.path, 'a.jpg')).readAsBytes(), bytes);
  });

  group('files', () {
    late Directory support;
    late Directory photos;
    setUp(() async {
      support = Directory(p.join(root.path, 'support'));
      photos = Directory(p.join(support.path, 'photos'));
      await photos.create(recursive: true);
    });

    List<FakeFile> stored() => drive.files.values
        .where((f) => f.properties['swKind'] == 'file')
        .toList();

    Future<Map<String, List<int>>> write(int count, {int size = 3000}) async {
      final written = <String, List<int>>{};
      for (var i = 0; i < count; i++) {
        final bytes = List.generate(
          size,
          (j) => Random(i * 997 + j).nextInt(256),
        );
        await File(p.join(photos.path, 'p$i.jpg')).writeAsBytes(bytes);
        written['photos/p$i.jpg'] = bytes;
      }
      return written;
    }

    BackupFileSet set({Set<String>? only}) => BackupFileSet(
      name: 'photos',
      root: support,
      include: const ['photos'],
      select: only == null ? null : () async => only,
    );

    Future<BackupEngine> restoredWithout(
      Iterable<String> missing, {
      BackupFileSet? files,
    }) async {
      final backup = (await engine(files: [files ?? set()]).latestBackup())!;
      for (final path in missing) {
        await File(p.join(support.path, path)).delete();
      }
      final e = engine(files: [files ?? set()]);
      final result = await e.restore(
        backup,
        closeDatabase: () async {},
        reopenDatabase: () async {},
      );
      expect(result.filesPending, isTrue);
      return e;
    }

    test('select backs up only the chosen paths', () async {
      await write(3);
      final chosen = set(
        only: {'photos/p0.jpg', 'photos/p2.jpg', '../x', 'other/p1.jpg'},
      );
      expect((await engine(files: [chosen]).backUpNow()).error, isNull);
      expect(stored(), hasLength(2));
    });

    test(
      'restore leaves files for the background and reports progress',
      () async {
        final written = await write(4);
        expect((await engine(files: [set()]).backUpNow()).error, isNull);
        final e = await restoredWithout(written.keys);
        expect(
          await File(p.join(support.path, 'photos/p0.jpg')).exists(),
          isFalse,
        );
        expect((await e.load()).filesPending, isTrue);

        final states = <BackupState>[];
        final landed = <String>[];
        final sub1 = e.states.listen(states.add);
        final sub2 = e.restoredFiles.listen(landed.add);
        final done = await e.restoreFiles();
        await sub1.cancel();
        await sub2.cancel();
        expect(done.error, isNull);
        expect(done.filesPending, isFalse);
        expect(landed.toSet(), written.keys.toSet());
        for (final MapEntry(:key, :value) in written.entries) {
          expect(await File(p.join(support.path, key)).readAsBytes(), value);
        }
        final progress = states
            .where((s) => s.activity == BackupActivity.restoringFiles)
            .toList();
        expect(progress, isNotEmpty);
        expect(progress.first.bytesTotal, 4 * 3000);
        expect(progress.last.bytesDone, 4 * 3000);
        expect(await e.filesPending(), isFalse);
      },
    );

    test('media waits for Wi-Fi when cellular is not allowed', () async {
      final written = await write(2);
      expect((await engine(files: [set()]).backUpNow()).error, isNull);
      final e = await restoredWithout(written.keys);
      network.unmetered = false;
      final waiting = await e.restoreFiles();
      expect(waiting.error?.kind, BackupErrorKind.offline);
      expect(waiting.filesPending, isTrue);
      network.unmetered = true;
      expect((await e.restoreFiles()).error, isNull);
      expect(await e.filesPending(), isFalse);
    });

    test('an interrupted restore resumes with the same total', () async {
      final written = await write(3, size: 40000);
      expect((await engine(files: [set()]).backUpNow()).error, isNull);
      final e = await restoredWithout(written.keys);
      final stop = e.states.listen((s) {
        if (s.activity == BackupActivity.restoringFiles && s.bytesDone > 0) {
          e.cancel();
        }
      });
      final failed = await e.restoreFiles();
      await stop.cancel();
      expect(failed.error?.kind, BackupErrorKind.cancelled);
      expect(failed.filesPending, isTrue);
      final states = <BackupState>[];
      final sub = e.states.listen(states.add);
      expect((await e.restoreFiles()).error, isNull);
      await sub.cancel();
      final first = states.firstWhere(
        (s) => s.activity == BackupActivity.restoringFiles,
      );
      expect(first.bytesTotal, 3 * 40000);
      for (final MapEntry(:key, :value) in written.entries) {
        expect(await File(p.join(support.path, key)).readAsBytes(), value);
      }
    });

    test(
      'a backup restores pending files first and keeps them in the cloud',
      () async {
        final written = await write(3);
        expect((await engine(files: [set()]).backUpNow()).error, isNull);
        final e = await restoredWithout(written.keys);
        final result = await e.backUpNow();
        expect(result.error, isNull);
        expect(result.filesPending, isFalse);
        expect(await e.filesPending(), isFalse);
        for (final key in written.keys) {
          expect(await File(p.join(support.path, key)).exists(), isTrue);
        }
        expect(stored(), hasLength(3));
      },
    );

    test('a prioritized file downloads first', () async {
      final written = await write(6);
      expect((await engine(files: [set()]).backUpNow()).error, isNull);
      final e = await restoredWithout(written.keys);
      e.prioritize('photos/p5.jpg');
      drive.requests.clear();
      expect((await e.restoreFiles()).error, isNull);
      final first = drive.requests.firstWhere((r) {
        final id = r.split('/').last;
        return r.startsWith('GET') &&
            drive.files[id]?.properties['swKind'] == 'file';
      });
      expect(
        drive.files[first.split('/').last]!.properties['swSha256'],
        '${sha256.convert(written['photos/p5.jpg']!)}',
      );
    });
  });

  group('settings', () {
    test('due by interval with slack', () {
      final now = DateTime(2026, 11, 17, 2);
      const daily = BackupSettings();
      expect(daily.isDue(null, now), isTrue);
      expect(daily.isDue(now.subtract(const Duration(hours: 23)), now), isTrue);
      expect(
        daily.isDue(now.subtract(const Duration(hours: 12)), now),
        isFalse,
      );
      const weekly = BackupSettings(interval: BackupInterval.weekly);
      expect(weekly.isDue(now.subtract(const Duration(days: 3)), now), isFalse);
      expect(weekly.isDue(now.subtract(const Duration(days: 7)), now), isTrue);
      const manual = BackupSettings(interval: BackupInterval.manual);
      expect(manual.isDue(null, now), isFalse);
    });

    test('round trips through the settings file', () async {
      final e = engine();
      expect(await e.readSettings(), const BackupSettings());
      await e.writeSettings(
        const BackupSettings(
          interval: BackupInterval.monthly,
          allowCellular: true,
        ),
      );
      expect(
        await engine().readSettings(),
        const BackupSettings(
          interval: BackupInterval.monthly,
          allowCellular: true,
        ),
      );
    });
  });
}

void _writeDatabase(
  String path, {
  required List<String> rows,
  required int version,
  int blob = 0,
}) {
  for (final suffix in ['', '-journal']) {
    final file = File('$path$suffix');
    if (file.existsSync()) file.deleteSync();
  }
  final db = sqlite3.open(path);
  db.execute('CREATE TABLE notes (body TEXT, data BLOB)');
  final random = Random(7);
  for (final row in rows) {
    db.execute('INSERT INTO notes VALUES (?, ?)', [
      row,
      Uint8List.fromList(List.generate(blob, (_) => random.nextInt(256))),
    ]);
  }
  db.execute('PRAGMA user_version = $version');
  db.close();
}

List<String> _rows(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return [
      for (final row in db.select('SELECT body FROM notes'))
        row['body'] as String,
    ];
  } finally {
    db.close();
  }
}
