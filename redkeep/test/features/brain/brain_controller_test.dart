import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/domain/local_inference.dart';
import 'package:redkeep/features/brain/application/brain_controller.dart';
import 'package:redkeep/features/brain/application/brain_providers.dart';
import 'package:redkeep/features/brain/domain/brain.dart';

import '../../support/fake_brain.dart';
import '../../support/fake_local_model.dart';

void main() {
  late ProviderContainer container;
  late FakeBrainAssignments assignments;
  late FakeBrainFiles files;
  late FakeModel model;
  late BrainController controller;
  setUp(() async {
    assignments = FakeBrainAssignments();
    files = FakeBrainFiles();
    model = FakeModel();
    container = ProviderContainer(
      overrides: [
        brainAssignmentsProvider.overrideWithValue(assignments),
        brainModelFilesProvider.overrideWith((ref) async => files),
        brainModelLoaderProvider.overrideWithValue((_, _) async => model),
      ],
    );
    container.listen(brainControllerProvider, (_, _) {});
    controller = container.read(brainControllerProvider.notifier);
    await flush();
  });
  tearDown(() => container.dispose());
  BrainState state() => container.read(brainControllerProvider);

  test('construction checks local readiness but never loads a model', () {
    expect(state().loaded, isTrue);
    expect(state().assignments, isEmpty);
    expect(state().files[qualifiedBrainModel.id], ModelFileState.available);
    expect(model.sessions, isEmpty);
    expect(model.closed, 0);
  });

  test('save feedback waits for commit, rejects overlap and failure keeps selection', () async {
    assignments.saving = Completer<void>();
    final saving = controller.assign(
      BrainCapability.rewrite,
      qualifiedBrainModel.id,
    );
    expect(state().busy, isTrue);
    expect(state().assignments, isEmpty);
    await controller.assign(BrainCapability.summarize, qualifiedBrainModel.id);
    assignments.saving!.complete();
    await saving;
    expect(state().assignments, {
      BrainCapability.rewrite: qualifiedBrainModel.id,
    });
    assignments.fail = true;
    await controller.assign(BrainCapability.rewrite, null);
    expect(state().failure, BrainFailure.storage);
    expect(
      state().assignments[BrainCapability.rewrite],
      qualifiedBrainModel.id,
    );
    assignments.fail = false;
    await controller.assign(BrainCapability.rewrite, null);
    expect(state().assignments, isEmpty);
  });

  test(
    'unknown and incompatible assignments are rejected before persistence',
    () async {
      await controller.assign(BrainCapability.rewrite, 'absent');
      expect(state().failure, BrainFailure.incompatible);
      container.updateOverrides([
        brainAssignmentsProvider.overrideWithValue(assignments),
        brainModelFilesProvider.overrideWith((ref) async => files),
        brainModelLoaderProvider.overrideWithValue((_, _) async => model),
      ]);
      expect(assignments.values, isEmpty);
      await controller.testAssignment(BrainCapability.rewrite);
      expect(state().failure, BrainFailure.unassigned);
      expect(model.sessions, isEmpty);
    },
  );

  test(
    'progress/cancel/retry and removal retain assignments without inference',
    () async {
      await controller.assign(BrainCapability.rewrite, qualifiedBrainModel.id);
      files.state = ModelFileState.missing;
      files.installing = Completer<void>();
      final installing = controller.install(qualifiedBrainModel.id);
      await flush();
      expect(state().received, 100);
      await controller.cancel();
      await installing;
      expect(state().failure, BrainFailure.cancelled);
      expect(state().files[qualifiedBrainModel.id], ModelFileState.missing);
      files.installing = null;
      await controller.install(qualifiedBrainModel.id);
      expect(state().files[qualifiedBrainModel.id], ModelFileState.available);
      await controller.remove(qualifiedBrainModel.id);
      expect(state().files[qualifiedBrainModel.id], ModelFileState.missing);
      expect(
        state().assignments[BrainCapability.rewrite],
        qualifiedBrainModel.id,
      );
      expect(model.closed, 0);
      expect(model.sessions, isEmpty);
    },
  );

  test('request detects replaced files and invalidates stale readiness; failed recheck can recover', () async {
    await controller.assign(BrainCapability.rewrite, qualifiedBrainModel.id);
    files.state = ModelFileState.corrupt;
    await controller.testAssignment(BrainCapability.rewrite);
    expect(state().failure, BrainFailure.integrity);
    expect(state().files[qualifiedBrainModel.id], ModelFileState.corrupt);
    expect(model.sessions, isEmpty);
    files.failure = BrainFailure.storage;
    await controller.refresh();
    expect(state().loaded, isFalse);
    expect(state().files, isEmpty);
    files.failure = null;
    files.state = ModelFileState.available;
    await controller.refresh();
    expect(state().loaded, isTrue);
    expect(state().failure, isNull);
  });

  test(
    'test streams synthetic output and commits success only after cleanup',
    () async {
      await controller.assign(BrainCapability.rewrite, qualifiedBrainModel.id);
      await controller.testAssignment(BrainCapability.rewrite);
      expect(state().output, 'one two');
      expect(state().testPassed, isTrue);
      expect(model.closed, 1);
    },
  );

  test('background cancels native work, preserves partial as incomplete, never resumes', () async {
    model.hold = true;
    await controller.assign(BrainCapability.rewrite, qualifiedBrainModel.id);
    final running = controller.testAssignment(BrainCapability.rewrite);
    await flush();
    expect(state().output, 'one');
    controller.setForeground(false);
    await running;
    expect(state().testPassed, isFalse);
    expect(state().failure, BrainFailure.cancelled);
    expect(model.closed, 1);
    controller.setForeground(true);
    await flush();
    expect(model.sessions.length, 1);
  });

  test('scope disposal cancels download without late updates', () async {
    files.installing = Completer<void>();
    final installing = controller.install(qualifiedBrainModel.id);
    await flush();
    container.dispose();
    await installing;
    // A second disposal is deliberately avoided in tearDown.
    container = ProviderContainer();
    expect(files.installs, 1);
  });

  test(
    'scope disposal during native load closes late model without session',
    () async {
      final loading = Completer<LocalModel>();
      container.updateOverrides([
        brainAssignmentsProvider.overrideWithValue(assignments),
        brainModelFilesProvider.overrideWith((ref) async => files),
        brainModelLoaderProvider.overrideWithValue((_, _) => loading.future),
      ]);
      await controller.assign(BrainCapability.rewrite, qualifiedBrainModel.id);
      final running = controller.testAssignment(BrainCapability.rewrite);
      await flush();
      container.dispose();
      container = ProviderContainer();
      loading.complete(model);
      await running;
      expect(model.sessions, isEmpty);
      expect(model.closed, 1);
    },
  );
}

Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
