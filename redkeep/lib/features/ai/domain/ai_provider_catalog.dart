import 'ai_provider.dart';

class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.format = AiProviderFormat.openAiCompatible,
    this.tokenLimitParameter = 'max_tokens',
    this.tokenRequired = true,
    this.keyUrl,
    this.capabilities = const {AiCapability.chat},
    this.defaultModels = const {},
    this.prices = const {},
  });
  final String id, name, baseUrl, tokenLimitParameter;

  /// Where a person creates a key. Opens in their browser.
  final String? keyUrl;
  final AiProviderFormat format;
  final bool tokenRequired;

  /// What this provider's API offers. Anything else never runs.
  final Set<AiCapability> capabilities;
  final Map<AiCapability, String> defaultModels;

  /// Known USD prices by model. Editable in Grand Maestar.
  final Map<String, AiPrice> prices;
}

/// Used for models without a known price. Deliberately on the high side so a
/// spending limit errs toward stopping early.
const fallbackAiPrice = AiPrice(input: 5, output: 20, unit: .1);

const customAiProviderPreset = AiProviderPreset(
  id: 'custom',
  name: 'Custom (OpenAI-compatible)',
  baseUrl: '',
  tokenRequired: false,
  capabilities: {
    AiCapability.chat,
    AiCapability.vision,
    AiCapability.embeddings,
    AiCapability.transcription,
    AiCapability.image,
  },
);

/// URLs stay editable. Model lists come from each provider.
const aiProviderCatalog = <AiProviderPreset>[
  AiProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    keyUrl: 'https://platform.openai.com/api-keys',
    tokenLimitParameter: 'max_completion_tokens',
    capabilities: {
      AiCapability.chat,
      AiCapability.vision,
      AiCapability.embeddings,
      AiCapability.transcription,
      AiCapability.image,
    },
    defaultModels: {
      AiCapability.chat: 'gpt-5-mini',
      AiCapability.embeddings: 'text-embedding-3-small',
      AiCapability.transcription: 'gpt-4o-mini-transcribe',
      AiCapability.image: 'gpt-image-1',
    },
    prices: {
      'gpt-5-mini': AiPrice(input: .25, output: 2),
      'gpt-5-nano': AiPrice(input: .05, output: .4),
      'gpt-5': AiPrice(input: 1.25, output: 10),
      'gpt-4.1-mini': AiPrice(input: .4, output: 1.6),
      'gpt-4o-mini': AiPrice(input: .15, output: .6),
      'text-embedding-3-small': AiPrice(input: .02),
      'text-embedding-3-large': AiPrice(input: .13),
      'gpt-4o-mini-transcribe': AiPrice(unit: .003),
      'gpt-4o-transcribe': AiPrice(unit: .006),
      'whisper-1': AiPrice(unit: .006),
      'gpt-image-1': AiPrice(unit: .07),
      'gpt-image-1-mini': AiPrice(unit: .02),
    },
  ),
  AiProviderPreset(
    id: 'anthropic',
    name: 'Anthropic',
    baseUrl: 'https://api.anthropic.com/v1',
    keyUrl: 'https://console.anthropic.com/settings/keys',
    format: AiProviderFormat.anthropic,
    capabilities: {AiCapability.chat, AiCapability.vision},
  ),
  AiProviderPreset(
    id: 'gemini',
    name: 'Google Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    keyUrl: 'https://aistudio.google.com/apikey',
    capabilities: {
      AiCapability.chat,
      AiCapability.vision,
      AiCapability.embeddings,
    },
  ),
  AiProviderPreset(
    id: 'openrouter',
    name: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    keyUrl: 'https://openrouter.ai/keys',
    capabilities: {AiCapability.chat, AiCapability.vision},
  ),
  AiProviderPreset(
    id: 'groq',
    name: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    keyUrl: 'https://console.groq.com/keys',
    capabilities: {AiCapability.chat, AiCapability.transcription},
  ),
  AiProviderPreset(
    id: 'mistral',
    name: 'Mistral',
    baseUrl: 'https://api.mistral.ai/v1',
    keyUrl: 'https://console.mistral.ai/api-keys',
    capabilities: {
      AiCapability.chat,
      AiCapability.vision,
      AiCapability.embeddings,
    },
  ),
  AiProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    keyUrl: 'https://platform.deepseek.com/api_keys',
  ),
  AiProviderPreset(
    id: 'xai',
    name: 'xAI',
    baseUrl: 'https://api.x.ai/v1',
    keyUrl: 'https://console.x.ai',
    capabilities: {AiCapability.chat, AiCapability.vision, AiCapability.image},
  ),
  customAiProviderPreset,
];

AiProviderPreset? aiProviderPreset(String id) =>
    aiProviderCatalog.where((p) => p.id == id).firstOrNull;
