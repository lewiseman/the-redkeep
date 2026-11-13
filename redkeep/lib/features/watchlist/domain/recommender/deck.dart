import 'dart:math';

import '../catalog_title.dart';
import '../explore.dart';
import 'feature_space.dart';
import 'taste.dart';

enum DeckSlot { coldStart, exploit, adjacent, wildcard }

class DeckCard {
  const DeckCard({
    required this.title,
    required this.enjoyment,
    required this.slot,
    required this.reason,
  });

  final CatalogTitle title;
  final double enjoyment;
  final DeckSlot slot;

  /// One line on why this card was dealt.
  final String reason;

  /// Hidden while Discover is still getting to know the reader.
  bool get showsMatch => slot != DeckSlot.coldStart;
  int get matchPercent => (enjoyment * 100).round().clamp(1, 99);
}

/// Deals a batch: mostly what the reader likes, some neighbours, a few
/// surprises, never too much of one genre in a row.
class DeckBuilder {
  DeckBuilder({Random? random}) : _random = random ?? Random();
  final Random _random;

  static const batchSize = 10;
  static const coldStartBatch = 5;

  static bool allowed(CatalogTitle title, Dealbreakers rules) {
    if (title.posterPath == null) return false;
    if (title.media.name == 'movie' ? !rules.films : !rules.shows) return false;
    if (!rules.anyLanguage &&
        title.language != null &&
        title.language != 'en') {
      return false;
    }
    final runtime = title.runtime;
    if (rules.maxRuntime > 0 && runtime != null && runtime > rules.maxRuntime) {
      return false;
    }
    return !FeatureSpace.genresOf(title).any(rules.excludedGenres.contains);
  }

  List<DeckCard> build({
    required List<CatalogTitle> candidates,
    required WatchProfile profile,
    required Set<String> seen,
    List<CatalogTitle> liked = const [],
  }) {
    final pool = [
      for (final c in candidates)
        if (!seen.contains(c.key.id) && allowed(c, profile.dealbreakers)) c,
    ];
    if (pool.isEmpty) return const [];
    final vectors = {for (final c in pool) c.key: FeatureSpace.vector(c)};
    if (profile.coldStart) return _coldStart(pool, vectors, profile);

    final scored = [
      for (final c in pool) (c, profile.enjoyment(vectors[c.key]!)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final third = (scored.length * .3).ceil();
    final exploit = scored.take(third).toList();
    final adjacent = scored
        .skip(third)
        .take(scored.length - 2 * third)
        .toList();
    final wildcard = scored.skip(scored.length - third).toList();
    final likedVectors = {
      for (final l in liked) l.title: FeatureSpace.vector(l),
    };

    final dealt = <DeckCard>[];
    final chosen = <List<double>>[];
    final size = min(batchSize, pool.length);
    var attempts = 0;
    while (dealt.length < size && attempts++ < size * 6) {
      final roll = _random.nextDouble();
      final (slot, from) = roll < .7 && exploit.isNotEmpty
          ? (DeckSlot.exploit, exploit)
          : roll < .9 && adjacent.isNotEmpty
          ? (DeckSlot.adjacent, adjacent)
          : wildcard.isNotEmpty
          ? (DeckSlot.wildcard, wildcard)
          : exploit.isNotEmpty
          ? (DeckSlot.exploit, exploit)
          : (DeckSlot.adjacent, adjacent);
      if (from.isEmpty) break;
      final pick = _diverse(from, vectors, chosen, dealt, slot);
      if (pick == null) continue;
      from.remove(pick);
      final vector = vectors[pick.$1.key]!;
      chosen.add(vector);
      dealt.add(
        DeckCard(
          title: pick.$1,
          enjoyment: pick.$2,
          slot: slot,
          reason: _reason(slot, vector, likedVectors, profile),
        ),
      );
    }
    return dealt;
  }

  /// Relevance less similarity to cards already dealt, and no fourth card
  /// running of the same leading genre.
  (CatalogTitle, double)? _diverse(
    List<(CatalogTitle, double)> from,
    Map<Object, List<double>> vectors,
    List<List<double>> chosen,
    List<DeckCard> dealt,
    DeckSlot slot,
  ) {
    String? lead(CatalogTitle t) => FeatureSpace.genresOf(t).firstOrNull;
    final streak =
        dealt.length >= 3 &&
            dealt
                    .skip(dealt.length - 3)
                    .map((c) => lead(c.title))
                    .toSet()
                    .length ==
                1
        ? lead(dealt.last.title)
        : null;
    (CatalogTitle, double)? best;
    var bestScore = double.negativeInfinity;
    for (final candidate in from.take(60)) {
      if (streak != null && lead(candidate.$1) == streak) continue;
      final vector = vectors[candidate.$1.key]!;
      final relevance = slot == DeckSlot.wildcard
          ? .5 * _desirability(candidate.$1) + .5 * _random.nextDouble()
          : candidate.$2;
      final overlap = chosen.isEmpty
          ? 0.0
          : chosen.map((c) => cosine(c, vector)).reduce(max);
      final score = .75 * relevance - .25 * overlap;
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
  }

  /// Getting to know the reader: well-known titles across as many genres as
  /// possible, so each swipe teaches something new.
  List<DeckCard> _coldStart(
    List<CatalogTitle> pool,
    Map<Object, List<double>> vectors,
    WatchProfile profile,
  ) {
    final known = [...pool]
      ..sort((a, b) => b.voteCount.compareTo(a.voteCount))
      ..removeRange(min(pool.length, 120), pool.length);
    final explored = <String>{
      for (var i = 0; i < FeatureSpace.genres.length; i++)
        if (profile.taste[i] != 0) FeatureSpace.genres[i],
    };
    final dealt = <DeckCard>[];
    while (dealt.length < min(coldStartBatch, known.length)) {
      final recent = dealt.reversed.take(3).map((c) => vectors[c.title.key]!);
      CatalogTitle? best;
      var bestScore = double.negativeInfinity;
      for (final title in known) {
        final genres = FeatureSpace.genresOf(title);
        final fresh = genres.where((g) => !explored.contains(g)).length;
        final overlap = recent.isEmpty
            ? 0.0
            : recent.map((v) => cosine(v, vectors[title.key]!)).reduce(max);
        final score =
            fresh * .4 +
            .3 / sqrt(max(1, genres.length)) +
            .2 * _desirability(title) -
            .8 * overlap +
            _random.nextDouble() * .01;
        if (score > bestScore) {
          bestScore = score;
          best = title;
        }
      }
      known.remove(best);
      explored.addAll(FeatureSpace.genresOf(best!));
      dealt.add(
        DeckCard(
          title: best,
          enjoyment: .5,
          slot: DeckSlot.coldStart,
          reason: 'Getting to know your taste',
        ),
      );
    }
    return dealt;
  }

  String _reason(
    DeckSlot slot,
    List<double> vector,
    Map<String, List<double>> liked,
    WatchProfile profile,
  ) {
    if (slot == DeckSlot.wildcard) return 'Something different';
    String? closest;
    var best = .5;
    liked.forEach((title, v) {
      final similarity = cosine(v, vector);
      if (similarity > best) {
        best = similarity;
        closest = title;
      }
    });
    if (closest != null) return 'Because you liked $closest';
    final genre = _strongestGenre(vector, profile);
    return genre == null ? 'Picked for you' : 'You keep choosing $genre';
  }

  String? _strongestGenre(List<double> vector, WatchProfile profile) {
    String? best;
    var score = 0.0;
    for (var i = 0; i < FeatureSpace.genres.length; i++) {
      final s = vector[i] * profile.taste[i];
      if (s > score) {
        score = s;
        best = FeatureSpace.genres[i];
      }
    }
    return best;
  }

  static double _desirability(CatalogTitle t) => desirability(t);
}
