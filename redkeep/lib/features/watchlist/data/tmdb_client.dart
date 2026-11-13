import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/catalog_title.dart';
import '../domain/watch_title.dart';

enum TmdbFailure { offline, unauthorized, notFound, busy, unavailable }

class TmdbException implements Exception {
  const TmdbException(this.failure);
  final TmdbFailure failure;

  String get message => switch (failure) {
    TmdbFailure.offline => 'You seem to be offline.',
    TmdbFailure.unauthorized => 'TMDB refused the key in env.json.',
    TmdbFailure.notFound => 'TMDB has no record of this title.',
    TmdbFailure.busy => 'TMDB is busy. Try again in a moment.',
    TmdbFailure.unavailable => 'TMDB could not be reached.',
  };

  @override
  String toString() => message;
}

/// TMDB v3 over plain HTTP. A v4 read token (a JWT) is sent as a bearer
/// token; a v3 key travels as `api_key`.
class TmdbClient {
  TmdbClient(
    this._http, {
    required this.apiKey,
    this.region = 'US',
    this.timeout = const Duration(seconds: 15),
  });

  final http.Client _http;
  final String apiKey;
  final String region;
  final Duration timeout;

  static const _base = 'https://api.themoviedb.org/3';

  static String image(String path, {String size = 'w342'}) =>
      'https://image.tmdb.org/t/p/$size$path';

  bool get _bearer => apiKey.startsWith('eyJ');

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    final uri = Uri.parse('$_base$path')
        .replace(queryParameters: {...query, if (!_bearer) 'api_key': apiKey});
    final http.Response response;
    try {
      response = await _http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (_bearer) 'Authorization': 'Bearer $apiKey',
            },
          )
          .timeout(timeout);
    } on SocketException {
      throw const TmdbException(TmdbFailure.offline);
    } on TimeoutException {
      throw const TmdbException(TmdbFailure.unavailable);
    } on http.ClientException {
      throw const TmdbException(TmdbFailure.offline);
    }
    switch (response.statusCode) {
      case 200:
        break;
      case 401:
        throw const TmdbException(TmdbFailure.unauthorized);
      case 404:
        throw const TmdbException(TmdbFailure.notFound);
      case 429:
        throw const TmdbException(TmdbFailure.busy);
      default:
        throw const TmdbException(TmdbFailure.unavailable);
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) return body;
    } on FormatException {
      // Falls through to unavailable.
    }
    throw const TmdbException(TmdbFailure.unavailable);
  }

  /// Films and shows together. People are left out.
  Future<List<CatalogTitle>> search(String query, {int page = 1}) async {
    final body = await _get('/search/multi', {
      'query': query,
      'page': '$page',
      'include_adult': 'false',
    });
    return summaries(body['results']);
  }

  Future<List<CatalogTitle>> trending() async =>
      summaries((await _get('/trending/all/week'))['results']);

  /// `popular` or `top_rated`.
  Future<List<CatalogTitle>> chart(
    WatchMedia media,
    String chart, {
    int page = 1,
  }) async => summaries(
    (await _get('/${media.name}/$chart', {'page': '$page'}))['results'],
    media: media,
  );

  Future<List<CatalogTitle>> discover(
    WatchMedia media,
    Map<String, String> filters, {
    int page = 1,
  }) async => summaries(
    (await _get('/discover/${media.name}', {
      ...filters,
      'page': '$page',
      'include_adult': 'false',
    }))['results'],
    media: media,
  );

  Future<CatalogTitle> details(WatchKey key) async {
    final tv = key.media == WatchMedia.tv;
    final body = await _get('/${key.media.name}/${key.tmdbId}', {
      'append_to_response': tv
          ? 'keywords,aggregate_credits,watch/providers,images'
          : 'keywords,credits,watch/providers,images',
      // Stills without text, which suit a profile's photos.
      'include_image_language': 'null',
    });
    return detailsFromJson(key.media, body, region: region);
  }

  Future<List<EpisodeSummary>> season(int tvId, int number) async {
    final body = await _get('/tv/$tvId/season/$number');
    return episodesFromJson(number, body);
  }

  // Parsing is static and pure so tests need no network.

  static const genreNames = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Science Fiction',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
    10759: 'Action & Adventure',
    10762: 'Kids',
    10763: 'News',
    10764: 'Reality',
    10765: 'Sci-Fi & Fantasy',
    10766: 'Soap',
    10767: 'Talk',
    10768: 'War & Politics',
  };

  static List<CatalogTitle> summaries(Object? results, {WatchMedia? media}) {
    if (results is! List) return const [];
    final seen = <WatchKey>{};
    return [
      for (final raw in results)
        if (raw is Map<String, dynamic>)
          if (_summary(raw, media) case final title?)
            if (seen.add(title.key)) title,
    ];
  }

  static CatalogTitle? _summary(Map<String, dynamic> json, WatchMedia? media) {
    media ??= WatchMedia.tryParse(json['media_type'] as String?);
    final id = json['id'];
    if (media == null || id is! int || id <= 0) return null;
    final title = _title(json, media);
    if (title == null) return null;
    return CatalogTitle(
      key: WatchKey(media, id),
      title: title,
      year: _year(json, media),
      overview: json['overview'] as String? ?? '',
      posterPath: _path(json['poster_path']),
      backdropPath: _path(json['backdrop_path']),
      genres: [
        for (final g in json['genre_ids'] as List? ?? const []) ?genreNames[g],
      ],
      language: json['original_language'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: json['vote_count'] as int? ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
    );
  }

  static CatalogTitle detailsFromJson(
    WatchMedia media,
    Map<String, dynamic> json, {
    String region = 'US',
  }) {
    final id = json['id'];
    final title = _title(json, media);
    if (id is! int || title == null) {
      throw const TmdbException(TmdbFailure.unavailable);
    }
    final tv = media == WatchMedia.tv;
    final credits =
        (json[tv ? 'aggregate_credits' : 'credits'] as Map?) ?? const {};
    final keywords = (json['keywords'] as Map?) ?? const {};
    final providers =
        ((json['watch/providers'] as Map?)?['results'] as Map?)?[region]
            as Map?;
    String? director;
    if (tv) {
      final creators = json['created_by'] as List? ?? const [];
      director =
          creators.whereType<Map>().map((c) => c['name']).firstOrNull
              as String?;
    } else {
      director =
          (credits['crew'] as List? ?? const [])
                  .whereType<Map>()
                  .where((c) => c['job'] == 'Director')
                  .map((c) => c['name'])
                  .firstOrNull
              as String?;
    }
    final runtimes = json['episode_run_time'] as List? ?? const [];
    return CatalogTitle(
      key: WatchKey(media, id),
      title: title,
      year: _year(json, media),
      overview: json['overview'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      posterPath: _path(json['poster_path']),
      backdropPath: _path(json['backdrop_path']),
      backdrops: [
        for (final b
            in ((json['images'] as Map?)?['backdrops'] as List? ?? const [])
                .take(5))
          if (b is Map) ?_path(b['file_path']),
      ],
      genres: [
        for (final g in json['genres'] as List? ?? const [])
          if (g is Map && g['name'] is String) g['name'] as String,
      ],
      keywords: [
        for (final k
            in (keywords[tv ? 'results' : 'keywords'] as List? ?? const [])
                .take(12))
          if (k is Map && k['name'] is String) k['name'] as String,
      ],
      cast: [
        for (final c in (credits['cast'] as List? ?? const []).take(8))
          if (c is Map && c['name'] is String) c['name'] as String,
      ],
      director: director,
      runtime: tv
          ? runtimes.whereType<int>().firstOrNull
          : (json['runtime'] as int?).takeIfPositive,
      language: json['original_language'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: json['vote_count'] as int? ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
      providers: [
        for (final p in providers?['flatrate'] as List? ?? const [])
          if (p is Map && p['provider_name'] is String)
            p['provider_name'] as String,
      ],
      seasons: [
        for (final s in json['seasons'] as List? ?? const [])
          if (s is Map &&
              s['season_number'] is int &&
              (s['season_number'] as int) > 0)
            SeasonSummary(
              number: s['season_number'] as int,
              name: s['name'] as String? ?? 'Season ${s['season_number']}',
              episodeCount: s['episode_count'] as int? ?? 0,
              airDate: DateTime.tryParse(s['air_date'] as String? ?? ''),
            ),
      ],
      detailed: true,
    );
  }

  static List<EpisodeSummary> episodesFromJson(
    int season,
    Map<String, dynamic> json,
  ) => [
    for (final e in json['episodes'] as List? ?? const [])
      if (e is Map && e['episode_number'] is int)
        EpisodeSummary(
          season: season,
          number: e['episode_number'] as int,
          name: e['name'] as String? ?? 'Episode ${e['episode_number']}',
          overview: e['overview'] as String? ?? '',
          airDate: DateTime.tryParse(e['air_date'] as String? ?? ''),
          runtime: e['runtime'] as int?,
        ),
  ];

  static String? _title(Map json, WatchMedia media) {
    final value = media == WatchMedia.tv ? json['name'] : json['title'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static int? _year(Map json, WatchMedia media) {
    final date =
        (media == WatchMedia.tv ? json['first_air_date'] : json['release_date'])
            as String?;
    return date == null || date.length < 4
        ? null
        : int.tryParse(date.substring(0, 4));
  }

  static String? _path(Object? value) =>
      value is String && value.startsWith('/') ? value : null;
}

extension on int? {
  int? get takeIfPositive => this == null || this! <= 0 ? null : this;
}
