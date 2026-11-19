import 'ai_provider.dart';

class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.tokenLimitParameter = 'max_tokens',
    this.tokenRequired = true,
    this.keyUrl,
    this.capabilities = const {AiCapability.chat},
    this.defaultModels = const {},
  });
  final String id, name, baseUrl, tokenLimitParameter;

  /// Where a person creates a key. Opens in their browser.
  final String? keyUrl;
  final bool tokenRequired;

  /// What this provider's API offers. Anything else never runs.
  final Set<AiCapability> capabilities;
  final Map<AiCapability, String> defaultModels;
}

const customAiProviderPreset = AiProviderPreset(
  id: 'custom',
  name: 'Custom (OpenAI-compatible)',
  baseUrl: '',
  tokenRequired: false,
  capabilities: {
    AiCapability.chat,
    AiCapability.vision,
    AiCapability.transcription,
  },
);

/// OpenAI-compatible providers only. URLs stay editable. Model lists come
/// from each provider.
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
      AiCapability.transcription,
    },
    defaultModels: {
      AiCapability.chat: 'gpt-5-mini',
      AiCapability.transcription: 'gpt-4o-mini-transcribe',
    },
  ),
  AiProviderPreset(
    id: 'gemini',
    name: 'Google Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    keyUrl: 'https://aistudio.google.com/apikey',
    capabilities: {AiCapability.chat, AiCapability.vision},
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
    capabilities: {AiCapability.chat, AiCapability.vision},
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
    capabilities: {AiCapability.chat, AiCapability.vision},
  ),
  customAiProviderPreset,
];

AiProviderPreset? aiProviderPreset(String id) =>
    aiProviderCatalog.where((p) => p.id == id).firstOrNull;

/// The known service an address belongs to, or Custom. Redkeep speaks only
/// the OpenAI-compatible API, so the person gives an address rather than
/// choosing from a list; a known one still gets its own token parameter,
/// features and key page.
AiProviderPreset aiProviderPresetForAddress(String address) {
  final host = Uri.tryParse(address.trim())?.host.toLowerCase() ?? '';
  if (host.isEmpty) return customAiProviderPreset;
  for (final preset in aiProviderCatalog) {
    if (preset.baseUrl.isEmpty) continue;
    if (Uri.parse(preset.baseUrl).host == host) return preset;
  }
  return customAiProviderPreset;
}
