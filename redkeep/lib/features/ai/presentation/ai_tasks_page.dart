import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../companion/application/companion_controller.dart';
import '../../companion/presentation/ai_studio_material.dart';
import '../../companion/presentation/companion_hub_widgets.dart';
import '../application/ai_preferences.dart';
import '../application/ai_providers.dart';
import '../domain/ai_operation.dart';
import '../domain/ai_preferences.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_route.dart';
import 'ai_route_board.dart';
import 'ai_route_picker.dart';

class AiTasksPage extends ConsumerWidget {
  const AiTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(aiPreferencesProvider).value;
    final providers = ref.watch(aiProvidersProvider).value ?? const [];
    final connected =
        ref.watch(companionControllerProvider).phase ==
        CompanionPhase.connected;
    final repository = ref.read(aiPreferencesRepositoryProvider);
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final tasks = AiOperation.values.where((o) => o.supportsProvider);
    final defaultRoute = prefs?.defaultRoute ?? const AiRoute.companion();
    final cloud = tasks
        .where((o) => prefs?.routeFor(o).isCompanion == false)
        .length;

    Future<void> routeGroup(String label, Iterable<AiOperation> group) async {
      final pick = await pickAiRoute(
        context,
        title: 'all $label tasks',
        canFollowDefault: true,
      );
      if (pick == null || !context.mounted) return;
      await changeAiRoutes(
        context,
        ref,
        () => repository.setTaskRoutes(group, pick.route),
      );
    }

    Widget group(String label, List<AiOperation> operations) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(label, style: text.titleMedium),
              TextButton(
                key: ValueKey('ai-group-${label.toLowerCase()}'),
                onPressed: prefs == null
                    ? null
                    : () => routeGroup(label.toLowerCase(), operations),
                child: const Text('Route all'),
              ),
            ],
          ),
          for (final (index, operation) in operations.indexed)
            _TaskLine(
              operation: operation,
              prefs: prefs,
              providers: providers,
              computerConnected: connected,
              first: index == 0,
              last: index == operations.length - 1,
            ),
        ],
      ),
    );

    final notes = tasks.where((o) => o.isNote).toList();
    return CompanionDetailLayout(
      title: 'Route tasks',
      children: [
        AiRouteLegend(local: tasks.length - cloud, cloud: cloud),
        const SizedBox(height: 16),
        _DefaultStation(
          route: defaultRoute,
          providers: providers,
          computerConnected: connected,
          onTap: prefs == null
              ? null
              : () async {
                  final pick = await pickAiRoute(
                    context,
                    title: 'your tasks',
                    canFollowDefault: false,
                    current: defaultRoute,
                  );
                  final route = pick?.route;
                  if (route == null || !context.mounted) return;
                  await changeAiRoutes(
                    context,
                    ref,
                    () => repository.setDefaultRoute(route),
                  );
                },
        ),
        group('Notes', notes),
        group('Diary', const [
          AiOperation.diaryDetails,
          AiOperation.dailyQuestion,
        ]),
        group('Flow', const [
          AiOperation.thoughtReflection,
          AiOperation.thoughtQuestion,
        ]),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.computer_rounded, size: 18, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Photos, voice, search by meaning and websites always use your computer.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DefaultStation extends StatelessWidget {
  const _DefaultStation({
    required this.route,
    required this.providers,
    required this.computerConnected,
    required this.onTap,
  });
  final AiRoute route;
  final List<AiProviderConnection> providers;
  final bool computerConnected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final about = describeAiRoute(
      route,
      providers,
      computerConnected: computerConnected,
    );
    return AiStudioCard(
      key: const ValueKey('ai-task-default'),
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AiStationMark(
            name: about.provider?.name,
            providerId: about.provider?.stationKey,
            size: 48,
            icon: about.cloud && about.provider == null
                ? Icons.link_off_rounded
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default destination',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(about.label, style: studioTitle(context, size: 17)),
                if (about.problem != null)
                  Text(
                    about.problem!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.colors.error),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: context.colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _TaskLine extends ConsumerWidget {
  const _TaskLine({
    required this.operation,
    required this.prefs,
    required this.providers,
    required this.computerConnected,
    required this.first,
    required this.last,
  });
  final AiOperation operation;
  final AiPreferences? prefs;
  final List<AiProviderConnection> providers;
  final bool computerConnected, first, last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = this.prefs;
    final override = prefs?.overrides[operation];
    final route = prefs?.routeFor(operation) ?? const AiRoute.companion();
    final about = describeAiRoute(
      route,
      providers,
      computerConnected: computerConnected,
    );
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final repository = ref.read(aiPreferencesRepositoryProvider);
    final color = about.cloud && about.provider == null
        ? colors.error
        : aiStationColor(context, about.provider?.stationKey);
    final daily =
        operation == AiOperation.dailyQuestion &&
        prefs != null &&
        !route.isCompanion;

    return AiRailRow(
      color: color,
      dashed: about.cloud,
      quiet: override == null,
      connectTop: !first,
      connectBottom: !last,
      nodeY: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('ai-task-${operation.name}'),
            borderRadius: BorderRadius.circular(12),
            onTap: prefs == null
                ? null
                : () async {
                    final pick = await pickAiRoute(
                      context,
                      title: operation.label,
                      canFollowDefault: true,
                      current: override,
                    );
                    if (pick == null || !context.mounted) return;
                    await changeAiRoutes(
                      context,
                      ref,
                      () => repository.setTaskRoute(operation, pick.route),
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(operation.label, style: text.titleSmall),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    about.cloud
                                        ? Icons.public_rounded
                                        : Icons.computer_rounded,
                                    size: 14,
                                    color: color,
                                  ),
                                ),
                              ),
                              // The default card reports its own problem once.
                              TextSpan(
                                text: override == null
                                    ? 'Default'
                                    : about.problem == null
                                    ? about.label
                                    : '${about.label} · ${about.problem}',
                              ),
                            ],
                          ),
                          style: text.bodySmall?.copyWith(
                            color: override != null && about.problem != null
                                ? colors.error
                                : colors.onSurfaceVariant,
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
          if (daily)
            SwitchListTile(
              key: const ValueKey('daily-auto-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Ask automatically'),
              subtitle: const Text(
                'When on, opening today’s diary sends your recent entries to this provider without a tap.',
              ),
              value: prefs.dailyQuestionMayRunAutomatically,
              onChanged: (value) => unawaited(
                value
                    ? askDailyQuestionOptIn(context, ref, route)
                    : repository.setDailyQuestionOptIn(null),
              ),
            ),
        ],
      ),
    );
  }
}
