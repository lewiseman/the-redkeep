import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:redkeep/app/bottom_navbar.dart';
import 'package:redkeep/app/main_tabs.dart';
import 'package:redkeep/app/more_page.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/presentation/diary_day_page.dart';
import 'package:redkeep/features/notes/presentation/notes_list_page.dart';

import '../support/fake_appearance_repository.dart';
import '../support/pump_app.dart';

String _path(GoRouter router) => router.routeInformationProvider.value.uri.path;

int _selectedTab(WidgetTester tester) => tester
    .widget<RedkeepBottomNavbar>(find.byType(RedkeepBottomNavbar))
    .selectedIndex;

/// How far [page]'s left edge sits from the pager's, in pager widths.
double _offset(WidgetTester tester, Finder page) {
  final pager = tester.getRect(find.byType(MainTabs));
  return (tester.getTopLeft(page).dx - pager.left) / pager.width;
}

Offset _middle(WidgetTester tester) =>
    tester.getRect(find.byType(MainTabs)).center;

void main() {
  void tabsTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          // Flush the pages' database streams before the test ends.
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });

  tabsTest('swipes move between Notes and More and back to the diary', (
    tester,
  ) async {
    final router = await pumpApp(tester, initialLocation: '/notes');
    await tester.dragFrom(_middle(tester), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(_path(router), '/more');
    expect(find.byType(MorePage).hitTestable(), findsOneWidget);
    expect(_selectedTab(tester), 2);

    // More is the last tab; a further swipe goes nowhere.
    await tester.dragFrom(_middle(tester), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(_path(router), '/more');

    await tester.dragFrom(_middle(tester), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(_path(router), '/notes');
    expect(find.byType(NotesListPage).hitTestable(), findsOneWidget);

    await tester.dragFrom(_middle(tester), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(_path(router), '/diary');
    expect(_offset(tester, find.byType(DiaryDayPage)), 0);
    expect(_selectedTab(tester), 0);
    expect(tester.takeException(), isNull);
  });

  tabsTest('the bar follows a drag once it passes halfway', (tester) async {
    final router = await pumpApp(tester, initialLocation: '/notes');
    final width = tester.getSize(find.byType(MainTabs)).width;
    final drag = await tester.startGesture(_middle(tester));
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(Offset(-width * .1, 0));
      await tester.pump();
    }
    expect(_selectedTab(tester), 2);
    expect(_path(router), '/notes');
    for (var i = 0; i < 3; i++) {
      await drag.moveBy(Offset(width * .1, 0));
      await tester.pump();
    }
    expect(_selectedTab(tester), 1);
    await drag.up();
    await tester.pumpAndSettle();
    expect(_path(router), '/notes');
    expect(_offset(tester, find.byType(NotesListPage)), 0);
  });

  tabsTest('back from Notes or More returns to the diary', (tester) async {
    final router = await pumpApp(tester, initialLocation: '/more');
    expect(router.canPop(), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_path(router), '/diary');
    expect(_offset(tester, find.byType(DiaryDayPage)), 0);
    expect(_selectedTab(tester), 0);
  });

  for (final reduced in [false, true]) {
    tabsTest('a bar tap slides to its tab; reduced motion $reduced', (
      tester,
    ) async {
      final appearance = FakeAppearanceRepository(
        AppearancePreferences(reduceMotion: reduced),
      );
      addTearDown(appearance.close);
      final router = await pumpApp(
        tester,
        initialLocation: '/diary',
        repository: appearance,
      );
      await tester.tap(find.bySemanticsLabel('Notes tab'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_selectedTab(tester), 1);
      final notes = find.byType(NotesListPage);
      if (reduced) {
        expect(_offset(tester, notes), 0);
      } else {
        expect(_offset(tester, notes), inExclusiveRange(0, 1));
      }
      await tester.pumpAndSettle();
      expect(_path(router), '/notes');
      expect(_offset(tester, notes), 0);

      // Diary to More is no neighbour: it jumps rather than passing Notes.
      await tester.tap(find.bySemanticsLabel('Diary tab'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('More tab'));
      await tester.pump();
      await tester.pump();
      expect(_offset(tester, find.byType(MorePage)), 0);
      expect(find.byType(NotesListPage), findsNothing);
      await tester.pumpAndSettle();
      expect(_path(router), '/more');
    });
  }
}
