import 'dart:math';

import '../catalog_title.dart';
import '../watch_title.dart';

/// Every title as a point in one space, so taste is a direction in it.
///
/// Facets are normalised on their own, weighted, then the whole vector is
/// normalised: a title with few facts (a search result) still compares fairly
/// with a fully detailed one on the facets they share.
class FeatureSpace {
  static const genres = [
    'Action',
    'Adventure',
    'Animation',
    'Comedy',
    'Crime',
    'Documentary',
    'Drama',
    'Family',
    'Fantasy',
    'History',
    'Horror',
    'Music',
    'Mystery',
    'Romance',
    'Science Fiction',
    'TV Movie',
    'Thriller',
    'War',
    'Western',
  ];

  /// Show genres folded into film genres.
  static const _aliases = {
    'Action & Adventure': ['Action', 'Adventure'],
    'Sci-Fi & Fantasy': ['Science Fiction', 'Fantasy'],
    'War & Politics': ['War', 'History'],
    'Kids': ['Family', 'Animation'],
    'Soap': ['Drama', 'Romance'],
    'Reality': ['Documentary'],
    'News': ['Documentary'],
    'Talk': ['Comedy'],
  };

  static const facets = <Facet>[
    Facet('genre', 19, 1.0),
    Facet('tone', 32, .8),
    Facet('people', 32, .6),
    Facet('era', 11, .5),
    Facet('runtime', 3, .4),
    Facet('language', 8, .5),
    Facet('form', 2, .3),
  ];

  static final int dimensions = facets.fold(0, (sum, f) => sum + f.size);

  static int offsetOf(String facet) {
    var offset = 0;
    for (final f in facets) {
      if (f.name == facet) return offset;
      offset += f.size;
    }
    throw ArgumentError.value(facet, 'facet');
  }

  static List<String> genresOf(CatalogTitle title) => {
    for (final g in title.genres)
      ...?_aliases[g] ?? (genres.contains(g) ? [g] : null),
  }.toList();

  static List<double> vector(CatalogTitle title) {
    final slices = <String, List<double>>{
      for (final f in facets) f.name: List.filled(f.size, 0.0),
    };
    for (final g in genresOf(title)) {
      slices['genre']![genres.indexOf(g)] = 1;
    }
    for (final k in title.keywords) {
      slices['tone']![stableHash('k:${k.toLowerCase()}') % 32] += 1;
    }
    if (title.director != null) {
      slices['people']![stableHash('p:${title.director}') % 32] += 1.5;
    }
    for (var i = 0; i < title.cast.length && i < 5; i++) {
      slices['people']![stableHash('p:${title.cast[i]}') % 32] += 1 - i * .12;
    }
    final year = title.year;
    if (year != null) {
      final decade = ((year - 1920) ~/ 10).clamp(0, 10);
      slices['era']![decade] = 1;
      if (decade > 0) slices['era']![decade - 1] = .4;
      if (decade < 10) slices['era']![decade + 1] = .4;
    }
    final runtime = title.runtime;
    if (runtime != null) {
      slices['runtime']![runtimeBucket(runtime)] = 1;
    }
    final language = title.language;
    if (language != null) {
      slices['language']![language == 'en'
              ? 0
              : 1 + stableHash('l:$language') % 7] =
          1;
    }
    slices['form']![title.media == WatchMedia.tv ? 1 : 0] = 1;
    final result = <double>[];
    for (final f in facets) {
      final slice = slices[f.name]!;
      final length = _norm(slice);
      final scale = length == 0 ? 0.0 : sqrt(f.weight) / length;
      result.addAll(slice.map((v) => v * scale));
    }
    return normalise(result);
  }

  static int runtimeBucket(int minutes) => minutes < 95
      ? 0
      : minutes <= 140
      ? 1
      : 2;
}

class Facet {
  const Facet(this.name, this.size, this.weight);
  final String name;
  final int size;
  final double weight;
}

/// FNV-1a: stable across runs and devices, unlike [String.hashCode].
int stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

double _norm(List<double> v) => sqrt(v.fold(0.0, (s, x) => s + x * x));

List<double> normalise(List<double> v) {
  final length = _norm(v);
  return length == 0 ? v : [for (final x in v) x / length];
}

double cosine(List<double> a, List<double> b) {
  final la = _norm(a), lb = _norm(b);
  if (la == 0 || lb == 0) return 0;
  var dot = 0.0;
  for (var i = 0; i < a.length && i < b.length; i++) {
    dot += a[i] * b[i];
  }
  return dot / (la * lb);
}
