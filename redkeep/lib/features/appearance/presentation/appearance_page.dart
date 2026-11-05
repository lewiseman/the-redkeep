import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_shell.dart';
import '../../../core/presentation/paper_surface.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../application/appearance_controller.dart';
import '../application/appearance_typography.dart';
import 'font_picker.dart';
import '../domain/appearance_preferences.dart';
import '../../assets/presentation/local_artwork.dart';

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
                          secondary: LocalArtwork(
                            assetKey: 'appearance.theme.${theme.name}',
                          ),
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
                Text('Accent color', style: text.titleLarge),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 336
                        ? constraints.maxWidth / AppAccent.values.length
                        : 64.0;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final accent in AppAccent.values)
                            SizedBox(
                              width: width,
                              child: Semantics(
                                button: true,
                                selected: state.preferences.accent == accent,
                                label: '${accent.label}: ${accent.description}',
                                child: InkWell(
                                  onTap: state.canEdit
                                      ? () => controller.setAccent(accent)
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  state.preferences.accent ==
                                                      accent
                                                  ? accent.darkPrimary
                                                  : Colors.transparent,
                                              width: 1.4,
                                            ),
                                          ),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: accent.seed,
                                              shape: BoxShape.circle,
                                            ),
                                            child:
                                                state.preferences.accent ==
                                                    accent
                                                ? const Icon(
                                                    Icons.check_rounded,
                                                    color: Colors.white,
                                                    size: 24,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          accent.label,
                                          textAlign: TextAlign.center,
                                          style: text.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PaperSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Typography', style: text.titleLarge),
                const SizedBox(height: 12),
                for (final role in FontRole.values) ...[
                  if (role != FontRole.values.first) const SizedBox(height: 10),
                  _FontButton(role: role, state: state),
                ],
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

class _FontButton extends ConsumerWidget {
  const _FontButton({required this.role, required this.state});
  final FontRole role;
  final AppearanceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final fontState = ref.watch(appearanceFontProvider(role));
    final (label, family) = switch (role) {
      FontRole.journal => ('Journal font', state.preferences.fontFamily),
      FontRole.diaryTitle => (
        'Diary title font',
        state.preferences.diaryTitleFontFamily,
      ),
      FontRole.diaryBody => (
        'Diary body font',
        state.preferences.diaryBodyFontFamily,
      ),
    };
    return Material(
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.primary.withValues(alpha: .16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: MediaQuery.textScalerOf(context).scale(25) > 40
                ? null
                : const Text(
                    'Aa',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
                  ),
            title: Text(label),
            subtitle: Text(family),
            trailing: const Icon(Icons.chevron_right_rounded),
            enabled: state.canEdit,
            onTap: () => showFontPicker(
              context,
              selectedFont: family,
              onSelected: (font) => ref
                  .read(appearanceControllerProvider.notifier)
                  .setFontFamily(font, role),
            ),
          ),
          if (fontState.hasError)
            TextButton(
              onPressed: () => ref.invalidate(appearanceFontProvider(role)),
              child: const Text('Font unavailable. Retry loading'),
            ),
        ],
      ),
    );
  }
}
