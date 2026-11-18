import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/cushion.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/watchlist/data/drift_watchlist_repository.dart';
import 'package:redkeep/features/watchlist/domain/catalog_title.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';
import 'package:redkeep/features/watchlist/presentation/watch_seasons.dart';
import 'package:redkeep/features/watchlist/presentation/watch_title_extras.dart';
import 'package:redkeep/features/watchlist/presentation/watch_host.dart';
import 'package:redkeep/features/watchlist/presentation/watch_spin.dart';
import 'package:redkeep/features/watchlist/presentation/watch_wall.dart';
import 'package:redkeep/features/watchlist/presentation/watch_widgets.dart';
import 'package:redkeep/features/watchlist/presentation/watchlist_page.dart';

import '../../support/pump_app.dart';
import 'watchlist_repository_test.dart' show thrones;

// No poster: widget tests never reach the image cache or the network.
const matrix = CatalogTitle(
  key: WatchKey(WatchMedia.movie, 603),
  title: 'The Matrix',
  year: 1999,
);

void main() {
  late AppDatabase db;
  late DriftWatchlistRepository repository;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftWatchlistRepository(
      db,
      clock: DateTime.now,
      newId: () => 'f' * 32,
    );
  });
  tearDown(() => db.close());

  // Closing the page cancels its queries; let those finish inside the test.
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

  pageTest('the wall filters from the dock and hides empty statuses', (
    tester,
  ) async {
    await repository.setStatus(matrix, WatchStatus.planned);
    await repository.createList('Weekends', first: thrones);
    await pumpApp(tester, initialLocation: '/watchlist', database: db);

    expect(find.text('The Matrix'), findsOneWidget);
    expect(find.text('Game of Thrones'), findsOneWidget);
    expect(
      find.textContaining('to see'),
      findsNothing,
      reason: 'no tally under the title',
    );
    expect(find.widgetWithText(WatchFilterPill, 'Planned'), findsOneWidget);
    expect(
      find.widgetWithText(WatchFilterPill, 'Watching'),
      findsNothing,
      reason: 'empty statuses stay out of the dock',
    );

    await tester.tap(find.widgetWithText(WatchFilterPill, 'Weekends'));
    await tester.pumpAndSettle();
    expect(find.text('Game of Thrones'), findsOneWidget);
    expect(find.text('The Matrix'), findsNothing);
  });

  pageTest('a double tap stamps a poster watched, and undo lifts it', (
    tester,
  ) async {
    await repository.setStatus(matrix, WatchStatus.planned);
    await pumpApp(tester, initialLocation: '/watchlist', database: db);
    expect(find.text('WATCHED'), findsNothing);

    final poster = find.byType(WallPolaroid);
    await tester.tap(poster);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(poster);
    await tester.pumpAndSettle();
    expect((await db.select(db.watchTitles).getSingle()).status, 'completed');
    expect(find.text('WATCHED'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await db.select(db.watchTitles).getSingle()).status, 'planned');
    expect(find.text('WATCHED'), findsNothing);
  });

  pageTest('spinning the reel lands on a title and can open it', (
    tester,
  ) async {
    await repository.setStatus(matrix, WatchStatus.planned);
    await repository.setStatus(thrones, WatchStatus.watching);
    await pumpApp(tester, initialLocation: '/watchlist', database: db);

    await tester.tap(find.text('Can’t choose? Tap me and I’ll pick one.'));
    await tester.pumpAndSettle();
    expect(find.byType(WatchSpinStage), findsOneWidget);
    expect(find.text('How about…'), findsOneWidget);
    final landed = ['The Matrix', 'Game of Thrones'].where(
      (t) => find
          .descendant(of: find.byType(WatchSpinStage), matching: find.text(t))
          .evaluate()
          .isNotEmpty,
    );
    expect(landed, hasLength(1));

    await tester.tap(find.text('Spin again'));
    await tester.pumpAndSettle();
    expect(find.text('How about…'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(WatchSpinStage), findsNothing);
  });

  pageTest('Tyrion flies from More and is on the wall from its first frame', (
    tester,
  ) async {
    await pumpApp(tester, initialLocation: '/more', database: db);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WatchlistMascot), findsOneWidget);

    await tester.tap(find.text('Watchlist'));
    await tester.pump();
    // Before the wall's titles arrive, the header is already there for him
    // to land on, so the flight has both ends.
    expect(find.byType(WatchlistMascot, skipOffstage: false), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WatchlistPage), findsOneWidget);
    expect(find.text('Nothing on your watchlist yet'), findsOneWidget);
    expect(
      find.byType(SpeechBubble),
      findsNothing,
      reason: 'nothing to pick between',
    );
  });

  pageTest('Tyrion only ever offers to pick something to watch', (
    tester,
  ) async {
    await repository.setStatus(matrix, WatchStatus.planned);
    await pumpApp(tester, initialLocation: '/watchlist', database: db);
    expect(
      find.byType(SpeechBubble),
      findsNothing,
      reason: 'one title is no choice',
    );

    await repository.setStatus(thrones, WatchStatus.planned);
    await tester.pumpAndSettle();
    expect(
      find.text('Can’t choose? Tap me and I’ll pick one.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Spin the reel'),
      findsNothing,
      reason: 'Tyrion is the one way to pick',
    );
    await tester.tap(find.byType(WatchlistMascot));
    await tester.pumpAndSettle();
    expect(find.byType(WatchSpinStage), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await repository.setStatus(matrix, WatchStatus.completed);
    await repository.setStatus(thrones, WatchStatus.completed);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fancy a rewatch? Tap me and I’ll pick one.'));
    await tester.pumpAndSettle();
    expect(find.byType(WatchSpinStage), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });

  pageTest('the header collapses into a bar and never rests halfway', (
    tester,
  ) async {
    for (var id = 1; id <= 8; id++) {
      await repository.setStatus(
        CatalogTitle(key: WatchKey(WatchMedia.movie, id), title: 'Film $id'),
        WatchStatus.planned,
      );
    }
    await pumpApp(tester, initialLocation: '/watchlist', database: db);
    final wall = find.byType(CustomScrollView);
    double offset() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    final header = tester.widget<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    final travel = header.delegate.maxExtent - header.delegate.minExtent;
    expect(find.byType(SpeechBubble), findsOneWidget);

    // Let go a little way in: it eases back open.
    await tester.drag(wall, Offset(0, -travel * .3));
    await tester.pumpAndSettle();
    expect(offset(), 0);

    // Past halfway: it closes into the bar, and the bubble is gone.
    await tester.drag(wall, Offset(0, -travel * .7));
    await tester.pumpAndSettle();
    expect(offset(), moreOrLessEquals(travel));
    expect(find.byType(SpeechBubble), findsNothing);
    expect(find.text('Watchlist'), findsWidgets);
    expect(find.byType(GlassBackButton), findsOneWidget);

    // Tyrion still picks from his porthole.
    await tester.tap(find.byType(WatchlistMascot));
    await tester.pumpAndSettle();
    expect(find.byType(WatchSpinStage), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });

  pageTest('a new list is named in a dialog and gets its own pill', (
    tester,
  ) async {
    await repository.setStatus(matrix, WatchStatus.planned);
    await pumpApp(tester, initialLocation: '/watchlist', database: db);
    await tester.tap(find.bySemanticsLabel('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Weekends');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(WatchFilterPill, 'Weekends'), findsOneWidget);
    expect(find.text('This list is empty'), findsOneWidget);
    expect((await db.select(db.watchLists).getSingle()).name, 'Weekends');
  });

  pageTest('an empty Watchlist keeps its artwork and offers search', (
    tester,
  ) async {
    await pumpApp(tester, initialLocation: '/watchlist', database: db);
    expect(find.text('Nothing on your watchlist yet'), findsOneWidget);
    await tester.tap(find.text('Find something'));
    await tester.pumpAndSettle();
    expect(
      find.text('Search needs TMDB'),
      findsOneWidget,
      reason: 'no key in tests',
    );
  });

  pageTest('a cached title shows what TMDB knows and takes a status', (
    tester,
  ) async {
    await repository.cacheTitles([
      const CatalogTitle(
        key: WatchKey(WatchMedia.movie, 603),
        title: 'The Matrix',
        year: 1999,
        runtime: 136,
        certification: 'R',
        director: 'Lana Wachowski',
        overview: 'A hacker learns the truth.',
        keywords: ['simulated reality'],
        backdrops: ['/b1.jpg', '/b2.jpg'],
        cast: [Credit(name: 'Keanu Reeves', role: 'Neo')],
        crew: [
          Credit(name: 'Lana Wachowski', role: 'Director, Screenplay'),
          Credit(name: 'Lilly Wachowski', role: 'Director'),
        ],
        videos: [TitleVideo(youtubeKey: 'k', name: 'Trailer', type: 'Trailer')],
        budget: 63000000,
        providers: ['Max'],
        rent: ['Apple TV'],
        recommendations: [
          CatalogTitle(
            key: WatchKey(WatchMedia.movie, 604),
            title: 'The Matrix Reloaded',
          ),
        ],
        detailed: true,
      ),
    ]);
    await pumpApp(
      tester,
      initialLocation: '/watchlist/movie/603',
      database: db,
    );
    Future<void> reveal(Finder target) async {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
    }

    expect(find.text('The Matrix'), findsOneWidget);
    expect(find.text('1999 · Film · 2h 16m · R'), findsOneWidget);
    expect(find.text('Play trailer'), findsOneWidget);

    await reveal(find.widgetWithText(ChoiceChip, 'Watching'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Watching'));
    await tester.pumpAndSettle();
    expect(find.text('Not rated'), findsNothing, reason: 'no ratings');
    expect(find.byType(TextField), findsNothing, reason: 'no notes');

    for (final text in [
      'simulated reality',
      'Pictures',
      'Neo',
      'Directors',
      'Lana Wachowski, Lilly Wachowski',
      'Screenplay',
      r'$63M',
      'Max',
      'Apple TV',
      'The Matrix Reloaded',
    ]) {
      await reveal(find.text(text));
      expect(find.text(text), findsOneWidget, reason: text);
    }

    final row = await db.select(db.watchTitles).getSingle();
    expect(row.status, 'watching');

    // A picture opens full screen, and swiping moves to the next.
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Still 1 of 2'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Still 1 of 2'));
    await tester.pumpAndSettle();
    expect(find.byType(TitleGalleryPage), findsOneWidget);
    expect(find.text('The Matrix · 1 of 2'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('The Matrix · 2 of 2'), findsOneWidget);
  });

  test('show progress counts real episodes and finds the next one', () {
    final seasons = [
      SeasonSummary(
        number: 1,
        name: 'Season 1',
        episodeCount: 2,
        airDate: DateTime(2020),
      ),
      SeasonSummary(
        number: 2,
        name: 'Season 2',
        episodeCount: 3,
        airDate: DateTime(2030),
      ),
    ];
    final progress = ShowProgress(seasons, {
      's1e1',
      's1e9',
      's3e1',
    }, DateTime(2026));
    expect(progress.watched, {
      's1e1',
    }, reason: 'codes outside the show are ignored');
    expect(progress.total, 5);
    expect(progress.aired, 2);
    expect(progress.next, 'S1E2');
    expect(progress.caughtUp, isFalse);
    final caughtUp = ShowProgress(seasons, {'s1e1', 's1e2'}, DateTime(2026));
    expect(caughtUp.caughtUp, isTrue);
    expect(caughtUp.next, 'S2E1');
  });

  pageTest(
    'a show ticks a whole season, starts watching and offers to finish',
    (tester) async {
      await repository.cacheTitles([
        CatalogTitle(
          key: thrones.key,
          title: 'Game of Thrones',
          seasons: [
            SeasonSummary(
              number: 1,
              name: 'Season 1',
              episodeCount: 2,
              airDate: DateTime(2011),
            ),
          ],
          detailed: true,
        ),
      ]);
      await repository.cacheSeason(thrones.key, 1, const [
        EpisodeSummary(season: 1, number: 1, name: 'Winter Is Coming'),
        EpisodeSummary(season: 1, number: 2, name: 'The Kingsroad'),
      ]);
      await repository.setStatus(thrones, WatchStatus.planned);
      await pumpApp(
        tester,
        initialLocation: '/watchlist/tv/1399',
        database: db,
      );

      Future<void> reveal(Finder target) async {
        await tester.scrollUntilVisible(
          target,
          120,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }

      await reveal(find.text('Season 1'));
      expect(find.text('0 of 2 episodes'), findsOneWidget);
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();
      await reveal(find.text('1. Winter Is Coming'));
      await tester.tap(find.text('1. Winter Is Coming'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 episodes · next S1E2'), findsOneWidget);
      expect((await db.select(db.watchTitles).getSingle()).status, 'watching');

      await reveal(find.text('Mark all'));
      await tester.tap(find.text('Mark all'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 episodes'), findsOneWidget);
      expect(find.text('You’re caught up on Game of Thrones.'), findsOneWidget);
      await tester.tap(find.text('Mark watched'));
      await tester.pumpAndSettle();
      expect((await db.select(db.watchTitles).getSingle()).status, 'completed');
    },
  );

  testWidgets('large text and narrow screens use fewer poster columns', (
    tester,
  ) async {
    late int normal, large;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (context) {
            normal = posterColumns(context, 360);
            return MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Builder(
                builder: (context) {
                  large = posterColumns(context, 360);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(normal, 3);
    expect(large, 2);
  });
}
