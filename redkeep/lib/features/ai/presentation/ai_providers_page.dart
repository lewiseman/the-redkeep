import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../companion/presentation/ai_studio_material.dart';
import '../../companion/presentation/companion_hub_widgets.dart';
import '../application/ai_providers.dart';
import '../domain/ai_provider_catalog.dart';

class AiProvidersPage extends ConsumerWidget {
  const AiProvidersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(aiProvidersProvider);
    final connected = providers.value ?? const [];
    return CompanionDetailLayout(
      title: 'AI providers',
      children: [
        const CompanionDetailHeading(
          icon: Icons.cloud_outlined,
          title: 'Bring your own provider',
          description: 'Tasks you assign to a provider send their text to it, under your own account and its terms. Tokens stay in protected storage on this phone.',
        ),
        if (providers.hasError)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Could not read your saved providers. Unlock the phone and retry.',
            ),
          ),
        if (connected.isNotEmpty) ...[
          const AiStudioSectionHeading(label: 'Connected'),
          AiStudioCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final provider in connected)
                  ListTile(
                    key: ValueKey('ai-provider-${provider.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(provider.name),
                    subtitle: Text(provider.baseUrl),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(
                      '/settings/brain/providers/${provider.id}',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const AiStudioSectionHeading(label: 'Add a provider'),
        AiStudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final preset in aiProviderCatalog)
                ListTile(
                  key: ValueKey('ai-preset-${preset.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(preset.name),
                  trailing: const Icon(Icons.add_rounded),
                  onTap: () => context.push(
                    '/settings/brain/providers/add/${preset.id}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
