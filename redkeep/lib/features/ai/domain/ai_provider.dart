enum AiProviderFormat { openAiCompatible, anthropic }

enum AiProviderFailureKind {
  badUrl,
  badToken,
  notFound,
  rateLimited,
  rejected,
  unavailable,
  timeout,
  offline,
  truncated,
  invalidResponse,
  cancelled,
}

/// Messages are fixed text. Response bodies, prompts and tokens never reach them.
class AiProviderFailure implements Exception {
  const AiProviderFailure(this.kind);
  final AiProviderFailureKind kind;
  String get message => switch (kind) {
    AiProviderFailureKind.badUrl =>
      'This provider URL must be a plain https:// address.',
    AiProviderFailureKind.badToken =>
      'The provider rejected this token. Check it in Grand Maestar.',
    AiProviderFailureKind.notFound => 'The provider could not find this model or URL. Check them in Grand Maestar.',
    AiProviderFailureKind.rateLimited => 'The provider says you hit a rate limit or ran out of quota. Try again later.',
    AiProviderFailureKind.rejected =>
      'The provider rejected this request. Try another model.',
    AiProviderFailureKind.unavailable =>
      'The provider is having trouble. Try again later.',
    AiProviderFailureKind.timeout => 'The provider took too long to answer.',
    AiProviderFailureKind.offline =>
      'Could not reach the provider. Check your connection.',
    AiProviderFailureKind.truncated => 'The model ran out of room before finishing, so nothing was kept. Try another model.',
    AiProviderFailureKind.invalidResponse =>
      'The provider sent an answer Redkeep could not read.',
    AiProviderFailureKind.cancelled => 'The request was cancelled.',
  };
  @override
  String toString() => 'AiProviderFailure(${kind.name})';
}

/// A connection the person configured. Stored only in protected storage.
class AiProviderConnection {
  const AiProviderConnection({
    required this.id,
    required this.presetId,
    required this.name,
    required this.format,
    required this.baseUrl,
    this.token = '',
    this.tokenLimitParameter = 'max_tokens',
  });
  final String id, presetId, name, baseUrl, token, tokenLimitParameter;
  final AiProviderFormat format;

  /// Keeps one provider's color on every page. Each custom server gets its own.
  String get stationKey => presetId == 'custom' ? id : presetId;

  AiProviderConnection copyWith({
    String? name,
    String? baseUrl,
    String? token,
  }) => AiProviderConnection(
    id: id,
    presetId: presetId,
    name: name ?? this.name,
    format: format,
    baseUrl: baseUrl ?? this.baseUrl,
    token: token ?? this.token,
    tokenLimitParameter: tokenLimitParameter,
  );

  Map<String, String> toJson() => {
    'id': id,
    'presetId': presetId,
    'name': name,
    'format': format.name,
    'baseUrl': baseUrl,
    'token': token,
    'tokenLimitParameter': tokenLimitParameter,
  };

  static AiProviderConnection? tryParse(Object? value) {
    if (value is! Map) return null;
    final format = AiProviderFormat.values
        .where((f) => f.name == value['format'])
        .firstOrNull;
    final id = value['id'], name = value['name'], base = value['baseUrl'];
    if (format == null || id is! String || name is! String || base is! String) {
      return null;
    }
    return AiProviderConnection(
      id: id,
      presetId: value['presetId'] as String? ?? 'custom',
      name: name,
      format: format,
      baseUrl: base,
      token: value['token'] as String? ?? '',
      tokenLimitParameter:
          value['tokenLimitParameter'] as String? ?? 'max_tokens',
    );
  }
}

class AiCompletionRequest {
  const AiCompletionRequest({
    required this.model,
    required this.system,
    required this.user,
    required this.outputTokens,
    required this.temperature,
    this.topP = 1,
  });
  final String model, system, user;
  final int outputTokens;
  final double temperature, topP;
}

abstract interface class AiProviderClient {
  /// Completing [abort] stops the request and throws a cancelled failure.
  Future<String> complete(
    AiProviderConnection connection,
    AiCompletionRequest request, {
    Future<void>? abort,
  });
  Future<List<String>> listModels(
    AiProviderConnection connection, {
    Future<void>? abort,
  });
}

/// Cloud models often wrap JSON in one Markdown fence; validators expect none.
String stripSurroundingCodeFence(String text) {
  final match = RegExp(
    r'^\s*```[A-Za-z0-9_-]*[ \t]*\r?\n([\s\S]*?)\r?\n?```\s*$',
  ).firstMatch(text);
  if (match == null || match[1]!.contains('```')) return text;
  return match[1]!;
}
