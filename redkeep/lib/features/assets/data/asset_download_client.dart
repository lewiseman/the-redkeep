import 'dart:async';
import 'dart:io';

import '../domain/asset_catalog.dart';

abstract interface class AssetDownloadClient {
  Stream<List<int>> open(Uri uri);
}

class HttpAssetDownloadClient implements AssetDownloadClient {
  HttpAssetDownloadClient({HttpClient Function()? createClient})
    : _createClient = createClient ?? HttpClient.new;
  final HttpClient Function() _createClient;

  @override
  Stream<List<int>> open(Uri uri) async* {
    final client = _createClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw const AssetException(AssetFailure.network);
      }
      yield* response.timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }
}

/// Unconfigured by default. HTTP is restricted to explicit debug fixtures.
class AssetLocation {
  AssetLocation(String base, {bool allowLocalFixture = false}) {
    if (base.isEmpty) return;
    final value = Uri.tryParse(base);
    if (value == null ||
        !value.hasAuthority ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.hasQuery ||
        value.hasFragment ||
        !value.path.endsWith('/') ||
        value.pathSegments.any((part) => part == '.' || part == '..') ||
        (value.scheme != 'https' &&
            !(allowLocalFixture &&
                value.scheme == 'http' &&
                ['localhost', '127.0.0.1', '::1'].contains(value.host)))) {
      throw const AssetException(AssetFailure.configuration);
    }
    _base = value;
  }

  Uri? _base;
  Uri url(String path) {
    if (_base == null || !safeAssetPath(path)) {
      throw const AssetException(AssetFailure.configuration);
    }
    return _base!.resolve(path);
  }
}
