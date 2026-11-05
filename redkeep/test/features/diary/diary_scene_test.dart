import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/app/bottom_navbar.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/application/diary_paper_providers.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/presentation/diary_calendar.dart';
import 'package:redkeep/features/diary/presentation/diary_paper_curl.dart';
import 'package:redkeep/features/diary/presentation/diary_scene.dart';

import '../../support/controlled_diary_repository.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';
import '../../support/warm_diary_faces.dart';

final today = CivilDate(2026, 11, 2);
const id = '11111111111111111111111111111111';

class PendingSearchRepository extends ControlledDiaryRepository {
  PendingSearchRepository(super.inner);
  final searches = <String, StreamController<List<DiaryListing>>>{};
  @override
  Stream<List<DiaryListing>> watchEntries({
    CivilDate? date,
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
      ('Lora', '../assets/reference/website/fonts/Lora-Regular.ttf'),
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
    CivilDate? date,
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

  Finder day(CivilDate date) => find.byKey(
    ValueKey(
      'calendar-day-${DateTime(date.year, date.month, date.day).toIso8601String()}',
    ),
  );

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
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(today.shift(-1)!),
      );
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
    'slow turns reuse real diary faces through pauses, reversals and promotion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seed();
      await pumpApp(
        tester,
        initialLocation: diaryDayLocation(today),
        diary: repo,
      );
      final paper = find.byKey(const ValueKey('diary-active-paper'));
      final cancelledDate = scene(tester).day.date;
      for (final direction in [1, 1, -1, -1]) {
        await warmDiaryFaces(tester);
        final from = scene(tester).day.date;
        final faces = tester
            .renderObjectList<RenderDiaryCurl>(find.byType(DiaryPaperCurl))
            .toList();
        final captures = {
          for (final face in faces)
            face: (
              face.debugFrontCaptures,
              face.debugBackCaptures,
              face.debugShadowCaptures,
            ),
        };
        void expectUnchanged() {
          for (final face in faces.where((face) => face.attached)) {
            expect((
              face.debugFrontCaptures,
              face.debugBackCaptures,
              face.debugShadowCaptures,
            ), captures[face]);
          }
        }

        final gesture = await tester.startGesture(tester.getRect(paper).center);
        await gesture.moveBy(Offset(24.0 * direction, 0));
        await tester.pump();
        for (var frame = 0; frame < 36; frame++) {
          await gesture.moveBy(Offset(3.0 * direction, 0));
          await tester.pump(const Duration(milliseconds: 24));
          expectUnchanged();
        }
        final outgoing = tester.renderObject<RenderDiaryCurl>(
          find.byWidgetPredicate((w) => w is DiaryPaperCurl && !w.flat),
        );
        expect(outgoing.debugUsesCurl, isTrue);
        await tester.pump(const Duration(milliseconds: 250));
        expectUnchanged();
        // Cross the drag origin, then return to the original direction.
        await gesture.moveBy(Offset(-180.0 * direction, 0));
        await tester.pump(const Duration(milliseconds: 24));
        await gesture.moveBy(Offset(190.0 * direction, 0));
        await tester.pump(const Duration(milliseconds: 24));
        expectUnchanged();
        await gesture.up();
        for (var frame = 0; scene(tester).busy && frame < 40; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expectUnchanged();
        }
        expect(scene(tester).busy, isFalse);
        expect(scene(tester).day.date, from.shift(-direction));
        expect(
          find.byType(DiaryPaperCurl).evaluate().length,
          lessThanOrEqualTo(3),
        );
        await tester.pumpAndSettle();
      }
      expect(scene(tester).day.date, cancelledDate);
      await warmDiaryFaces(tester);
      final faces = tester
          .renderObjectList<RenderDiaryCurl>(find.byType(DiaryPaperCurl))
          .toList();
      final captures = [for (final face in faces) face.debugFrontCaptures];
      final gesture = await tester.startGesture(tester.getRect(paper).center);
      await gesture.moveBy(const Offset(24, 0));
      for (var frame = 0; frame < 30; frame++) {
        await gesture.moveBy(const Offset(4, 0));
        await tester.pump(const Duration(milliseconds: 32));
      }
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, cancelledDate);
      expect([for (final face in faces) face.debugFrontCaptures], captures);
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest(
    'the curved date pin stays on today while focus and page turns move',
    (tester) async {
      final router = await pumpApp(
        tester,
        initialLocation: '/diary',
        diary: repo,
      );
      final pin = find.byKey(const ValueKey('diary-calendar-pin'));
      final todayTab = find.byKey(
        ValueKey(
          'diary-calendar-date-${DateTime(2026, 11, 2).toIso8601String()}',
        ),
      );
      void expectTodayPinned() {
        expect(pin, findsOneWidget);
        expect(find.descendant(of: todayTab, matching: pin), findsOneWidget);
        expect(
          tester
              .getRect(pin)
              .overlaps(tester.getRect(find.byType(DiaryCalendar).last)),
          isTrue,
        );
        for (final opacity in tester.widgetList<Opacity>(
          find.ancestor(of: pin, matching: find.byType(Opacity)),
        )) {
          expect(opacity.opacity, greaterThan(0));
        }
      }

      expectTodayPinned();
      scene(tester).onDateChanged(DateTime(2026, 11, 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expectTodayPinned();
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, today.shift(-1));
      expectTodayPinned();
      scene(tester).onDateChanged(DateTime(2026, 10, 31));
      await tester.pumpAndSettle();
      expectTodayPinned();
      router.go(diaryDayLocation(today.shift(-10)!));
      await tester.pumpAndSettle();
      expect(pin, findsNothing);
      router.go(diaryDayLocation(today));
      await tester.pumpAndSettle();
      expectTodayPinned();
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest(
    'simpler effects never instantiate curl render objects; future writing remains addressable',
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
      expect(find.byType(DiaryPaperCurl), findsNothing);
      scene(tester).onDateChanged(DateTime(2026, 11, 1));
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, today.shift(-1));
      expect(find.byType(DiaryPaperCurl), findsNothing);
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
      await tester.tap(find.byKey(const ValueKey('calendar-today')));
      await tester.pumpAndSettle();
      expect(day(today), findsOneWidget);
      await tester.ensureVisible(day(today));
      await tester.pumpAndSettle();
      await tester.tap(day(today));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        diaryDayLocation(today),
      );
      expect(tester.takeException(), isNull);
    },
  );

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
        initialLocation: diaryDayLocation(today),
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
      await tester.tap(find.byKey(const ValueKey('diary-search-control')).last);
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
    final first = CivilDate(1, 1, 1);
    await pumpApp(
      tester,
      initialLocation: diaryDayLocation(first),
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
      scene(tester).onDateChanged(DateTime(2026, 11, 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      appearance.emit(const AppearancePreferences(reduceMotion: true));
      await tester.pumpAndSettle();
      expect(scene(tester).day.date, today.shift(-1));
      expect(scene(tester).busy, isFalse);
      scene(tester).onDateChanged(DateTime(2026, 11, 2));
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
    final leap = CivilDate(2024, 2, 29);
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
    expect(
      router.routeInformationProvider.value.uri.path,
      diaryDayLocation(leap),
    );
    expect(tester.takeException(), isNull);
  });

  sceneTest(
    'keyword suggestions refresh and submit without starting AI features',
    (tester) async {
      await seed();
      await pumpApp(tester, initialLocation: '/diary/search', diary: repo);
      final ideas = find.byKey(const ValueKey('diary-search-more-ideas'));
      expect(ideas.hitTestable(), findsOneWidget);
      expect(tester.getSize(ideas).width, greaterThanOrEqualTo(44));
      await tester.tap(ideas);
      await tester.pumpAndSettle();
      expect(find.text('route'), findsOneWidget);
      await tester.tap(ideas);
      await tester.pumpAndSettle();
      final coffee = find.text('coffee');
      await tester.ensureVisible(coffee);
      await tester.pumpAndSettle();
      await tester.tap(coffee);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('diary-search-match-0')),
        findsOneWidget,
      );
      expect(find.textContaining('paired computer'), findsNothing);
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
