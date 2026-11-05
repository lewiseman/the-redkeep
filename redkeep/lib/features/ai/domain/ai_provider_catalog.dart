import 'ai_provider.dart';

class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.format = AiProviderFormat.openAiCompatible,
    this.tokenLimitParameter = 'max_tokens',
    this.tokenRequired = true,
  });
  final String id, name, baseUrl, tokenLimitParameter;
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
    tokenLimitParameter: 'max_completion_tokens',
  ),
  AiProviderPreset(
    id: 'anthropic',
    name: 'Anthropic',
    baseUrl: 'https://api.anthropic.com/v1',
    format: AiProviderFormat.anthropic,
  ),
  AiProviderPreset(
    id: 'gemini',
    name: 'Google Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
  ),
  AiProviderPreset(
    id: 'openrouter',
    name: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
  ),
  AiProviderPreset(
    id: 'groq',
    name: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
  ),
  AiProviderPreset(
    id: 'mistral',
    name: 'Mistral',
    baseUrl: 'https://api.mistral.ai/v1',
  ),
  AiProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
  ),
  AiProviderPreset(id: 'xai', name: 'xAI', baseUrl: 'https://api.x.ai/v1'),
  customAiProviderPreset,
];

AiProviderPreset? aiProviderPreset(String id) =>
    aiProviderCatalog.where((p) => p.id == id).firstOrNull;
