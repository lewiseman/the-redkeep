import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/assets/data/asset_download_client.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

import '../../support/asset_test_pack.dart';

void main() {
  test('pins stable keys, revisions, hashes, locations and provenance', () {
    final catalog = testCatalog();
    expect(catalog.asset('test.one').revision, 'v1');
    expect(catalog.asset('test.one').sourcePath, 'art/one.png');
    expect(() => catalog.asset('absent.key'), throwsA(isA<AssetException>()));
  });

  for (final path in [
    '../one.png',
    '/one.png',
    'a/../../one.png',
    r'a\one.png',
    'a/%2e%2e/one.png',
    'a//one.png',
    'a/./one.png',
    'a/one.png?x=1',
    'a/one.png#x',
    'a/one-pending.png',
    'a/one.mp3',
    'a/ONE.png',
  ]) {
    test('rejects unsafe/unassigned media path $path', () {
      final json = testCatalogJson();
      (json['assets'] as List).first['path'] = path;
      expect(
        () => AssetCatalog.parse(jsonEncode(json)),
        throwsA(isA<AssetException>()),
      );
      (json['assets'] as List).first['path'] = 'art/one.png';
      (json['assets'] as List).first['sourcePath'] = path;
      expect(
        () => AssetCatalog.parse(jsonEncode(json)),
        throwsA(isA<AssetException>()),
      );
    });
  }

  test(
    'rejects duplicates, unknown schema, empty metadata and invalid bounds',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (j) => j['schema'] = 2,
        (j) => j['assets'] = [],
        (j) => (j['assets'] as List).add((j['assets'] as List).first),
        (j) => (j['assets'] as List).first['sha256'] = 'bad',
        (j) => (j['assets'] as List).first['bytes'] = 0,
        (j) => (j['assets'] as List).first['bytes'] = 11 * 1024 * 1024,
        (j) => (j['assets'] as List).first['provenance'] = '',
        (j) => (j['assets'] as List).first['key'] = 'Bad Key',
      ]) {
        final json = testCatalogJson();
        change(json);
        expect(
          () => AssetCatalog.parse(jsonEncode(json)),
          throwsA(isA<AssetException>()),
        );
      }
      expect(() => AssetCatalog.parse('{'), throwsA(isA<AssetException>()));
    },
  );

  test(
    'asset locations require HTTPS without credentials, queries or fragments',
    () {
      expect(
        () => AssetLocation('').url('a.png'),
        throwsA(isA<AssetException>()),
      );
      for (final value in [
        'http://localhost:8080/',
        'http://127.0.0.1:8080/',
        'http://host/',
        'https://user:secret@host/',
        'https://host/no-slash',
        'https://host/?token=x',
        'file:///tmp/',
        'https://host/#fragment',
      ]) {
        expect(() => AssetLocation(value), throwsA(isA<AssetException>()));
      }
      expect(
        AssetLocation('https://media.redkeep.org/v1/').url('a/b.png').path,
        '/v1/a/b.png',
      );
    },
  );

  test('production images use one public website directory', () {
    expect(
      AssetLocation('https://redkeep.lewiseman.com/art/')
          .url('notes.webp')
          .toString(),
      'https://redkeep.lewiseman.com/art/notes.webp',
    );
    final json = testCatalogJson();
    (json['assets'] as List).first['sourcePath'] = 'one.png';
    final asset = AssetCatalog.parse(jsonEncode(json)).asset('test.one');
    expect(asset.path, 'art/one.png');
    expect(asset.sourcePath, 'one.png');
  });
}
