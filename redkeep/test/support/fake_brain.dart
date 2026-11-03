import 'dart:async';

import 'package:redkeep/features/brain/domain/brain.dart';

class FakeBrainAssignments implements BrainAssignments {
  final values = <BrainCapability, String>{};
  bool fail = false;
  Completer<void>? saving;
  @override
  Future<List<BrainAssignment>> read() async => [
    for (final entry in values.entries)
      BrainAssignment(capability: entry.key, modelId: entry.value),
  ];
  @override
  Future<void> assign(BrainCapability capability, String? modelId) async {
    await saving?.future;
    if (fail) throw StateError('private storage details');
    if (modelId == null) {
      values.remove(capability);
    } else {
      values[capability] = modelId;
    }
  }
}

class FakeBrainFiles implements BrainModelFiles {
  ModelFileState state = ModelFileState.available;
  BrainFailure? failure;
  int checks = 0;
  int installs = 0;
  int removes = 0;
  Completer<void>? installing;
  @override
  Future<ModelFileState> inspect(BrainModel model) async {
    checks++;
    if (failure != null) throw BrainException(failure!);
    return state;
  }

  @override
  Future<String> verifiedPath(BrainModel model) async {
    final status = await inspect(model);
    if (status != ModelFileState.available) {
      throw BrainException(
        status == ModelFileState.corrupt
            ? BrainFailure.integrity
            : BrainFailure.missing,
      );
    }
    return '/synthetic/verified-model';
  }

  @override
  Future<void> install(
    BrainModel model,
    BrainCancellation cancellation,
    void Function(int) onProgress,
  ) async {
    installs++;
    onProgress(100);
    if (installing != null) {
      await Future.any([installing!.future, cancellation.whenCancelled]);
    }
    cancellation.check();
    if (failure != null) throw BrainException(failure!);
    state = ModelFileState.available;
  }

  @override
  Future<void> remove(BrainModel model) async {
    removes++;
    state = ModelFileState.missing;
  }
}
