import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/watchlist/data/drift_watchlist_repository.dart';
import 'package:redkeep/features/watchlist/domain/catalog_title.dart';
import 'package:redkeep/features/watchlist/domain/recommender/taste.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_watch_reminders.dart';
import 'package:redkeep/features/watchlist/presentation/discover_view.dart';
import 'package:redkeep/features/watchlist/presentation/watch_title_page.dart';
import 'package:redkeep/features/watchlist/presentation/watch_widgets.dart';

import '../../support/pump_app.dart';

const genres = ['Drama', 'Comedy', 'Horror', 'Animation', 'Western', 'Crime'];

void main() {
  late AppDatabase db;
  late DriftWatchlistRepository repository;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftWatchlistRepository(
      db,
      clock: DateTime.now,
      newId: () => 'e' * 32,
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

  Future<void> seedCatalog() => repository.cacheTitles([
    for (var i = 0; i < genres.length; i++)
      CatalogTitle(
        key: WatchKey(WatchMedia.movie, i + 1),
        title: '${genres[i]} film',
        year: 2015,
        genres: [genres[i]],
        language: 'en',
        posterPath: '/p$i.jpg',
        voteAverage: 7,
        voteCount: 5000 - i,
      ),
  ]);

  Future<void> openSection(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ));
    await tester.pumpAndSettle();
  }

  pageTest('with reduced motion, the card decides, matches and plans a night', (tester) async {
    await seedCatalog();
    final reminders = FakeWatchReminders();
    final appearance = FakeAppearanceRepository(
      const AppearancePreferences(reduceMotion: true, simplerEffects: true),
    );
    addTearDown(appearance.close);
    await pumpApp(
      tester,
      initialLocation: '/watchlist',
      database: db,
      repository: appearance,
      watchReminders: reminders,
    );
    await openSection(tester, 'Discover');

    expect(find.byTooltip('Search films and shows'), findsNothing);
    expect(find.textContaining('Learning your type'), findsNothing);
    expect(find.text('Getting to know your taste'), findsOneWidget);
    await tester.tap(find.byTooltip('Nope'));
    await tester.pumpAndSettle();
    var rows = await db.select(db.watchTitles).get();
    expect(rows.single.swipe, 'nope');

    await tester.tap(find.byTooltip('Rewind'));
    await tester.pumpAndSettle();
    expect(await repository.titles(), isEmpty);

    // Up: already watched, straight into the Library, no match.
    await tester.tap(find.byTooltip('Already watched'));
    await tester.pumpAndSettle();
    rows = await db.select(db.watchTitles).get();
    expect(rows.single.swipe, 'watched');
    expect(rows.single.status, 'completed');
    expect(rows.single.matchState, isNull);
    expect(find.text('Marked as watched in your Library.'), findsOneWidget);

    await tester.tap(find.byTooltip('Like'));
    await tester.pumpAndSettle();
    expect(find.text('It’s a'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.textContaining('You matched with'), findsOneWidget);
    await tester.tap(find.text('Plan a night'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomorrow night'));
    await tester.pumpAndSettle();

    final liked = (await db.select(db.watchTitles).get())
        .where((r) => r.swipe == 'like')
        .single;
    expect(liked.matchState, 'dated');
    expect(liked.status, 'planned');
    expect(liked.nightAt, isNotNull);
    expect(reminders.permissionRequests, 1);
    expect(reminders.scheduled.map((r) => r.titleId).toSet(), {liked.id});
    final profile = WatchProfile.fromJson((await repository.readProfile())!);
    expect(profile.swipes, 2, reason: 'the rewound nope is forgotten');

    await openSection(tester, 'Likes');
    expect(find.text('Upcoming nights'), findsOneWidget);
  });

  pageTest('a card flips photos, opens its profile, and the profile decides', (tester) async {
    await repository.cacheTitles([
      const CatalogTitle(
        key: WatchKey(WatchMedia.movie, 1),
        title: 'Arrival',
        year: 2016,
        genres: ['Science Fiction', 'Drama'],
        keywords: ['linguistics', 'first contact'],
        cast: ['Amy Adams', 'Jeremy Renner'],
        director: 'Denis Villeneuve',
        runtime: 116,
        language: 'en',
        posterPath: '/arrival.jpg',
        backdropPath: '/a1.jpg',
        backdrops: ['/a2.jpg'],
        voteAverage: 7.6,
        voteCount: 18000,
        providers: ['Netflix'],
        detailed: true,
      ),
    ]);
    await pumpApp(tester, initialLocation: '/watchlist', database: db);
    await openSection(tester, 'Discover');

    String? photo() => tester
        .widget<WatchPoster>(
          find.descendant(
            of: find.byType(TinderCard),
            matching: find.byType(WatchPoster),
          ),
        )
        .path;
    expect(photo(), '/arrival.jpg');
    // Tapping the right of the photo moves on; the left goes back.
    final card = tester.getRect(find.byType(TinderCard));
    await tester.tapAt(Offset(card.right - 40, card.top + 120));
    await tester.pumpAndSettle();
    expect(photo(), '/a1.jpg');
    await tester.tapAt(Offset(card.right - 40, card.top + 120));
    await tester.pumpAndSettle();
    expect(photo(), '/a2.jpg');
    await tester.tapAt(Offset(card.left + 40, card.top + 120));
    await tester.pumpAndSettle();
    expect(photo(), '/a1.jpg');

    double barHeight(Type bar) => tester
        .getSize(find.ancestor(
          of: find.byType(bar),
          matching: find.byType(SizeTransition),
        ).first)
        .height;
    expect(barHeight(NavigationBar), greaterThan(0));

    // Tags live on the profile, not the card.
    expect(find.text('On Netflix'), findsNothing);

    // The card grows into the profile in place; the bars move away.
    await tester.tap(find.byTooltip('View profile'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(WatchProfileView), findsOneWidget, reason: 'mid-growth');
    expect(barHeight(NavigationBar), greaterThan(0));
    await tester.pumpAndSettle();
    expect(barHeight(NavigationBar), 0);
    expect(barHeight(AppBar), 0, reason: 'the Watchlist bar, not the profile');
    Finder inProfile(Finder f) =>
        find.descendant(of: find.byType(WatchProfileView), matching: f);
    expect(inProfile(find.byType(BackButton)), findsNothing);
    expect(inProfile(find.byTooltip('Close profile')), findsOneWidget);
    // No name in the bar: the first photo, then the name and tags.
    final profileAppBar = inProfile(find.byType(AppBar));
    expect(
      find.descendant(of: profileAppBar, matching: find.textContaining('Arrival')),
      findsNothing,
    );
    final profileList = inProfile(find.byType(Scrollable)).first;
    final name = find.text('Arrival  2016', findRichText: true);
    await tester.scrollUntilVisible(inProfile(name), 200, scrollable: profileList);
    expect(inProfile(find.text('Getting to know your taste')), findsOneWidget);
    expect(inProfile(find.text('On Netflix')), findsOneWidget);
    expect(
      tester.getTopLeft(inProfile(name)).dy,
      greaterThan(
        tester.getBottomLeft(inProfile(find.byType(WatchPoster)).first).dy - 1,
      ),
      reason: 'below the first photo',
    );

    // The chevron shrinks it back into the same, undecided card.
    await tester.tap(find.byTooltip('Close profile'));
    await tester.pumpAndSettle();
    expect(find.byType(WatchProfileView), findsNothing);
    expect(barHeight(NavigationBar), greaterThan(0));
    expect(await db.select(db.watchTitles).get(), isEmpty);
    expect(photo(), '/a1.jpg', reason: 'the same card, on the same photo');

    await tester.tap(find.byTooltip('View profile'));
    await tester.pumpAndSettle();
    final list = find
        .descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Looking for'), 200, scrollable: list);
    await tester.scrollUntilVisible(find.text('About me'), 200, scrollable: list);
    await tester.scrollUntilVisible(find.text('Raised by'), 200, scrollable: list);
    expect(find.text('Denis Villeneuve'), findsOneWidget);
    expect(find.text('1h 56m'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('My friends'), 200, scrollable: list);
    await tester.ensureVisible(find.text('Like').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Like').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Noted: you like'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Like').last);
    await tester.pumpAndSettle();
    expect(find.byType(WatchProfileView), findsNothing, reason: 'the profile closed');
    final row = await db.select(db.watchTitles).getSingle();
    expect(row.swipe, 'like');
    expect(row.matchState, 'active', reason: 'early likes always match');
    expect(find.text('It’s a'), findsOneWidget);
    await tester.tap(find.byTooltip('Keep swiping'));
    await tester.pumpAndSettle();
    expect(find.text('It’s a'), findsNothing);
  });

  pageTest('Likes checks in on a past night and lets a stale match drift', (tester) async {
    final now = DateTime.now().toUtc();
    const night = CatalogTitle(
      key: WatchKey(WatchMedia.movie, 10),
      title: 'Paddington 2',
      genres: ['Family'],
    );
    const stale = CatalogTitle(key: WatchKey(WatchMedia.movie, 11), title: 'Heat');
    const fresh = CatalogTitle(key: WatchKey(WatchMedia.tv, 12), title: 'Severance');
    await repository.edit(
      night,
      (_) => WatchTitlesCompanion(
        matchState: const Value('dated'),
        nightAt: Value(now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch),
      ),
    );
    await repository.edit(
      stale,
      (_) => WatchTitlesCompanion(
        matchState: const Value('active'),
        expiresAt: Value(now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch),
      ),
    );
    await repository.edit(
      fresh,
      (_) => WatchTitlesCompanion(
        matchState: const Value('active'),
        expiresAt: Value(now.add(const Duration(days: 3, hours: 1)).millisecondsSinceEpoch),
      ),
    );
    await pumpApp(tester, initialLocation: '/watchlist', database: db);
    await openSection(tester, 'Likes');

    expect(find.text('How did it go?'), findsOneWidget);
    expect(find.text('3 days to plan a night'), findsOneWidget);
    expect(find.text('Drifted away'), findsOneWidget);

    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loved it'));
    await tester.pumpAndSettle();

    final row = await (db.select(db.watchTitles)
          ..where((r) => r.id.equals(night.key.id)))
        .getSingle();
    expect(row.outcome, 'loved');
    expect(row.status, 'completed');
    expect(find.text('Loved'), findsOneWidget);
    final profile = WatchProfile.fromJson((await repository.readProfile())!);
    expect(profile.empty, isFalse, reason: 'the night taught taste');
  });

  pageTest('Discover explains how to add a TMDB key when it has nothing to deal', (tester) async {
    await pumpApp(tester, initialLocation: '/watchlist', database: db);
    await openSection(tester, 'Discover');
    expect(find.text('Discover needs TMDB'), findsOneWidget);
  });
}
