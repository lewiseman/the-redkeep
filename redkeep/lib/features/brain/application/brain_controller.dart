import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/brain.dart';
import 'brain_executor.dart';
import 'brain_providers.dart';

final brainControllerProvider =
    NotifierProvider.autoDispose<BrainController, BrainState>(
      BrainController.new,
    );

class BrainState {
  const BrainState({
    this.loaded = false,
    this.busy = false,
    this.operation,
    this.assignments = const {},
    this.files = const {},
    this.received = 0,
    this.failure,
    this.output = '',
    this.testPassed = false,
  });
  final bool loaded;
  final bool busy;
  final String? operation;
  final Map<BrainCapability, String> assignments;
  final Map<String, ModelFileState> files;
  final int received;
  final BrainFailure? failure;
  final String output;
  final bool testPassed;
  BrainState copyWith({
    bool? loaded,
    bool? busy,
    String? operation,
    Map<BrainCapability, String>? assignments,
    Map<String, ModelFileState>? files,
    int? received,
    BrainFailure? failure,
    String? output,
    bool? testPassed,
  }) => BrainState(
    loaded: loaded ?? this.loaded,
    busy: busy ?? this.busy,
    operation: operation,
    assignments: assignments ?? this.assignments,
    files: files ?? this.files,
    received: received ?? this.received,
    failure: failure,
    output: output ?? this.output,
    testPassed: testPassed ?? this.testPassed,
  );
}

class BrainController extends Notifier<BrainState> {
  BrainCancellation? _download;
  BrainExecutor? _executor;
  final _requestOwner = Object();
  bool _foreground = true;
  bool _stopRequested = false;
  Future<void>? _work;

  @override
  BrainState build() {
    ref.onDispose(() {
      _download?.cancel();
      unawaited(_executor?.cancel(owner: _requestOwner));
    });
    unawaited(Future<void>.microtask(refresh));
    return const BrainState();
  }

  BrainModel _model(String id) => ref
      .read(brainCatalogProvider)
      .firstWhere(
        (model) => model.id == id,
        orElse: () => throw const BrainException(BrainFailure.incompatible),
      );

  Future<void> _perform(String operation, Future<void> Function() work) async {
    if (!ref.mounted || state.busy || !_foreground) return;
    _stopRequested = false;
    state = state.copyWith(
      busy: true,
      operation: operation,
      received: 0,
      output: '',
      testPassed: false,
    );
    final done = Completer<void>();
    _work = done.future;
    try {
      await work();
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          loaded: operation == 'Checking model files' ? false : state.loaded,
          files: operation == 'Checking model files' ? const {} : state.files,
          failure: error is BrainException
              ? error.failure
              : BrainFailure.storage,
        );
      }
    } finally {
      if (ref.mounted) {
        state = state.copyWith(busy: false, failure: state.failure);
      }
      _work = null;
      done.complete();
    }
  }

  Future<void> _read() async {
    final assignments = await ref.read(brainAssignmentsProvider).read();
    if (!ref.mounted) return;
    final files = await ref.read(brainModelFilesProvider.future);
    if (!ref.mounted) return;
    final catalog = ref.read(brainCatalogProvider);
    final states = <String, ModelFileState>{};
    for (final model in catalog) {
      states[model.id] = await files.inspect(model);
    }
    if (ref.mounted) {
      state = state.copyWith(
        loaded: true,
        operation: state.operation,
        assignments: {
          for (final assignment in assignments)
            assignment.capability: assignment.modelId,
        },
        files: Map.unmodifiable(states),
      );
    }
  }

  Future<void> refresh() => _perform('Checking model files', _read);

  Future<void> assign(BrainCapability capability, String? modelId) =>
      _perform('Saving assignment', () async {
        if (!state.loaded) return;
        if (modelId != null &&
            !_model(modelId).capabilities.contains(capability)) {
          throw const BrainException(BrainFailure.incompatible);
        }
        await ref.read(brainAssignmentsProvider).assign(capability, modelId);
        // Read committed assignments; a failed save never updates the selected value.
        if (ref.mounted) await _read();
      });

  Future<void> install(String id) => _perform(
    'Downloading optional model',
    () async {
      final model = _model(id);
      final cancellation = BrainCancellation();
      _download = cancellation;
      try {
        final files = await ref.read(brainModelFilesProvider.future);
        cancellation.check();
        await files.install(model, cancellation, (bytes) {
          if (ref.mounted && !cancellation.cancelled) {
            state = state.copyWith(received: bytes, operation: state.operation);
          }
        });
      } finally {
        _download = null;
        if (ref.mounted) await _read();
      }
    },
  );

  Future<void> remove(String id) => _perform('Removing model', () async {
    final model = _model(id);
    _executor = await ref.read(brainExecutorProvider.future);
    await _executor!.cancel();
    if (!ref.mounted || _stopRequested) return;
    final files = await ref.read(brainModelFilesProvider.future);
    await files.remove(model);
    if (ref.mounted) await _read();
    // Assignments intentionally survive removal: ready again after reinstall.
  });

  Future<void> testAssignment(BrainCapability capability) =>
      _perform('Testing on device', () async {
        final id = state.assignments[capability];
        if (id == null) throw const BrainException(BrainFailure.unassigned);
        final model = _model(id);
        final executor = await ref.read(brainExecutorProvider.future);
        _executor = executor;
        if (!ref.mounted || !_foreground) return;
        if (_stopRequested) throw const BrainException(BrainFailure.cancelled);
        try {
          await executor.execute(
            owner: _requestOwner,
            model: model,
            capability: capability,
            text: 'Mira planted a tree. She watered it each morning. New leaves appeared.',
            onChunk: (chunk) {
              if (ref.mounted && _foreground) {
                state = state.copyWith(
                  output: state.output + chunk,
                  operation: state.operation,
                );
              }
            },
          );
        } on BrainException catch (error) {
          if (ref.mounted &&
              (error.failure == BrainFailure.missing ||
                  error.failure == BrainFailure.integrity)) {
            state = state.copyWith(
              files: Map.unmodifiable({
                ...state.files,
                id: error.failure == BrainFailure.missing
                    ? ModelFileState.missing
                    : ModelFileState.corrupt,
              }),
            );
          }
          rethrow;
        }
        if (ref.mounted) state = state.copyWith(testPassed: true);
      });

  Future<void> cancel() async {
    _stopRequested = true;
    _download?.cancel();
    await _executor?.cancel(owner: _requestOwner);
    await _work;
  }

  /// Called for inactive/hidden/paused as well as route disposal. No auto-resume.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) unawaited(cancel());
  }
}
