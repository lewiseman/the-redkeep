import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/watchlist/application/watchlist_providers.dart';
import 'package:redkeep/features/watchlist/data/drift_watchlist_repository.dart';
import 'package:redkeep/features/watchlist/domain/catalog_title.dart';
import 'package:redkeep/features/watchlist/domain/explore.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';
import 'package:redkeep/features/watchlist/presentation/explore_view.dart';
import 'package:redkeep/features/watchlist/presentation/watch_explore_parts.dart';
import 'package:redkeep/features/watchlist/presentation/watch_wall.dart';

import '../../support/pump_app.dart';

Map<String, Object?> summary(int id, String title, {String media = 'movie'}) =>
    {
      'id': id,
      'media_type': media,
      if (media == 'movie') 'title': title else 'name': title,
      'poster_path': '/$id.jpg',
    };

void main() {
  test('moods ask TMDB by genre, length and era', () {
    final cozy = Mood.byId('cozy')!;
    expect(moodFilters(cozy, WatchMedia.tv), isNull, reason: 'films only');
    expect(moodFilters(cozy, WatchMedia.movie), {
      'sort_by': 'popularity.desc',
      'vote_count.gte': '200',
      'with_genres': '35|10751|16|10749',
      'with_runtime.lte': '115',
    });
    expect(
      moodFilters(
        Mood.byId('classic')!,
        WatchMedia.movie,
      )!['primary_release_date.lte'],
      '1980-01-01',
    );
  });

  test('mood addresses are validated', () {
    expect(watchMoodLocation('scare'), '/watchlist/mood/scare');
    expect(watchMoodLocation('nope'), '/unavailable');
    expect(
      validatedNavigationLocation('/watchlist/mood/cry'),
      '/watchlist/mood/cry',
    );
    expect(validatedNavigationLocation('/watchlist/mood/sad'), '/unavailable');
    expect(
      validatedNavigationLocation('/watchlist/mood/cry/1'),
      '/unavailable',
    );
  });

  group('search', () {
    late AppDatabase db;
    late DriftWatchlistRepository repository;
    late List<Uri> requests;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftWatchlistRepository(
        db,
        clock: DateTime.now,
        newId: () => 'd' * 32,
      );
      requests = [];
    });
    tearDown(() => db.close());

    // A TMDB that answers browsing, moods and search without the network.
    final tmdb = MockClient((request) async {
      requests.add(request.url);
      final results = switch (request.url.path) {
        '/3/trending/all/week' => [
          summary(1, 'Paddington 2'),
          summary(5, 'Saved Already'),
          summary(7, 'Heat'),
          summary(8, 'Jaws'),
        ],
        '/3/movie/popular' => [summary(2, 'The Thing')],
        '/3/tv/popular' => [summary(3, 'Severance', media: 'tv')],
        '/3/discover/movie' => [summary(4, 'Up')],
        '/3/search/multi' => [summary(6, 'Alien')],
        _ => const <Object>[],
      };
      return http.Response.bytes(
        utf8.encode(jsonEncode({'results': results})),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    Future<void> openSearch(WidgetTester tester) => pumpApp(
      tester,
      initialLocation: '/watchlist/search',
      database: db,
      overrides: [
        tmdbApiKeyProvider.overrideWithValue('test-key'),
        tmdbHttpClientProvider.overrideWithValue(tmdb),
      ],
    );

    void pageTest(
      String description,
      Future<void> Function(WidgetTester) body,
    ) {
      testWidgets(description, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
    }

    pageTest('an empty search browses moods and trending titles', (
      tester,
    ) async {
      await repository.setStatus(
        const CatalogTitle(
          key: WatchKey(WatchMedia.movie, 5),
          title: 'Saved Already',
        ),
        WatchStatus.planned,
      );
      await openSearch(tester);

      expect(find.byType(ExploreView), findsOneWidget);
      expect(find.text('In the mood for'), findsNothing);
      expect(find.text('🍿'), findsOneWidget, reason: 'each mood its emoji');
      // The page's own list, not a row of posters inside it.
      final page = find
          .descendant(
            of: find.byType(ExploreView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Paddington 2'),
        200,
        scrollable: page,
      );
      expect(find.textContaining('Now showing'), findsNothing);
      expect(find.text('Saved Already'), findsNothing, reason: 'already saved');
      await tester.scrollUntilVisible(
        find.text('Severance'),
        200,
        scrollable: page,
      );
      expect(find.text('Popular shows'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Cozy night in'),
        -200,
        scrollable: page,
      );
      await tester.ensureVisible(find.text('Cozy night in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cozy night in'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(WatchMoodPage),
          matching: find.text('Up'),
        ),
        findsOneWidget,
      );
      final mood = requests.lastWhere((u) => u.path == '/3/discover/movie');
      expect(mood.queryParameters['with_runtime.lte'], '115');
    });

    pageTest('pinning a loose photo tapes it to the wall, and undo peels it', (
      tester,
    ) async {
      await openSearch(tester);
      final page = find
          .descendant(
            of: find.byType(ExploreView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Paddington 2'),
        200,
        scrollable: page,
      );
      await tester.pumpAndSettle();
      expect(find.byType(WashiTape), findsNothing, reason: 'all loose');

      final paddington = find.ancestor(
        of: find.text('Paddington 2'),
        matching: find.byType(LoosePolaroid),
      );
      final pin = find.descendant(
        of: paddington,
        matching: find.byType(GlassBead),
      );
      // Clear of the search dock at the foot of the page.
      await Scrollable.ensureVisible(tester.element(pin), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(pin);
      await tester.pumpAndSettle();
      final row = await db.select(db.watchTitles).getSingle();
      expect(row.status, 'planned');
      expect(row.title, 'Paddington 2');
      expect(
        find.descendant(of: paddington, matching: find.byType(WashiTape)),
        findsOneWidget,
      );
      expect(
        find.text('Paddington 2'),
        findsOneWidget,
        reason: 'pinned here, so it stays to be seen taped',
      );

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        await repository.titles(),
        isEmpty,
        reason: 'taken back off the wall',
      );
    });

    pageTest('the trending fan keeps its shape when the page comes back', (
      tester,
    ) async {
      await openSearch(tester);
      Finder deck() => find
          .descendant(
            of: find.byType(ExploreView),
            matching: find.byType(PageView),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Paddington 2'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ExploreView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(tester.element(deck()), alignment: .2);
      await tester.pumpAndSettle();
      // Swipe along until the first photo has gone by.
      for (
        var i = 0;
        i < 3 && find.text('Paddington 2').evaluate().isNotEmpty;
        i++
      ) {
        await tester.dragFrom(
          tester.getTopLeft(deck()) + const Offset(300, 60),
          Offset(-tester.getSize(deck()).width * .54, 0),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Paddington 2'), findsNothing, reason: 'swiped past');

      double lean(String title) {
        final tilt = tester.widget<Transform>(
          find
              .ancestor(
                of: find.text(title),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Transform && w.alignment == Alignment.bottomCenter,
                ),
              )
              .first,
        );
        return tilt.transform.storage[1];
      }

      final front = ['Heat', 'Jaws'].firstWhere((t) => lean(t).abs() < .01);

      // Leave browsing and come back, so the deck is built afresh.
      await tester.enterText(find.byType(TextField), 'alien');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();

      expect(find.text(front), findsOneWidget);
      expect(lean(front), closeTo(0, .01), reason: 'still fanned around it');
    });

    pageTest('typing replaces browsing with results', (tester) async {
      await openSearch(tester);
      await tester.enterText(find.byType(TextField), 'alien');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(ExploreView), findsNothing);
      expect(find.text('Alien'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.byType(ExploreView), findsOneWidget);
    });
  });
}
