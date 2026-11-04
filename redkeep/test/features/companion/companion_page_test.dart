import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/voice/application/phone_voice.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';

class _Voice implements GuideVoice {
  int spoken = 0, stopped = 0;
  @override
  Future<void> speak(String text) async {
    spoken++;
  }

  @override
  Future<void> stop() async {
    stopped++;
  }
}

void main() {
  Future<void> tap(WidgetTester tester, Finder control) async {
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  testWidgets('hub and preferences fit 320px, 3x text and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final appearance = FakeAppearanceRepository(
      const AppearancePreferences(simplerEffects: true),
    );
    addTearDown(appearance.close);
    final router = await pumpApp(
      tester,
      initialLocation: '/settings/brain',
      repository: appearance,
    );
    expect(tester.takeException(), isNull);
    await tap(tester, find.byKey(const ValueKey('ai-mode-companion')));
    await tap(tester, find.text('Advanced'));
    expect(find.text('Follow choice above'), findsWidgets);
    expect(tester.takeException(), isNull);
    router.push('/settings/brain/preferences');
    await tester.pumpAndSettle();
    await tap(tester, find.byType(Switch).first);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'requested setup narration stops when opening a child route and leaving',
    (tester) async {
      final voice = _Voice();
      final router = await pumpApp(
        tester,
        initialLocation: '/settings/brain',
        guideVoice: voice,
      );
      await tap(tester, find.byKey(const ValueKey('ai-mode-companion')));
      await tap(tester, find.text('Hear setup guide'));
      expect(voice.spoken, 1);
      router.push('/settings/brain/help');
      await tester.pumpAndSettle();
      expect(voice.stopped, greaterThan(0));
      final before = voice.stopped;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(voice.stopped, greaterThan(before));
    },
  );
}
