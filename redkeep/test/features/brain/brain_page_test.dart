import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/brain/application/brain_controller.dart';
import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/brain/presentation/brain_page.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:drift/native.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_brain.dart';
import '../../support/fake_local_model.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/pump_app.dart';

void main() {
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Brain continuation crosses onboarding, assigns, tests and removes without clearing assignment',
    (tester) async {
      final assignments = FakeBrainAssignments();
      final files = FakeBrainFiles();
      final model = FakeModel();
      final router = await pumpApp(
        tester,
        initialLocation: '/settings/brain',
        onboarding: FakeOnboardingRepository(completed: false),
        brainAssignments: assignments,
        brainFiles: files,
        brainLoader: (_, _) async => model,
      );
      expect(router.routeInformationProvider.value.uri.path, '/onboarding');
      await tap(tester, find.text('Enter Redkeep'));
      expect(find.byType(BrainPage), findsOneWidget);
      expect(model.sessions, isEmpty);
      await tap(tester, find.text('Assign ${qualifiedBrainModel.label}').first);
      expect(
        assignments.values[BrainCapability.rewrite],
        qualifiedBrainModel.id,
      );
      await tap(tester, find.text('Test rewriting'));
      expect(model.closed, 1);
      expect(
        find.text('Synthetic test finished · Model released'),
        findsOneWidget,
      );
      await tap(tester, find.text('Remove model'));
      await tap(tester, find.text('Keep model'));
      expect(files.removes, 0);
      await tap(tester, find.text('Remove model'));
      await tap(tester, find.text('Remove model files'));
      expect(files.removes, 1);
      expect(
        assignments.values[BrainCapability.rewrite],
        qualifiedBrainModel.id,
      );
      expect(find.text('Not installed'), findsOneWidget);
      router.go('/more');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Brain'));
      expect(find.byType(BrainPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final simple in [false, true]) {
      testWidgets(
        'Brain and removal dialog at 320px/3x/safe/keyboard $theme simpler=$simple',
        (tester) async {
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 3;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final appearance = FakeAppearanceRepository(
            AppearancePreferences(
              theme: theme,
              reduceMotion: simple,
              simplerEffects: simple,
            ),
          );
          addTearDown(appearance.close);
          final assignments = FakeBrainAssignments()
            ..values[BrainCapability.rewrite] = qualifiedBrainModel.id;
          final files = FakeBrainFiles();
          final model = FakeModel();
          await pumpApp(
            tester,
            initialLocation: '/settings/brain',
            repository: appearance,
            brainAssignments: assignments,
            brainFiles: files,
            brainLoader: (_, _) async => model,
          );
          expect(tester.takeException(), isNull);
          for (final label in [
            'Remove model',
            'Clear rewriting',
            'Test rewriting',
            'Assign ${qualifiedBrainModel.label}',
          ]) {
            final finder = find.text(label).first;
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (label == 'Remove model') {
              await tap(tester, finder);
              await tap(tester, find.text('Keep model'));
              expect(tester.takeException(), isNull);
            }
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets('leaving Brain cancels active native work and late output', (
    tester,
  ) async {
    final model = FakeModel()..hold = true;
    final assignments = FakeBrainAssignments()
      ..values[BrainCapability.rewrite] = qualifiedBrainModel.id;
    final router = await pumpApp(
      tester,
      initialLocation: '/settings/brain',
      brainAssignments: assignments,
      brainFiles: FakeBrainFiles(),
      brainLoader: (_, _) async => model,
    );
    await tap(tester, find.text('Test rewriting'));
    router.go('/more');
    await tester.pumpAndSettle();
    expect(model.sessions.single.stopped, 1);
    expect(model.closed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('normal Flow writing never opens Brain storage or a model', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final files = FakeBrainFiles()..failure = BrainFailure.storage;
    final model = FakeModel();
    await pumpApp(
      tester,
      initialLocation: '/flow',
      flow: DriftFlowRepository(database, clock: () => DateTime.utc(2026)),
      flowId: () => 'a' * 32,
      brainAssignments: FakeBrainAssignments(),
      brainFiles: files,
      brainLoader: (_, _) async => model,
    );
    await tester.enterText(
      find.byKey(const ValueKey('flow-body')),
      'Writing without AI',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Capture thought'));
    expect(files.checks, 0);
    expect(model.sessions, isEmpty);
    expect(tester.container().exists(brainControllerProvider), isFalse);
    expect(
      (await database.select(database.flowThoughts).get()).single.body,
      'Writing without AI',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await database.close();
  });
}
