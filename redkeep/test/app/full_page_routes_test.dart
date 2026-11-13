import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:redkeep/app/bottom_navbar.dart';
import 'package:redkeep/app/more_page.dart';
import 'package:redkeep/features/ai/presentation/ai_settings_page.dart';
import 'package:redkeep/features/appearance/presentation/appearance_page.dart';
import 'package:redkeep/features/flow/presentation/flow_page.dart';
import 'package:redkeep/features/flow/presentation/flow_search_page.dart';
import 'package:redkeep/features/flow/presentation/thought_read_page.dart';
import 'package:redkeep/features/notes/presentation/notes_list_page.dart';

import '../support/pump_app.dart';

void main() {
  final bar = find.byType(RedkeepBottomNavbar);
  final thought = 'a' * 32;

  for (final (location, page) in <(String, Type)>[
    ('/settings', AppearancePage),
  ]) {
    testWidgets('$location is a full page without the bottom bar', (
      tester,
    ) async {
      await pumpApp(tester, initialLocation: location);
      expect(find.byType(page), findsOneWidget);
      expect(bar, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  // These start timers of their own, so check the routes without building them.
  testWidgets('Grand Maestar and thought routes cover the shell', (
    tester,
  ) async {
    final router = await pumpApp(tester, initialLocation: '/more');
    for (final location in [
      '/settings/brain',
      '/settings/brain/library',
      '/flow/$thought',
      '/flow/$thought/edit',
    ]) {
      final route = router.configuration.findMatch(Uri.parse(location)).last;
      expect(route.route.parentNavigatorKey, router.configuration.navigatorKey);
    }
  });

  testWidgets('leaving a full page brings the bottom bar back', (tester) async {
    final GoRouter router = await pumpApp(tester, initialLocation: '/more');
    expect(bar, findsOneWidget);
    router.push('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(AppearancePage), findsOneWidget);
    expect(bar, findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MorePage), findsOneWidget);
    expect(bar, findsOneWidget);
  });

  // Each opens pages the way the app does, then expects to step back through
  // them one at a time. Thoughts and Grand Maestar leave timers running, so the
  // tree is torn down and those timers flushed at the end.
  final journeys = <(String, String, List<(String, bool)>, Type)>[
    ('Appearance from More', '/more', [('/settings', true)], MorePage),
    ('Grand Maestar from More', '/more', [('/settings/brain', true)], MorePage),
    ('Watchlist from More', '/more', [('/watchlist', true)], MorePage),
    (
      'the Library from Grand Maestar',
      '/more',
      [('/settings/brain', true), ('/settings/brain/library', true)],
      AiSettingsPage,
    ),
    ('a thought from Flow', '/flow', [('/flow/$thought', false)], FlowPage),
    (
      'a thought from search',
      '/flow/search',
      [('/flow/$thought', true)],
      FlowSearchPage,
    ),
    (
      'a thought editor',
      '/flow',
      [('/flow/$thought', false), ('/flow/$thought/edit', false)],
      ThoughtReadPage,
    ),
    (
      'a page inside the shell',
      '/notes',
      [('/notes/${'b' * 32}', true)],
      NotesListPage,
    ),
  ];

  for (final (name, start, steps, previous) in journeys) {
    for (final gesture in [true, false]) {
      testWidgets(
        '${gesture ? 'back gesture' : 'system back'} leaves $name for the previous page',
        (tester) async {
          final router = await pumpApp(tester, initialLocation: start);
          for (final (location, push) in steps) {
            push ? router.push(location) : router.go(location);
            await tester.pumpAndSettle();
          }
          if (gesture) {
            await _backGesture(tester);
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
          expect(find.byType(previous), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(minutes: 2));
        },
      );
    }
  }
}

/// Android's predictive back gesture, as the engine delivers it.
Future<void> _backGesture(WidgetTester tester) async {
  Future<void> send(String method, [Object? arguments]) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );
  await send('startBackGesture', <String, Object?>{
    'touchOffset': <double>[5, 300],
    'progress': 0.0,
    'swipeEdge': 0,
  });
  await tester.pump();
  await send('commitBackGesture');
}
