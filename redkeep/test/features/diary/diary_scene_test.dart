import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/diary/presentation/diary_search_loading.dart';
import 'package:redkeep/features/diary/presentation/diary_search_opening.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/app/bottom_navbar.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/application/diary_paper_providers.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/presentation/diary_calendar.dart';
import 'package:redkeep/features/diary/presentation/diary_calendar_page.dart';
import 'package:redkeep/features/diary/presentation/diary_scene.dart';
import 'package:redkeep/features/diary/presentation/diary_sheet.dart';

import '../../support/controlled_diary_repository.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';
import '../../support/diary_reader.dart';

final today = DiaryPeriod(2026, 11, 2);
const id = '11111111111111111111111111111111';

class PendingSearchRepository extends ControlledDiaryRepository {
  PendingSearchRepository(super.inner);
  final searches = <String, StreamController<List<DiaryListing>>>{};
  @override
  Stream<List<DiaryListing>> watchEntries({
    DiaryPeriod? date,
    String search = '',
  }) =>
      searches[search]?.stream ??
      super.watchEntries(date: date, search: search);
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('DIARY_CAPTURES')) return;
    for (final font in <(String, String)>[
      ('Caveat', '../assets/reference/website/fonts/Caveat-Medium.ttf'),
      // Fonts aren't in the repo; a similar serif keeps captures realistic.
      ('Literata', '../assets/reference/website/fonts/Lora-Regular.ttf'),
      (
        'Poppins',
        File.fromUri(
          File(Platform.resolvedExecutable).uri
              .resolve('../../material_fonts/Roboto-Regular.ttf'),
        ).path,
      ),
      (
        'MaterialIcons',
        'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      ),
    ]) {
      await (FontLoader(font.$1)..addFont(
            Future.value(
              ByteData.sublistView(await File(font.$2).readAsBytes()),
            ),
          ))
          .load();
    }
  });
  late AppDatabase db;
  late PendingSearchRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PendingSearchRepository(
      DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 2)),
    );
  });
  tearDown(() async {
    for (final stream in repo.searches.values) {
      await stream.close();
    }
    await db.close();
  });
  void sceneTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
  Future<void> seed({
    DiaryPeriod? date,
    String body = 'The light came in through the kitchen window. I made coffee and watched the street wake up.',
  }) async {
    await repo.save(
      id: id,
      date: date ?? today,
      text: DiaryText(body: body),
      expectedRevision: 0,
    );
  }

  DiaryScene scene(WidgetTester tester) =>
      tester.widget<DiaryScene>(find.byType(DiaryScene).last);
  Future<void> submit(
    WidgetTester tester,
    String query, {
    bool settle = true,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('diary-search-input')),
      query,
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Finder day(DiaryPeriod date) => find.byKey(
    ValueKey(
      'calendar-day-${DateTime(date.year, date.month, date.day).toIso8601String()}',
    ),
  );

  sceneTest('the raven on the cord brings a letter from last week', (
    tester,
  ) async {
    final lastMonday = DiaryPeriod(2026, 10, 26);
    await pumpApp(tester, initialLocation: '/diary', diary: repo);
    final raven = find.byKey(const ValueKey('diary-raven'));
    expect(raven, findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('A raven brings')), findsNothing);

    // Writing on last Monday gives today's raven that page's letter.
    await seed(date: lastMonday);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        RegExp('A raven brings your page from last Monday'),
      ),
      findsOneWidget,
    );
    await tester.tap(raven);
    await tester.pumpAndSettle();
    expect(scene(tester).day.date, lastMonday);
  });

  for (final location in ['/', '/diary']) {
    sceneTest('the immersive reader at $location slides the bottom bar away', (
      tester,
    ) async {
      await seed(body: List.filled(80, 'A long remembered line.').join('\n'));
      await pumpApp(tester, initialLocation: location, diary: repo);
      expect(navbarHidden(tester), isFalse);
      final paper = find.byKey(const ValueKey('diary-active-paper'));
      await tester.dragFrom(
        tester.getRect(paper).center,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(scene(tester).collapse, 1);
      expect(navbarHidden(tester), isTrue);
      await tester.dragFrom(tester.getRect(paper).center, const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(scene(tester).collapse, lessThan(1));
      expect(navbarHidden(tester), isFalse);
      // Restoring the page from immersive never runs on into the calendar.
      expect(find.byType(DiaryCalendarPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  sceneTest('on today a swipe left moves to Notes; other swipes turn days', (
    tester,
  ) async {
    await seed();
    final router = await pumpApp(
      tester,
      initialLocation: '/diary',
      diary: repo,
    );
    String path() => router.routeInformationProvider.value.uri.path;
    final paper = find.byKey(const ValueKey('diary-active-paper'));

    await tester.flingFrom(
      tester.getRect(paper).center,
      const Offset(-300, 0),
      1500,
    );
    await tester.pumpAndSettle();
    expect(path(), '/notes');

    final middle = tester.getRect(find.byType(Scaffold).first).center;
    await tester.flingFrom(middle, const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(path(), '/diary');
    expect(scene(tester).day.date, today);

    // Back a day, the reader turns as before in both directions.
    await tester.dragFrom(tester.getRect(paper).center, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(path(), '/diary');
    expect(scene(tester).day.date, today.shift(-1));
    await tester.dragFrom(tester.getRect(paper).center, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(path(), '/diary');
    expect(scene(tester).day.date, today);

    // The header's day strip hands the same swipe over too.
    await tester.fling(find.byType(DiaryCalendar), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(path(), '/notes');
    expect(tester.takeException(), isNull);
  });

  sceneTest('the diary calendar keeps its swipes to itself', (tester) async {
    await seed();
    final router = await pumpApp(
      tester,
      initialLocation: '/diary',
      diary: repo,
    );
    await tester.tap(find.byKey(const ValueKey('diary-date-control')));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryCalendarPage).hitTestable(), findsOneWidget);
    final middle = tester.getRect(find.byType(DiaryCalendarPage)).center;
    await tester.flingFrom(middle, const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/diary');
    expect(find.byType(DiaryCalendarPage).hitTestable(), findsOneWidget);
  });

  sceneTest('each tab keeps its own bottom bar state', (tester) async {
    await seed(body: List.filled(80, 'A long remembered line.').join('\n'));
    final router = await pumpApp(
      tester,
      initialLocation: '/diary',
      diary: repo,
    );
    final paper = find.byKey(const ValueKey('diary-active-paper'));
    await tester.dragFrom(tester.getRect(paper).center, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(scene(tester).collapse, 1);
    expect(navbarHidden(tester), isTrue);

    // The immersive page of today still swipes on to Notes, with its bar.
    await tester.flingFrom(
      tester.getRect(paper).center,
      const Offset(-300, 0),
      1500,
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/notes');
    expect(navbarHidden(tester), isFalse);

    final middle = tester.getRect(find.byType(Scaffold).first).center;
    await tester.flingFrom(middle, const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/diary');
    expect(scene(tester).collapse, 1);
    expect(navbarHidden(tester), isTrue);
  });

  sceneTest(
    'pulling the page down unrolls the calendar; lifting its thread, a tab, a date or Back returns',
    (tester) async {
      await seed();
      await pumpApp(tester, initialLocation: '/diary', diary: repo);
      expect(find.byKey(const ValueKey('diary-search-control')), findsNothing);
      final paper = find.byKey(const ValueKey('diary-active-paper'));
      final resting = tester.getRect(paper).top;

      // A short pull springs back to the page and keeps the bottom bar.
      final short = await tester.startGesture(tester.getRect(paper).center);
      for (var i = 0; i < 4; i++) {
        await short.moveBy(const Offset(0, 15));
        await tester.pump();
      }
      expect(find.byKey(const ValueKey('diary-pulled-thread')), findsOneWidget);
      expect(navbarHidden(tester), isFalse);
      await short.up();
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCalendarPage), findsNothing);
      expect(tester.getRect(paper).top, resting);
      expect(navbarHidden(tester), isFalse);

      // Mid-pull the page hangs from the stretched thread, under the finger.
      final gesture = await tester.startGesture(tester.getRect(paper).center);
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }
      expect(find.byKey(const ValueKey('diary-pulled-thread')), findsOneWidget);
      expect(tester.getRect(paper).top, greaterThan(resting + 150));
      expect(find.byType(DiaryCalendarPage).hitTestable(), findsNothing);
      // Past the point where letting go opens it, the bar has left.
      expect(navbarHidden(tester), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCalendarPage).hitTestable(), findsOneWidget);
      expect(navbarHidden(tester), isTrue);

      // The thread rests across the calendar's bottom, holding the day's tab.
      Finder threadTab(DiaryPeriod date) => find.descendant(
        of: find.byKey(const ValueKey('diary-resting-thread')),
        matching: find.byKey(
          ValueKey(
            'diary-calendar-date-${DateTime(date.year, date.month, date.day).toIso8601String()}',
          ),
        ),
      );
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      // Today, a Monday, hangs in full above the bottom of the screen.
      final restingLabel = tester.getRect(
        find.descendant(of: threadTab(today), matching: find.text('Mon')),
      );
      expect(restingLabel.bottom, lessThan(height));
      expect(restingLabel.top, greaterThan(height * .6));
      expect(tester.getRect(paper).top, greaterThan(height - 40));

      // A short lift settles back; lifting it further raises the page home.
      await tester.drag(threadTab(today), const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCalendarPage).hitTestable(), findsOneWidget);
      final lift = await tester.startGesture(
        tester.getRect(threadTab(today)).center,
      );
      for (var i = 0; i < 10; i++) {
        await lift.moveBy(const Offset(0, -30));
        await tester.pump();
      }
      expect(navbarHidden(tester), isFalse);
      await lift.up();
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCalendarPage), findsNothing);
      expect(scene(tester).day.date, today);
      expect(tester.getRect(paper).top, resting);

      // Another tab on the resting thread returns on its day.
      await tester.tap(find.byKey(const ValueKey('diary-date-control')));
      await tester.pumpAndSettle();
      await tester.tap(threadTab(DiaryPeriod(2026, 11, 1)));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCalendarPage), findsNothing);
      expect(scene(tester).day.date, DiaryPeriod(2026, 11, 1));

      // So does the day's own tab, and a day chosen in the calendar.
      await tester.tap(find.byKey(const ValueKey('diary-date-control')));
      await tester.pumpAndSettle();
      await tester.tap(threadTab(DiaryPeriod(2026, 11, 1)));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCalendarPage), findsNothing);
      expect(scene(tester).day.date, DiaryPeriod(2026, 11, 1));
      await tester.tap(find.byKey(const ValueKey('diary-date-control')));
      await tester.pumpAndSettle();
      await tester.tap(day(DiaryPeriod(2026, 11, 1)));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCalendarPage), findsNothing);
      expect(scene(tester).day.date, DiaryPeriod(2026, 11, 1));
      expect(tester.getRect(paper).top, resting);
      expect(navbarHidden(tester), isFalse);

      // The month label opens it too, and Back closes it on the same day.
      await tester.tap(find.byKey(const ValueKey('diary-date-control')));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCalendarPage).hitTestable(), findsOneWidget);
      expect(navbarHidden(tester), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCalendarPage), findsNothing);
      expect(navbarHidden(tester), isFalse);
      expect(scene(tester).day.date, DiaryPeriod(2026, 11, 1));
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest('reduced motion opens and closes the calendar without motion', (
    tester,
  ) async {
    final appearance = FakeAppearanceRepository();
    addTearDown(appearance.close);
    await pumpApp(
      tester,
      initialLocation: '/diary',
      diary: repo,
      repository: appearance,
    );
    appearance.emit(const AppearancePreferences(reduceMotion: true));
    await tester.pumpAndSettle();
    await tester.dragFrom(
      tester.getRect(find.byKey(const ValueKey('diary-active-paper'))).center,
      const Offset(0, 300),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(DiaryCalendarPage).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('diary-calendar-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diary-search-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  sceneTest(
    'landing is today; paper and calendar share turns, cancellation and the future boundary',
    (tester) async {
      final router = await pumpApp(
        tester,
        initialLocation: '/diary',
        diary: repo,
      );
      expect(scene(tester).day.date, today);
      expect(find.byType(RedkeepBottomNavbar), findsOneWidget);
      final paper = find.byKey(const ValueKey('diary-active-paper'));
      final start = tester.getRect(paper).center;
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(180, 0));
      await tester.pump();
      expect(scene(tester).turn, greaterThan(0));
      final calendar = tester.widget<DiaryCalendar>(
        find.byType(DiaryCalendar).last,
      );
      expect(
        calendar.dayOffset,
        closeTo(-scene(tester).direction * scene(tester).turn, .00001),
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, today);
      await tester.dragFrom(start, Offset(tester.getSize(paper).width * .6, 0));
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, today.shift(-1));
      expectDiaryDay(tester, router, today.shift(-1)!);
      await tester.dragFrom(
        tester.getRect(paper).center,
        Offset(-tester.getSize(paper).width * .6, 0),
      );
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, today);
      await tester.dragFrom(
        tester.getRect(paper).center,
        const Offset(-250, 0),
      );
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, today);
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest(
    'flat slides move both sheets and keep a single live reader at rest',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final yesterday = today.shift(-1)!;
      const todayBody = 'Today the sun came out.';
      const yesterdayBody = 'Yesterday it rained.';
      await seed(body: todayBody);
      await repo.save(
        id: '22222222222222222222222222222222',
        date: yesterday,
        text: const DiaryText(body: yesterdayBody),
        expectedRevision: 0,
      );
      await pumpApp(tester, initialLocation: '/diary', diary: repo);
      final paper = find.byKey(const ValueKey('diary-active-paper'));
      final live = find.byKey(const ValueKey('diary-live-content'));
      final contentState = tester.state(live);
      expect(find.text(todayBody), findsOneWidget);
      expect(find.text(yesterdayBody), findsNothing);

      for (final (direction, date, body) in [
        (1, yesterday, yesterdayBody),
        (-1, today, todayBody),
      ]) {
        final resting = tester.getRect(paper);
        final incoming = find.descendant(
          of: find.byKey(ValueKey('diary-side-sheet-${date.key}')),
          matching: find.byType(DiarySheet),
        );
        final gesture = await tester.startGesture(resting.center);
        await gesture.moveBy(Offset(24.0 * direction, 0));
        await gesture.moveBy(Offset(60.0 * direction, 0));
        await tester.pump();

        final sliding = tester.getRect(paper);
        final incomingLeft = tester.getRect(incoming).left;
        expect((sliding.left - resting.left) * direction, greaterThan(0));
        expect(sliding.size, resting.size);
        expect(sliding.top, resting.top);
        expect(find.text(body), findsOneWidget);
        expect(find.byType(DiaryDayContent), findsNWidgets(2));
        expect(tester.state(live), same(contentState));

        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.getRect(paper), sliding);
        await gesture.moveBy(Offset(-100.0 * direction, 0));
        await tester.pump();
        expect(scene(tester).direction, -direction);
        await gesture.moveBy(Offset(180.0 * direction, 0));
        await tester.pump();
        expect(
          (tester.getRect(incoming).left - incomingLeft) * direction,
          greaterThan(0),
        );
        await gesture.up();
        await tester.pumpAndSettle();

        expect(scene(tester).day.date, date);
        expect(tester.getRect(paper), resting);
        expect(find.text(body), findsOneWidget);
        expect(find.byType(DiaryDayContent), findsOneWidget);
        expect(tester.state(live), same(contentState));
      }
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest('today stays circled on the cord while focus and page turns move', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/diary',
      diary: repo,
    );
    final circle = find.byKey(const ValueKey('diary-calendar-today'));
    final todayTab = find.byKey(
      ValueKey(
        'diary-calendar-date-${DateTime(2026, 11, 2).toIso8601String()}',
      ),
    );
    void expectTodayCircled() {
      expect(circle, findsOneWidget);
      expect(find.descendant(of: todayTab, matching: circle), findsOneWidget);
      expect(
        tester
            .getRect(circle)
            .overlaps(tester.getRect(find.byType(DiaryCalendar).last)),
        isTrue,
      );
      for (final opacity in tester.widgetList<Opacity>(
        find.ancestor(of: circle, matching: find.byType(Opacity)),
      )) {
        expect(opacity.opacity, greaterThan(0));
      }
    }

    expectTodayCircled();
    scene(tester).onDateChanged(DiaryPeriod(2026, 11, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expectTodayCircled();
    await tester.pumpAndSettle();
    expect(scene(tester).day.date, today.shift(-1));
    expectTodayCircled();
    scene(tester).onDateChanged(DiaryPeriod(2026, 10, 31));
    await tester.pumpAndSettle();
    expectTodayCircled();
    goDiaryDay(tester, router, today.shift(-10)!);
    await tester.pumpAndSettle();
    expect(circle, findsNothing);
    goDiaryDay(tester, router, today);
    await tester.pumpAndSettle();
    expectTodayCircled();
    expect(tester.takeException(), isNull);
  });

  sceneTest(
    'simpler effects switch pages without a slide; future writing remains addressable',
    (tester) async {
      final future = today.shift(1)!;
      await seed(date: future);
      final appearance = FakeAppearanceRepository(
        const AppearancePreferences(simplerEffects: true),
      );
      addTearDown(appearance.close);
      final router = await pumpApp(
        tester,
        initialLocation: '/diary',
        diary: repo,
        repository: appearance,
      );
      final paper = find.byKey(const ValueKey('diary-active-paper'));
      final resting = tester.getRect(paper);
      final gesture = await tester.startGesture(resting.center);
      await gesture.moveBy(const Offset(24, 0));
      await gesture.moveBy(Offset(resting.width * .6, 0));
      await tester.pump();
      expect(tester.getRect(paper), resting);
      expect(find.byType(DiarySheet), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, today.shift(-1));
      router.go(diaryEntryLocation(future, id));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      router.go(diaryEntryLocation(future, id, edit: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('diary-body')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest(
    'calendar markers react to deletion; year navigation and Today retain date bounds',
    (tester) async {
      await seed();
      final router = await pumpApp(
        tester,
        initialLocation: diaryCalendarLocation(today),
        diary: repo,
      );
      var node = tester.widget<Semantics>(
        find.descendant(of: day(today), matching: find.byType(Semantics)).first,
      );
      expect(node.properties.label, contains('Journal entry'));
      await repo.deleteEntry(id, 1);
      await tester.pumpAndSettle();
      node = tester.widget<Semantics>(
        find.descendant(of: day(today), matching: find.byType(Semantics)).first,
      );
      expect(node.properties.label, contains('No journal entry'));
      expect(find.textContaining('summary'), findsNothing);
      expect(day(today.shift(1)!), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('calendar-year-pages')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('summary'), findsNothing);
      await tester.tap(find.byKey(ValueKey('calendar-year-tab-${today.year}')));
      await tester.pumpAndSettle();
      // Tapping the selected current year returns to today's month.
      await tester.tap(find.byKey(ValueKey('calendar-year-tab-${today.year}')));
      await tester.pumpAndSettle();
      expect(day(today), findsOneWidget);
      await tester.ensureVisible(day(today));
      await tester.pumpAndSettle();
      await tester.tap(day(today));
      await tester.pumpAndSettle();
      expectDiaryDay(tester, router, today);
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest('typing on the opening page rebuilds nothing above the field', (
    tester,
  ) async {
    await seed();
    await pumpApp(tester, initialLocation: '/diary/search', diary: repo);
    await submit(tester, 'coffee');
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('diary-search-recent-0'));
    final before = tester.element(card);
    final input = find.byKey(const ValueKey('diary-search-input'));
    for (final text in ['w', 'wa', 'wal', 'w', '']) {
      await tester.enterText(input, text);
      await tester.pump();
      expect(find.byType(DiarySearchOpening), findsOneWidget, reason: text);
      expect(tester.element(card), same(before), reason: text);
    }
    expect(tester.takeException(), isNull);
  });

  sceneTest('the loading scene waits before it appears', (tester) async {
    await seed();
    final slow = StreamController<List<DiaryListing>>.broadcast();
    addTearDown(slow.close);
    repo.searches['slow'] = slow;
    await pumpApp(tester, initialLocation: '/diary/search', diary: repo);
    await submit(tester, 'slow', settle: false);
    final loading = find.byKey(const ValueKey('diary-search-loading'));
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.descendant(of: loading, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;
    expect(loading, findsOneWidget);
    expect(opacity(), 0);
    expect(find.bySemanticsLabel(RegExp('Looking through')), findsNothing);
    await tester.pump(DiarySearchLoading.revealAfter);
    // The scan loops while shown, so wait out the fade instead of settling.
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 1);
    expect(find.bySemanticsLabel(RegExp('Looking through')), findsOneWidget);
    slow.add([DiaryListing(id: id, date: today)]);
    await tester.pumpAndSettle();
    expect(loading, findsNothing);
    expect(find.byKey(const ValueKey('diary-search-match-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  sceneTest(
    'query changes and clear detach pending searches; errors can retry',
    (tester) async {
      await seed();
      final late = StreamController<List<DiaryListing>>.broadcast();
      repo.searches['late'] = late;
      await pumpApp(tester, initialLocation: '/diary/search', diary: repo);
      await submit(tester, 'late', settle: false);
      expect(
        find.byKey(const ValueKey('diary-search-loading')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('diary-search-input')),
        'coffee',
      );
      await tester.pump();
      late.add([DiaryListing(id: id, date: today)]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('diary-search-match-0')), findsNothing);
      await submit(tester, 'coffee');
      expect(
        find.byKey(const ValueKey('diary-search-match-0')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('diary-search-match-0')), findsNothing);
      repo.failRead = true;
      await submit(tester, 'failure');
      expect(find.byKey(const ValueKey('diary-search-retry')), findsOneWidget);
      repo.failRead = false;
      await tester.ensureVisible(
        find.byKey(const ValueKey('diary-search-retry')),
      );
      await tester.tap(find.byKey(const ValueKey('diary-search-retry')));
      await tester.pumpAndSettle();
      expect(find.text('No moments found yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest(
    'searching the current day reopens its beginning; failed paper documents retry',
    (tester) async {
      await seed(body: List.filled(80, 'coffee by the window').join('\n'));
      await pumpApp(
        tester,
        initialLocation: '/diary',
        diaryDay: today,
        diary: repo,
      );
      final nested = tester.state<NestedScrollViewState>(
        find.byType(NestedScrollView).last,
      );
      nested.outerController.jumpTo(120);
      await tester.pumpAndSettle();
      nested.innerController.jumpTo(300);
      await tester.pumpAndSettle();
      expect(nested.innerController.offset, greaterThan(0));
      nested.outerController.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('diary-date-control')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('diary-calendar-search')));
      await tester.pumpAndSettle();
      await submit(tester, 'coffee');
      await tester.tap(find.byKey(const ValueKey('diary-search-match-0')));
      await tester.pumpAndSettle();
      final reopened = tester.state<NestedScrollViewState>(
        find.byType(NestedScrollView).last,
      );
      expect(reopened.innerController.offset, 0);
      final container = tester.container();
      repo.failRead = true;
      container.invalidate(diaryDocumentProvider(id));
      await tester.pumpAndSettle();
      final retry = find.descendant(
        of: find.byKey(const ValueKey('diary-live-content')),
        matching: find.text('Could not load this day. Retry'),
      );
      expect(retry, findsOneWidget);
      repo.failRead = false;
      reopened.outerController.jumpTo(0);
      reopened.innerController.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(container.read(diaryPaperDayProvider(today)).failed, isFalse);
      expect(
        container.read(diaryPaperDayProvider(today)).entries.single.text.body,
        List.filled(80, 'coffee by the window').join('\n'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest('earliest civil day has no previous face or underflow', (
    tester,
  ) async {
    final first = DiaryPeriod(1, 1, 1);
    await pumpApp(
      tester,
      initialLocation: '/diary',
      diaryDay: first,
      diary: repo,
    );
    expect(scene(tester).day.date, first);
    await tester.dragFrom(
      tester.getRect(find.byKey(const ValueKey('diary-active-paper'))).center,
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
    expect(scene(tester).day.date, first);
    expect(tester.takeException(), isNull);
  });

  sceneTest(
    'reduced motion enabled during a committed turn finishes and releases input',
    (tester) async {
      final appearance = FakeAppearanceRepository();
      addTearDown(appearance.close);
      await pumpApp(
        tester,
        initialLocation: '/diary',
        diary: repo,
        repository: appearance,
      );
      scene(tester).onDateChanged(DiaryPeriod(2026, 11, 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      appearance.emit(const AppearancePreferences(reduceMotion: true));
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, today.shift(-1));
      expect(scene(tester).busy, isFalse);
      scene(tester).onDateChanged(DiaryPeriod(2026, 11, 2));
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, today);
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest('seven-column calendar remains usable at 320px and 3x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final leap = DiaryPeriod(2024, 2, 29);
    final router = await pumpApp(
      tester,
      initialLocation: diaryCalendarLocation(leap),
      diary: repo,
    );
    await tester.ensureVisible(day(leap));
    await tester.pumpAndSettle();
    expect(tester.getSize(day(leap)).width, greaterThanOrEqualTo(44));
    expect(day(leap).hitTestable(), findsOneWidget);
    await tester.tap(day(leap));
    await tester.pumpAndSettle();
    expectDiaryDay(tester, router, leap);
    expect(tester.takeException(), isNull);
  });

  sceneTest(
    'the opening shows the last three searches, newest first, and reruns them',
    (tester) async {
      await seed();
      await pumpApp(tester, initialLocation: '/diary/search', diary: repo);
      expect(find.text('Try a keyword'), findsNothing);
      expect(
        find.byKey(const ValueKey('diary-search-more-ideas')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('diary-search-recent-0')), findsNothing);

      Future<void> clear() async {
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();
      }

      for (final query in ['walk', 'coffee', 'rain', 'tea']) {
        await submit(tester, query);
        await clear();
      }
      String card(int i) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey('diary-search-recent-$i')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect([card(0), card(1), card(2)], ['tea', 'rain', 'coffee']);
      expect(find.byKey(const ValueKey('diary-search-recent-3')), findsNothing);
      expect(find.byIcon(Icons.history_rounded), findsNWidgets(3));

      final coffee = find.byKey(const ValueKey('diary-search-recent-2'));
      await tester.ensureVisible(coffee);
      await tester.pumpAndSettle();
      await tester.tap(coffee);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('diary-search-match-0')),
        findsOneWidget,
      );
      await clear();
      expect([card(0), card(1), card(2)], ['coffee', 'tea', 'rain']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    sceneTest('paper, calendar, search and editor visual review $theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      addTearDown(tester.view.reset);
      await seed();
      final appearance = FakeAppearanceRepository(
        AppearancePreferences(theme: theme),
      );
      addTearDown(appearance.close);
      final router = await pumpApp(
        tester,
        initialLocation: '/diary',
        diary: repo,
        repository: appearance,
      );
      await capture(tester, '${theme.name}-diary');
      router.go(diaryCalendarLocation(today));
      await tester.pumpAndSettle();
      expect(find.byType(RedkeepBottomNavbar), findsNothing);
      await capture(tester, '${theme.name}-calendar');
      router.go('/diary/search');
      await tester.pumpAndSettle();
      expect(find.byType(RedkeepBottomNavbar), findsNothing);
      await capture(tester, '${theme.name}-search');
      await submit(tester, 'coffee');
      await capture(tester, '${theme.name}-results');
      router.go(diaryEntryLocation(today, id, edit: true));
      await tester.pumpAndSettle();
      expect(find.byType(RedkeepBottomNavbar), findsNothing);
      await capture(tester, '${theme.name}-editor');
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('DIARY_CAPTURES')) return;
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }
  for (final element in find.byType(Image).evaluate().toList()) {
    final image = element.widget as Image;
    await tester.runAsync(() async {
      // Restart loads begun in the widget test's fake I/O zone.
      await image.image.evict();
      await precacheImage(
        image.image,
        element,
      ).timeout(const Duration(seconds: 3));
    });
  }
  for (final element in find.byType(Image).evaluate().toList()) {
    // Reconnect just the image listeners to the cache populated in real I/O.
    // A full app reassemble also resets unrelated button and route animations.
    // ignore: invalid_use_of_protected_member
    element.reassemble();
  }
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/tmp/redkeep-diary-$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

bool navbarHidden(WidgetTester tester) =>
    tester
        .widget<AnimatedSlide>(
          find.ancestor(
            of: find.byType(RedkeepBottomNavbar),
            matching: find.byType(AnimatedSlide),
          ),
        )
        .offset !=
    Offset.zero;
