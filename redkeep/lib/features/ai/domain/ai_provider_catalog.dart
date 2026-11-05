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
  });
  final String id, name, baseUrl, tokenLimitParameter;

  /// Where a person creates a key. Opens in their browser.
  final String? keyUrl;
  final AiProviderFormat format;
  final bool tokenRequired;
}

const customAiProviderPreset = AiProviderPreset(
  id: 'custom',
  name: 'Custom (OpenAI-compatible)',
  baseUrl: '',
  tokenRequired: false,
);

/// URLs stay editable. Models come from each provider, so no list can go stale.
const aiProviderCatalog = <AiProviderPreset>[
  AiProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    keyUrl: 'https://platform.openai.com/api-keys',
    tokenLimitParameter: 'max_completion_tokens',
  ),
  AiProviderPreset(
    id: 'anthropic',
    name: 'Anthropic',
    baseUrl: 'https://api.anthropic.com/v1',
    keyUrl: 'https://console.anthropic.com/settings/keys',
    format: AiProviderFormat.anthropic,
  ),
  AiProviderPreset(
    id: 'gemini',
    name: 'Google Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    keyUrl: 'https://aistudio.google.com/apikey',
  ),
  AiProviderPreset(
    id: 'openrouter',
    name: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    keyUrl: 'https://openrouter.ai/keys',
  ),
  AiProviderPreset(
    id: 'groq',
    name: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    keyUrl: 'https://console.groq.com/keys',
  ),
  AiProviderPreset(
    id: 'mistral',
    name: 'Mistral',
    baseUrl: 'https://api.mistral.ai/v1',
    keyUrl: 'https://console.mistral.ai/api-keys',
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
  ),
  customAiProviderPreset,
];

AiProviderPreset? aiProviderPreset(String id) =>
    aiProviderCatalog.where((p) => p.id == id).firstOrNull;
