import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sync_wise/google_drive.dart';
import 'package:sync_wise/sync_wise.dart';
import 'package:sync_wise/workmanager.dart';

import 'support/fake_drive.dart';

void main() {
  late Directory root;
  late FakeDrive drive;
  late GoogleDriveBackupRemote remote;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync-wise-drive-');
    drive = FakeDrive();
    remote = GoogleDriveBackupRemote(
      drive.client,
      appId: 'app',
      chunkSize: 256 * 1024,
      legacyNamespaces: const [DriveNamespace('legacyNs', 'app-v1')],
      retry: BackupRetry(attempts: 3, sleep: (_) async {}),
    );
  });
  tearDown(() => root.delete(recursive: true));

  Future<File> blob(int length) async {
    final file = File('${root.path}/blob');
    await file.writeAsBytes(
      Uint8List.fromList(List.generate(length, (_) => Random(1).nextInt(256))),
    );
    return file;
  }

  test('uploads in chunks with an owner property', () async {
    final file = await blob(600 * 1024);
    final session = await remote.createUploadSession(
      name: 'x',
      length: 600 * 1024,
      properties: {'swKind': 'snapshot'},
    );
    final sent = <int>[];
    final object = await remote.upload(
      session: session,
      file: file,
      length: 600 * 1024,
      onProgress: sent.add,
    );
    expect(drive.chunkPuts, 3);
    expect(object.properties, containsPair('swApp', 'app'));
    expect(object.size, 600 * 1024);
    expect(sent.last, 600 * 1024);
  });

  test('asks the server for its offset after a failed chunk', () async {
    final file = await blob(600 * 1024);
    var failed = false;
    drive.onChunk = (session, offset, length) {
      if (!failed && offset == 256 * 1024) {
        failed = true;
        return 1000;
      }
      return null;
    };
    final session = await remote.createUploadSession(
      name: 'x',
      length: 600 * 1024,
      properties: const {},
    );
    final object = await remote.upload(
      session: session,
      file: file,
      length: 600 * 1024,
    );
    expect(drive.files[object.id]!.bytes, await file.readAsBytes());
  });

  test('reports an expired session so the caller starts again', () async {
    final file = await blob(1000);
    await expectLater(
      remote.upload(
        session: 'https://upload.test/session/gone',
        file: file,
        length: 1000,
      ),
      throwsA(isA<UploadSessionExpired>()),
    );
  });

  test('ignores and refuses objects owned by other apps', () async {
    final mine = drive.add({'swApp': 'app', 'swKind': 'snapshot'});
    final theirs = drive.add({'swApp': 'other', 'swKind': 'snapshot'});
    expect((await remote.list(kind: 'snapshot')).map((o) => o.id), [mine.id]);
    expect(await remote.get(theirs.id), isNull);
    await remote.delete(theirs.id);
    expect(drive.files.containsKey(theirs.id), isTrue);
    await expectLater(
      remote.download(theirs.id, File('${root.path}/x')),
      throwsFormatException,
    );
  });

  test('reset deletes current and legacy objects only', () async {
    drive.add({'swApp': 'app'});
    drive.add({'legacyNs': 'app-v1'});
    final foreign = drive.add({'legacyNs': 'someone-else'});
    final progress = <int>[];
    await remote.deleteAll(onProgress: (done, _) => progress.add(done));
    expect(drive.files.keys, [foreign.id]);
    expect(progress, [0, 1, 2]);
  });

  test('scheduler targets the next preferred hour', () {
    expect(
      BackupScheduler.delayUntilPreferredHour(DateTime(2026, 11, 17, 22), 2),
      const Duration(hours: 4),
    );
    expect(
      BackupScheduler.delayUntilPreferredHour(DateTime(2026, 11, 17, 1, 50), 2),
      const Duration(days: 1, minutes: 10),
    );
  });

  group('restore recovery', () {
    late Directory state;
    late String db;
    setUp(() async {
      state = Directory('${root.path}/state');
      db = '${root.path}/app.sqlite';
    });

    test('a swap interrupted after moving the old database completes', () async {
      final candidate = File('${root.path}/candidate')
        ..writeAsStringSync('new');
      File('$db${RestoreRecovery.previousSuffix}').writeAsStringSync('old');
      await File('${state.path}/restore.json').create(recursive: true);
      await File('${state.path}/restore.json').writeAsString(
        '{"phase":"swapping","database":"$db","candidate":"${candidate.path}"}',
      );
      await RestoreRecovery.finish(stateDirectory: state, databasePath: db);
      expect(File(db).readAsStringSync(), 'new');
      expect(await File('${state.path}/restore.json').exists(), isFalse);
    });

    test('a missing candidate puts the previous database back', () async {
      File('$db${RestoreRecovery.previousSuffix}').writeAsStringSync('old');
      await File('${state.path}/restore.json').create(recursive: true);
      await File('${state.path}/restore.json').writeAsString(
        '{"phase":"swapping","database":"$db","candidate":"${root.path}/gone"}',
      );
      await RestoreRecovery.finish(stateDirectory: state, databasePath: db);
      expect(File(db).readAsStringSync(), 'old');
    });

    test('swap keeps the previous database and drops stale journals', () async {
      File(db).writeAsStringSync('old');
      File('$db-journal').writeAsStringSync('hot');
      final candidate = File('${root.path}/candidate')
        ..writeAsStringSync('new');
      await RestoreRecovery.swap(
        stateDirectory: state,
        databasePath: db,
        candidate: candidate,
      );
      expect(File(db).readAsStringSync(), 'new');
      expect(File('$db-journal').existsSync(), isFalse);
      expect(
        File('$db${RestoreRecovery.previousSuffix}').readAsStringSync(),
        'old',
      );
    });
  });
}
