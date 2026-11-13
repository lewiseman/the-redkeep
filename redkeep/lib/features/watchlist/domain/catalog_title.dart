import 'watch_title.dart';

/// TMDB facts about a title, cached on this device only.
class CatalogTitle {
  const CatalogTitle({
    required this.key,
    required this.title,
    this.year,
    this.overview = '',
    this.tagline = '',
    this.posterPath,
    this.backdropPath,
    this.backdrops = const [],
    this.genres = const [],
    this.keywords = const [],
    this.cast = const [],
    this.director,
    this.runtime,
    this.language,
    this.voteAverage = 0,
    this.voteCount = 0,
    this.popularity = 0,
    this.providers = const [],
    this.seasons = const [],
    this.detailed = false,
  });

  final WatchKey key;
  final String title;
  final int? year;
  final String overview;
  final String tagline;
  final String? posterPath;
  final String? backdropPath;

  /// Scene stills, once details are fetched.
  final List<String> backdrops;
  final List<String> genres;
  final List<String> keywords;
  final List<String> cast;

  /// A film's director, or a show's creator.
  final String? director;

  /// Minutes; for a show, a typical episode.
  final int? runtime;
  final String? language;
  final double voteAverage;
  final int voteCount;
  final double popularity;

  /// Streaming services in the reader's region.
  final List<String> providers;
  final List<SeasonSummary> seasons;

  /// Whether this came from a details request, not a list or search result.
  final bool detailed;

  WatchMedia get media => key.media;

  /// Its "photos" for a dating profile: the poster, then scene stills.
  List<(String path, String size)> get photos {
    final stills = {?backdropPath, ...backdrops}.take(5);
    return [
      if (posterPath != null) (posterPath!, 'w780'),
      for (final b in stills) (b, 'w1280'),
    ];
  }

  Map<String, dynamic> toJson() => {
    'key': key.value,
    'title': title,
    'year': year,
    'overview': overview,
    'tagline': tagline,
    'poster': posterPath,
    'backdrop': backdropPath,
    'backdrops': backdrops,
    'genres': genres,
    'keywords': keywords,
    'cast': cast,
    'director': director,
    'runtime': runtime,
    'language': language,
    'vote_average': voteAverage,
    'vote_count': voteCount,
    'popularity': popularity,
    'providers': providers,
    'seasons': [for (final s in seasons) s.toJson()],
    'detailed': detailed,
  };

  static CatalogTitle? fromJson(Map<String, dynamic> json) {
    final key = WatchKey.tryParse(json['key'] as String?);
    final title = json['title'];
    if (key == null || title is! String) return null;
    List<String> strings(Object? value) =>
        value is List ? value.whereType<String>().toList() : const [];
    return CatalogTitle(
      key: key,
      title: title,
      year: json['year'] as int?,
      overview: json['overview'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      posterPath: json['poster'] as String?,
      backdropPath: json['backdrop'] as String?,
      backdrops: strings(json['backdrops']),
      genres: strings(json['genres']),
      keywords: strings(json['keywords']),
      cast: strings(json['cast']),
      director: json['director'] as String?,
      runtime: json['runtime'] as int?,
      language: json['language'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: json['vote_count'] as int? ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
      providers: strings(json['providers']),
      seasons: [
        for (final s in json['seasons'] as List? ?? const [])
          if (s is Map) SeasonSummary.fromJson(s.cast<String, dynamic>()),
      ],
      detailed: json['detailed'] == true,
    );
  }
}

class SeasonSummary {
  const SeasonSummary({
    required this.number,
    required this.name,
    required this.episodeCount,
    this.airDate,
  });

  final int number;
  final String name;
  final int episodeCount;
  final DateTime? airDate;

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'episodes': episodeCount,
    'air_date': airDate?.toIso8601String(),
  };

  factory SeasonSummary.fromJson(Map<String, dynamic> json) => SeasonSummary(
    number: json['number'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    episodeCount: json['episodes'] as int? ?? 0,
    airDate: DateTime.tryParse(json['air_date'] as String? ?? ''),
  );
}

class EpisodeSummary {
  const EpisodeSummary({
    required this.season,
    required this.number,
    required this.name,
    this.overview = '',
    this.airDate,
    this.runtime,
  });

  final int season;
  final int number;
  final String name;
  final String overview;
  final DateTime? airDate;
  final int? runtime;

  String get code => episodeCode(season, number);

  bool airedBy(DateTime now) => airDate != null && !airDate!.isAfter(now);

  Map<String, dynamic> toJson() => {
    'season': season,
    'number': number,
    'name': name,
    'overview': overview,
    'air_date': airDate?.toIso8601String(),
    'runtime': runtime,
  };

  factory EpisodeSummary.fromJson(Map<String, dynamic> json) => EpisodeSummary(
    season: json['season'] as int? ?? 0,
    number: json['number'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    overview: json['overview'] as String? ?? '',
    airDate: DateTime.tryParse(json['air_date'] as String? ?? ''),
    runtime: json['runtime'] as int?,
  );
}
