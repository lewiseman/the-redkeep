import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/assets/data/asset_download_client.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

void main() {
  test(
    'requests identity bytes without redirects and closes transport',
    () async {
      final client = _Client(200);
      final stream = HttpAssetDownloadClient(createClient: () => client)
          .open(Uri.https('fixture.test', '/a.png'));
      expect(await stream.toList(), [
        [1, 2, 3],
      ]);
      expect(client.request.followRedirects, isFalse);
      expect(
        client.request.headers.values[HttpHeaders.acceptEncodingHeader],
        'identity',
      );
      expect(client.closed, isTrue);
    },
  );

  for (final status in [302, 404, 500]) {
    test('rejects HTTP $status and closes transport', () async {
      final client = _Client(status);
      await expectLater(
        HttpAssetDownloadClient(createClient: () => client)
            .open(Uri.https('fixture.test', '/a.png'))
            .toList(),
        throwsA(isA<AssetException>()),
      );
      expect(client.closed, isTrue);
    });
  }
}

class _Client implements HttpClient {
  _Client(int status) : request = _Request(status);
  final _Request request;
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => request;
  @override
  void close({bool force = false}) {
    closed = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.status);
  final int status;
  @override
  bool followRedirects = true;
  @override
  final _Headers headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => _Response(status);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  final values = <String, Object>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode);
  @override
  final int statusCode;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value([1, 2, 3]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
