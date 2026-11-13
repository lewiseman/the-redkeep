import 'catalog_title.dart';
import 'recommender/feature_space.dart';
import 'watch_title.dart';

/// A feeling mapped to genres and limits, browsed on Explore.
class Mood {
  const Mood(
    this.id,
    this.label, {
    this.genres = const [],
    this.maxRuntime,
    this.releasedBefore,
  });

  /// The address segment, `/watchlist/mood/<id>`.
  final String id;
  final String label;
  final List<String> genres;
  final int? maxRuntime;
  final int? releasedBefore;

  /// Films only: shows have no single runtime or release to limit.
  bool get filmsOnly => maxRuntime != null || releasedBefore != null;

  bool matches(CatalogTitle t) {
    if (filmsOnly && t.media != WatchMedia.movie) return false;
    final runtime = t.runtime, year = t.year;
    return (genres.isEmpty || FeatureSpace.genresOf(t).any(genres.contains)) &&
        (maxRuntime == null || (runtime != null && runtime <= maxRuntime!)) &&
        (releasedBefore == null || (year != null && year < releasedBefore!));
  }

  static Mood? byId(String? id) => all.where((m) => m.id == id).firstOrNull;

  static const all = [
    Mood(
      'cozy',
      'Cozy night in',
      genres: ['Comedy', 'Family', 'Animation', 'Romance'],
      maxRuntime: 115,
    ),
    Mood('scare', 'Scare me', genres: ['Horror', 'Thriller']),
    Mood('cry', 'Cry it out', genres: ['Drama', 'Romance']),
    Mood('laugh', 'Make me laugh', genres: ['Comedy']),
    Mood('mind', 'Mind-bending', genres: ['Science Fiction', 'Mystery']),
    Mood('rush', 'Adrenaline', genres: ['Action', 'Adventure']),
    Mood('short', 'Under 100 min', maxRuntime: 100),
    Mood('classic', 'Old classics', releasedBefore: 1980),
  ];
}

/// A rating trusted in proportion to its votes, 0 to 1.
double desirability(CatalogTitle t) =>
    ((t.voteAverage * t.voteCount + 6.5 * 500) / (t.voteCount + 500)) / 10;

/// Well rated by the few who found it.
bool isHiddenGem(CatalogTitle t) =>
    t.voteAverage >= 7.2 && t.voteCount >= 150 && t.voteCount <= 2500;

/// TMDB genre ids for each film genre, by media.
const tmdbGenreIds = <WatchMedia, Map<String, int>>{
  WatchMedia.movie: {
    'Action': 28,
    'Adventure': 12,
    'Animation': 16,
    'Comedy': 35,
    'Crime': 80,
    'Drama': 18,
    'Family': 10751,
    'Fantasy': 14,
    'Horror': 27,
    'Mystery': 9648,
    'Romance': 10749,
    'Science Fiction': 878,
    'Thriller': 53,
  },
  WatchMedia.tv: {
    'Action': 10759,
    'Adventure': 10759,
    'Animation': 16,
    'Comedy': 35,
    'Crime': 80,
    'Drama': 18,
    'Family': 10751,
    'Fantasy': 10765,
    'Mystery': 9648,
    'Science Fiction': 10765,
  },
};

/// TMDB discover filters for a mood, or null when that media cannot match.
Map<String, String>? moodFilters(Mood mood, WatchMedia media) {
  if (media == WatchMedia.tv && mood.filmsOnly) return null;
  final ids = {for (final g in mood.genres) ?tmdbGenreIds[media]![g]};
  if (mood.genres.isNotEmpty && ids.isEmpty) return null;
  return {
    'sort_by': mood.releasedBefore != null
        ? 'vote_average.desc'
        : 'popularity.desc',
    'vote_count.gte': '200',
    if (ids.isNotEmpty) 'with_genres': ids.join('|'),
    if (mood.maxRuntime != null) 'with_runtime.lte': '${mood.maxRuntime}',
    if (mood.releasedBefore != null)
      'primary_release_date.lte': '${mood.releasedBefore}-01-01',
  };
}
