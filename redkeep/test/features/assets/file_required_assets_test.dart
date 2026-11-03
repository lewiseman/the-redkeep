import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/assets/data/asset_download_client.dart';
import 'package:redkeep/features/assets/data/file_required_assets.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

import '../../support/asset_test_pack.dart';

void main() {
  late Directory temporary;
  late Directory root;
  late TestAssetClient client;
  FileRequiredAssets store({AssetCatalog? catalog, AssetLocation? location}) =>
      FileRequiredAssets(
        catalog: catalog ?? testCatalog(),
        root: root,
        location: location ?? AssetLocation('https://fixtures.redkeep.test/'),
        client: client,
        // Storage edge cases use tiny synthetic bytes; real image qualification
        // has its own suite with the production verifier and local originals.
        verifyImage: (_, _) async {},
      );
  File file(String path) => File.fromUri(root.uri.resolve(path));
  final storageError = isA<AssetException>().having(
    (e) => e.failure,
    'failure',
    AssetFailure.storage,
  );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('redkeep-assets-test-');
    root = Directory.fromUri(temporary.uri.resolve('artwork/'));
    client = TestAssetClient();
  });
  tearDown(() => temporary.delete(recursive: true));

  test('fresh offline blocks; completed offline launch and resolver use no network', () async {
    expect(await store().inspect(), ['test.one', 'test.two']);
    expect(client.requests, isEmpty);
    final progress = <AssetProgress>[];
    await store().download(progress.add);
    expect(progress.last.completedBytes, 8);
    expect(progress.last.totalBytes, 8);
    client.requests.clear();
    client.response = (_) => throw const SocketException('offline');
    final reopened = store(location: AssetLocation(''));
    expect(await reopened.inspect(), isEmpty);
    expect(
      await reopened.resolve('test.one'),
      Uri.file(await file('art/one.png').resolveSymbolicLinks()),
    );
    await reopened.download((_) {});
    expect(client.requests, isEmpty);
  });

  test('an injected receive deadline rejects an overlong transfer', () async {
    final assets = FileRequiredAssets(
      catalog: testCatalog(),
      root: root,
      location: AssetLocation('https://fixtures.redkeep.test/'),
      client: client,
      createDownloadTimer: _ExpiredDownloadTimer.new,
      verifyImage: (_, _) async {},
    );
    await expectLater(
      assets.download((_) {}),
      throwsA(
        isA<AssetException>().having(
          (e) => e.failure,
          'failure',
          AssetFailure.network,
        ),
      ),
    );
    expect(await file('art/one.png').exists(), isFalse);
    expect(await file('art/one-pending.png').exists(), isFalse);
  });

  test(
    'saved keys do not hide missing, truncated or same-size replaced files',
    () async {
      await store().download((_) {});
      await file('art/one.png').delete();
      expect(await store().inspect(), ['test.one']);
      await store().download((_) {});
      final target = file('art/two.png');
      final modified = await target.lastModified();
      await target.writeAsBytes([0, 0, 0, 0], flush: true);
      await target.setLastModified(modified);
      // ctime detects a same-size replacement even when mtime is restored.
      expect(await store().inspect(), ['test.two']);
      await store().download((_) {});
      await target.writeAsBytes([0]);
      expect(await store().inspect(), ['test.two']);
      await expectLater(
        store().resolve('test.two'),
        throwsA(isA<AssetException>()),
      );
    },
  );

  test(
    'revision/hash changes at the same path force verification and replacement',
    () async {
      await store().download((_) {});
      final json = testCatalogJson();
      final row = (json['assets'] as List).first;
      row['revision'] = 'v2';
      row['sha256'] = sha256.convert([9, 9, 9, 9]).toString();
      final next = store(catalog: AssetCatalog.parse(jsonEncode(json)));
      expect(await next.inspect(), ['test.one']);
      client.response = (_) => Stream.value([9, 9, 9, 9]);
      await next.download((_) {});
      expect(await next.inspect(), isEmpty);
      expect(await file('art/one.png').readAsBytes(), [9, 9, 9, 9]);
    },
  );

  test('interruption keeps completed files and retry downloads only the missing file', () async {
    client.response = (uri) async* {
      if (uri.path.endsWith('one.png')) {
        yield testPayloads['art/one.png']!;
      } else {
        yield [5, 6];
        throw const SocketException('interrupted');
      }
    };
    await expectLater(
      store().download((_) {}),
      throwsA(
        isA<AssetException>().having(
          (e) => e.failure,
          'failure',
          AssetFailure.network,
        ),
      ),
    );
    expect(
      await file('art/one.png').readAsBytes(),
      testPayloads['art/one.png'],
    );
    expect(await file('art/two.png').exists(), isFalse);
    expect(await file('art/two-pending.png').exists(), isFalse);
    // Simulate process termination with an abandoned, unverified temporary file.
    await file('art/two-pending.png').writeAsBytes([5, 6]);
    final restarted = store();
    expect(await restarted.inspect(), ['test.two']);
    client.requests.clear();
    client.response = null;
    await restarted.download((_) {});
    expect(client.requests, ['/art/two.png']);
    expect(await restarted.inspect(), isEmpty);
    expect(await file('art/two-pending.png').exists(), isFalse);
  });

  for (final bytes in [
    [1, 2],
    [0, 0, 0, 0],
    [1, 2, 3, 4, 5],
  ]) {
    test('rejects short, corrupt or oversized streams: $bytes', () async {
      client.response = (_) => Stream.value(bytes);
      await expectLater(
        store().download((_) {}),
        throwsA(
          isA<AssetException>().having(
            (e) => e.failure,
            'failure',
            AssetFailure.integrity,
          ),
        ),
      );
      expect(await file('art/one.png').exists(), isFalse);
      expect(await store().inspect(), ['test.one', 'test.two']);
    });
  }

  test(
    'verified rename before ledger commit is recovered offline after restart',
    () async {
      await file('art/one.png').parent.create(recursive: true);
      await file('art/one.png').writeAsBytes(testPayloads['art/one.png']!);
      expect(await store().inspect(), ['test.two']);
      await file('ledger.json').writeAsBytes([255]);
      expect(await store().inspect(), ['test.two']);
      expect(client.requests, isEmpty);
    },
  );

  test('storage failure is retryable and never touches the adjacent primary database', () async {
    final primary = File.fromUri(temporary.uri.resolve('redkeep.sqlite'));
    await primary.writeAsString('synthetic writing sentinel');
    await root.create();
    await Directory.fromUri(root.uri.resolve('art/one-pending.png/'))
        .create(recursive: true);
    await expectLater(store().download((_) {}), throwsA(storageError));
    expect(await primary.readAsString(), 'synthetic writing sentinel');
    await Directory.fromUri(root.uri.resolve('art/one-pending.png/')).delete();
    await store().download((_) {});
    expect(await store().inspect(), isEmpty);
    expect(await primary.readAsString(), 'synthetic writing sentinel');
  });

  test(
    'ledger commit failure retains verified payload for a network-free retry',
    () async {
      await root.create();
      await Directory.fromUri(root.uri.resolve('ledger-pending.json/'))
          .create();
      await expectLater(store().download((_) {}), throwsA(storageError));
      expect(await file('art/one.png').exists(), isTrue);
      await Directory.fromUri(root.uri.resolve('ledger-pending.json/'))
          .delete();
      expect(await store().inspect(), ['test.two']);
      client.requests.clear();
      await store().download((_) {});
      expect(client.requests, ['/art/two.png']);
    },
  );

  test(
    'rejects root, directory, target and temporary symlinks without escaping',
    () async {
      final outside = File.fromUri(temporary.uri.resolve('outside.png'));
      await outside.writeAsString('outside sentinel');
      await root.create();
      final directoryLink = Link.fromUri(root.uri.resolve('art'));
      await directoryLink.create(temporary.path);
      await expectLater(store().inspect(), throwsA(storageError));
      await directoryLink.delete();
      await file('art/one.png').parent.create();
      for (final path in [
        'art/one.png',
        'art/one-pending.png',
        'ledger.json',
      ]) {
        final link = Link(file(path).path);
        await link.create(outside.path);
        await expectLater(store().download((_) {}), throwsA(storageError));
        await link.delete();
      }
      await root.delete(recursive: true);
      final rootLink = Link(root.path.replaceFirst(RegExp(r'/+$'), ''));
      await rootLink.create(temporary.path);
      await expectLater(store().inspect(), throwsA(storageError));
      await rootLink.delete();
      expect(await outside.readAsString(), 'outside sentinel');
    },
  );

  test('explicit verification repairs forged/stale ledger stats and concurrent resolves serialize', () async {
    final assets = store();
    await assets.download((_) {});
    final target = file('art/one.png');
    await target.writeAsBytes([0, 0, 0, 0]);
    final ledgerFile = file('ledger.json');
    final ledger = jsonDecode(await ledgerFile.readAsString()) as Map;
    final stat = await target.stat();
    ledger['installed']['test.one']['modified'] =
        stat.modified.microsecondsSinceEpoch;
    ledger['installed']['test.one']['changed'] =
        stat.changed.microsecondsSinceEpoch;
    await ledgerFile.writeAsString(jsonEncode(ledger));
    expect(await assets.inspect(verifyAll: true), ['test.one']);
    await assets.download((_) {});
    expect(
      await Future.wait([
        assets.resolve('test.one'),
        assets.resolve('test.two'),
      ]),
      hasLength(2),
    );
  });
}

class _ExpiredDownloadTimer implements Stopwatch {
  @override
  Duration get elapsed => const Duration(minutes: 3);
  @override
  void start() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
