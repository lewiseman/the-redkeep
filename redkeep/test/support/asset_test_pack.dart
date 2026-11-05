import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:redkeep/features/assets/data/asset_download_client.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

const testPayloads = <String, List<int>>{
  'art/one.png': [1, 2, 3, 4],
  'art/two.png': [5, 6, 7, 8],
};

Map<String, dynamic> testCatalogJson() => {
  'schema': 1,
  'pack': 'test-v1',
  'assets': [
    for (final entry in testPayloads.entries)
      {
        'key': 'test.${entry.key.split('/').last.split('.').first}',
        'revision': 'v1',
        'path': entry.key,
        'bytes': entry.value.length,
        'sha256': sha256.convert(entry.value).toString(),
        'provenance': 'synthetic deterministic bytes, never production media',
      },
  ],
};

AssetCatalog testCatalog() => AssetCatalog.parse(jsonEncode(testCatalogJson()));

class TestAssetClient implements AssetDownloadClient {
  final requests = <String>[];
  Stream<List<int>> Function(Uri)? response;

  @override
  Stream<List<int>> open(Uri uri) {
    requests.add(uri.path);
    return response?.call(uri) ??
        Stream.value(testPayloads[uri.path.substring(1)]!);
  }
}
