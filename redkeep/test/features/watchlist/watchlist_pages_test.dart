import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/watchlist/data/drift_watchlist_repository.dart';
import 'package:redkeep/features/watchlist/domain/catalog_title.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';
import 'package:redkeep/features/watchlist/presentation/watch_seasons.dart';
import 'package:redkeep/features/watchlist/presentation/watch_widgets.dart';

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

  pageTest('the Library groups saved titles by status and list', (tester) async {
    await repository.setStatus(matrix, WatchStatus.planned);
    await repository.createList('Weekends', first: thrones);
    await pumpApp(tester, initialLocation: '/watchlist', database: db);

    expect(find.text('The Matrix'), findsOneWidget);
    expect(find.text('Game of Thrones'), findsOneWidget);
    expect(find.text('Planned'), findsWidgets, reason: 'tab and badge');

    await tester.tap(find.widgetWithText(Tab, 'Watching'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing on the go'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(Tab, 'Weekends'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Weekends'));
    await tester.pumpAndSettle();
    expect(find.text('Game of Thrones'), findsOneWidget);
    expect(find.text('1 title'), findsOneWidget);
  });

  pageTest('an empty Watchlist keeps its artwork and offers search', (tester) async {
    await pumpApp(tester, initialLocation: '/watchlist', database: db);
    expect(find.text('Nothing on your watchlist yet'), findsOneWidget);
    await tester.tap(find.text('Find something'));
    await tester.pumpAndSettle();
    expect(find.text('Search needs TMDB'), findsOneWidget, reason: 'no key in tests');
  });

  pageTest('a cached title takes a status, a rating and a note', (tester) async {
    await repository.cacheTitles([
      const CatalogTitle(
        key: WatchKey(WatchMedia.movie, 603),
        title: 'The Matrix',
        year: 1999,
        runtime: 136,
        director: 'Lana Wachowski',
        overview: 'A hacker learns the truth.',
        providers: ['Max'],
        detailed: true,
      ),
    ]);
    await pumpApp(tester, initialLocation: '/watchlist/movie/603', database: db);

    expect(find.text('The Matrix, 1999'), findsOneWidget);
    expect(find.text('Lana Wachowski'), findsOneWidget, reason: 'raised by');
    expect(find.text('2h 16m'), findsOneWidget, reason: 'height');
    expect(find.text('Max'), findsOneWidget, reason: 'lives on');
    Future<void> reveal(Finder target) async {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
    }

    await reveal(find.widgetWithText(ChoiceChip, 'Watching'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Watching'));
    await tester.pumpAndSettle();
    await reveal(find.bySemanticsLabel('8 out of 10'));
    await tester.tap(find.bySemanticsLabel('8 out of 10'));
    await tester.pumpAndSettle();
    expect(find.text('8/10'), findsOneWidget);

    await reveal(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'With Sam');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final row = await db.select(db.watchTitles).getSingle();
    expect(row.status, 'watching');
    expect(row.rating, 8);
    expect(row.note, 'With Sam');
  });

  test('show progress counts real episodes and finds the next one', () {
    final seasons = [
      SeasonSummary(number: 1, name: 'Season 1', episodeCount: 2, airDate: DateTime(2020)),
      SeasonSummary(number: 2, name: 'Season 2', episodeCount: 3, airDate: DateTime(2030)),
    ];
    final progress = ShowProgress(seasons, {'s1e1', 's1e9', 's3e1'}, DateTime(2026));
    expect(progress.watched, {'s1e1'}, reason: 'codes outside the show are ignored');
    expect(progress.total, 5);
    expect(progress.aired, 2);
    expect(progress.next, 'S1E2');
    expect(progress.caughtUp, isFalse);
    final caughtUp = ShowProgress(seasons, {'s1e1', 's1e2'}, DateTime(2026));
    expect(caughtUp.caughtUp, isTrue);
    expect(caughtUp.next, 'S2E1');
  });

  pageTest('a show ticks a whole season, starts watching and offers to finish', (tester) async {
    await repository.cacheTitles([
      CatalogTitle(
        key: thrones.key,
        title: 'Game of Thrones',
        seasons: [
          SeasonSummary(number: 1, name: 'Season 1', episodeCount: 2, airDate: DateTime(2011)),
        ],
        detailed: true,
      ),
    ]);
    await repository.cacheSeason(thrones.key, 1, const [
      EpisodeSummary(season: 1, number: 1, name: 'Winter Is Coming'),
      EpisodeSummary(season: 1, number: 2, name: 'The Kingsroad'),
    ]);
    await repository.setStatus(thrones, WatchStatus.planned);
    await pumpApp(tester, initialLocation: '/watchlist/tv/1399', database: db);

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
  });

  testWidgets('large text and narrow screens use fewer poster columns', (tester) async {
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
