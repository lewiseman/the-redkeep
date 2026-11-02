import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/features/appearance/application/appearance_controller.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';

import '../../support/fake_appearance_repository.dart';

void main() {
  ProviderContainer containerFor(FakeAppearanceRepository repository) {
    addTearDown(repository.close);
    final container = ProviderContainer.test(
      overrides: [appearanceRepositoryProvider.overrideWithValue(repository)],
    );
    container.listen(appearanceControllerProvider, (_, _) {});
    return container;
  }

  test(
    'controller loads, follows repository changes, and isolates scopes',
    () async {
      final repository = FakeAppearanceRepository();
      final first = containerFor(repository);
      final second = containerFor(FakeAppearanceRepository());
      expect(first.read(appearanceControllerProvider).loaded, isFalse);
      second.read(appearanceControllerProvider);
      await first.pump();
      await second.pump();
      expect(first.read(appearanceControllerProvider).loaded, isTrue);
      repository.emit(const AppearancePreferences(theme: AppTheme.dark));
      await first.pump();
      expect(
        first.read(appearanceControllerProvider).preferences.theme,
        AppTheme.dark,
      );
      expect(
        second.read(appearanceControllerProvider).preferences.theme,
        AppTheme.system,
      );
    },
  );

  test(
    'saves reflect commits, reject overlapping edits and recover after failure',
    () async {
      final repository = FakeAppearanceRepository();
      final container = containerFor(repository);
      final controller = container.read(appearanceControllerProvider.notifier);
      await container.pump();
      repository.saveGate = Completer<void>();
      final save = controller.setTheme(AppTheme.dark);
      expect(container.read(appearanceControllerProvider).saving, isTrue);
      expect(
        container.read(appearanceControllerProvider).preferences.theme,
        AppTheme.system,
      );
      await controller.setReduceMotion(true);
      expect(repository.saveCount, 1);
      repository.saveGate!.complete();
      await save;
      await container.pump();
      expect(
        container.read(appearanceControllerProvider).preferences.theme,
        AppTheme.dark,
      );

      repository.failSave = true;
      await controller.setReduceMotion(true);
      expect(container.read(appearanceControllerProvider).saveFailed, isTrue);
      expect(
        container.read(appearanceControllerProvider).preferences.reduceMotion,
        isFalse,
      );
      repository.failSave = false;
      await controller.setReduceMotion(true);
      await container.pump();
      expect(
        container.read(appearanceControllerProvider).preferences.reduceMotion,
        isTrue,
      );
      expect(container.read(appearanceControllerProvider).saveFailed, isFalse);
    },
  );

  test(
    'read failure disables writes and can retry without replacing saved data',
    () async {
      final repository = FakeAppearanceRepository(
        const AppearancePreferences(theme: AppTheme.light),
      )..failRead = true;
      final container = containerFor(repository);
      final controller = container.read(appearanceControllerProvider.notifier);
      await container.pump();
      expect(container.read(appearanceControllerProvider).loadError, isTrue);
      await controller.setTheme(AppTheme.dark);
      expect(repository.saveCount, 0);
      repository.failRead = false;
      final reloaded = Completer<void>();
      final subscription = container.listen(appearanceControllerProvider, (
        _,
        next,
      ) {
        if (next.canEdit && !reloaded.isCompleted) reloaded.complete();
      });
      controller.retryLoading();
      await reloaded.future;
      subscription.close();
      expect(container.read(appearanceControllerProvider).canEdit, isTrue);
      expect(
        container.read(appearanceControllerProvider).preferences.theme,
        AppTheme.light,
      );
    },
  );

  test('disposal during a pending save has no late state update', () async {
    final repository = FakeAppearanceRepository()..saveGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [appearanceRepositoryProvider.overrideWithValue(repository)],
    );
    final controller = container.read(appearanceControllerProvider.notifier);
    await container.pump();
    final save = controller.setSimplerEffects(true);
    container.dispose();
    repository.saveGate!.complete();
    await save;
    await repository.close();
  });
}
