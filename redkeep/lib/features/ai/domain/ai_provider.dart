import 'dart:typed_data';

import 'ai_provider_catalog.dart';

enum AiProviderFormat { openAiCompatible, anthropic }

/// What one provider can do. A missing capability means that feature simply
/// does not run; nothing is routed anywhere else.
enum AiCapability {
  chat('Writing'),
  vision('Images in'),
  embeddings('Search index'),
  transcription('Speech to text'),
  image('Image generation');

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
  spendLimit,
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
      'The provider rejected your key. Check it in Grand Maestar.',
    AiProviderFailureKind.notFound => 'The provider could not find this model or URL. Check them in Grand Maestar.',
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
      'Add an AI provider and key in Grand Maestar first.',
    AiProviderFailureKind.unsupported =>
      'Your AI provider does not offer this feature.',
    AiProviderFailureKind.spendLimit =>
      'This month’s AI spending limit is reached. Raise it in Grand Maestar.',
  };
  @override
  String toString() => 'AiProviderFailure(${kind.name})';
}

/// USD prices. Tokens are priced per million; audio per minute; images each.
class AiPrice {
  const AiPrice({this.input = 0, this.output = 0, this.unit = 0});
  final double input, output, unit;
  Map<String, double> toJson() => {
    'input': input,
    'output': output,
    'unit': unit,
  };
  static AiPrice? tryParse(Object? value) => value is Map
      ? AiPrice(
          input: (value['input'] as num?)?.toDouble() ?? 0,
          output: (value['output'] as num?)?.toDouble() ?? 0,
          unit: (value['unit'] as num?)?.toDouble() ?? 0,
        )
      : null;
}

/// The single provider the person configured. Stored only in protected storage.
class AiCloudSettings {
  const AiCloudSettings({
    required this.presetId,
    required this.baseUrl,
    this.token = '',
    this.models = const {},
    this.prices = const {},
    this.monthlyLimitUsd = 5,
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

  /// Overrides for [AiProviderPreset.prices], keyed by model name.
  final Map<String, AiPrice> prices;

  /// Zero means no limit.
  final double monthlyLimitUsd;

  AiProviderPreset get preset =>
      aiProviderPreset(presetId) ?? customAiProviderPreset;
  AiProviderFormat get format => preset.format;
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

  AiPrice priceFor(String model) =>
      prices[model] ?? preset.prices[model] ?? fallbackAiPrice;

  AiCloudSettings copyWith({
    String? presetId,
    String? baseUrl,
    String? token,
    Map<AiCapability, String>? models,
    Map<String, AiPrice>? prices,
    double? monthlyLimitUsd,
  }) => AiCloudSettings(
    presetId: presetId ?? this.presetId,
    baseUrl: baseUrl ?? this.baseUrl,
    token: token ?? this.token,
    models: models ?? this.models,
    prices: prices ?? this.prices,
    monthlyLimitUsd: monthlyLimitUsd ?? this.monthlyLimitUsd,
  );

  Map<String, Object?> toJson() => {
    'presetId': presetId,
    'baseUrl': baseUrl,
    'token': token,
    'models': {for (final e in models.entries) e.key.name: e.value},
    'prices': {for (final e in prices.entries) e.key: e.value.toJson()},
    'monthlyLimitUsd': monthlyLimitUsd,
  };

  static AiCloudSettings? tryParse(Object? value) {
    if (value is! Map) return null;
    final presetId = value['presetId'], baseUrl = value['baseUrl'];
    if (presetId is! String || baseUrl is! String) return null;
    final models = value['models'], prices = value['prices'];
    return AiCloudSettings(
      presetId: presetId,
      baseUrl: baseUrl,
      token: value['token'] as String? ?? '',
      models: {
        if (models is Map)
          for (final capability in AiCapability.values)
            if (models[capability.name] is String)
              capability: models[capability.name] as String,
      },
      prices: {
        if (prices is Map)
          for (final entry in prices.entries)
            if (entry.key is String && AiPrice.tryParse(entry.value) != null)
              entry.key as String: AiPrice.tryParse(entry.value)!,
      },
      monthlyLimitUsd: (value['monthlyLimitUsd'] as num?)?.toDouble() ?? 5,
    );
  }
}

/// What a finished call used, for the spending ledger.
class AiUsage {
  const AiUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.seconds = 0,
    this.images = 0,
  });
  final int inputTokens, outputTokens, images;
  final double seconds;

  double cost(AiPrice price) =>
      inputTokens * price.input / 1e6 +
      outputTokens * price.output / 1e6 +
      seconds / 60 * price.unit +
      images * price.unit;
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
  });
  final String model, system, user;
  final int outputTokens;
  final double temperature, topP;
  final List<AiImageInput> images;
}

class AiResult<T> {
  const AiResult(this.value, this.usage);
  final T value;
  final AiUsage usage;
}

/// OpenAI conventions are the baseline. Adapters override what differs and
/// throw [AiProviderFailureKind.unsupported] for what a provider lacks.
/// Completing an abort future stops the request with a cancelled failure.
abstract interface class AiCloudClient {
  Future<AiResult<String>> chat(
    AiCloudSettings settings,
    AiChatRequest request, {
    Future<void>? abort,
  });
  Future<AiResult<List<List<double>>>> embed(
    AiCloudSettings settings,
    String model,
    List<String> inputs, {
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
  Future<AiResult<Uint8List>> generateImage(
    AiCloudSettings settings,
    String model,
    String prompt, {
    String size = '1024x1536',
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
