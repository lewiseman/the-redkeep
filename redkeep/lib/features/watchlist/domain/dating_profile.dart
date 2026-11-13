import 'catalog_title.dart';
import 'explore.dart';
import 'recommender/feature_space.dart';
import 'recommender/taste.dart';
import 'watch_title.dart';

class ProfilePrompt {
  const ProfilePrompt(this.question, this.answer, {this.facet});
  final String question;
  final String answer;

  /// What a like on this prompt teaches.
  final String? facet;
}

class Vitals {
  const Vitals({
    this.height,
    this.age,
    this.rating,
    this.language,
    this.livesOn,
  });

  /// Runtime, such as "2h 7m".
  final String? height;

  /// Years since release.
  final int? age;
  final String? rating;
  final String? language;

  /// Streaming services.
  final List<String>? livesOn;
}

/// A film or show written up as a dating profile.
class DatingProfile {
  const DatingProfile({
    required this.bio,
    required this.vitals,
    required this.prompts,
    required this.greenFlags,
    required this.redFlags,
  });

  final String bio;
  final Vitals vitals;
  final List<ProfilePrompt> prompts;
  final List<String> greenFlags;
  final List<String> redFlags;

  /// The first prompt: who this title is looking for.
  String get lookingFor => prompts.first.answer;

  static const _bios = <String, List<String>>{
    'Horror': [
      "I'll keep you up at night, and not in the fun way. Okay, a bit in the fun way.",
      'Looking for someone who holds hands during the scary bits.',
    ],
    'Comedy': [
      "I'm the one who makes you snort-laugh in public.",
      "Low effort, high reward. I'll make your bad day better.",
    ],
    'Romance': [
      'Hopeless romantic seeking someone who cries at airports.',
      'I believe in grand gestures and rain-soaked confessions.',
    ],
    'Drama': [
      "I'll make you feel things. Bring tissues and an open heart.",
      'Deep conversations only. Small talk is for trailers.',
    ],
    'Action': [
      'Adrenaline junkie. I do my own stunts.',
      "Things explode around me. I don't look back.",
    ],
    'Science Fiction': [
      'Big ideas, bigger questions. Will rearrange how you see the stars.',
      "I've been to the future. You're in it.",
    ],
    'Thriller': [
      "Trust issues, but I'll keep you on the edge of your seat.",
      "Twists you won't see coming. Neither will your friends.",
    ],
    'Animation': ['Young at heart, but I hit harder than you think.'],
    'Documentary': ['Everything about me is true. Ask me anything.'],
    'Crime': ['Morally grey and proud of it.'],
    'Fantasy': [
      'Swords, spells and a map in the front. Come get lost with me.',
    ],
    'Mystery': ["I've got secrets. Stick around till the end."],
    'Family': ['Great with parents. Even better with snacks.'],
  };

  static const _seriesBios = [
    "Not a one-night thing. I'm looking for something long-term.",
    'Fair warning: once you start, you will want to see me every night.',
  ];

  /// Deterministic per title, so a profile reads the same every time.
  static DatingProfile of(CatalogTitle t, {DateTime? now}) {
    final year = (now ?? DateTime.now()).year;
    final seed = t.key.tmdbId;
    final genre = FeatureSpace.genresOf(t).firstOrNull;
    final options =
        _bios[genre] ?? const ['Hard to describe. Easier to watch.'];
    var bio = options[seed % options.length];
    if (t.media == WatchMedia.tv && seed.isEven) {
      bio = _seriesBios[(seed ~/ 2) % _seriesBios.length];
    }
    if (t.tagline.isNotEmpty) bio = '$bio (${t.tagline})';
    return DatingProfile(
      bio: bio,
      vitals: Vitals(
        height: _height(t),
        age: t.year == null ? null : year - t.year!,
        rating: t.voteCount > 0
            ? '${t.voteAverage.toStringAsFixed(1)}/10'
            : null,
        language: t.language?.toUpperCase(),
        livesOn: t.providers.isEmpty ? null : t.providers,
      ),
      prompts: _prompts(t),
      greenFlags: _greenFlags(t),
      redFlags: _redFlags(t),
    );
  }

  static String? _height(CatalogTitle t) {
    final runtime = t.runtime;
    if (runtime == null) return null;
    if (t.media == WatchMedia.tv) {
      final seasons = t.seasons.length;
      return seasons == 0
          ? '${runtime}m an episode'
          : '${runtime}m an episode, $seasons season${seasons == 1 ? '' : 's'}';
    }
    return duration(runtime);
  }

  static String duration(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m}m';
  }

  static List<ProfilePrompt> _prompts(CatalogTitle t) => [
    ProfilePrompt('My ideal viewer...', _idealViewer(t), facet: 'tone'),
    if (t.director != null)
      ProfilePrompt('I was raised by...', t.director!, facet: 'people'),
    if (t.cast.isNotEmpty)
      ProfilePrompt(
        'You should know my friends...',
        t.cast.take(3).join(', '),
        facet: 'people',
      ),
    if (t.keywords.isNotEmpty)
      ProfilePrompt(
        "I'm into...",
        t.keywords.take(4).join(' · '),
        facet: 'tone',
      ),
    if (t.year != null) ProfilePrompt('Born in...', '${t.year}', facet: 'era'),
  ];

  static String _idealViewer(CatalogTitle t) {
    final genres = FeatureSpace.genresOf(t);
    final parts = [
      if (t.language != null && t.language != 'en') "doesn't mind reading",
      if ((t.runtime ?? 0) > 140 || t.seasons.length > 3) 'has a free evening',
      if (genres.contains('Horror') || genres.contains('War'))
        'has nerves of steel',
      if (t.year != null && t.year! < 1980) 'appreciates a classic',
      if (t.voteCount > 0 && t.voteCount < 800) 'likes finding things first',
    ];
    if (parts.isEmpty) return "Anyone with popcorn. I'm easy-going.";
    return 'Someone who ${parts.join(', ')}.';
  }

  static List<String> _greenFlags(CatalogTitle t) {
    final genres = FeatureSpace.genresOf(t);
    return [
      if (desirability(t) >= .78) 'Critics adore me',
      if (isHiddenGem(t)) "Hidden gem, you'll be the first of your friends",
      if (t.media == WatchMedia.movie &&
          t.runtime != null &&
          FeatureSpace.runtimeBucket(t.runtime!) == 0)
        "Won't keep you up late",
      if (t.voteCount >= 10000) 'Everyone has heard of me',
      if (genres.contains('Family') || genres.contains('Animation'))
        'Fine to watch with your parents',
      if (t.media == WatchMedia.tv && t.seasons.length == 1) 'Low commitment',
    ];
  }

  static List<String> _redFlags(CatalogTitle t) {
    final genres = FeatureSpace.genresOf(t);
    return [
      if (t.media == WatchMedia.movie &&
          t.runtime != null &&
          FeatureSpace.runtimeBucket(t.runtime!) == 2)
        'Clingy: ${duration(t.runtime!)} long',
      if (t.media == WatchMedia.tv && t.seasons.length >= 5)
        'Big commitment: ${t.seasons.length} seasons',
      if (t.language != null && t.language != 'en') 'Subtitles',
      if (genres.contains('Horror')) 'Jump scares',
      if (genres.contains('War')) 'Emotionally heavy',
      if (t.voteCount > 0 && t.voteAverage < 6) 'Divisive',
      if (t.year != null && t.year! < 1970) 'Old-fashioned',
    ];
  }

  /// Small talk for the match screen: what you have in common.
  static String icebreaker(CatalogTitle t, WatchProfile profile) {
    if (profile.empty) return 'A fresh start. Who knows where this goes?';
    final vector = FeatureSpace.vector(t);
    final similarity = cosine(profile.taste, vector);
    if (similarity <= 0) return 'Opposites attract?';
    var facet = '';
    var best = double.negativeInfinity;
    var offset = 0;
    for (final f in FeatureSpace.facets) {
      var score = 0.0;
      for (var i = offset; i < offset + f.size; i++) {
        score += profile.taste[i] * vector[i];
      }
      if (score > best) {
        best = score;
        facet = f.name;
      }
      offset += f.size;
    }
    final genre = FeatureSpace.genresOf(t).firstOrNull?.toLowerCase();
    final line = switch (facet) {
      'genre' => 'You both love ${genre ?? 'a good story'}.',
      'tone' => "You're on the same wavelength.",
      'people' => 'You have friends in common.',
      'era' => 'You grew up in the same era.',
      'runtime' => 'You agree on how long a night in should be.',
      'language' => 'You speak the same language.',
      _ =>
        t.media == WatchMedia.tv
            ? 'You both like a long story.'
            : 'You both like a night in.',
    };
    return profile.enjoyment(vector) > .8
        ? '$line This could be the one.'
        : line;
  }
}
