enum InferenceBackend { cpu, gpu }

enum InferenceFailure {
  load,
  generation,
  cancellation,
  cleanup,
  busy,
  disposed,
}

/// Safe application error; native errors can contain paths or prompt text.
class InferenceException implements Exception {
  const InferenceException(this.failure);
  final InferenceFailure failure;

  @override
  String toString() => 'Local inference: ${failure.name}';
}

/// A deliberately bounded text-only qualification configuration.
class InferenceSettings {
  const InferenceSettings({this.backend = InferenceBackend.cpu});
  final InferenceBackend backend;
  int get contextTokens => 2048;
  int get outputTokens => 96;
  double get temperature => 0;
  int get topK => 1;
  double get topP => 1;
  int get seed => 42;
}

/// Injected native boundary. Neither callers nor tests need plugin types.
abstract interface class LocalModel {
  InferenceBackend get backend;
  Future<LocalSession> createSession();
  Future<void> close();
}

abstract interface class LocalSession {
  Future<void> addPrompt(String text);
  Stream<String> stream();
  Future<void> stop();
  Future<void> close();
}
