import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/paper_surface.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/appearance/presentation/appearance_page.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets(
    'route fades become immediate when reduction changes mid-transition',
    (tester) async {
      final repository = FakeAppearanceRepository();
      addTearDown(repository.close);
      final router = await pumpApp(tester, repository: repository);
      router.go('/settings');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final fades = find.ancestor(
        of: find.byType(AppearancePage),
        matching: find.byType(FadeTransition),
      );
      expect(fades, findsWidgets);
      expect(
        tester
            .widgetList<FadeTransition>(fades)
            .any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
        isTrue,
      );
      repository.emit(const AppearancePreferences(reduceMotion: true));
      await tester.pump();
      expect(fades, findsNothing);
      expect(find.byType(AppearancePage), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pump();
      await tester.pump();
      expect(find.text('My diary'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home opens settings; theme, motion and effects apply live and back works',
    (tester) async {
      final repository = FakeAppearanceRepository();
      addTearDown(repository.close);
      final router = await pumpApp(tester, repository: repository);
      await tester.tap(find.bySemanticsLabel('More tab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(find.byType(AppearancePage), findsOneWidget);
      expect(router.canPop(), isTrue);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      var context = tester.element(find.byType(AppearancePage));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(repository.value.theme, AppTheme.dark);

      final motion = find.widgetWithText(SwitchListTile, 'Reduce motion');
      await tester.ensureVisible(motion);
      await tester.tap(motion);
      await tester.pumpAndSettle();
      context = tester.element(find.byType(AppearancePage));
      expect(RenderingPolicyScope.of(context).reducedMotion, isTrue);
      expect(find.text('Flat paper is active.'), findsOneWidget);
      expect(repository.value.reduceMotion, isTrue);

      // An independent repository update also reaches the visible UI immediately.
      repository.emit(
        const AppearancePreferences(
          theme: AppTheme.light,
          simplerEffects: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(Theme.of(context).brightness, Brightness.light);
      expect(RenderingPolicyScope.of(context).reducedMotion, isFalse);
      expect(RenderingPolicyScope.of(context).simplerEffects, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('My diary'), findsOneWidget);
    },
  );

  testWidgets(
    'system theme and OS motion flags change while settings are open',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpApp(tester, initialLocation: '/settings');
      final context = tester.element(find.byType(AppearancePage));
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(reduceMotion: true);
      await tester.pumpAndSettle();
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(find.text('Motion is reduced by your device.'), findsOneWidget);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures();
      await tester.pumpAndSettle();
      expect(Theme.of(context).brightness, Brightness.light);
      expect(RenderingPolicyScope.of(context).reducedMotion, isFalse);
    },
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      '$theme settings remain reachable at 320px, 3x text, keyboard and safe areas',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(top: 24, bottom: 16);
        tester.view.viewInsets = FakeViewPadding(bottom: 180);
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final repository = FakeAppearanceRepository(
          AppearancePreferences(theme: theme),
        );
        addTearDown(repository.close);
        await pumpApp(
          tester,
          initialLocation: '/settings',
          repository: repository,
        );
        expect(tester.takeException(), isNull);
        final effects = find.widgetWithText(SwitchListTile, 'Simpler effects');
        // Scroll the actual switch into the keyboard-constrained viewport.
        final toggle = find.descendant(
          of: effects,
          matching: find.byType(Switch),
        );
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(repository.value.simplerEffects, isTrue);
        expect(tester.getBottomRight(toggle).dy, lessThanOrEqualTo(300));
        expect(tester.getTopLeft(toggle).dy, greaterThanOrEqualTo(24));
        await tester.ensureVisible(find.text('Light'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'loading failure retries; save failure stays visible and retains committed choices',
    (tester) async {
      final repository = FakeAppearanceRepository()..failRead = true;
      addTearDown(repository.close);
      await pumpApp(
        tester,
        initialLocation: '/settings',
        repository: repository,
      );
      expect(find.text('Retry local checks'), findsOneWidget);
      repository.failRead = false;
      await tester.tap(find.text('Retry local checks'));
      await tester.pumpAndSettle();
      repository.failSave = true;
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your change could not be saved.'),
        findsOneWidget,
      );
      expect(repository.value.theme, AppTheme.system);
      repository.failSave = false;
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(repository.value.theme, AppTheme.dark);
      expect(
        find.textContaining('Your change could not be saved.'),
        findsNothing,
      );
    },
  );

  testWidgets('paper shadow disappears live under simpler effects', (
    tester,
  ) async {
    final repository = FakeAppearanceRepository();
    addTearDown(repository.close);
    await pumpApp(tester, repository: repository);
    BoxDecoration decoration() =>
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(PaperSurface),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(decoration().boxShadow, isNotEmpty);
    repository.emit(const AppearancePreferences(simplerEffects: true));
    await tester.pumpAndSettle();
    expect(decoration().boxShadow, isEmpty);
  });

  test('light and dark paper retain readable text and control contrast', () {
    double contrast(Color a, Color b) {
      final values = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (values.last + 0.05) / (values.first + 0.05);
    }

    for (final theme in [RedkeepTheme.light, RedkeepTheme.dark]) {
      final paper = theme.extension<PaperColors>()!.sheet;
      expect(
        contrast(theme.colorScheme.onSurface, paper),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(theme.colorScheme.onSurfaceVariant, paper),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(theme.colorScheme.primary, paper),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(theme.colorScheme.outline, paper),
        greaterThanOrEqualTo(3),
      );
      expect(theme.textTheme.bodyLarge!.fontSize, 18);
    }
  });
}
