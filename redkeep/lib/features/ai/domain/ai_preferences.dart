import 'ai_operation.dart';

class AiPreferences {
  const AiPreferences({
    this.mode = AiMode.auto,
    this.overrides = const {},
    this.dailyQuestions = true,
    this.collections = const {'note', 'diary', 'thought'},
    this.paused = false,
    this.voice,
  });
  final AiMode mode;
  final Map<AiOperation, AiMode> overrides;
  final bool dailyQuestions, paused;
  final Set<String> collections;
  final Map<String, String>? voice;
  AiMode modeFor(AiOperation operation) => overrides[operation] ?? mode;
}
