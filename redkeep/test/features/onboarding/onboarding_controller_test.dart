import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/features/onboarding/application/onboarding_controller.dart';

import '../../support/fake_onboarding_repository.dart';

void main() {
  ProviderContainer scope(FakeOnboardingRepository repository) =>
      ProviderContainer.test(
        overrides: [onboardingRepositoryProvider.overrideWithValue(repository)],
      );

  test('blank names never save; names trim and loading cannot replace a pending save', () async {
    final repository = FakeOnboardingRepository(completed: false);
    final container = scope(repository);
    final controller = container.read(onboardingControllerProvider.notifier);
    await controller.load();
    await controller.complete('   ');
    expect(repository.saves, 0);
    expect(container.read(onboardingControllerProvider).nameInvalid, true);
    repository.saveGate = Completer<void>();
    final save = controller.complete('  Léa 王  ');
    await controller.load();
    expect(container.read(onboardingControllerProvider).saving, true);
    expect(container.read(onboardingControllerProvider).complete, false);
    repository.saveGate!.complete();
    await save;
    expect(repository.savedName, 'Léa 王');
    expect(container.read(onboardingControllerProvider).name, 'Léa 王');
  });

  test(
    'completion waits for commit, serializes and retains incomplete on failure',
    () async {
      final repository = FakeOnboardingRepository(completed: false)
        ..saveGate = Completer<void>();
      final container = scope(repository);
      final controller = container.read(onboardingControllerProvider.notifier);
      await controller.complete('Test Writer');
      expect(repository.saves, 0);
      await controller.load();
      final save = controller.complete('Test Writer');
      await controller.complete('Test Writer');
      expect(repository.saves, 1);
      expect(container.read(onboardingControllerProvider).complete, isFalse);
      expect(container.read(onboardingControllerProvider).saving, isTrue);
      repository.failSave = true;
      repository.saveGate!.complete();
      await save;
      expect(repository.completed, isFalse);
      expect(container.read(onboardingControllerProvider).saveFailed, isTrue);
      repository.failSave = false;
      await controller.complete('Test Writer');
      expect(container.read(onboardingControllerProvider).complete, isTrue);
      await controller.complete('Test Writer');
      expect(repository.saves, 2);
    },
  );

  test('scopes are isolated; disposal ignores late reads and saves', () async {
    final firstRepository = FakeOnboardingRepository(completed: false);
    final first = scope(firstRepository);
    final second = scope(FakeOnboardingRepository());
    await first.read(onboardingControllerProvider.notifier).load();
    await second.read(onboardingControllerProvider.notifier).load();
    expect(first.read(onboardingControllerProvider).complete, isFalse);
    expect(second.read(onboardingControllerProvider).complete, isTrue);
    firstRepository.saveGate = Completer<void>();
    final saving = first
        .read(onboardingControllerProvider.notifier)
        .complete('Test Writer');
    first.dispose();
    firstRepository.saveGate!.complete();
    await saving;
    final delayed = FakeOnboardingRepository()..readGate = Completer<void>();
    final third = scope(delayed);
    final loading = third.read(onboardingControllerProvider.notifier).load();
    third.dispose();
    delayed.readGate!.complete();
    await loading;
  });
}
