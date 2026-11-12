/// Provider-neutral tool calling. The app declares tools; the model may ask
/// for them, and the app decides what each call does. Nothing a model asks
/// for runs by itself.
library;

/// A tool the model may call, with a JSON schema for its arguments.
class AiToolSpec {
  const AiToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });
  final String name, description;
  final Map<String, Object?> parameters;
}

/// One call the model asked for. [arguments] are untrusted until checked.
class AiToolCall {
  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
  final String id, name;
  final Map<String, Object?> arguments;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'arguments': arguments,
  };

  static AiToolCall? tryParse(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        value['name'] is! String ||
        value['arguments'] is! Map) {
      return null;
    }
    return AiToolCall(
      id: value['id'] as String,
      name: value['name'] as String,
      arguments: Map<String, Object?>.from(value['arguments'] as Map),
    );
  }
}

/// What the app tells the model about one of its calls.
class AiToolResult {
  const AiToolResult(this.callId, this.content);
  final String callId, content;
}

/// One exchange of an earlier conversation: what the person said, what the
/// model answered and called, and what came of each call.
class AiExchange {
  const AiExchange({
    required this.user,
    this.reply = '',
    this.calls = const [],
    this.results = const [],
  });
  final String user, reply;
  final List<AiToolCall> calls;

  /// One per call, in the same order; adapters send these before the next
  /// user message, as every provider requires.
  final List<AiToolResult> results;
}

class AiConverseRequest {
  const AiConverseRequest({
    required this.model,
    required this.system,
    required this.history,
    required this.user,
    required this.tools,
    required this.outputTokens,
    this.temperature = .3,
    this.timeout,
  });
  final String model, system, user;
  final List<AiExchange> history;
  final List<AiToolSpec> tools;
  final int outputTokens;
  final double temperature;
  final Duration? timeout;
}

class AiConverseReply {
  const AiConverseReply({this.text = '', this.calls = const []});
  final String text;
  final List<AiToolCall> calls;
  bool get isEmpty => text.trim().isEmpty && calls.isEmpty;
}
