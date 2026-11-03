import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:redkeep/features/assets/data/asset_download_client.dart';
import 'package:redkeep/features/assets/data/file_required_assets.dart';
import 'package:redkeep/features/assets/data/verify_asset_image.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

class _LocalClient implements AssetDownloadClient {
  _LocalClient(this.bytes);
  List<int> bytes;
  final requests = <Uri>[];
  @override
  Stream<List<int>> open(Uri uri) {
    requests.add(uri);
    return Stream.value(bytes);
  }
}

void main() {
  final integrity = isA<AssetException>().having(
    (e) => e.failure,
    'failure',
    AssetFailure.integrity,
  );
  test('actual local originals qualify as still PNG, WebP and JPEG; wrong extension, corruption, dimensions and animation fail', () async {
    for (final path in [
      '../website/public/art/theme_light.png',
      '../website/public/art/notes.webp',
      '../website/public/art/flow.jpg',
    ]) {
      final bytes = await File(path).readAsBytes();
      verifyAssetImageBytes(bytes, path);
      expect(
        () => verifyAssetImageBytes(
          bytes,
          path.endsWith('.png') ? 'wrong.webp' : 'wrong.png',
        ),
        throwsA(integrity),
      );
      expect(
        () => verifyAssetImageBytes(Uint8List.sublistView(bytes, 0, 32), path),
        throwsA(integrity),
      );
    }
    final oversized = image.encodePng(image.Image(width: 2049, height: 1));
    expect(
      () => verifyAssetImageBytes(oversized, 'wide.png'),
      throwsA(integrity),
    );
    final animated = image.Image(width: 2, height: 2)
      ..addFrame(image.Image(width: 2, height: 2));
    expect(
      () => verifyAssetImageBytes(image.encodePng(animated), 'animated.png'),
      throwsA(integrity),
    );
  });

  for (final name in ['notes.webp', 'flow.jpg']) {
    test(
      '$name exact local bytes install atomically, reopen offline, repair corruption, and never touch writing',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'redkeep-real-image-',
        );
        addTearDown(() => temp.delete(recursive: true));
        final bytes = await File('../website/public/art/$name').readAsBytes();
        final row = {
          'key': 'test.image',
          'revision': 'v1',
          'path': 'onboarding/$name',
          'bytes': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
          'license': 'LicenseRef-Test',
          'provenance': 'actual local reference',
        };
        final catalog = AssetCatalog.parse(
          jsonEncode({
            'schema': 1,
            'pack': 'test-v1',
            'assets': [row],
          }),
        );
        final client = _LocalClient(bytes);
        final root = Directory('${temp.path}/artwork');
        FileRequiredAssets store() => FileRequiredAssets(
          catalog: catalog,
          root: root,
          location: AssetLocation('https://fixtures.redkeep.test/'),
          client: client,
        );
        final writing = File('${temp.path}/redkeep.sqlite');
        await writing.writeAsString('synthetic writing sentinel');
        expect(await store().inspect(), ['test.image']);
        await store().download((_) {});
        expect(await store().inspect(), isEmpty);
        expect(client.requests, hasLength(1));
        final target = File.fromUri(await store().resolve('test.image'));
        expect(await target.readAsBytes(), bytes);
        final pending = File(target.path.replaceFirst('.', '-pending.'));
        expect(await pending.exists(), false);
        await target.writeAsBytes(List.filled(bytes.length, 0), flush: true);
        await expectLater(store().resolve('test.image'), throwsA(integrity));
        expect(await store().inspect(), ['test.image']);
        client.bytes = bytes.sublist(0, 20);
        await expectLater(store().download((_) {}), throwsA(integrity));
        expect(await pending.exists(), false);
        client.bytes = bytes;
        await store().download((_) {});
        final reopened = store();
        client.requests.clear();
        expect(await reopened.inspect(verifyAll: true), isEmpty);
        await reopened.resolve('test.image');
        expect(client.requests, isEmpty);
        expect(await writing.readAsString(), 'synthetic writing sentinel');
        // Even matching malicious metadata cannot promote undecodable bytes.
        final bad = Uint8List(64);
        row['bytes'] = bad.length;
        row['sha256'] = sha256.convert(bad).toString();
        final badCatalog = AssetCatalog.parse(
          jsonEncode({
            'schema': 1,
            'pack': 'bad-v1',
            'assets': [row],
          }),
        );
        final badStore = FileRequiredAssets(
          catalog: badCatalog,
          root: Directory('${temp.path}/bad'),
          location: AssetLocation('https://fixtures.redkeep.test/'),
          client: _LocalClient(bad),
        );
        await expectLater(badStore.download((_) {}), throwsA(integrity));
        expect(await badStore.inspect(), ['test.image']);
        expect(await File('${temp.path}/bad/onboarding/$name').exists(), false);
      },
    );
  }

  test('M07 installed PNGs survive the UI01 upgrade; only missing originals transfer', () async {
    final temp = await Directory.systemTemp.createTemp('redkeep-pack-upgrade-');
    addTearDown(() => temp.delete(recursive: true));
    final json = jsonDecode(
      await File('assets/catalog/presentation-v1.json').readAsString(),
    ) as Map<String, dynamic>;
    final next = AssetCatalog.parse(jsonEncode(json));
    final old = AssetCatalog.parse(
      jsonEncode({
        ...json,
        'pack': 'presentation-m07-v1',
        'assets': (json['assets'] as List).take(4).toList(),
      }),
    );
    final writing = File('${temp.path}/redkeep.sqlite');
    await writing.writeAsString(
      'existing writing, settings and completion sentinel',
    );
    final client = _WebsiteClient();
    FileRequiredAssets store(AssetCatalog catalog) => FileRequiredAssets(
      catalog: catalog,
      root: Directory('${temp.path}/artwork'),
      location: AssetLocation('https://fixtures.redkeep.test/'),
      client: client,
    );
    await store(old).download((_) {});
    final hashes = <String, String>{};
    for (final asset in old.assets) {
      hashes[asset.key] = sha256
          .convert(
            await File.fromUri(await store(old).resolve(asset.key))
                .readAsBytes(),
          )
          .toString();
    }
    client.requests.clear();
    final upgraded = store(next);
    expect(await upgraded.inspect(), next.assets.skip(4).map((a) => a.key));
    await upgraded.download((_) {});
    expect(
      client.requests.map((u) => u.path),
      next.assets.skip(4).map((a) => '/${a.sourcePath}'),
    );
    expect(await upgraded.inspect(), isEmpty);
    for (final asset in old.assets) {
      expect(
        sha256
            .convert(
              await File.fromUri(await upgraded.resolve(asset.key))
                  .readAsBytes(),
            )
            .toString(),
        hashes[asset.key],
      );
    }
    client.requests.clear();
    expect(await store(next).inspect(), isEmpty);
    expect(client.requests, isEmpty);
    expect(
      await writing.readAsString(),
      'existing writing, settings and completion sentinel',
    );
  });

  test('an existing installation reuses all eleven unchanged images and downloads only the Redkeep cover', () async {
    final temp = await Directory.systemTemp.createTemp(
      'redkeep-website-upgrade-',
    );
    addTearDown(() => temp.delete(recursive: true));
    final catalog = AssetCatalog.parse(
      await File('assets/catalog/presentation-v1.json').readAsString(),
    );
    final root = Directory('${temp.path}/artwork');
    for (final asset in catalog.assets.where(
      (a) => a.key != 'onboarding.cover',
    )) {
      final target = File.fromUri(root.uri.resolve(asset.path));
      await target.parent.create(recursive: true);
      await File('../website/public/art/${asset.sourcePath}').copy(target.path);
    }
    final writing = File('${temp.path}/redkeep.sqlite');
    await writing.writeAsString('existing writing sentinel');
    final client = _WebsiteClient();
    final store = FileRequiredAssets(
      catalog: catalog,
      root: root,
      location: AssetLocation('https://fixtures.redkeep.test/'),
      client: client,
    );
    expect(await store.inspect(), ['onboarding.cover']);
    expect(client.requests, isEmpty);
    await store.download((_) {});
    expect(client.requests.map((u) => u.path), [
      '/cover-redkeep-castle-v1.jpg',
    ]);
    expect(await store.inspect(verifyAll: true), isEmpty);
    client.requests.clear();
    final offline = FileRequiredAssets(
      catalog: catalog,
      root: root,
      location: AssetLocation(''),
      client: client,
    );
    expect(await offline.inspect(), isEmpty);
    await offline.download((_) {});
    expect(client.requests, isEmpty);
    expect(await writing.readAsString(), 'existing writing sentinel');
  });

  test(
    'website catalog matches local sources and preserves installed paths',
    () async {
      final catalog = AssetCatalog.parse(
        await File('assets/catalog/presentation-v1.json').readAsString(),
      );
      expect(catalog.assets, hasLength(22));
      expect(
        catalog.asset('onboarding.cover').sourcePath,
        'cover-redkeep-castle-v1.jpg',
      );
      for (final asset in catalog.assets) {
        final local = await File('../website/public/art/${asset.sourcePath}')
            .readAsBytes();
        expect(asset.bytes, local.length);
        expect(asset.sha256, sha256.convert(local).toString());
      }
      expect(catalog.assets.any((a) => a.key == 'flow.mascot'), isFalse);
      // Branding is always bundled, even on a fresh offline installation.
      for (final entry in {
        'ink-paper.webp': 'ink-paper.webp',
        'grand_maestar.png': 'j.png',
      }.entries) {
        expect(
          await File('assets/branding/${entry.key}').readAsBytes(),
          await File('../website/public/art/${entry.value}').readAsBytes(),
        );
      }
      expect(
        catalog.assets.any((a) => a.key == 'onboarding.background.ink'),
        isFalse,
      );
      expect(
        catalog.assets.any((a) => a.key == 'onboarding.brand.mascot'),
        isFalse,
      );
      expect(
        catalog.assets
            .take(4)
            .map(
              (a) => '${a.key}|${a.revision}|${a.path}|${a.sha256}|${a.bytes}',
            ),
        [
          'appearance.theme.system|v1|appearance/theme-system-v1.png|d4d4de4cb5ad3c83cf66db8838e69395cf61b90c7d697b84d7f3bbe8575c3176|159869',
          'appearance.theme.light|v1|appearance/theme-light-v1.png|2e08abe549f65713bcccfba9d19035c68946f3fbfef3e88b9e24a0c0f66649fc|146694',
          'appearance.theme.dark|v1|appearance/theme-dark-v1.png|dd744501d2cfb75cb83948f0f83568c6dd31fd52e03bbcf538e91f9a6eb87e32|127553',
          'notes.add|v1|notes/add-v1.png|5674c0849f384dc06e9b36ddbc34dd03acac1e2e67b6881a347a8a7a7ecc65b8|45800',
        ],
      );
    },
  );
}

class _WebsiteClient implements AssetDownloadClient {
  final requests = <Uri>[];
  @override
  Stream<List<int>> open(Uri uri) {
    requests.add(uri);
    return File('../website/public/art${uri.path}').openRead();
  }
}
