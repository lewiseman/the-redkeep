import 'watch_title.dart';

/// Bumped when details gain fields, so older cached details are fetched
/// again rather than shown with gaps.
const catalogDetailsVersion = 2;

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
    this.posters = const [],
    this.genres = const [],
    this.keywords = const [],
    this.cast = const [],
    this.crew = const [],
    this.director,
    this.runtime,
    this.language,
    this.voteAverage = 0,
    this.voteCount = 0,
    this.popularity = 0,
    this.providers = const [],
    this.rent = const [],
    this.buy = const [],
    this.seasons = const [],
    this.videos = const [],
    this.recommendations = const [],
    this.originalTitle,
    this.status,
    this.releaseDate,
    this.lastAirDate,
    this.certification,
    this.budget,
    this.revenue,
    this.companies = const [],
    this.countries = const [],
    this.spokenLanguages = const [],
    this.networks = const [],
    this.episodeCount,
    this.nextEpisode,
    this.homepage,
    this.detailed = false,
  });

  final WatchKey key;
  final String title;
  final int? year;
  final String overview;
  final String tagline;
  final String? posterPath;
  final String? backdropPath;

  /// Scene stills and other posters, once details are fetched.
  final List<String> backdrops;
  final List<String> posters;
  final List<String> genres;
  final List<String> keywords;

  /// Actors with the parts they play, billing order first.
  final List<Credit> cast;

  /// The people behind it, with their jobs.
  final List<Credit> crew;

  /// A film's director, or a show's creator.
  final String? director;

  /// Minutes; for a show, a typical episode.
  final int? runtime;
  final String? language;
  final double voteAverage;
  final int voteCount;
  final double popularity;

  /// Streaming services in the reader's region, then where to rent or buy.
  final List<String> providers;
  final List<String> rent;
  final List<String> buy;
  final List<SeasonSummary> seasons;

  /// Trailers and clips on YouTube, trailers first.
  final List<TitleVideo> videos;

  /// Titles TMDB suggests alongside this one.
  final List<CatalogTitle> recommendations;

  /// The name in its own language, when it differs.
  final String? originalTitle;

  /// Such as "Released", "Returning Series" or "Ended".
  final String? status;

  /// A film's release, or a show's first air date.
  final DateTime? releaseDate;
  final DateTime? lastAirDate;

  /// The age rating in the reader's region, such as "PG-13" or "TV-MA".
  final String? certification;

  /// US dollars; zero is unknown and left out.
  final int? budget;
  final int? revenue;
  final List<String> companies;
  final List<String> countries;
  final List<String> spokenLanguages;

  /// Where a show airs.
  final List<String> networks;
  final int? episodeCount;
  final EpisodeSummary? nextEpisode;
  final String? homepage;

  /// Whether this came from a details request, not a list or search result.
  final bool detailed;

  WatchMedia get media => key.media;

  /// The trailer worth playing first, if any.
  TitleVideo? get trailer =>
      videos.where((v) => v.type == 'Trailer').firstOrNull ??
      videos.firstOrNull;

  Map<String, dynamic> toJson() => {
    'key': key.value,
    'title': title,
    'year': year,
    'overview': overview,
    'tagline': tagline,
    'poster': posterPath,
    'backdrop': backdropPath,
    'backdrops': backdrops,
    'posters': posters,
    'genres': genres,
    'keywords': keywords,
    'cast': [for (final c in cast) c.toJson()],
    'crew': [for (final c in crew) c.toJson()],
    'director': director,
    'runtime': runtime,
    'language': language,
    'vote_average': voteAverage,
    'vote_count': voteCount,
    'popularity': popularity,
    'providers': providers,
    'rent': rent,
    'buy': buy,
    'seasons': [for (final s in seasons) s.toJson()],
    'videos': [for (final v in videos) v.toJson()],
    'recommendations': [for (final r in recommendations) r.toJson()],
    'original_title': originalTitle,
    'status': status,
    'release_date': releaseDate?.toIso8601String(),
    'last_air_date': lastAirDate?.toIso8601String(),
    'certification': certification,
    'budget': budget,
    'revenue': revenue,
    'companies': companies,
    'countries': countries,
    'spoken_languages': spokenLanguages,
    'networks': networks,
    'episode_count': episodeCount,
    'next_episode': nextEpisode?.toJson(),
    'homepage': homepage,
    'detailed': detailed,
    'version': catalogDetailsVersion,
  };

  static CatalogTitle? fromJson(Map<String, dynamic> json) {
    final key = WatchKey.tryParse(json['key'] as String?);
    final title = json['title'];
    if (key == null || title is! String) return null;
    List<String> strings(Object? value) =>
        value is List ? value.whereType<String>().toList() : const [];
    List<Map<String, dynamic>> maps(Object? value) => [
      if (value is List)
        for (final m in value)
          if (m is Map) m.cast<String, dynamic>(),
    ];
    DateTime? date(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    final next = json['next_episode'];
    return CatalogTitle(
      key: key,
      title: title,
      year: json['year'] as int?,
      overview: json['overview'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      posterPath: json['poster'] as String?,
      backdropPath: json['backdrop'] as String?,
      backdrops: strings(json['backdrops']),
      posters: strings(json['posters']),
      genres: strings(json['genres']),
      keywords: strings(json['keywords']),
      cast: [
        // Older caches kept names only.
        for (final c in json['cast'] as List? ?? const [])
          if (c is String)
            Credit(name: c)
          else if (c is Map)
            ?Credit.fromJson(c.cast<String, dynamic>()),
      ],
      crew: [for (final c in maps(json['crew'])) ?Credit.fromJson(c)],
      director: json['director'] as String?,
      runtime: json['runtime'] as int?,
      language: json['language'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: json['vote_count'] as int? ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
      providers: strings(json['providers']),
      rent: strings(json['rent']),
      buy: strings(json['buy']),
      seasons: [
        for (final s in maps(json['seasons'])) SeasonSummary.fromJson(s),
      ],
      videos: [for (final v in maps(json['videos'])) ?TitleVideo.fromJson(v)],
      recommendations: [
        for (final r in maps(json['recommendations']))
          ?CatalogTitle.fromJson(r),
      ],
      originalTitle: json['original_title'] as String?,
      status: json['status'] as String?,
      releaseDate: date(json['release_date']),
      lastAirDate: date(json['last_air_date']),
      certification: json['certification'] as String?,
      budget: json['budget'] as int?,
      revenue: json['revenue'] as int?,
      companies: strings(json['companies']),
      countries: strings(json['countries']),
      spokenLanguages: strings(json['spoken_languages']),
      networks: strings(json['networks']),
      episodeCount: json['episode_count'] as int?,
      nextEpisode: next is Map
          ? EpisodeSummary.fromJson(next.cast<String, dynamic>())
          : null,
      homepage: json['homepage'] as String?,
      // Details cached before they had every field are fetched again.
      detailed:
          json['detailed'] == true && json['version'] == catalogDetailsVersion,
    );
  }
}

/// A person on a title: an actor and their part, or a crew member and job.
class Credit {
  const Credit({required this.name, this.role, this.profilePath});

  final String name;

  /// A character for cast, a job for crew.
  final String? role;
  final String? profilePath;

  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    'profile': profilePath,
  };

  static Credit? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    return Credit(
      name: name,
      role: json['role'] as String?,
      profilePath: json['profile'] as String?,
    );
  }
}

/// A YouTube trailer, teaser or clip.
class TitleVideo {
  const TitleVideo({required this.youtubeKey, required this.name, this.type});

  final String youtubeKey;
  final String name;

  /// Such as "Trailer", "Teaser" or "Clip".
  final String? type;

  Uri get url => Uri.https('www.youtube.com', '/watch', {'v': youtubeKey});

  Map<String, dynamic> toJson() => {
    'key': youtubeKey,
    'name': name,
    'type': type,
  };

  static TitleVideo? fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    if (key is! String || key.isEmpty) return null;
    return TitleVideo(
      youtubeKey: key,
      name: json['name'] as String? ?? 'Trailer',
      type: json['type'] as String?,
    );
  }
}

class SeasonSummary {
  const SeasonSummary({
    required this.number,
    required this.name,
    required this.episodeCount,
    this.airDate,
    this.posterPath,
    this.overview = '',
  });

  final int number;
  final String name;
  final int episodeCount;
  final DateTime? airDate;
  final String? posterPath;
  final String overview;

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'episodes': episodeCount,
    'air_date': airDate?.toIso8601String(),
    'poster': posterPath,
    'overview': overview,
  };

  factory SeasonSummary.fromJson(Map<String, dynamic> json) => SeasonSummary(
    number: json['number'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    episodeCount: json['episodes'] as int? ?? 0,
    airDate: DateTime.tryParse(json['air_date'] as String? ?? ''),
    posterPath: json['poster'] as String?,
    overview: json['overview'] as String? ?? '',
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
    this.stillPath,
  });

  final int season;
  final int number;
  final String name;
  final String overview;
  final DateTime? airDate;
  final int? runtime;

  /// A frame from the episode.
  final String? stillPath;

  String get code => episodeCode(season, number);

  bool airedBy(DateTime now) => airDate != null && !airDate!.isAfter(now);

  Map<String, dynamic> toJson() => {
    'season': season,
    'number': number,
    'name': name,
    'overview': overview,
    'air_date': airDate?.toIso8601String(),
    'runtime': runtime,
    'still': stillPath,
  };

  factory EpisodeSummary.fromJson(Map<String, dynamic> json) => EpisodeSummary(
    season: json['season'] as int? ?? 0,
    number: json['number'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    overview: json['overview'] as String? ?? '',
    airDate: DateTime.tryParse(json['air_date'] as String? ?? ''),
    runtime: json['runtime'] as int?,
    stillPath: json['still'] as String?,
  );
}
