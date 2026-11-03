import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/brain/data/model_download.dart';
import 'package:redkeep/features/brain/domain/brain.dart';

void main() {
  test(
    'HTTPS CDN redirect keeps identity transfer and closes transport',
    () async {
      final client = _Client([
        _Response(302, location: 'https://cdn.test/signed?token=synthetic'),
        _Response(200),
      ]);
      final chunks = await HttpModelDownload(createClient: () => client)
          .open(Uri.https('fixture.test', '/model'), BrainCancellation())
          .toList();
      expect(chunks, [
        [1, 2, 3],
      ]);
      expect(client.urls.map((u) => u.host), ['fixture.test', 'cdn.test']);
      expect(
        client.requests.every(
          (r) =>
              !r.followRedirects &&
              r.headers.values[HttpHeaders.acceptEncodingHeader] == 'identity',
        ),
        isTrue,
      );
      expect(client.closed, isTrue);
    },
  );
  for (final scenario in [
    'http',
    'credentials',
    'missing-location',
    'loop',
    '404',
  ]) {
    test('$scenario fails safely with bounded redirects', () async {
      final responses = switch (scenario) {
        'http' => [_Response(302, location: 'http://cdn.test/model')],
        'credentials' => [
          _Response(302, location: 'https://user:secret@cdn.test/model'),
        ],
        'missing-location' => [_Response(302)],
        'loop' => List.generate(6, (_) => _Response(302, location: '/again')),
        _ => [_Response(404)],
      };
      final client = _Client(responses);
      await expectLater(
        HttpModelDownload(createClient: () => client)
            .open(Uri.https('fixture.test', '/model'), BrainCancellation())
            .toList(),
        throwsA(
          isA<BrainException>().having(
            (e) => e.failure,
            'failure',
            BrainFailure.download,
          ),
        ),
      );
      expect(client.closed, isTrue);
      expect(client.urls.length, lessThanOrEqualTo(6));
    });
  }
  test('cancel closes native transport while headers are pending', () async {
    final client = _Client([_Response(200)])
      ..headersPending = Completer<HttpClientResponse>();
    final cancellation = BrainCancellation();
    final consumed = HttpModelDownload(createClient: () => client)
        .open(Uri.https('fixture.test', '/model'), cancellation)
        .toList();
    final failure = expectLater(consumed, throwsA(isA<StateError>()));
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    await failure;
    expect(client.closed, isTrue);
  });
}

class _Client implements HttpClient {
  _Client(this.responses);
  final List<_Response> responses;
  final urls = <Uri>[];
  final requests = <_Request>[];
  Completer<HttpClientResponse>? headersPending;
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    urls.add(url);
    final request = _Request(responses.removeAt(0), headersPending);
    requests.add(request);
    return request;
  }

  @override
  void close({bool force = false}) {
    closed = force;
    if (headersPending != null && !headersPending!.isCompleted) {
      headersPending!.completeError(StateError('synthetic abort'));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.response, this.pending);
  final _Response response;
  final Completer<HttpClientResponse>? pending;
  @override
  bool followRedirects = true;
  @override
  final _Headers headers = _Headers();
  @override
  Future<HttpClientResponse> close() async =>
      pending == null ? response : pending!.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  _Headers([String? location]) {
    if (location != null) values[HttpHeaders.locationHeader] = location;
  }
  final values = <String, Object>{};
  @override
  String? value(String name) => values[name] as String?;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, {String? location}) : headers = _Headers(location);
  @override
  final int statusCode;
  @override
  final _Headers headers;
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
