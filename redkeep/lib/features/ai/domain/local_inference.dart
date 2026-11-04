enum InferenceBackend { cpu, gpu }

enum InferenceFailure {
  load,
  input,
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
  const InferenceSettings({
    this.backend = InferenceBackend.cpu,
    this.contextTokens = 2048,
    this.outputTokens = 96,
    this.temperature = 0,
    this.topK = 1,
    this.topP = 1,
    this.seed = 42,
    this.systemInstruction = 'Follow the instruction. Answer briefly.',
  });
  final InferenceBackend backend;
  final int contextTokens, outputTokens, topK, seed;
  final double temperature, topP;
  final String systemInstruction;
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
