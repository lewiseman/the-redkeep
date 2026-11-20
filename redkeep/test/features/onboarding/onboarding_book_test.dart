import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/onboarding/presentation/book_artwork.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_book.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_page.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_controls.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/pump_app.dart';
import '../../support/onboarding_navigation.dart';

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _name(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.byType(TextField));
  await tester.enterText(find.byType(TextField), name);
  await tester.pump();
}

Future<void> _decodeVisible(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
    if (find.byType(OnboardingPage).evaluate().isEmpty) return;
    final frames = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
    if (frames.isNotEmpty && frames.every((f) => f.image != null)) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail(
    'Local artwork did not decode: '
    '${tester.widgetList<RawImage>(find.byType(RawImage)).map((f) => f.image)}; '
    'exception: ${tester.takeException()}',
  );
}

void main() {
  setUp(() {
    // An unfinished decode from an earlier fake-async test must not retain its
    // image stream in this test's cache, especially for the larger mascot.
    final cache = TestWidgetsFlutterBinding.ensureInitialized().imageCache;
    cache.clear();
    cache.clearLiveImages();
  });
  testWidgets('original open spread and manual boundaries/swipes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final repository = FakeOnboardingRepository(completed: false);
      await pumpApp(tester, onboarding: repository);
      expect(
        find.bySemanticsLabel(RegExp(r'Notes\. Catch a thought')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('onboarding-book-semantics')),
            )
            .properties
            .onDecrease,
        isNull,
      );
      await tester.pump(const Duration(seconds: 4));
      expect(chapterPosition(1), findsOneWidget);
      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('onboarding-book'))),
      );
      await drag.moveBy(const Offset(-15, 0));
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(chapterPosition(1), findsOneWidget);
      for (var chapter = 2; chapter <= 3; chapter++) {
        await navigateChapter(tester, 1);
        expect(chapterPosition(chapter), findsOneWidget);
      }
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('onboarding-book-semantics')),
            )
            .properties
            .onIncrease,
        isNull,
      );
      await tester.drag(
        find.byKey(const ValueKey('onboarding-book')),
        const Offset(180, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp(r'Diary\. Keep the moments')),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey('onboarding-book')),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      expect(chapterPosition(3), findsOneWidget);
      expect(repository.saves, 0);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the tour never turns a page by itself', (tester) async {
    final repository = FakeOnboardingRepository(completed: false);
    await pumpApp(tester, onboarding: repository);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(chapterPosition(1), findsOneWidget);
    await navigateChapter(tester, 1);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(chapterPosition(2), findsOneWidget);
    expect(repository.saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'open-page artwork retains its decoded frame throughout closing and reopening',
    (tester) async {
      await pumpApp(
        tester,
        onboarding: FakeOnboardingRepository(completed: false),
      );
      await _decodeVisible(tester);
      void expectPaintedLeaves() {
        final leaves = find.byWidgetPredicate(
          (w) => w is BookFileImage && w.assetKey == 'onboarding.chapter.notes',
        );
        expect(leaves, findsWidgets);
        for (final leaf in leaves.evaluate()) {
          final frames = tester.widgetList<RawImage>(
            find.descendant(
              of: find.byElementPredicate((e) => identical(e, leaf)),
              matching: find.byType(RawImage),
            ),
          );
          expect(
            frames,
            hasLength(1),
            reason:
                'A page must not become a loading placeholder '
                '(closing: ${tester.widget<OnboardingBook>(find.byType(OnboardingBook)).closing})',
          );
          expect(
            frames.single.image,
            isNotNull,
            reason: 'A page must keep its decoded frame',
          );
        }
      }

      expectPaintedLeaves();
      await tester.tap(find.text("Let's begin"));
      await tester.pump();
      for (var frame = 0; frame < 23; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        expectPaintedLeaves();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      await _decodeVisible(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      for (var frame = 0; frame < 23; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        expectPaintedLeaves();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(chapterPosition(1), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the page follows a drag and a canceled turn restores the same chapter',
    (tester) async {
      await pumpApp(
        tester,
        onboarding: FakeOnboardingRepository(completed: false),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('onboarding-book'))),
      );
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      expect(
        tester.widget<OnboardingBook>(find.byType(OnboardingBook)).turn,
        greaterThan(0),
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(chapterPosition(1), findsOneWidget);
      expect(
        tester.widget<OnboardingBook>(find.byType(OnboardingBook)).turn,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final mode in ['normal', 'reduced', 'simple']) {
    for (final accessible in [false, true]) {
      testWidgets(
        '$mode ${accessible ? 'large text' : 'cover'} name input receives focus after closing',
        (tester) async {
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = accessible
              ? const Size(320, 480)
              : const Size(390, 844);
          if (accessible) {
            tester.platformDispatcher.textScaleFactorTestValue = 3;
          }
          final preferences = FakeAppearanceRepository(
            AppearancePreferences(
              reduceMotion: mode == 'reduced',
              simplerEffects: mode == 'simple',
            ),
          );
          addTearDown(preferences.close);
          await pumpApp(
            tester,
            repository: preferences,
            onboarding: FakeOnboardingRepository(completed: false),
          );
          final focus = tester
              .widget<OnboardingBook>(find.byType(OnboardingBook))
              .nameFocus;
          expect(focus.hasFocus, false);
          await tester.ensureVisible(find.text("Let's begin"));
          await tester.tap(find.text("Let's begin"));
          await tester.pump();
          if (mode == 'normal') {
            await tester.pump(const Duration(milliseconds: 500));
            expect(focus.hasFocus, false);
            expect(tester.testTextInput.isVisible, false);
          }
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(find.byType(TextField)).enabled,
            true,
          );
          expect(focus.hasFocus, true);
          expect(tester.testTextInput.isVisible, true);

          await reopenOnboardingBook(tester);
          expect(focus.hasFocus, false);
          await _tap(tester, "Let's begin");
          expect(focus.hasFocus, true);
          expect(tester.testTextInput.isVisible, true);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'system back dismisses name focus, reopens the book, then permits root exit',
    (tester) async {
      await pumpApp(
        tester,
        onboarding: FakeOnboardingRepository(completed: false),
      );
      await _tap(tester, "Let's begin");
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      if (chapterPosition(1).evaluate().isEmpty) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      expect(chapterPosition(1), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'folding cover requires name; failed save retains text and retry waits for commit',
    (tester) async {
      final repository = FakeOnboardingRepository(completed: false);
      final router = await pumpApp(
        tester,
        onboarding: repository,
        initialLocation: '/settings',
      );
      await _tap(tester, "Let's begin");
      expect(
        tester.widget<OnboardingBook>(find.byType(OnboardingBook)).closing,
        1,
      );
      expect(repository.saves, 0);
      expect(
        tester
            .widget<OnboardingPrimaryButton>(
              find.byType(OnboardingPrimaryButton),
            )
            .onPressed,
        isNull,
      );
      await _name(tester, '   ');
      expect(
        tester
            .widget<OnboardingPrimaryButton>(
              find.byType(OnboardingPrimaryButton),
            )
            .onPressed,
        isNull,
      );
      await _name(tester, '  Ada 王  ');
      await reopenOnboardingBook(tester);
      expect(chapterPosition(1), findsOneWidget);
      await _tap(tester, "Let's begin");
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '  Ada 王  ',
      );
      repository.saveGate = Completer<void>();
      repository.failSave = true;
      await tester.tap(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(repository.saves, 1);
      expect(find.text('Saving…'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
      expect(find.text('Back to chapters'), findsNothing);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['continue'],
        '/settings',
      );
      repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '  Ada 王  ',
      );
      expect(find.textContaining('Synthetic'), findsNothing);
      repository.failSave = false;
      repository.saveGate = Completer<void>();
      await _tap(tester, 'Save');
      expect(repository.completed, false);
      expect(router.routeInformationProvider.value.uri.path, '/onboarding');
      repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(repository.savedName, 'Ada 王');
      expect(repository.saves, 2);
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in ['normal', 'reduced', 'simple']) {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      testWidgets(
        '$theme $mode large text, narrow landscape, keyboard and name input remain usable',
        (tester) async {
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          tester.view.devicePixelRatio = 1;
          final appearance = FakeAppearanceRepository(
            AppearancePreferences(
              theme: theme,
              reduceMotion: mode == 'reduced',
              simplerEffects: mode == 'simple',
            ),
          );
          addTearDown(appearance.close);
          for (final size in [const Size(320, 480), const Size(740, 360)]) {
            await tester.pumpWidget(const SizedBox());
            tester.view.physicalSize = size;
            tester.view.padding = FakeViewPadding(
              top: 24,
              bottom: 16,
              left: 8,
              right: 8,
            );
            tester.view.viewInsets = FakeViewPadding(bottom: 100);
            tester.platformDispatcher.textScaleFactorTestValue = 3;
            await pumpApp(
              tester,
              repository: appearance,
              onboarding: FakeOnboardingRepository(completed: false),
            );
            final background = tester.widget<Image>(
              find.byKey(const ValueKey('onboarding-background')),
            );
            expect(
              ((background.image as ResizeImage).imageProvider as AssetImage)
                  .assetName,
              'assets/branding/ink-paper.webp',
            );
            await navigateChapter(tester, 1);
            await navigateChapter(tester, 1);
            expect(find.text('Backup'), findsOneWidget);
            expect(
              find.textContaining('Restore your journal from a backup'),
              findsOneWidget,
            );
            await navigateChapter(tester, -1);
            await _tap(tester, "Let's begin");
            await _name(tester, 'Test Writer');
            await reopenOnboardingBook(tester);
            await _tap(tester, "Let's begin");
            await _tap(tester, 'Save');
            expect(find.byType(OnboardingPage), findsNothing);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  for (final preference in [
    'reduceMotion',
    'simplerEffects',
    'OS',
    'inactive',
    'offscreen',
  ]) {
    testWidgets(
      'live $preference settles a page turn and disposal stops tickers',
      (tester) async {
        final preferences = FakeAppearanceRepository();
        addTearDown(preferences.close);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await pumpApp(
          tester,
          repository: preferences,
          onboarding: FakeOnboardingRepository(completed: false),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        if (preference == 'OS') {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(reduceMotion: true);
        } else if (preference == 'inactive') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        } else if (preference == 'offscreen') {
          Navigator.of(tester.element(find.byType(OnboardingPage))).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Covered route')),
            ),
          );
        } else {
          preferences.emit(
            AppearancePreferences(
              reduceMotion: preference == 'reduceMotion',
              simplerEffects: preference == 'simplerEffects',
            ),
          );
        }
        await tester.pumpAndSettle();
        if (preference != 'offscreen') {
          expect(chapterPosition(2), findsOneWidget);
          expect(
            tester
                .widget<Semantics>(
                  find.byKey(const ValueKey('onboarding-book-semantics')),
                )
                .properties
                .onIncrease,
            isNotNull,
          );
        }
        await tester.pumpWidget(const SizedBox());
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'live reduction completes an in-flight cover fold without saving a name',
    (tester) async {
      final preferences = FakeAppearanceRepository();
      addTearDown(preferences.close);
      final repository = FakeOnboardingRepository(completed: false);
      await pumpApp(tester, repository: preferences, onboarding: repository);
      await tester.tap(find.text("Let's begin"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      preferences.emit(const AppearancePreferences(reduceMotion: true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<OnboardingBook>(find.byType(OnboardingBook)).closing,
        1,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(repository.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
