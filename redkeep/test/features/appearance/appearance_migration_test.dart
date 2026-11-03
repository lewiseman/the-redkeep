import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bottom_navbar.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/presentation/diary_typography.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/features/appearance/application/appearance_controller.dart';
import 'package:redkeep/features/appearance/application/appearance_typography.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/appearance/presentation/appearance_page.dart';

import '../../support/fake_appearance_fonts.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';

void main() {
  test(
    'every legacy accent generates the same global light and dark palette',
    () {
      for (final accent in AppAccent.values) {
        for (final brightness in Brightness.values) {
          final theme = RedkeepTheme.forAppearance(brightness, accent);
          final generated = ColorScheme.fromSeed(
            seedColor: accent.seed,
            brightness: brightness,
          );
          final primary = brightness == Brightness.dark
              ? accent.darkPrimary
              : accent.seed;
          expect(
            theme.colorScheme,
            generated.copyWith(
              primary: primary,
              primaryContainer: Color.alphaBlend(
                primary.withValues(
                  alpha: brightness == Brightness.dark ? .18 : .10,
                ),
                generated.surface,
              ),
              onPrimaryContainer: generated.onSurface,
            ),
          );
          expect(theme.scaffoldBackgroundColor, generated.surface);
          expect(theme.extension<PaperColors>()!.sheet, generated.surface);
        }
      }
    },
  );

  test('fonts load before saving, failed loads and saves keep committed choices, retry works', () async {
    final repository = FakeAppearanceRepository();
    addTearDown(repository.close);
    Completer<ResolvedFont>? gate;
    var fail = false;
    final container = ProviderContainer.test(
      overrides: [
        appearanceRepositoryProvider.overrideWithValue(repository),
        appearanceFontLoaderProvider.overrideWithValue((family, role) async {
          if (fail) throw StateError('offline');
          return gate?.future ?? fakeAppearanceFontLoader(family, role);
        }),
      ],
    );
    container.listen(appearanceControllerProvider, (_, _) {});
    await container.pump();
    final controller = container.read(appearanceControllerProvider.notifier);
    gate = Completer<ResolvedFont>();
    final saving = controller.setFontFamily('Lora', FontRole.journal);
    expect(repository.saveCount, 0);
    expect(repository.value.fontFamily, 'Poppins');
    await controller.setAccent(AppAccent.teal);
    expect(repository.saveCount, 0);
    gate.complete(await fakeAppearanceFontLoader('Lora', FontRole.journal));
    await saving;
    expect(repository.value.fontFamily, 'Lora');
    gate = null;
    fail = true;
    await expectLater(
      controller.setFontFamily('Caveat', FontRole.diaryTitle),
      throwsStateError,
    );
    expect(repository.value.diaryTitleFontFamily, 'Caveat');
    expect(repository.saveCount, 1);
    fail = false;
    repository.failSave = true;
    await expectLater(
      controller.setFontFamily('Poppins', FontRole.diaryTitle),
      throwsStateError,
    );
    expect(repository.value.diaryTitleFontFamily, 'Caveat');
    repository.failSave = false;
    await controller.setFontFamily('Poppins', FontRole.diaryTitle);
    await controller.setFontFamily('Caveat', FontRole.diaryBody);
    await controller.setAccent(AppAccent.plum);
    expect(repository.value.fontFamily, 'Lora');
    expect(repository.value.diaryTitleFontFamily, 'Poppins');
    expect(repository.value.diaryBodyFontFamily, 'Caveat');
    expect(repository.value.accent, AppAccent.plum);
    await expectLater(
      controller.setFontFamily('missing-family', FontRole.journal),
      throwsArgumentError,
    );
  });

  testWidgets(
    'accent picker and searchable font picker update all destinations',
    (tester) async {
      final repository = FakeAppearanceRepository();
      addTearDown(repository.close);
      final router = await pumpApp(
        tester,
        initialLocation: '/settings',
        repository: repository,
      );
      await tester.ensureVisible(find.text('Teal'));
      await tester.tap(find.text('Teal'));
      await tester.pumpAndSettle();
      expect(repository.value.accent, AppAccent.teal);
      await tester.ensureVisible(find.text('Journal font'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Journal font'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'no-such-font-123');
      await tester.pumpAndSettle();
      expect(find.text('No fonts found'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Lora');
      await tester.pumpAndSettle();
      final option = find.widgetWithText(ListTile, 'Lora').last;
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(repository.value.fontFamily, 'Lora');
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      for (final path in ['/diary', '/notes', '/flow', '/more', '/settings']) {
        router.go(path);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(RedkeepBottomNavbar));
        expect(Theme.of(context).colorScheme.primary, AppAccent.teal.seed);
        expect(Theme.of(context).textTheme.bodyMedium!.fontFamily, 'Lora');
        expect(DiaryTypography.of(context).title.fontFamily, 'Caveat');
        expect(DiaryTypography.of(context).body.fontFamily, 'Lora');
      }
      repository.emit(repository.value.copyWith(theme: AppTheme.dark));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppearancePage)))
            .colorScheme
            .primary,
        AppAccent.teal.darkPrimary,
      );
    },
  );

  testWidgets(
    'font picker reports failure and retains the previous selection',
    (tester) async {
      final repository = FakeAppearanceRepository();
      addTearDown(repository.close);
      var fail = false;
      await pumpApp(
        tester,
        initialLocation: '/settings',
        repository: repository,
        fontLoader: (family, role) async {
          if (fail) throw StateError('offline');
          return fakeAppearanceFontLoader(family, role);
        },
      );
      await tester.ensureVisible(find.text('Journal font'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Journal font'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Lora');
      await tester.pumpAndSettle();
      fail = true;
      await tester.tap(find.widgetWithText(ListTile, 'Lora').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This font couldn’t be loaded or saved.'),
        findsOneWidget,
      );
      expect(repository.value.fontFamily, 'Poppins');
      fail = false;
      await tester.tap(find.widgetWithText(ListTile, 'Lora').last);
      await tester.pumpAndSettle();
      expect(repository.value.fontFamily, 'Lora');
    },
  );

  testWidgets(
    'bottom navigation stays accessible at 320px and 3x text with reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(bottom: 16);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final repository = FakeAppearanceRepository(
        const AppearancePreferences(reduceMotion: true),
      );
      addTearDown(repository.close);
      final router = await pumpApp(
        tester,
        initialLocation: '/settings',
        repository: repository,
      );
      final bar = find.byType(RedkeepBottomNavbar);
      for (final label in ['Diary', 'More']) {
        await tester.tap(find.bySemanticsLabel('$label tab'));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/${label.toLowerCase()}',
        );
        expect(tester.takeException(), isNull);
      }
      for (final scale in tester.widgetList<AnimatedScale>(
        find.descendant(of: bar, matching: find.byType(AnimatedScale)),
      )) {
        expect(scale.duration, Duration.zero);
      }
      tester.view.viewInsets = FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      expect(bar, findsNothing);
    },
  );
  testWidgets(
    'font picker remains scrollable with 3x text and a keyboard at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final repository = FakeAppearanceRepository();
      addTearDown(repository.close);
      await pumpApp(
        tester,
        initialLocation: '/settings',
        repository: repository,
      );
      await tester.ensureVisible(find.text('Journal font'));
      await tester.pumpAndSettle();
      // At this scale the label spans more than the viewport; activate its visible first line.
      final title = tester.getRect(find.text('Journal font'));
      await tester.tapAt(Offset(title.center.dx, title.top + 12));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      await tester.enterText(search, 'Lora');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final sheet = find.byType(CustomScrollView);
      final option = find.descendant(
        of: sheet,
        matching: find.widgetWithText(ListTile, 'Lora'),
      );
      await tester.scrollUntilVisible(
        option,
        100,
        scrollable: find
            .descendant(of: sheet, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(repository.value.fontFamily, 'Lora');
      expect(tester.takeException(), isNull);
    },
  );
}
