import 'dart:io';

import '../domain/brain.dart';

abstract interface class ModelDownload {
  Stream<List<int>> open(Uri uri, BrainCancellation cancellation);
}

/// Hugging Face uses signed CDN redirects. Each hop must remain HTTPS.
class HttpModelDownload implements ModelDownload {
  HttpModelDownload({HttpClient Function()? createClient})
    : _createClient = createClient ?? HttpClient.new;
  final HttpClient Function() _createClient;

  @override
  Stream<List<int>> open(Uri uri, BrainCancellation cancellation) async* {
    final client = _createClient()
      ..connectionTimeout = const Duration(seconds: 20);
    var finished = false;
    // Closing the client interrupts connection/headers as well as body reads.
    cancellation.whenCancelled.then((_) {
      if (!finished) client.close(force: true);
    });
    try {
      for (var redirects = 0; redirects <= 5; redirects++) {
        cancellation.check();
        if (uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw const BrainException(BrainFailure.download);
        }
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 20));
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) break;
          uri = uri.resolve(location);
          // No need to consume a potentially unbounded redirect body.
          await response.listen((_) {}).cancel();
          continue;
        }
        if (response.statusCode != HttpStatus.ok) break;
        yield* response.timeout(const Duration(seconds: 30));
        return;
      }
      throw const BrainException(BrainFailure.download);
    } finally {
      finished = true;
      client.close(force: true);
    }
  }
}
