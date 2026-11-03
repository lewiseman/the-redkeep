import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/assets/data/asset_download_client.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

import '../../../tool/prepare_asset_sources.dart';
import '../../support/asset_test_pack.dart';

void main() {
  test('complete HTTPS object URLs retain encoded names and query; other entries use the directory fallback', () {
    const source =
        'https://firebasestorage.googleapis.com/v0/b/example/o/redkeep%2Fassets%2Fone.webp?alt=media&token=synthetic-token%2B1';
    final location = AssetLocation(
      'https://media.redkeep.test/v1/',
      catalog: testCatalog(),
      sourceUrlsJson: jsonEncode({'test.one': source}),
    );
    expect(location.url('art/one.png').toString(), source);
    expect(
      location.url('art/two.png').toString(),
      'https://media.redkeep.test/v1/art/two.png',
    );
    expect(() => location.url('../one.png'), throwsA(isA<AssetException>()));
    for (final invalid in [
      '{',
      '[]',
      '{"unknown.key":"https://host/image.webp"}',
      ...[
        'http://localhost/image.png',
        'file:///tmp/image.png',
        'https://user:secret@host/image.png',
        'https://host/image.png#fragment',
        'https://host/',
        '',
      ].map((url) => jsonEncode({'test.one': url})),
    ]) {
      expect(
        () =>
            AssetLocation('', catalog: testCatalog(), sourceUrlsJson: invalid),
        throwsA(isA<AssetException>()),
      );
    }
  });

  test('preparation serializes only consumed keys, preserves unrelated configuration, and fails atomically', () async {
    final root = await Directory.systemTemp.createTemp(
      'redkeep-source-config-',
    );
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/input.json');
    final env = File('${root.path}/env.json');
    const url =
        'https://firebasestorage.googleapis.com/v0/b/example/o/folder%2Fnotes.webp?alt=media&token=synthetic';
    await source.writeAsString(
      jsonEncode({
        'onboarding.chapter.notes': url,
        'onboarding.cover': url,
        'onboarding.background.ink': url,
      }),
    );
    await env.writeAsString(
      jsonEncode({
        'ASSET_BASE_URL': 'https://existing.redkeep.test/v1/',
        'ASSET_ALLOW_LOCAL_FIXTURE': false,
        'OTHER_SETTING': {'retained': 17},
      }),
    );
    expect(await prepareAssetSources(source.path, env.path), 2);
    final values = jsonDecode(await env.readAsString()) as Map;
    expect(values['ASSET_BASE_URL'], 'https://existing.redkeep.test/v1/');
    expect(values['ASSET_ALLOW_LOCAL_FIXTURE'], false);
    expect(values['OTHER_SETTING'], {'retained': 17});
    expect(jsonDecode(values['ASSET_SOURCE_URLS_JSON'] as String), {
      'onboarding.chapter.notes': url,
      'onboarding.cover': url,
    });
    final before = await env.readAsBytes();
    await source.writeAsString(
      jsonEncode({'onboarding.chapter.notes': 'http://unsafe/image.webp'}),
    );
    await expectLater(
      prepareAssetSources(source.path, env.path),
      throwsA(isA<AssetException>()),
    );
    expect(await env.readAsBytes(), before);
    expect(await File('${env.path}.pending').exists(), false);
  });

  test('old full source maps ignore the bundled ink paper and retain all download URLs', () async {
    final catalog = AssetCatalog.parse(
      await File('assets/catalog/presentation-v1.json').readAsString(),
    );
    final sources = {
      for (final asset in catalog.assets)
        asset.key:
            'https://fixtures.redkeep.test/${asset.path}?token=synthetic',
      'onboarding.background.ink': 'retired value is never used',
    };
    final location = AssetLocation(
      '',
      catalog: catalog,
      sourceUrlsJson: jsonEncode(sources),
    );
    for (final asset in catalog.assets) {
      expect(location.url(asset.path).toString(), sources[asset.key]);
    }
    expect(
      () => location.url('onboarding/ink-paper.webp'),
      throwsA(isA<AssetException>()),
    );
  });
}
