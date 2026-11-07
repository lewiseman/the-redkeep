import 'package:redkeep/features/ai/presentation/ai_settings_page.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/appearance/presentation/appearance_page.dart';
import 'package:redkeep/features/assets/presentation/local_artwork.dart';
import 'package:redkeep/features/more/presentation/more_index_entry.dart';
import 'package:redkeep/features/sync/presentation/sync_card.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_ai_provider.dart';
import '../../support/pump_app.dart';

void main() {
  Finder appearanceArtwork() => find.byWidgetPredicate(
    (widget) => widget is LocalArtwork && widget.assetKey == 'more.appearance',
  );

  testWidgets('More opens both existing settings destinations and returns', (
    tester,
  ) async {
    final aiProvider = FakeAiProviderClient();
    final router = await pumpApp(
      tester,
      initialLocation: '/more',
      aiProvider: aiProvider,
    );
    expect(find.text('Friends'), findsNothing);
    expect(find.text('Local QVAC'), findsNothing);
    expect(find.text('Brain'), findsNothing);
    expect(find.text('Colors, theme and fonts'), findsOneWidget);
    expect(find.byType(SyncAccountCard), findsNothing);
    expect(aiProvider.requests, isEmpty);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.byType(AppearancePage), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grand Maestar'));
    await tester.pumpAndSettle();
    expect(find.byType(AiSettingsPage), findsOneWidget);
    expect(find.text('Phone'), findsNothing);
    expect(aiProvider.requests, isEmpty);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Grand Maestar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Appearance resolves local downloaded art; Grand Maestar uses bundled branding',
    (tester) async {
      await pumpApp(tester, initialLocation: '/more');
      final artwork = tester.widget<LocalArtwork>(appearanceArtwork());
      expect(artwork.assetKey, 'more.appearance');
      final appearance = tester.widget<Image>(
        find.descendant(of: appearanceArtwork(), matching: find.byType(Image)),
      );
      final local =
          (appearance.image as ResizeImage).imageProvider as FileImage;
      expect(local.file.uri.scheme, 'file');
      expect(
        local.file.readAsBytesSync(),
        File('../website/public/art/more_appearance.png').readAsBytesSync(),
      );
      final branding = tester.widget<Image>(
        find.byWidgetPredicate((widget) {
          if (widget is! Image || widget.image is! ResizeImage) return false;
          final source = (widget.image as ResizeImage).imageProvider;
          return source is AssetImage &&
              source.assetName == 'assets/branding/grand_maestar.png';
        }),
      );
      expect(branding.fit, BoxFit.contain);
      expect(branding.excludeFromSemantics, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final layout in [
      (width: 390.0, scale: 1.0, reduced: false, simple: false),
      (width: 320.0, scale: 1.0, reduced: false, simple: true),
      (width: 280.0, scale: 1.0, reduced: true, simple: false),
      (width: 320.0, scale: 3.0, reduced: true, simple: true),
    ]) {
      testWidgets('More fits $theme $layout and both entries remain usable', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(layout.width, 640);
        tester.platformDispatcher.textScaleFactorTestValue = layout.scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final preferences = FakeAppearanceRepository(
          AppearancePreferences(
            theme: theme,
            reduceMotion: layout.reduced,
            simplerEffects: layout.simple,
          ),
        );
        addTearDown(preferences.close);
        final router = await pumpApp(
          tester,
          initialLocation: '/more',
          repository: preferences,
        );
        final showArtwork = layout.width - 56 >= 250 && layout.scale * 14 <= 20;
        expect(
          appearanceArtwork(),
          showArtwork ? findsOneWidget : findsNothing,
        );
        final paints = tester.widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(MoreIndexEntry),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(
          paints.where((paint) => paint.painter != null).length,
          showArtwork && !layout.simple && !layout.reduced ? 2 : 0,
        );
        for (final label in ['Appearance', 'Grand Maestar']) {
          final entry = find.text(label);
          await tester.ensureVisible(entry);
          await tester.pumpAndSettle();
          expect(entry.hitTestable(), findsOneWidget);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          expect(
            label == 'Appearance'
                ? find.byType(AppearancePage)
                : find.byType(AiSettingsPage),
            findsOneWidget,
          );
          router.pop();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
