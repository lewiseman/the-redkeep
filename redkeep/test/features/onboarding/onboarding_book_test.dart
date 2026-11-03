import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_book.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_page.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_controls.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/fake_required_assets.dart';
import '../../support/pump_app.dart';
import '../../support/onboarding_navigation.dart';

class _ObservingAssets extends FakeRequiredAssets {
  final resolved = <String>[];
  String? failedKey;
  Uri? brokenImage;
  @override
  Future<Uri> resolve(String key) async {
    resolved.add(key);
    if (key == failedKey) {
      if (brokenImage != null) return brokenImage!;
      throw const AssetException(AssetFailure.integrity);
    }
    return super.resolve(key);
  }
}

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
  testWidgets(
    'original open spread, manual boundaries/swipes and no autoplay',
    (tester) async {
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
        final size = tester.getSize(find.byType(OnboardingBook));
        expect((size.width - 12) / (size.height - 20), closeTo(4 / 3, .001));
        await tester.pump(const Duration(seconds: 30));
        expect(chapterPosition(1), findsOneWidget);
        final drag = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('onboarding-book'))),
        );
        await drag.moveBy(const Offset(-15, 0));
        await drag.cancel();
        await tester.pumpAndSettle();
        expect(chapterPosition(1), findsOneWidget);
        for (var chapter = 2; chapter <= 5; chapter++) {
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
        await navigateChapter(tester, -1);
        await tester.drag(
          find.byKey(const ValueKey('onboarding-book')),
          const Offset(180, 0),
        );
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel(
            RegExp('Grand Maester.*Models are downloaded separately'),
          ),
          findsOneWidget,
        );
        await tester.drag(
          find.byKey(const ValueKey('onboarding-book')),
          const Offset(-180, 0),
        );
        await tester.pumpAndSettle();
        expect(chapterPosition(4), findsOneWidget);
        expect(repository.saves, 0);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
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

  testWidgets(
    'only current and turning neighbor decode; full leaf artwork is bounded and accessible',
    (tester) async {
      final assets = _ObservingAssets();
      await pumpApp(
        tester,
        onboarding: FakeOnboardingRepository(completed: false),
        assets: assets,
      );
      await _decodeVisible(tester);
      expect(assets.resolved.toSet(), {
        'onboarding.material.paper',
        'onboarding.material.binding',
        'onboarding.chapter.notes',
      });
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        if (image.key == const ValueKey('onboarding-mascot')) {
          expect(image.image, isA<ResizeImage>());
          final resized = image.image as ResizeImage;
          expect(resized.imageProvider, isA<AssetImage>());
          expect(
            (resized.imageProvider as AssetImage).assetName,
            'assets/branding/grand_maestar.png',
          );
          expect(image.height, lessThanOrEqualTo(100));
          expect(
            resized.height,
            inInclusiveRange(1, (100 * tester.view.devicePixelRatio).ceil()),
          );
        } else if (image.key == const ValueKey('onboarding-background')) {
          final resized = image.image as ResizeImage;
          expect(resized.width, 1024);
          expect(
            (resized.imageProvider as AssetImage).assetName,
            'assets/branding/ink-paper.webp',
          );
        } else {
          expect(image.image, isA<ResizeImage>());
          final resized = image.image as ResizeImage;
          expect(resized.width, inInclusiveRange(1, 1448));
          expect(resized.imageProvider, isA<FileImage>());
        }
      }
      final before = assets.resolved.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(assets.resolved.skip(before).toSet(), {
        'onboarding.chapter.diary',
      });
      await tester.pumpAndSettle();
      await _decodeVisible(tester);
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
            final assets = _ObservingAssets();
            await pumpApp(
              tester,
              repository: appearance,
              onboarding: FakeOnboardingRepository(completed: false),
              assets: assets,
            );
            final background = tester.widget<Image>(
              find.byKey(const ValueKey('onboarding-background')),
            );
            expect(
              ((background.image as ResizeImage).imageProvider as AssetImage)
                  .assetName,
              'assets/branding/ink-paper.webp',
            );
            expect(
              assets.resolved,
              isNot(contains('onboarding.background.ink')),
            );
            await navigateChapter(tester, 1);
            await navigateChapter(tester, 1);
            expect(find.text('Grand Maester'), findsOneWidget);
            expect(
              find.textContaining('Models are downloaded separately'),
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

  testWidgets(
    'both themes retain the original facing-page geometry; simpler mode is flat',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(const SizedBox());
        final preferences = FakeAppearanceRepository(
          AppearancePreferences(theme: theme, simplerEffects: true),
        );
        addTearDown(preferences.close);
        await pumpApp(
          tester,
          repository: preferences,
          onboarding: FakeOnboardingRepository(completed: false),
        );
        expect(
          tester.widget<OnboardingBook>(find.byType(OnboardingBook)).simple,
          true,
        );
        final size = tester.getSize(find.byType(OnboardingBook));
        expect((size.width - 12) / (size.height - 20), closeTo(4 / 3, .001));
        await navigateChapter(tester, 1);
        expect(chapterPosition(2), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

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
  for (final key in [
    'onboarding.material.paper',
    'onboarding.material.binding',
  ]) {
    testWidgets('$key decoder failure closes entry safely', (tester) async {
      final temp = Directory.systemTemp.createTempSync(
        'redkeep-texture-corrupt-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final file = File('${temp.path}/texture.webp')
        ..writeAsBytesSync([1, 2, 3]);
      final assets = _ObservingAssets()
        ..failedKey = key
        ..brokenImage = file.uri;
      final router = await pumpApp(
        tester,
        onboarding: FakeOnboardingRepository(completed: false),
        assets: assets,
        initialLocation: '/settings',
      );
      await _decodeVisible(tester);
      expect(find.text('Retry local checks'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['continue'],
        '/settings',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'cover preload failure uses repair without an unhandled error or saved name',
    (tester) async {
      final assets = _ObservingAssets()..failedKey = 'onboarding.cover';
      final repository = FakeOnboardingRepository(completed: false);
      final router = await pumpApp(
        tester,
        onboarding: repository,
        assets: assets,
        initialLocation: '/settings',
      );
      await _tap(tester, "Let's begin");
      expect(find.text('Retry local checks'), findsOneWidget);
      expect(repository.saves, 0);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['continue'],
        '/settings',
      );
      expect(tester.takeException(), isNull);
    },
  );

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
  for (final corrupt in [false, true]) {
    testWidgets(
      '${corrupt ? 'decoder error' : 'missing image'} preserves continuation through repair',
      (tester) async {
        final assets = _ObservingAssets()
          ..failedKey = 'onboarding.chapter.notes';
        if (corrupt) {
          final temp = Directory.systemTemp.createTempSync(
            'redkeep-widget-corrupt-',
          );
          addTearDown(() => temp.deleteSync(recursive: true));
          final file = File('${temp.path}/notes.webp')
            ..writeAsBytesSync([1, 2, 3]);
          assets.brokenImage = file.uri;
        }
        final repository = FakeOnboardingRepository(completed: false);
        final router = await pumpApp(
          tester,
          onboarding: repository,
          assets: assets,
          initialLocation: '/settings',
        );
        if (corrupt) await _decodeVisible(tester);
        expect(find.text('Retry local checks'), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.queryParameters['continue'],
          '/settings',
        );
        expect(repository.completed, false);
        assets.failedKey = null;
        await _tap(tester, 'Retry local checks');
        expect(find.byType(OnboardingPage), findsOneWidget);
        await _decodeVisible(tester);
        expect(repository.saves, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
