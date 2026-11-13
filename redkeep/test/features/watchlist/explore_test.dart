import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/watchlist/data/drift_watchlist_repository.dart';
import 'package:redkeep/features/watchlist/domain/catalog_title.dart';
import 'package:redkeep/features/watchlist/domain/explore.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';
import 'package:redkeep/features/watchlist/presentation/explore_view.dart';

import '../../support/pump_app.dart';

CatalogTitle film(
  int id,
  String name,
  List<String> genres, {
  WatchMedia media = WatchMedia.movie,
  int? runtime,
  int year = 2015,
  double rating = 7,
  int votes = 5000,
}) => CatalogTitle(
  key: WatchKey(media, id),
  title: name,
  year: year,
  genres: genres,
  runtime: runtime,
  posterPath: '/$id.jpg',
  voteAverage: rating,
  voteCount: votes,
);

void main() {
  test('moods match genres, lengths and eras, and ask TMDB the same way', () {
    final cozy = Mood.byId('cozy')!;
    expect(cozy.matches(film(1, 'Up', ['Animation'], runtime: 96)), isTrue);
    expect(cozy.matches(film(2, 'Long', ['Comedy'], runtime: 150)), isFalse);
    expect(cozy.matches(film(3, 'Unknown length', ['Comedy'])), isFalse);
    expect(
      Mood.byId('mind')!.matches(
        film(4, 'Dark', ['Sci-Fi & Fantasy'], media: WatchMedia.tv),
      ),
      isTrue,
      reason: 'show genres fold into film genres',
    );
    expect(Mood.byId('classic')!.matches(film(5, 'Jaws', [], year: 1975)), isTrue);

    expect(moodFilters(cozy, WatchMedia.tv), isNull, reason: 'films only');
    expect(moodFilters(cozy, WatchMedia.movie), {
      'sort_by': 'popularity.desc',
      'vote_count.gte': '200',
      'with_genres': '35|10751|16|10749',
      'with_runtime.lte': '115',
    });
    expect(
      moodFilters(Mood.byId('classic')!, WatchMedia.movie)!['primary_release_date.lte'],
      '1980-01-01',
    );
    expect(isHiddenGem(film(6, 'Gem', [], rating: 7.6, votes: 400)), isTrue);
    expect(isHiddenGem(film(7, 'Famous', [], rating: 8.5, votes: 30000)), isFalse);
  });

  test('mood addresses are validated', () {
    expect(watchMoodLocation('scare'), '/watchlist/mood/scare');
    expect(watchMoodLocation('nope'), '/unavailable');
    expect(validatedNavigationLocation('/watchlist/mood/cry'), '/watchlist/mood/cry');
    expect(validatedNavigationLocation('/watchlist/mood/sad'), '/unavailable');
    expect(validatedNavigationLocation('/watchlist/mood/cry/1'), '/unavailable');
  });

  group('pages', () {
    late AppDatabase db;
    late DriftWatchlistRepository repository;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftWatchlistRepository(
        db,
        clock: DateTime.now,
        newId: () => 'd' * 32,
      );
    });
    tearDown(() => db.close());

    void pageTest(String description, Future<void> Function(WidgetTester) body) {
      testWidgets(description, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
    }

    pageTest('Explore shows rows of unseen titles and opens a mood', (tester) async {
      await repository.cacheTitles([
        film(1, 'Paddington 2', ['Family', 'Comedy'], runtime: 104),
        film(2, 'The Thing', ['Horror'], year: 1982),
        film(3, 'Quiet Gem', ['Drama'], rating: 7.8, votes: 600),
        film(4, 'Severance', ['Mystery', 'Drama'], media: WatchMedia.tv),
        film(5, 'Saved Already', ['Comedy']),
      ]);
      await repository.setStatus(
        film(5, 'Saved Already', ['Comedy']),
        WatchStatus.planned,
      );
      await pumpApp(tester, initialLocation: '/watchlist', database: db);
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Explore'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('In the mood for'), findsOneWidget);
      expect(find.text('Popular right now'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Shows to settle into'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Hidden gems'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Quiet Gem'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Saved Already'), findsNothing, reason: 'already saved');

      await tester.scrollUntilVisible(
        find.text('Cozy night in'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Cozy night in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cozy night in'));
      await tester.pumpAndSettle();
      Finder onMood(String text) =>
          find.descendant(of: find.byType(WatchMoodPage), matching: find.text(text));
      expect(onMood('Paddington 2'), findsOneWidget);
      expect(onMood('The Thing'), findsNothing);
    });

    pageTest('coming back to Explore keeps its rows instead of loading again', (tester) async {
      await repository.cacheTitles([
        film(1, 'Paddington 2', ['Family', 'Comedy'], runtime: 104),
        film(2, 'The Thing', ['Horror'], year: 1982),
      ]);
      await pumpApp(tester, initialLocation: '/watchlist', database: db);
      Future<void> open(String section) async {
        await tester.tap(find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(section),
        ));
        await tester.pumpAndSettle();
      }

      await open('Explore');
      expect(find.text('Paddington 2'), findsWidgets);

      // Away: a new title reaches the catalog, and one is saved.
      await open('Library');
      await repository.cacheTitles([film(3, 'Newcomer', ['Drama'], votes: 9999)]);
      await repository.setStatus(
        film(2, 'The Thing', ['Horror'], year: 1982),
        WatchStatus.planned,
      );
      await open('Explore');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Newcomer'), findsNothing, reason: 'the rows were kept');
      expect(
        find.descendant(of: find.byType(ExploreView), matching: find.text('The Thing')),
        findsNothing,
        reason: 'saved titles still drop out',
      );

      // Pulling down asks again.
      await tester.fling(find.byType(ExploreView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Newcomer'), findsWidgets);
    });
  });
}
