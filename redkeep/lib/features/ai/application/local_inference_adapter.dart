import 'dart:async';

import '../domain/local_inference.dart';

/// Owns one loaded model, one turn at a time, with a fresh session per turn.
/// Construction does no work; the caller explicitly loads and injects a model.
class LocalInferenceAdapter {
  LocalInferenceAdapter(this._model);

  final LocalModel _model;
  InferenceRun? _active;
  Future<void>? _closing;
  bool _unhealthy = false;

  InferenceBackend get backend => _model.backend;

  InferenceRun generate(String prompt) {
    if (_closing != null || _unhealthy) {
      throw const InferenceException(InferenceFailure.disposed);
    }
    if (_active != null) {
      throw const InferenceException(InferenceFailure.busy);
    }
    if (prompt.trim().isEmpty || prompt.length > 4096) {
      throw ArgumentError('Use 1–4096 characters of text.');
    }
    final run = InferenceRun._();
    _active = run;
    run._output.onListen = () {
      run._started = true;
      unawaited(_execute(run, prompt));
    };
    run._output.onCancel = run.cancel;
    return run;
  }

  Future<void> _execute(InferenceRun run, String prompt) async {
    LocalSession? session;
    try {
      if (!run._cancelled) {
        session = await _model.createSession();
        run._session = session;
        if (!run._cancelled) await session.addPrompt(prompt);
        if (!run._cancelled) {
          await for (final chunk in session.stream()) {
            if (!run._cancelled) run._output.add(chunk);
          }
        }
      }
    } catch (_) {
      // A native cancellation may terminate its stream with an error.
      if (!run._cancelled) {
        run._failure = InferenceFailure.generation;
      }
    } finally {
      run._finishing = true;
      if (session != null) {
        try {
          if (run._cancelled) await run._stop();
        } catch (_) {
          run._failure = InferenceFailure.cancellation;
        }
        try {
          await session.close();
        } catch (_) {
          run._failure = InferenceFailure.cleanup;
        }
      }
      // Failed teardown must not allow reuse of an uncertain native resource.
      if (run._failure == InferenceFailure.cleanup ||
          run._failure == InferenceFailure.cancellation) {
        _unhealthy = true;
      }
      _active = null;
      run._complete.complete();
      if (run._failure case final failure?) {
        run._output.addError(InferenceException(failure));
      }
      unawaited(run._output.close());
    }
  }

  /// Cancels and waits for native teardown before releasing the weights.
  /// Repeated callers observe the same completion (including a close failure).
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    final run = _active;
    try {
      if (run != null) {
        await run.cancel();
        await run.done;
      }
    } finally {
      try {
        await _model.close();
      } catch (_) {
        throw const InferenceException(InferenceFailure.cleanup);
      }
    }
  }
}

class InferenceRun {
  InferenceRun._();
  final _output = StreamController<String>();
  final _complete = Completer<void>();
  LocalSession? _session;
  Future<void>? _stopping;
  bool _cancelled = false;
  bool _started = false;
  bool _finishing = false;
  InferenceFailure? _failure;

  Stream<String> get chunks => _output.stream;
  Future<void> get done => _complete.future;
  bool get cancelled => _cancelled;
  InferenceFailure? get failure => _failure;

  Future<void> _stop() => _stopping ??= _session!.stop();

  /// Stop reaches native decoding. Later chunks are suppressed immediately.
  Future<void> cancel() async {
    if (_complete.isCompleted) return;
    _cancelled = true;
    if (_session != null && !_finishing) {
      try {
        await _stop();
      } catch (_) {
        _failure = InferenceFailure.cancellation;
      }
    }
    // Also handles a turn cancelled before anyone subscribes to it.
    if (!_started) {
      _output.stream.listen((_) {}, onError: (Object _) {});
    }
    await done;
  }
}
