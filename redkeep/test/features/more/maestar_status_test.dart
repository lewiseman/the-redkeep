import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/brain/application/brain_controller.dart';
import 'package:redkeep/features/brain/application/brain_providers.dart';
import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/more/application/maestar_status.dart';

class _SnapshotBrain extends BrainController {
  _SnapshotBrain(this.snapshot);
  final BrainState snapshot;
  @override
  BrainState build() => snapshot;
}

void main() {
  final assigned = {BrainCapability.rewrite: qualifiedBrainModel.id};
  final verified = {qualifiedBrainModel.id: ModelFileState.available};
  for (final scenario in [
    (state: const BrainState(), label: 'Checking model files…', ready: false),
    (
      state: const BrainState(
        busy: true,
        operation: 'Downloading optional model',
      ),
      label: 'Downloading optional model',
      ready: false,
    ),
    (
      state: const BrainState(failure: BrainFailure.storage),
      label: 'Needs attention',
      ready: false,
    ),
    (
      state: BrainState(loaded: true, assignments: assigned, files: verified),
      label: 'Ready on this device',
      ready: true,
    ),
    (
      state: BrainState(loaded: true, files: verified),
      label: 'Set up on-device AI',
      ready: false,
    ),
    for (final fileState in [
      ModelFileState.missing,
      ModelFileState.corrupt,
      ModelFileState.interrupted,
    ])
      (
        state: BrainState(
          loaded: true,
          assignments: assigned,
          files: {qualifiedBrainModel.id: fileState},
        ),
        label: 'Set up on-device AI',
        ready: false,
      ),
    (
      state: const BrainState(
        loaded: true,
        assignments: {BrainCapability.rewrite: 'unknown'},
        files: {'unknown': ModelFileState.available},
      ),
      label: 'Set up on-device AI',
      ready: false,
    ),
    (
      state: BrainState(
        loaded: true,
        assignments: assigned,
        files: verified,
        failure: BrainFailure.load,
      ),
      label: 'Needs attention',
      ready: false,
    ),
  ]) {
    test('model readiness: ${scenario.label} ${scenario.state.files}', () {
      final container = ProviderContainer.test(
        overrides: [
          brainControllerProvider.overrideWith(
            () => _SnapshotBrain(scenario.state),
          ),
        ],
      );
      expect(container.read(maestarStatusProvider), (
        label: scenario.label,
        ready: scenario.ready,
      ));
    });
  }

  test('a verified assignment must support the assigned capability', () {
    final container = ProviderContainer.test(
      overrides: [
        brainCatalogProvider.overrideWithValue([
          BrainModel(
            id: qualifiedBrainModel.id,
            label: qualifiedBrainModel.label,
            bytes: qualifiedBrainModel.bytes,
            sha256: qualifiedBrainModel.sha256,
            url: qualifiedBrainModel.url,
            capabilities: const {BrainCapability.reflect},
          ),
        ]),
        brainControllerProvider.overrideWith(
          () => _SnapshotBrain(
            BrainState(loaded: true, assignments: assigned, files: verified),
          ),
        ),
      ],
    );
    expect(container.read(maestarStatusProvider).ready, isFalse);
  });
}
