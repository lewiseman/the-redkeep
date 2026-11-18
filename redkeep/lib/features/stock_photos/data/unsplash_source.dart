import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:http/http.dart' as http;

import '../../diary/data/prepare_diary_image.dart';
import '../domain/stock_photo.dart';
import '../domain/stock_photo_source.dart';

/// Unsplash over its public API with an access key. Grid and preview images
/// load from Unsplash's own links, and choosing a photo reports the download
/// first, as Unsplash's API guidelines require.
class UnsplashSource implements StockPhotoSource {
  UnsplashSource(
    this._http, {
    required this.accessKey,
    this.appName = 'redkeep',
    this.timeout = const Duration(seconds: 15),
  });

  final http.Client _http;
  final String accessKey;

  /// Sent as `utm_source` on every link back to Unsplash.
  final String appName;
  final Duration timeout;

  static const _base = 'https://api.unsplash.com';
  static const perPage = 30;

  /// Long edge of the chosen image before Redkeep compresses it.
  static const downloadWidth = 1600;
  static const maxDownloadBytes = 15 * 1024 * 1024;

  @override
  String get name => 'Unsplash';

  @override
  Uri get homeUrl => _referral('https://unsplash.com/');

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Accept-Version': 'v1',
    'Authorization': 'Client-ID $accessKey',
  };

  Uri _referral(String url) {
    final uri = Uri.parse(url);
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'utm_source': appName,
        'utm_medium': 'referral',
      },
    );
  }

  Future<http.Response> _send(Uri uri, {Map<String, String>? headers}) async {
    final http.Response response;
    try {
      response = await _http.get(uri, headers: headers).timeout(timeout);
    } on SocketException {
      throw StockPhotoException(StockPhotoFailure.offline, name);
    } on TimeoutException {
      throw StockPhotoException(StockPhotoFailure.badResponse, name);
    } on http.ClientException {
      throw StockPhotoException(StockPhotoFailure.offline, name);
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return response;
    throw StockPhotoException(switch (status) {
      401 => StockPhotoFailure.unauthorized,
      403 when response.body.toLowerCase().contains('rate limit') =>
        StockPhotoFailure.rateLimited,
      403 => StockPhotoFailure.unauthorized,
      404 => StockPhotoFailure.notFound,
      429 => StockPhotoFailure.rateLimited,
      _ => StockPhotoFailure.badResponse,
    }, name);
  }

  Future<Object?> _get(String path, Map<String, String> query) async {
    final response = await _send(
      Uri.parse('$_base$path').replace(queryParameters: query),
      headers: _headers,
    );
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw StockPhotoException(StockPhotoFailure.badResponse, name);
    }
  }

  /// Tall wallpaper-style photos, most popular first.
  @override
  Future<StockPhotoPage> browse({int page = 1}) async {
    final body = await _get('/topics/wallpapers/photos', {
      'page': '$page',
      'per_page': '$perPage',
      'orientation': 'portrait',
      'order_by': 'popular',
    });
    final photos = _photos(body);
    return StockPhotoPage(photos: photos, hasMore: photos.length >= perPage);
  }

  @override
  Future<StockPhotoPage> search(String query, {int page = 1}) async {
    final body = await _get('/search/photos', {
      'query': query,
      'page': '$page',
      'per_page': '$perPage',
      'orientation': 'portrait',
      'content_filter': 'high',
    });
    if (body is! Map) {
      throw StockPhotoException(StockPhotoFailure.badResponse, name);
    }
    final pages = body['total_pages'];
    return StockPhotoPage(
      photos: _photos(body['results']),
      hasMore: pages is int && page < pages,
    );
  }

  @override
  Future<Uint8List> download(StockPhoto photo) async {
    final track = photo.trackUrl;
    if (track != null) await _send(Uri.parse(track), headers: _headers);
    final response = await _send(Uri.parse(photo.downloadUrl));
    final bytes = response.bodyBytes;
    if (bytes.isEmpty ||
        bytes.length > maxDownloadBytes ||
        imageSignature(bytes) == null) {
      throw StockPhotoException(StockPhotoFailure.badResponse, name);
    }
    return bytes;
  }

  List<StockPhoto> _photos(Object? list) => [
    if (list is List)
      for (final item in list)
        if (item is Map) ?_photo(item),
  ];

  StockPhoto? _photo(Map<dynamic, dynamic> json) {
    final id = json['id'];
    final urls = json['urls'];
    final links = json['links'];
    final user = json['user'];
    if (id is! String || urls is! Map || links is! Map || user is! Map) {
      return null;
    }
    final raw = urls['raw'];
    final small = urls['small'];
    final regular = urls['regular'];
    final html = links['html'];
    final userName = user['name'];
    final userLinks = user['links'];
    final userHtml = userLinks is Map ? userLinks['html'] : null;
    if (raw is! String ||
        small is! String ||
        regular is! String ||
        html is! String ||
        userName is! String ||
        userHtml is! String) {
      return null;
    }
    final rawUri = Uri.parse(raw);
    final download = rawUri.replace(
      queryParameters: {
        ...rawUri.queryParameters,
        'w': '$downloadWidth',
        'fm': 'jpg',
        'q': '85',
        'fit': 'max',
      },
    );
    final track = links['download_location'];
    final width = json['width'];
    final height = json['height'];
    final text = json['alt_description'] ?? json['description'];
    return StockPhoto(
      id: id,
      thumbUrl: small,
      previewUrl: regular,
      downloadUrl: download.toString(),
      trackUrl: track is String ? track : null,
      width: width is int ? width : 0,
      height: height is int ? height : 0,
      color: _color(json['color']),
      description: text is String ? text : null,
      photographerName: userName,
      photographerUrl: _referral(userHtml).toString(),
      photoUrl: _referral(html).toString(),
    );
  }

  static Color? _color(Object? hex) {
    if (hex is! String) return null;
    final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex);
    if (match == null) return null;
    return Color(0xFF000000 | int.parse(match[1]!, radix: 16));
  }
}
