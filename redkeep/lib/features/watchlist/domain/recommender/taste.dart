import 'dart:math';

import '../watch_title.dart';
import 'feature_space.dart';

/// What the reader never wants dealt.
class Dealbreakers {
  const Dealbreakers({
    this.excludedGenres = const {},
    this.maxRuntime = 0,
    this.films = true,
    this.shows = true,
    this.anyLanguage = true,
  });

  final Set<String> excludedGenres;

  /// Minutes; 0 for no limit. Only applies where the runtime is known.
  final int maxRuntime;
  final bool films;
  final bool shows;

  /// Off keeps the deck to English-language titles.
  final bool anyLanguage;

  Dealbreakers copyWith({
    Set<String>? excludedGenres,
    int? maxRuntime,
    bool? films,
    bool? shows,
    bool? anyLanguage,
  }) => Dealbreakers(
    excludedGenres: excludedGenres ?? this.excludedGenres,
    maxRuntime: maxRuntime ?? this.maxRuntime,
    films: films ?? this.films,
    shows: shows ?? this.shows,
    anyLanguage: anyLanguage ?? this.anyLanguage,
  );

  Map<String, dynamic> toJson() => {
    'excluded_genres': excludedGenres.toList()..sort(),
    'max_runtime': maxRuntime,
    'films': films,
    'shows': shows,
    'any_language': anyLanguage,
  };

  factory Dealbreakers.fromJson(Map<String, dynamic> json) => Dealbreakers(
    excludedGenres: {
      for (final g in json['excluded_genres'] as List? ?? const [])
        if (g is String) g,
    },
    maxRuntime: (json['max_runtime'] as int? ?? 0).clamp(0, 600),
    films: json['films'] as bool? ?? true,
    shows: json['shows'] as bool? ?? true,
    anyLanguage: json['any_language'] as bool? ?? true,
  );
}

/// The reader's taste, learned from Discover and watch nights. Synced as the
/// single `watchtaste` document.
class WatchProfile {
  WatchProfile({
    List<double>? taste,
    this.swipes = 0,
    List<double>? recentScores,
    this.offset = 0,
    this.dealbreakers = const Dealbreakers(),
  }) : taste = taste ?? List.filled(FeatureSpace.dimensions, 0.0),
       recentScores = recentScores ?? [];

  /// Unnormalised; its direction is what matters.
  final List<double> taste;
  int swipes;

  /// Recent match scores, for a threshold that adapts to the reader.
  final List<double> recentScores;

  /// Raised by bad nights, lowered by good ones.
  double offset;
  Dealbreakers dealbreakers;

  static const coldStartSwipes = 15;
  static const everyLikeMatches = 8;
  static const decay = .985;

  bool get coldStart => swipes < coldStartSwipes;
  bool get empty => taste.every((v) => v == 0);

  WatchProfile copy() => WatchProfile.fromJson(toJson());

  /// How much the reader should enjoy a title, 0 to 1.
  double enjoyment(List<double> vector) =>
      empty ? .5 : 1 / (1 + exp(-6 * (cosine(taste, vector) - .15)));

  void _learn(List<double> vector, double weight, {bool decays = true}) {
    for (var i = 0; i < taste.length; i++) {
      taste[i] = (decays ? taste[i] * decay : taste[i]) + weight * vector[i];
    }
  }

  static double swipeWeight(SwipeChoice choice) => switch (choice) {
    SwipeChoice.nope => -1,
    SwipeChoice.like => 1,
    // Chosen once, so a mild lean toward it; no match to follow.
    SwipeChoice.watched => .5,
  };

  /// Decides a match against the taste before this swipe, then learns.
  bool swipe(List<double> vector, SwipeChoice choice) {
    var matched = false;
    if (choice == SwipeChoice.like) {
      final score = enjoyment(vector);
      matched = swipes < everyLikeMatches || score >= threshold;
      recentScores.add(score);
      if (recentScores.length > 40) recentScores.removeAt(0);
    }
    swipes++;
    _learn(vector, swipeWeight(choice));
    return matched;
  }

  /// About two thirds of likes match, moved by how nights have gone.
  double get threshold {
    if (recentScores.isEmpty) return offset;
    final sorted = [...recentScores]..sort();
    return sorted[((sorted.length - 1) * .32).round()] + offset;
  }

  void night(List<double> vector, NightOutcome outcome) {
    _learn(vector, switch (outcome) {
      NightOutcome.loved => 4,
      NightOutcome.fine => .5,
      NightOutcome.neverAgain => -3,
    });
    offset =
        (offset +
                switch (outcome) {
                  NightOutcome.loved => -.01,
                  NightOutcome.fine => 0,
                  NightOutcome.neverAgain => .02,
                })
            .clamp(-.1, .15);
  }

  /// A like on one part of a profile teaches only that facet.
  void likeFacet(List<double> vector, String facet) {
    final start = FeatureSpace.offsetOf(facet);
    final size = FeatureSpace.facets.firstWhere((f) => f.name == facet).size;
    for (var i = start; i < start + size; i++) {
      taste[i] += 1.5 * vector[i];
    }
  }

  /// A match left to expire, or ended.
  void lost(List<double> vector) => _learn(vector, -.5, decays: false);

  Map<String, dynamic> toJson() => {
    'version': 1,
    'taste': [for (final v in taste) double.parse(v.toStringAsFixed(5))],
    'swipes': swipes,
    'recent_scores': [
      for (final s in recentScores) double.parse(s.toStringAsFixed(4)),
    ],
    'offset': offset,
    'dealbreakers': dealbreakers.toJson(),
  };

  factory WatchProfile.fromJson(Map<String, dynamic> json) {
    final taste = [
      for (final v in json['taste'] as List? ?? const [])
        if (v is num) v.toDouble(),
    ];
    return WatchProfile(
      // A changed feature space starts taste afresh rather than misreading it.
      taste: taste.length == FeatureSpace.dimensions ? taste : null,
      swipes: json['swipes'] as int? ?? 0,
      recentScores: [
        for (final v in json['recent_scores'] as List? ?? const [])
          if (v is num) v.toDouble(),
      ],
      offset: (json['offset'] as num?)?.toDouble() ?? 0,
      dealbreakers: json['dealbreakers'] is Map
          ? Dealbreakers.fromJson(
              (json['dealbreakers'] as Map).cast<String, dynamic>(),
            )
          : const Dealbreakers(),
    );
  }
}
