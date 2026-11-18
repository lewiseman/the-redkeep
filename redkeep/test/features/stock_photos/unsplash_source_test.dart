import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redkeep/features/stock_photos/data/unsplash_source.dart';
import 'package:redkeep/features/stock_photos/domain/stock_photo_source.dart';

Map<String, Object?> _photo(String id) => {
  'id': id,
  'width': 3000,
  'height': 4500,
  'color': '#40608c',
  'alt_description': 'calm sea',
  'urls': {
    'raw': 'https://images.unsplash.com/photo-$id?ixid=abc',
    'small': 'https://images.unsplash.com/photo-$id?w=400',
    'regular': 'https://images.unsplash.com/photo-$id?w=1080',
  },
  'links': {
    'html': 'https://unsplash.com/photos/$id',
    'download_location':
        'https://api.unsplash.com/photos/$id/download?ixid=abc',
  },
  'user': {
    'name': 'Ada Lens',
    'links': {'html': 'https://unsplash.com/@ada'},
  },
};

final _jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);

void main() {
  late List<http.Request> sent;
  UnsplashSource source(Future<http.Response> Function(http.Request) handler) {
    sent = [];
    return UnsplashSource(
      MockClient((request) {
        sent.add(request);
        return handler(request);
      }),
      accessKey: 'key-1',
    );
  }

  http.Response json(Object? body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);

  test('search sends the key and portrait filter and parses photos', () async {
    final unsplash = source(
      (_) async => json({
        'total_pages': 3,
        'results': [
          _photo('a'),
          {'id': 'broken'},
          _photo('b'),
        ],
      }),
    );
    final page = await unsplash.search('sea', page: 2);
    final request = sent.single;
    expect(request.url.path, '/search/photos');
    expect(request.url.queryParameters, {
      'query': 'sea',
      'page': '2',
      'per_page': '30',
      'orientation': 'portrait',
      'content_filter': 'high',
    });
    expect(request.headers['Authorization'], 'Client-ID key-1');
    expect(request.headers['Accept-Version'], 'v1');
    expect(page.hasMore, isTrue);
    expect(page.photos.map((p) => p.id), ['a', 'b']);
    final photo = page.photos.first;
    expect(photo.description, 'calm sea');
    expect(photo.color?.toARGB32(), 0xFF40608C);
    expect(photo.aspectRatio, closeTo(2 / 3, .001));
    final download = Uri.parse(photo.downloadUrl);
    expect(download.queryParameters, containsPair('ixid', 'abc'));
    expect(download.queryParameters, containsPair('w', '1600'));
    expect(download.queryParameters, containsPair('fm', 'jpg'));
    // Credits link back with Unsplash's referral parameters.
    expect(Uri.parse(photo.photographerUrl).queryParameters, {
      'utm_source': 'redkeep',
      'utm_medium': 'referral',
    });
    expect(Uri.parse(photo.photoUrl).queryParameters['utm_source'], 'redkeep');
  });

  test('the last search page has no more', () async {
    final unsplash = source(
      (_) async => json({
        'total_pages': 2,
        'results': [_photo('a')],
      }),
    );
    expect((await unsplash.search('sea', page: 2)).hasMore, isFalse);
  });

  test('browse lists tall photos from a list response', () async {
    final unsplash = source((_) async => json([_photo('a')]));
    final page = await unsplash.browse();
    expect(sent.single.url.queryParameters['orientation'], 'portrait');
    expect(page.photos.single.id, 'a');
    expect(page.hasMore, isFalse);
  });

  test('download reports the download first, then fetches the image', () async {
    final photo = (await (source(
      (_) async => json([_photo('a')]),
    )).browse()).photos.single;
    final unsplash = source(
      (request) async => request.url.host == 'api.unsplash.com'
          ? json({'url': 'https://example/x'})
          : http.Response.bytes(_jpeg, 200),
    );
    expect(await unsplash.download(photo), _jpeg);
    expect(sent.map((r) => r.url.path), ['/photos/a/download', '/photo-a']);
    expect(sent.first.headers['Authorization'], 'Client-ID key-1');
    // The image itself comes from the CDN, without the key.
    expect(sent.last.headers['Authorization'], isNull);
  });

  test('a download that is not an image is rejected', () async {
    final photo = (await (source(
      (_) async => json([_photo('a')]),
    )).browse()).photos.single;
    final unsplash = source(
      (request) async => request.url.host == 'api.unsplash.com'
          ? json({})
          : http.Response('<html>', 200),
    );
    await expectLater(
      unsplash.download(photo),
      throwsA(
        isA<StockPhotoException>().having(
          (e) => e.failure,
          'failure',
          StockPhotoFailure.badResponse,
        ),
      ),
    );
  });

  for (final (status, body, failure) in [
    (401, 'OAuth error', StockPhotoFailure.unauthorized),
    (403, 'Rate Limit Exceeded', StockPhotoFailure.rateLimited),
    (404, '', StockPhotoFailure.notFound),
    (500, '', StockPhotoFailure.badResponse),
  ]) {
    test('HTTP $status is reported as ${failure.name}', () async {
      final unsplash = source((_) async => http.Response(body, status));
      await expectLater(
        unsplash.search('sea'),
        throwsA(
          isA<StockPhotoException>().having((e) => e.failure, 'f', failure),
        ),
      );
    });
  }

  test('no connection is reported as offline', () async {
    final unsplash = source((_) async => throw const SocketException('down'));
    await expectLater(
      unsplash.browse(),
      throwsA(
        isA<StockPhotoException>().having(
          (e) => e.failure,
          'failure',
          StockPhotoFailure.offline,
        ),
      ),
    );
  });
}
