import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/application/diary_reader_day.dart';
import 'package:redkeep/features/diary/domain/diary_day_details.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/home_widgets/application/home_widget_sync.dart';
import 'package:redkeep/features/home_widgets/data/home_widget_bridge.dart';
import 'package:redkeep/features/home_widgets/domain/home_widget_snapshot.dart';
import 'package:redkeep/features/home_widgets/presentation/home_widget_launch_page.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';

import '../../support/empty_diary_repository.dart';

void main() {
  final today = DateTime(2026, 11, 18, 21, 30);

  test('snapshot carries only written days, their moods and the accent', () {
    final snapshot = homeWidgetSnapshot(
      written: {
        DiaryPeriod(2026, 11, 18),
        DiaryPeriod(2026, 11, 2),
        DiaryPeriod.month(2026, 11),
        DiaryPeriod(2026, 11, 19), // not yet: outside the window
        DiaryPeriod(2023, 1, 1), // too old
      },
      moods: {
        DiaryPeriod(2026, 11, 18): DiaryMood.happy,
        DiaryPeriod(2026, 11, 10): DiaryMood.fromEmoji('🌧️')!,
        DiaryPeriod.week(DiaryPeriod(2026, 11, 18).start): DiaryMood.calm,
      },
      appearance: const AppearancePreferences(
        theme: AppTheme.dark,
        accent: AppAccent.teal,
      ),
      today: today,
    );
    expect(snapshot['theme'], 'dark');
    expect(snapshot['accent'], '#176B65');
    expect(snapshot['accentDark'], '#80D5CC');
    expect(snapshot['days'], {
      '2026-11-02': '',
      '2026-11-10': '🌧️',
      '2026-11-18': '😊',
    });
    // Written keys only: no titles or writing reach the home screen.
    expect(jsonEncode(snapshot), isNot(contains('heading')));
  });

  testWidgets('sync publishes once a burst settles, and only on change', (
    tester,
  ) async {
    final bridge = _RecordingBridge();
    final source = NotifierProvider<_Source, String?>(_Source.new);
    final container = ProviderContainer(
      overrides: [
        homeWidgetBridgeProvider.overrideWithValue(bridge),
        homeWidgetSnapshotProvider.overrideWith((ref) => ref.watch(source)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HomeWidgetSync(child: SizedBox()),
      ),
    );
    container.read(source.notifier).set('a');
    await tester.pump(const Duration(milliseconds: 100));
    container.read(source.notifier).set('b');
    await tester.pump(const Duration(seconds: 1));
    expect(bridge.published, ['b']);

    container.read(source.notifier).set('b');
    await tester.pump(const Duration(seconds: 1));
    container.read(source.notifier).set(null);
    await tester.pump(const Duration(seconds: 1));
    expect(bridge.published, ['b']);
  });

  group('widget launches', () {
    Future<(GoRouter, ProviderContainer)> launch(
      WidgetTester tester,
      String location,
    ) async {
      final container = ProviderContainer(
        overrides: [
          diaryRepositoryProvider.overrideWithValue(EmptyDiaryRepository()),
          diaryClockProvider.overrideWithValue(() => today),
          diaryIdProvider.overrideWithValue(() => 'a' * 32),
          noteIdProvider.overrideWithValue(() => 'b' * 32),
        ],
      );
      addTearDown(container.dispose);
      Widget stub(GoRouterState state) => Text(state.uri.path);
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/diary',
            builder: (_, state) => stub(state),
            routes: [
              GoRoute(
                path: 'write',
                builder: (_, _) =>
                    const HomeWidgetLaunchPage(launch: WriteTodayLaunch()),
              ),
              GoRoute(
                path: 'day/:date',
                builder: (_, state) => HomeWidgetLaunchPage(
                  launch: DiaryDayLaunch(
                    DiaryPeriod.tryParse(state.pathParameters['date']!),
                  ),
                ),
              ),
              GoRoute(
                path: ':date/entries/:id/edit',
                builder: (_, state) => stub(state),
              ),
            ],
          ),
          GoRoute(
            path: '/notes',
            builder: (_, state) => stub(state),
            routes: [
              GoRoute(
                path: 'write',
                builder: (_, _) =>
                    const HomeWidgetLaunchPage(launch: NewNoteLaunch()),
              ),
              GoRoute(path: ':id', builder: (_, state) => stub(state)),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return (router, container);
    }

    String at(GoRouter router) =>
        router.routerDelegate.currentConfiguration.uri.toString();

    testWidgets('write opens a new entry for today in the editor', (
      tester,
    ) async {
      final (router, container) = await launch(tester, '/diary/write');
      expect(at(router), '/diary/2026-11-18/entries/${'a' * 32}/edit');
      expect(container.read(diaryNewIdsProvider), {'a' * 32});
    });

    testWidgets('a day turns the reader to it, then shows the diary', (
      tester,
    ) async {
      final (router, container) = await launch(tester, '/diary/day/2026-11-02');
      expect(at(router), '/diary');
      expect(
        container.read(diaryReaderDayProvider).date,
        DiaryPeriod(2026, 11, 2),
      );
    });

    testWidgets('new note opens a fresh note', (tester) async {
      final (router, container) = await launch(tester, newNoteLocation);
      expect(at(router), noteLocation('b' * 32));
      expect(container.read(noteNewIdsProvider), {'b' * 32});
    });
  });
}

class _RecordingBridge implements HomeWidgetBridge {
  final published = <String>[];
  @override
  Future<void> publish(String snapshot) async => published.add(snapshot);
}

class _Source extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}
