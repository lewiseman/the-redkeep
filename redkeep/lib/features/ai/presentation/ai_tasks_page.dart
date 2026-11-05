import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../companion/presentation/ai_studio_material.dart';
import '../../companion/presentation/companion_hub_widgets.dart';
import '../application/ai_preferences.dart';
import '../application/ai_providers.dart';
import '../domain/ai_operation.dart';
import '../domain/ai_preferences.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_route.dart';

String _routeLabel(AiRoute route, List<AiProviderConnection> providers) {
  if (route.isCompanion) return 'Your computer';
  final provider = providers.where((p) => p.id == route.providerId).firstOrNull;
  return provider == null
      ? 'Provider removed. Choose another.'
      : '${provider.name} · ${route.model}';
}

class AiTasksPage extends ConsumerWidget {
  const AiTasksPage({super.key});

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    AiPreferences previous,
    List<AiProviderConnection> providers,
    Future<void> Function() write,
  ) async {
    final repository = ref.read(aiPreferencesRepositoryProvider);
    try {
      await write();
      final next = await repository.read();
      final route = next.routeFor(AiOperation.dailyQuestion);
      final moved =
          route.providerId !=
          previous.routeFor(AiOperation.dailyQuestion).providerId;
      if (!context.mounted || !moved || route.isCompanion) return;
      if (!next.dailyQuestions) return;
      await _askDailyOptIn(context, ref, route, providers);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this choice. Retry.')),
        );
      }
    }
  }

  Future<void> _askDailyOptIn(
    BuildContext context,
    WidgetRef ref,
    AiRoute route,
    List<AiProviderConnection> providers,
  ) async {
    final name =
        providers.where((p) => p.id == route.providerId).firstOrNull?.name ??
        'this provider';
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Let $name ask daily questions automatically?'),
        content: Text(
          'While today’s diary is open, Redkeep would send up to four entries from today, eight from the previous week and your last five questions to $name without you tapping anything. If you choose not to, it only runs when you tap to ask.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('daily-opt-in-decline'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Only when I tap'),
          ),
          TextButton(
            key: const ValueKey('daily-opt-in-allow'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow automatic'),
          ),
        ],
      ),
    );
    await ref
        .read(aiPreferencesRepositoryProvider)
        .setDailyQuestionOptIn(allowed == true ? route.providerId : null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(aiPreferencesProvider).value;
    final providers = ref.watch(aiProvidersProvider).value ?? const [];
    final repository = ref.read(aiPreferencesRepositoryProvider);

    Widget row(AiOperation operation) {
      final override = prefs?.overrides[operation];
      return ListTile(
        key: ValueKey('ai-task-${operation.name}'),
        contentPadding: EdgeInsets.zero,
        title: Text(operation.label),
        subtitle: Text(
          override == null
              ? 'Default · ${_routeLabel(prefs?.defaultRoute ?? const AiRoute.companion(), providers)}'
              : _routeLabel(override, providers),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: prefs == null
            ? null
            : () async {
                final pick = await _pickRoute(context, operation.label, true);
                if (pick == null || !context.mounted) return;
                await _change(
                  context,
                  ref,
                  prefs,
                  providers,
                  () => repository.setTaskRoute(operation, pick.route),
                );
              },
      );
    }

    Widget group(String label, Iterable<AiOperation> operations) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        AiStudioSectionHeading(label: label),
        AiStudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final operation in operations) row(operation)],
          ),
        ),
      ],
    );

    final tasks = AiOperation.values.where((o) => o.supportsProvider);
    final dailyRoute = prefs?.routeFor(AiOperation.dailyQuestion);
    return CompanionDetailLayout(
      title: 'Tasks',
      children: [
        const CompanionDetailHeading(
          icon: Icons.checklist_rounded,
          title: 'Choose what runs each task',
          description: 'A task only uses what you choose here. If that isn’t ready, Redkeep tells you instead of sending your text somewhere else.',
        ),
        if (providers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextButton.icon(
              key: const ValueKey('ai-tasks-add-provider'),
              onPressed: () => context.push('/settings/brain/providers'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a provider'),
            ),
          ),
        AiStudioCard(
          child: ListTile(
            key: const ValueKey('ai-task-default'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Default'),
            subtitle: Text(
              _routeLabel(
                prefs?.defaultRoute ?? const AiRoute.companion(),
                providers,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: prefs == null
                ? null
                : () async {
                    final pick = await _pickRoute(context, 'Default', false);
                    final route = pick?.route;
                    if (route == null || !context.mounted) return;
                    await _change(
                      context,
                      ref,
                      prefs,
                      providers,
                      () => repository.setDefaultRoute(route),
                    );
                  },
          ),
        ),
        group('Notes', tasks.where((o) => o.isNote)),
        group('Diary', const [
          AiOperation.diaryDetails,
          AiOperation.dailyQuestion,
        ]),
        if (prefs != null && dailyRoute != null && !dailyRoute.isCompanion)
          SwitchListTile(
            key: const ValueKey('daily-auto-toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Ask daily questions automatically'),
            subtitle: const Text(
              'When on, opening today’s diary sends your recent entries to this provider without a tap.',
            ),
            value: prefs.dailyQuestionMayRunAutomatically,
            onChanged: (value) => unawaited(
              value
                  ? _askDailyOptIn(context, ref, dailyRoute, providers)
                  : repository.setDailyQuestionOptIn(null),
            ),
          ),
        group('Flow', const [
          AiOperation.thoughtReflection,
          AiOperation.thoughtQuestion,
        ]),
        const SizedBox(height: 16),
        const Text(
          'Photos, voice, search by meaning and websites still need your computer.',
        ),
      ],
    );
  }
}

/// A null [route] means "follow the default".
class _RoutePick {
  const _RoutePick(this.route);
  final AiRoute? route;
}

Future<_RoutePick?> _pickRoute(
  BuildContext context,
  String title,
  bool canFollowDefault,
) => showModalBottomSheet<_RoutePick>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _RoutePickerSheet(title: title, canFollowDefault: canFollowDefault),
);

class _RoutePickerSheet extends ConsumerStatefulWidget {
  const _RoutePickerSheet({
    required this.title,
    required this.canFollowDefault,
  });
  final String title;
  final bool canFollowDefault;
  @override
  ConsumerState<_RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends ConsumerState<_RoutePickerSheet> {
  final _abort = Completer<void>();
  final _typed = TextEditingController();
  AiProviderConnection? _provider;
  List<String> _models = const [];
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    if (!_abort.isCompleted) _abort.complete();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _choose(AiProviderConnection provider) async {
    setState(() {
      _provider = provider;
      _loading = true;
      _message = null;
    });
    try {
      final models = await ref
          .read(aiProviderClientProvider)
          .listModels(provider, abort: _abort.future);
      if (mounted) setState(() => _models = models);
    } on AiProviderFailure catch (error) {
      if (mounted) {
        setState(
          () => _message = '${error.message} You can still type a model name.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pick(AiRoute? route) => Navigator.pop(context, _RoutePick(route));

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final providers = ref.watch(aiProvidersProvider).value ?? const [];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                provider?.name ?? widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (provider == null) ...[
                if (widget.canFollowDefault)
                  ListTile(
                    key: const ValueKey('ai-route-default'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Follow default'),
                    onTap: () => _pick(null),
                  ),
                ListTile(
                  key: const ValueKey('ai-route-companion'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.computer_rounded),
                  title: const Text('Your computer'),
                  onTap: () => _pick(const AiRoute.companion()),
                ),
                for (final option in providers)
                  ListTile(
                    key: ValueKey('ai-route-provider-${option.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_outlined),
                    title: Text(option.name),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _choose(option),
                  ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('ai-route-model'),
                        controller: _typed,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Model name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: const ValueKey('ai-route-model-use'),
                      onPressed: () {
                        final model = _typed.text.trim();
                        if (model.isNotEmpty) {
                          _pick(AiRoute.provider(provider.id, model));
                        }
                      },
                      child: const Text('Use'),
                    ),
                  ],
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_message!),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                for (final model in _models)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(model),
                    onTap: () => _pick(AiRoute.provider(provider.id, model)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
