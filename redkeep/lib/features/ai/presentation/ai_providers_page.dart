import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../companion/presentation/ai_studio_material.dart';
import '../../companion/presentation/companion_hub_widgets.dart';
import '../application/ai_preferences.dart';
import '../application/ai_providers.dart';
import '../domain/ai_provider_catalog.dart';
import 'ai_route_board.dart';

class AiProvidersPage extends ConsumerWidget {
  const AiProvidersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(aiProvidersProvider);
    final prefs = ref.watch(aiPreferencesProvider).value;
    final connected = providers.value ?? const [];
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final grouped = prefs == null
        ? const <String?, List<Never>>{}
        : aiRoutesByStation(prefs.routeFor);
    final presets = aiProviderCatalog.where((p) => p != customAiProviderPreset);
    return CompanionDetailLayout(
      title: 'Providers',
      children: [
        Text(
          'Connect a provider with your own key. It only receives text from tasks you route to it, under your account and its terms.',
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
        ),
        const SizedBox(height: 12),
        if (providers.hasError)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Could not read your saved providers. Unlock the phone and retry.',
            ),
          ),
        if (connected.isNotEmpty) ...[
          const AiStudioSectionHeading(label: 'Connected'),
          for (final provider in connected)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AiStudioCard(
                key: ValueKey('ai-provider-${provider.id}'),
                padding: const EdgeInsets.all(14),
                onTap: () =>
                    context.push('/settings/brain/providers/${provider.id}'),
                child: Row(
                  children: [
                    AiStationMark(
                      name: provider.name,
                      providerId: provider.stationKey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(provider.name, style: text.titleSmall),
                          Text(
                            (grouped[provider.id]?.length ?? 0) == 0
                                ? 'No tasks routed here'
                                : aiTaskCount(grouped[provider.id]!.length),
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
        ],
        AiStudioSectionHeading(
          label: connected.isEmpty ? 'Choose a provider' : 'Add another',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = constraints.maxWidth >= 320 && scale <= 1.3 ? 2 : 1;
            final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final preset in presets)
                  SizedBox(
                    width: width,
                    child: AiStudioCard(
                      key: ValueKey('ai-preset-${preset.id}'),
                      padding: const EdgeInsets.all(12),
                      onTap: () => context.push(
                        '/settings/brain/providers/add/${preset.id}',
                      ),
                      child: Row(
                        children: [
                          AiStationMark(
                            name: preset.name,
                            color: colors.onSurfaceVariant,
                            size: 34,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(preset.name, style: text.titleSmall),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        AiStudioCard(
          key: ValueKey('ai-preset-${customAiProviderPreset.id}'),
          padding: const EdgeInsets.all(12),
          onTap: () => context.push(
            '/settings/brain/providers/add/${customAiProviderPreset.id}',
          ),
          child: Row(
            children: [
              AiStationMark(
                icon: Icons.settings_ethernet_rounded,
                color: colors.onSurfaceVariant,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Custom server', style: text.titleSmall),
                    Text(
                      'Any OpenAI-compatible HTTPS address.',
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
