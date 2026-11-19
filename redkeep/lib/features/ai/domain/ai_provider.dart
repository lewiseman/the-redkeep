import 'dart:typed_data';

import 'ai_conversation.dart';
import 'ai_provider_catalog.dart';

/// What one provider can do. A missing capability means that feature simply
/// does not run; nothing is routed anywhere else.
enum AiCapability {
  chat('Writing'),
  vision('Images in'),
  transcription('Speech to text');

  const AiCapability(this.label);
  final String label;
}

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
  notConfigured,
  unsupported,
}

/// Messages are fixed text. Response bodies, prompts and tokens never reach them.
class AiProviderFailure implements Exception {
  const AiProviderFailure(this.kind);
  final AiProviderFailureKind kind;

  /// Worth trying again by itself later, without the person changing anything.
  bool get transient => const {
    AiProviderFailureKind.rateLimited,
    AiProviderFailureKind.unavailable,
    AiProviderFailureKind.timeout,
    AiProviderFailureKind.offline,
  }.contains(kind);

  String get message => switch (kind) {
    AiProviderFailureKind.badUrl =>
      'This provider URL must be a plain https:// address.',
    AiProviderFailureKind.badToken =>
      'The provider rejected your key. Check it in Settings.',
    AiProviderFailureKind.notFound =>
      'The provider could not find this model or URL. Check them in Settings.',
    AiProviderFailureKind.rateLimited => 'The provider is rate limiting requests or your quota ran out. Try again later.',
    AiProviderFailureKind.rejected =>
      'The provider rejected this request. Try another model.',
    AiProviderFailureKind.unavailable =>
      'The provider is having trouble. Try again later.',
    AiProviderFailureKind.timeout => 'The provider took too long to answer.',
    AiProviderFailureKind.offline =>
      'You are offline. Connect to the internet and try again.',
    AiProviderFailureKind.truncated => 'The model ran out of room before finishing, so nothing was kept. Try another model.',
    AiProviderFailureKind.invalidResponse =>
      'The provider sent an answer Redkeep could not read.',
    AiProviderFailureKind.cancelled => 'The request was cancelled.',
    AiProviderFailureKind.notConfigured =>
      'Add an AI provider and key in Settings first.',
    AiProviderFailureKind.unsupported =>
      'Your AI provider does not offer this feature.',
  };
  @override
  String toString() => 'AiProviderFailure(${kind.name})';
}

/// The single provider the person configured. Stored only in protected storage.
class AiCloudSettings {
  const AiCloudSettings({
    required this.presetId,
    required this.baseUrl,
    this.token = '',
    this.models = const {},
  });

  factory AiCloudSettings.fromPreset(AiProviderPreset preset) =>
      AiCloudSettings(
        presetId: preset.id,
        baseUrl: preset.baseUrl,
        models: preset.defaultModels,
      );

  final String presetId, baseUrl, token;

  /// One model per capability. A blank or missing model turns it off.
  final Map<AiCapability, String> models;

  AiProviderPreset get preset =>
      aiProviderPreset(presetId) ?? customAiProviderPreset;
  String get name => preset.name;
  bool get configured =>
      baseUrl.trim().isNotEmpty && (!preset.tokenRequired || token.isNotEmpty);

  String? model(AiCapability capability) {
    if (!preset.capabilities.contains(capability)) return null;
    final model = models[capability]?.trim() ?? '';
    return model.isEmpty ? null : model;
  }

  /// Vision reuses the chat model; it is only usable when the preset allows it.
  bool supports(AiCapability capability) =>
      configured &&
      (capability == AiCapability.vision
          ? preset.capabilities.contains(AiCapability.vision) &&
                model(AiCapability.chat) != null
          : model(capability) != null);

  AiCloudSettings copyWith({
    String? presetId,
    String? baseUrl,
    String? token,
    Map<AiCapability, String>? models,
  }) => AiCloudSettings(
    presetId: presetId ?? this.presetId,
    baseUrl: baseUrl ?? this.baseUrl,
    token: token ?? this.token,
    models: models ?? this.models,
  );

  Map<String, Object?> toJson() => {
    'presetId': presetId,
    'baseUrl': baseUrl,
    'token': token,
    'models': {for (final e in models.entries) e.key.name: e.value},
  };

  static AiCloudSettings? tryParse(Object? value) {
    if (value is! Map) return null;
    final presetId = value['presetId'], baseUrl = value['baseUrl'];
    if (presetId is! String || baseUrl is! String) return null;
    final models = value['models'];
    return AiCloudSettings(
      // A provider that is no longer offered keeps its URL and key as Custom.
      presetId: aiProviderPreset(presetId)?.id ?? customAiProviderPreset.id,
      baseUrl: baseUrl,
      token: value['token'] as String? ?? '',
      models: {
        if (models is Map)
          for (final capability in AiCapability.values)
            if (models[capability.name] is String)
              capability: models[capability.name] as String,
      },
    );
  }
}

/// What a finished call used, as the provider reported it.
class AiUsage {
  const AiUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.seconds = 0,
  });
  final int inputTokens, outputTokens;
  final double seconds;
}

class AiImageInput {
  const AiImageInput(this.bytes, {this.mime = 'image/jpeg'});
  final Uint8List bytes;
  final String mime;
}

class AiChatRequest {
  const AiChatRequest({
    required this.model,
    required this.system,
    required this.user,
    required this.outputTokens,
    this.temperature = 0,
    this.topP = 1,
    this.images = const [],
    this.timeout,
  });
  final String model, system, user;
  final int outputTokens;
  final double temperature, topP;
  final List<AiImageInput> images;

  /// How long one attempt may take; null keeps the transport's default.
  final Duration? timeout;
}

class AiResult<T> {
  const AiResult(this.value, this.usage);
  final T value;
  final AiUsage usage;
}

/// One piece of a streamed answer: more [text], or, last, what it used.
class AiStreamPiece {
  const AiStreamPiece(this.text, {this.usage});
  final String text;

  /// Set on the final piece when the provider reports it.
  final AiUsage? usage;
}

/// Every provider speaks the OpenAI-compatible API. A provider that lacks a
/// feature fails with [AiProviderFailureKind.unsupported].
/// Completing an abort future stops the request with a cancelled failure.
abstract interface class AiCloudClient {
  Future<AiResult<String>> chat(
    AiCloudSettings settings,
    AiChatRequest request, {
    Future<void>? abort,
  });

  /// [chat] as it is written: text pieces as they arrive, then the usage.
  /// Text only; images are not sent.
  Stream<AiStreamPiece> chatStream(
    AiCloudSettings settings,
    AiChatRequest request, {
    Future<void>? abort,
  });

  /// A conversation turn in which the model may answer, call [tools], or both.
  Future<AiResult<AiConverseReply>> converse(
    AiCloudSettings settings,
    AiConverseRequest request, {
    Future<void>? abort,
  });
  Future<AiResult<String>> transcribe(
    AiCloudSettings settings,
    String model,
    Uint8List audio, {
    String filename = 'speech.wav',
    String mime = 'audio/wav',
    double seconds = 0,
    Future<void>? abort,
  });
  Future<List<String>> listModels(
    AiCloudSettings settings, {
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
