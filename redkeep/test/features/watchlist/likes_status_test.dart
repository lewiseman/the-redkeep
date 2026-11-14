import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/watchlist/application/discover_controller.dart';
import 'package:redkeep/features/watchlist/application/watchlist_providers.dart';
import 'package:redkeep/features/watchlist/domain/catalog_title.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';

import '../../support/fake_watch_reminders.dart';

/// A title is liked or in a status, never both.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FakeWatchReminders reminders;
  final now = DateTime.utc(2026, 11, 14, 12);
  const heat = CatalogTitle(key: WatchKey(WatchMedia.movie, 11), title: 'Heat');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    reminders = FakeWatchReminders();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        watchRemindersProvider.overrideWithValue(reminders),
        watchClockProvider.overrideWithValue(() => now),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<WatchTitle> match() => container
      .read(watchlistRepositoryProvider)
      .edit(
        heat,
        (_) => WatchTitlesCompanion(
          matchState: const Value('active'),
          expiresAt: Value(
            now.add(const Duration(days: 3)).millisecondsSinceEpoch,
          ),
        ),
      );

  Future<Library> library() async {
    final repository = container.read(watchlistRepositoryProvider);
    return Library(titles: await repository.titles(), lists: const []);
  }

  Future<WatchTitle> reload() async =>
      (await container.read(watchlistRepositoryProvider).title(heat.key.id))!;

  List<String> names(Library l, LibraryTab tab) => [
    for (final t in l.titlesFor(tab)) t.title,
  ];

  test('a live match is in Likes and All, and no status', () async {
    await match();
    final l = await library();
    expect(names(l, const LikesTab()), ['Heat']);
    expect(names(l, const AllTab()), ['Heat']);
    for (final s in WatchStatus.values) {
      expect(names(l, StatusTab(s)), isEmpty);
    }
  });

  test(
    'planning a night moves it to Planned; cancelling brings it back',
    () async {
      final nights = container.read(watchNightsProvider);
      await nights.planNight(await match(), now.add(const Duration(days: 1)));
      var l = await library();
      expect(names(l, const LikesTab()), isEmpty);
      expect(names(l, const StatusTab(WatchStatus.planned)), ['Heat']);
      expect(LikesGroups(l.titles, now).upcoming.single.title, 'Heat');

      await nights.cancelNight(await reload());
      l = await library();
      expect(names(l, const LikesTab()), ['Heat']);
      expect(names(l, const StatusTab(WatchStatus.planned)), isEmpty);
    },
  );

  test('unmatching a planned night leaves the Library', () async {
    final nights = container.read(watchNightsProvider);
    await nights.planNight(await match(), now.add(const Duration(days: 1)));
    await nights.unmatch(await reload());
    final l = await library();
    expect(names(l, const AllTab()), isEmpty);
    expect((await reload()).matchState, MatchState.unmatched);
  });

  test('moving a liked title to a status ends the match', () async {
    final nights = container.read(watchNightsProvider);
    await match();
    await nights.setStatus(heat, WatchStatus.watching);
    final saved = await reload();
    expect(saved.status, WatchStatus.watching);
    expect(saved.matchState, isNull);
    expect(saved.expiresAt, isNull);
    final l = await library();
    expect(names(l, const LikesTab()), isEmpty);
    expect(names(l, const StatusTab(WatchStatus.watching)), ['Heat']);
  });

  test('moving a planned night to Watching drops the night', () async {
    final nights = container.read(watchNightsProvider);
    await nights.planNight(await match(), now.add(const Duration(days: 1)));
    expect(reminders.scheduled, isNotEmpty);
    await nights.setStatus(heat, WatchStatus.watching);
    final saved = await reload();
    expect(saved.nightAt, isNull);
    expect(saved.matchState, isNull);
    expect(reminders.scheduled, isEmpty);
  });
}
