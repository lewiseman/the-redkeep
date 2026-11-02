import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_shell.dart';
import '../../../core/presentation/paper_surface.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../application/appearance_controller.dart';
import '../domain/appearance_preferences.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appearanceControllerProvider);
    final controller = ref.read(appearanceControllerProvider.notifier);
    final policy = RenderingPolicyScope.of(context);
    final text = Theme.of(context).textTheme;
    return AppShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Appearance', style: text.headlineSmall),
          ),
          const SizedBox(height: 8),
          const Text(
            'Make this space comfortable for you. Changes save automatically.',
          ),
          if (state.loadError) ...[
            const SizedBox(height: 16),
            const Text(
              'Saved appearance could not be loaded. Your settings have not been replaced.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: controller.retryLoading,
                child: const Text('Retry loading'),
              ),
            ),
          ] else if (!state.loaded) ...[
            const SizedBox(height: 16),
            const Text('Loading saved appearance…'),
          ],
          if (state.saving || state.saveFailed) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                state.saveFailed
                    ? 'Your change could not be saved. Previous settings are still in use. Try the control again.'
                    : 'Saving appearance…',
              ),
            ),
          ],
          const SizedBox(height: 24),
          PaperSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text('Theme', style: text.titleLarge),
                ),
                const SizedBox(height: 8),
                RadioGroup<AppTheme>(
                  groupValue: state.preferences.theme,
                  onChanged: (value) {
                    if (state.canEdit && value != null) {
                      controller.setTheme(value);
                    }
                  },
                  child: Column(
                    children: [
                      for (final theme in AppTheme.values)
                        RadioListTile<AppTheme>(
                          contentPadding: EdgeInsets.zero,
                          value: theme,
                          enabled: state.canEdit,
                          title: Text(switch (theme) {
                            AppTheme.system => 'Use device theme',
                            AppTheme.light => 'Light',
                            AppTheme.dark => 'Dark',
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PaperSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text('Motion and effects', style: text.titleLarge),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reduce motion'),
                  subtitle: const Text(
                    'Use immediate transitions. Device motion reduction always applies.',
                  ),
                  value: state.preferences.reduceMotion,
                  onChanged: state.canEdit ? controller.setReduceMotion : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Simpler effects'),
                  subtitle: const Text(
                    'Use flat paper surfaces. Reduced motion also enables this.',
                  ),
                  value: state.preferences.simplerEffects,
                  onChanged: state.canEdit
                      ? controller.setSimplerEffects
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  policy.osReducedMotion
                      ? 'Motion is reduced by your device.'
                      : policy.reducedMotion
                      ? 'Motion is reduced by your preference.'
                      : 'Standard motion is available.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  policy.simplerEffects
                      ? 'Flat paper is active.'
                      : 'Soft paper shadows are active.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
