import 'dart:async';

import '../../ai/application/local_inference_adapter.dart';
import '../../ai/domain/local_inference.dart';
import '../domain/brain.dart';

typedef BrainModelLoader = Future<LocalModel> Function(
  String path,
  InferenceSettings settings,
);

/// Device-only, one request at a time. Weights are released after every request.
/// Closing/backgrounding during a native load waits and closes the late resource.
class BrainExecutor {
  BrainExecutor({
    required this.files,
    required this.loadModel,
    this.requestTimeout = const Duration(seconds: 90),
  });
  final BrainModelFiles files;
  final BrainModelLoader loadModel;
  final Duration requestTimeout;
  Future<void>? _active;
  BrainCancellation? _cancellation;
  Object? _owner;
  LocalInferenceAdapter? _adapter;
  bool _disposed = false;
  bool _poisoned = false;

  bool get busy => _active != null;

  Future<void> execute({
    required BrainModel model,
    required BrainCapability capability,
    required String text,
    required void Function(String) onChunk,
    Object? owner,
    String? preparedPrompt,
    InferenceSettings settings = const InferenceSettings(),
  }) {
    if (_disposed) throw const BrainException(BrainFailure.disposed);
    if (_poisoned) throw const BrainException(BrainFailure.cleanup);
    if (busy) throw const BrainException(BrainFailure.busy);
    if (!model.capabilities.contains(capability)) {
      throw const BrainException(BrainFailure.incompatible);
    }
    final prompt = preparedPrompt ?? capability.prompt(text);
    final cancellation = BrainCancellation();
    _cancellation = cancellation;
    _owner = owner;
    final done = Completer<void>();
    _active = done.future;
    return _execute(
      model,
      prompt,
      settings,
      cancellation,
      onChunk,
    ).whenComplete(() {
      _active = null;
      _cancellation = null;
      _owner = null;
      done.complete();
    });
  }

  Future<void> _execute(
    BrainModel model,
    String prompt,
    InferenceSettings settings,
    BrainCancellation cancellation,
    void Function(String) onChunk,
  ) async {
    var timedOut = false;
    final timer = Timer(requestTimeout, () {
      timedOut = true;
      cancellation.cancel();
      _stopAdapter();
    });
    try {
      final path = await files.verifiedPath(model);
      cancellation.check();
      final loaded = await loadModel(path, settings);
      final adapter = LocalInferenceAdapter(loaded);
      _adapter = adapter;
      cancellation.check();
      if (adapter.backend != InferenceBackend.cpu) {
        throw const BrainException(BrainFailure.load);
      }
      final run = adapter.generate(prompt);
      var outputCharacters = 0;
      await for (final chunk in run.chunks) {
        if (!cancellation.cancelled) {
          outputCharacters += chunk.length;
          if (outputCharacters > 16000) {
            throw const BrainException(BrainFailure.generation);
          }
          onChunk(chunk);
        }
      }
      await run.done;
      cancellation.check();
      if (outputCharacters == 0) {
        throw const BrainException(BrainFailure.generation);
      }
    } on BrainException {
      if (timedOut) throw const BrainException(BrainFailure.timeout);
      rethrow;
    } on InferenceException catch (error) {
      if (error.failure == InferenceFailure.input) {
        throw const BrainException(BrainFailure.context);
      }
      if (error.failure == InferenceFailure.cleanup ||
          error.failure == InferenceFailure.cancellation) {
        _poisoned = true;
        throw const BrainException(BrainFailure.cleanup);
      }
      if (timedOut) throw const BrainException(BrainFailure.timeout);
      cancellation.check();
      throw BrainException(
        error.failure == InferenceFailure.load
            ? BrainFailure.load
            : BrainFailure.generation,
      );
    } catch (_) {
      if (timedOut) throw const BrainException(BrainFailure.timeout);
      cancellation.check();
      throw BrainException(
        _adapter == null ? BrainFailure.load : BrainFailure.generation,
      );
    } finally {
      timer.cancel();
      try {
        await _adapter?.close();
      } catch (_) {
        _poisoned = true;
        throw const BrainException(BrainFailure.cleanup);
      } finally {
        _adapter = null;
      }
    }
  }

  void _stopAdapter() {
    final adapter = _adapter;
    if (adapter != null) {
      // The execute future reports teardown failures after its finally block.
      unawaited(adapter.close().catchError((Object _) {}));
    }
  }

  /// A supplied owner can stop only its own active request. Omitting it is the
  /// resource owner's explicit global stop (model removal/scope disposal).
  Future<void> cancel({Object? owner}) async {
    if (owner != null && !identical(owner, _owner)) return;
    _cancellation?.cancel();
    _stopAdapter();
    await _active;
  }

  Future<void> dispose() async {
    _disposed = true;
    await cancel();
  }
}
