import 'ai_operation.dart';

/// One in-memory AI request owned by a page. Never stored.
class AiJob {
  const AiJob({
    required this.id,
    required this.operation,
    required this.key,
    this.prompt = '',
    this.source = '',
    this.phase = 'running',
    this.text,
  });
  final String id, key, prompt, source, phase;
  final AiOperation operation;
  final String? text;
  bool get terminal =>
      const {'completed', 'failed', 'cancelled'}.contains(phase);

  AiJob copy({String? phase, String? text}) => AiJob(
    id: id,
    operation: operation,
    key: key,
    prompt: prompt,
    source: source,
    phase: phase ?? this.phase,
    text: text ?? this.text,
  );
}
