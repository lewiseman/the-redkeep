import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/watchlist/application/watch_chat_controller.dart';
import 'package:redkeep/features/watchlist/domain/catalog_title.dart';
import 'package:redkeep/features/watchlist/domain/dating_profile.dart';
import 'package:redkeep/features/watchlist/domain/recommender/deck.dart';
import 'package:redkeep/features/watchlist/domain/recommender/feature_space.dart';
import 'package:redkeep/features/watchlist/domain/recommender/taste.dart';
import 'package:redkeep/features/watchlist/domain/reminders.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';
import 'package:redkeep/features/watchlist/presentation/night_planner.dart';

CatalogTitle title(
  int id,
  List<String> genres, {
  WatchMedia media = WatchMedia.movie,
  int year = 2010,
  int? runtime,
  String language = 'en',
  int votes = 3000,
}) => CatalogTitle(
  key: WatchKey(media, id),
  title: 'Title $id',
  year: year,
  genres: genres,
  runtime: runtime,
  language: language,
  posterPath: '/$id.jpg',
  voteAverage: 7,
  voteCount: votes,
);

WatchTitle saved(
  String name, {
  MatchState? match,
  DateTime? expiresAt,
  DateTime? nightAt,
  NightOutcome? outcome,
}) => WatchTitle(
  id: WatchKey(WatchMedia.movie, name.length).id,
  key: WatchKey(WatchMedia.movie, name.length),
  title: name,
  revision: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  matchState: match,
  expiresAt: expiresAt,
  nightAt: nightAt,
  outcome: outcome,
);

void main() {
  test('vectors fold show genres into film genres and are unit length', () {
    final show = FeatureSpace.vector(
      title(1, ['Sci-Fi & Fantasy'], media: WatchMedia.tv),
    );
    final film = FeatureSpace.vector(title(2, ['Science Fiction', 'Fantasy']));
    expect(show, hasLength(FeatureSpace.dimensions));
    expect(
      sqrt(show.fold(0.0, (s, v) => s + v * v)),
      closeTo(1, 1e-9),
    );
    expect(cosine(show, film), greaterThan(.75), reason: 'same genres and era');
    expect(cosine(show, film), lessThan(1), reason: 'a series is not a film');
    expect(stableHash('k:heist'), stableHash('k:heist'));
  });

  test('likes pull taste toward a genre; the first likes always match', () {
    final profile = WatchProfile();
    final horror = FeatureSpace.vector(title(1, ['Horror']));
    final comedy = FeatureSpace.vector(title(2, ['Comedy']));
    for (var i = 0; i < WatchProfile.everyLikeMatches; i++) {
      expect(profile.swipe(horror, SwipeChoice.like), isTrue);
    }
    for (var i = 0; i < 6; i++) {
      profile.swipe(comedy, SwipeChoice.nope);
    }
    expect(profile.enjoyment(horror), greaterThan(.8));
    expect(profile.enjoyment(comedy), lessThan(.5));
    expect(profile.swipe(comedy, SwipeChoice.like), isFalse, reason: 'below the bar');
    expect(profile.recentScores, hasLength(WatchProfile.everyLikeMatches + 1));

    final restored = WatchProfile.fromJson(profile.toJson());
    expect(restored.swipes, profile.swipes);
    expect(restored.enjoyment(horror), closeTo(profile.enjoyment(horror), 1e-3));
  });

  test('a loved night raises taste and lowers the bar; never again does neither', () {
    final profile = WatchProfile();
    final vector = FeatureSpace.vector(title(1, ['Drama']));
    profile.night(vector, NightOutcome.loved);
    expect(profile.offset, lessThan(0));
    expect(profile.enjoyment(vector), greaterThan(.9));
    profile
      ..night(vector, NightOutcome.neverAgain)
      ..night(vector, NightOutcome.neverAgain);
    expect(profile.offset, greaterThan(0));
  });

  test('the deck skips seen titles and dealbreakers, and breaks genre streaks', () {
    final catalog = [
      for (var i = 1; i <= 30; i++) title(i, ['Drama']),
      for (var i = 31; i <= 40; i++) title(i, ['Comedy']),
      title(41, ['Horror']),
      title(42, ['Drama'], runtime: 200),
      title(43, ['Drama'], language: 'fr'),
      CatalogTitle(key: const WatchKey(WatchMedia.movie, 44), title: 'No poster'),
    ];
    final profile = WatchProfile(
      swipes: 20,
      dealbreakers: const Dealbreakers(
        excludedGenres: {'Horror'},
        maxRuntime: 150,
        anyLanguage: false,
      ),
    );
    final drama = FeatureSpace.vector(title(99, ['Drama']));
    for (var i = 0; i < 10; i++) {
      profile.swipe(drama, SwipeChoice.like);
    }
    final deck = DeckBuilder(random: Random(1)).build(
      candidates: catalog,
      profile: profile,
      seen: {catalog.first.key.id},
    );
    final ids = deck.map((c) => c.title.key.tmdbId).toSet();
    expect(deck, hasLength(DeckBuilder.batchSize));
    expect(ids, isNot(contains(1)), reason: 'already seen');
    expect(ids, isNot(anyOf(contains(41), contains(42), contains(43), contains(44))));
    for (var i = 3; i < deck.length; i++) {
      final run = deck.sublist(i - 3, i + 1).map((c) => c.title.genres.first).toSet();
      expect(run.length, greaterThan(1), reason: 'no four in a row');
    }
  });

  test('cold start deals well-known titles across different genres', () {
    final catalog = [
      for (var i = 1; i <= 10; i++) title(i, ['Drama'], votes: 9000 - i),
      title(20, ['Comedy']),
      title(21, ['Horror']),
      title(22, ['Animation']),
      title(23, ['Western']),
    ];
    final deck = DeckBuilder(random: Random(2)).build(
      candidates: catalog,
      profile: WatchProfile(),
      seen: const {},
    );
    expect(deck, hasLength(DeckBuilder.coldStartBatch));
    expect(deck.every((c) => !c.showsMatch), isTrue);
    expect(deck.map((c) => c.title.genres.first).toSet().length, 5);
  });

  test('reminders: a day before a match ends, an hour before and after a night', () {
    final now = DateTime.utc(2026, 11, 13, 12);
    final plan = const ReminderPlanner().plan(
      [
        saved('Arrival', match: MatchState.active, expiresAt: now.add(const Duration(days: 3))),
        saved('Up', match: MatchState.dated, nightAt: now.add(const Duration(hours: 8))),
        saved('Heat', match: MatchState.active, expiresAt: now.add(const Duration(hours: 5))),
        saved('Jaws!', match: MatchState.dated, nightAt: now, outcome: NightOutcome.fine),
      ],
      now: now,
      runtimes: {saved('Up').id: 96},
    );
    expect(plan.map((r) => r.kind), [
      ReminderKind.matchExpiring,
      ReminderKind.nightSoon,
      ReminderKind.checkIn,
    ]);
    expect(plan[0].at, now.add(const Duration(days: 2)));
    expect(plan[1].at, now.add(const Duration(hours: 7)));
    expect(plan[2].at, now.add(const Duration(hours: 8, minutes: 111)));
    expect(plan.map((r) => r.id).toSet(), hasLength(3));
    expect(plan.every((r) => r.id > 0), isTrue);
  });

  test('quick nights offer tonight, tomorrow and the coming Saturday', () {
    // Wednesday afternoon.
    final wednesday = quickNights(DateTime(2026, 11, 11, 15));
    expect(wednesday.map((n) => n.$1), ['Tonight', 'Tomorrow night', 'Saturday night']);
    expect(wednesday.last.$2, DateTime(2026, 11, 14, 20));
    // Friday late: tonight has gone and Saturday is tomorrow.
    final friday = quickNights(DateTime(2026, 11, 13, 21));
    expect(friday.map((n) => n.$1), ['Tomorrow night']);
    // Saturday late: next Saturday.
    final saturday = quickNights(DateTime(2026, 11, 14, 22));
    expect(saturday.last.$2, DateTime(2026, 11, 21, 20));
  });

  test('chat history pairs messages and opens with a quiet reader turn', () {
    WatchChatMessage m(bool reader, String body) =>
        WatchChatMessage(id: body, fromReader: reader, body: body, at: DateTime.utc(2026));
    final exchanges = exchangesOf([
      m(false, 'Hey, I’m Arrival.'),
      m(true, 'Hi'),
      m(true, 'Are you sad?'),
      m(false, 'A little.'),
      m(true, 'Unanswered'),
    ]).toList();
    expect(exchanges, hasLength(2));
    expect(exchanges[0].user, '(We just matched.)');
    expect(exchanges[0].reply, 'Hey, I’m Arrival.');
    expect(exchanges[1].user, 'Hi\nAre you sad?');
    expect(exchanges[1].reply, 'A little.');
  });

  test('the persona speaks as the title, from its facts, without spoilers', () {
    final prompt = watchPersonaPrompt(
      const CatalogTitle(
        key: WatchKey(WatchMedia.tv, 1399),
        title: 'Game of Thrones',
        director: 'David Benioff',
        seasons: [SeasonSummary(number: 1, name: 'S1', episodeCount: 10)],
      ),
      saved('Up', match: MatchState.active),
    );
    expect(prompt, contains('You are the TV series "Game of Thrones"'));
    expect(prompt, contains('Created by: David Benioff'));
    expect(prompt, contains('just matched'));
    expect(prompt, contains('Never reveal twists'));
    expect(prompt, contains('you are an AI'));
  });

  test('a title reads as a dating profile, the same way every time', () {
    const heat = CatalogTitle(
      key: WatchKey(WatchMedia.movie, 949),
      title: 'Heat',
      year: 1995,
      genres: ['Crime', 'Thriller'],
      runtime: 170,
      director: 'Michael Mann',
      cast: ['Al Pacino', 'Robert De Niro', 'Val Kilmer', 'Jon Voight'],
      language: 'en',
      tagline: 'A Los Angeles crime saga',
      voteAverage: 8.0,
      voteCount: 7500,
    );
    final profile = DatingProfile.of(heat, now: DateTime(2026));
    expect(profile.bio, 'Morally grey and proud of it. (A Los Angeles crime saga)');
    expect(profile.vitals.height, '2h 50m');
    expect(profile.vitals.age, 31);
    expect(profile.vitals.rating, '8.0/10');
    expect(profile.lookingFor, 'Someone who has a free evening.');
    expect(profile.prompts.map((p) => p.question), contains('I was raised by...'));
    expect(profile.redFlags, contains('Clingy: 2h 50m long'));
    expect(profile.greenFlags, contains('Critics adore me'));
    expect(DatingProfile.of(heat, now: DateTime(2026)).bio, profile.bio);

    final show = DatingProfile.of(
      CatalogTitle(
        key: WatchKey(WatchMedia.tv, 2),
        title: 'Long Show',
        runtime: 50,
        seasons: [
          for (var i = 1; i <= 6; i++)
            const SeasonSummary(number: 1, name: 'S', episodeCount: 10),
        ],
      ),
    );
    expect(show.vitals.height, '50m an episode, 6 seasons');
    expect(show.redFlags, contains('Big commitment: 6 seasons'));
  });

  test('watched leans taste a little and never matches', () {
    final profile = WatchProfile();
    final vector = FeatureSpace.vector(title(1, ['Western']));
    expect(profile.swipe(vector, SwipeChoice.watched), isFalse);
    expect(profile.recentScores, isEmpty);
    expect(profile.enjoyment(vector), greaterThan(.5));
    expect(WatchProfile.swipeWeight(SwipeChoice.watched),
        lessThan(WatchProfile.swipeWeight(SwipeChoice.like)));
  });

  test('liking one part of a profile teaches only that facet', () {
    final profile = WatchProfile();
    final vector = FeatureSpace.vector(
      const CatalogTitle(
        key: WatchKey(WatchMedia.movie, 3),
        title: 'X',
        genres: ['Drama'],
        cast: ['Someone'],
        director: 'Someone Else',
      ),
    );
    profile.likeFacet(vector, 'people');
    final people = FeatureSpace.offsetOf('people');
    expect(profile.taste.sublist(people, people + 32).any((v) => v > 0), isTrue);
    expect(profile.taste.sublist(0, 19).every((v) => v == 0), isTrue);
  });
}
