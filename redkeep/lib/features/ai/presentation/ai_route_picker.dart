import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../companion/presentation/ai_studio_material.dart';
import '../application/ai_preferences.dart';
import '../application/ai_providers.dart';
import '../domain/ai_operation.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_route.dart';
import 'ai_route_board.dart';

/// A null [route] means "follow the default".
class AiRoutePick {
  const AiRoutePick(this.route);
  final AiRoute? route;
}

Future<AiRoutePick?> pickAiRoute(
  BuildContext context, {
  required String title,
  required bool canFollowDefault,
  AiRoute? current,
  AiProviderConnection? startAt,
}) => showModalBottomSheet<AiRoutePick>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _RoutePickerSheet(
    title: title,
    canFollowDefault: canFollowDefault,
    current: current,
    startAt: startAt,
  ),
);

/// Saves a routing change, then asks before diary text may leave automatically.
Future<void> changeAiRoutes(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() write,
) async {
  final repository = ref.read(aiPreferencesRepositoryProvider);
  try {
    final before = (await repository.read()).routeFor(
      AiOperation.dailyQuestion,
    );
    await write();
    final next = await repository.read();
    final route = next.routeFor(AiOperation.dailyQuestion);
    if (!context.mounted ||
        route.isCompanion ||
        route.providerId == before.providerId ||
        !next.dailyQuestions) {
      return;
    }
    await askDailyQuestionOptIn(context, ref, route);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this choice. Retry.')),
      );
    }
  }
}

Future<void> askDailyQuestionOptIn(
  BuildContext context,
  WidgetRef ref,
  AiRoute route,
) async {
  final providers = await ref.read(aiProvidersProvider.future);
  if (!context.mounted) return;
  final name =
      providers.where((p) => p.id == route.providerId).firstOrNull?.name ??
      'this provider';
  final allowed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.public_rounded),
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

class _RoutePickerSheet extends ConsumerStatefulWidget {
  const _RoutePickerSheet({
    required this.title,
    required this.canFollowDefault,
    this.current,
    this.startAt,
  });
  final String title;
  final bool canFollowDefault;
  final AiRoute? current;
  final AiProviderConnection? startAt;
  @override
  ConsumerState<_RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends ConsumerState<_RoutePickerSheet> {
  final _abort = Completer<void>();
  final _search = TextEditingController();
  AiProviderConnection? _provider;
  List<String> _models = const [];
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    final start = widget.startAt;
    if (start != null) unawaited(_choose(start));
  }

  @override
  void dispose() {
    if (!_abort.isCompleted) _abort.complete();
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(AiProviderConnection provider) async {
    setState(() {
      _provider = provider;
      _models = const [];
      _loading = true;
      _message = null;
      _search.clear();
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

  void _pick(AiRoute? route) => Navigator.pop(context, AiRoutePick(route));

  Widget _stationStage(BuildContext context) {
    final providers = ref.watch(aiProvidersProvider).value ?? const [];
    final current = widget.current;
    Widget row({
      required Key key,
      required Widget mark,
      required String title,
      String? detail,
      required VoidCallback onTap,
      bool selected = false,
      bool chevron = false,
    }) => ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      leading: mark,
      title: Text(title),
      subtitle: detail == null ? null : Text(detail),
      selected: selected,
      trailing: selected
          ? const Icon(Icons.check_rounded)
          : chevron
          ? const Icon(Icons.chevron_right_rounded)
          : null,
      onTap: onTap,
    );

    return Flexible(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          if (widget.canFollowDefault)
            row(
              key: const ValueKey('ai-route-default'),
              mark: AiStationMark(
                icon: Icons.call_merge_rounded,
                color: context.colors.onSurfaceVariant,
              ),
              title: 'Follow default',
              selected: current == null,
              onTap: () => _pick(null),
            ),
          row(
            key: const ValueKey('ai-route-companion'),
            mark: const AiStationMark(),
            title: 'Your computer',
            detail: 'Stays on your own network.',
            selected: current?.isCompanion == true,
            onTap: () => _pick(const AiRoute.companion()),
          ),
          if (providers.isNotEmpty) const AiInternetBoundary(),
          for (final option in providers)
            row(
              key: ValueKey('ai-route-provider-${option.id}'),
              mark: AiStationMark(
                name: option.name,
                providerId: option.stationKey,
              ),
              title: option.name,
              detail: current?.providerId == option.id
                  ? current!.model
                  : 'Choose a model',
              selected: current?.providerId == option.id,
              chevron: true,
              onTap: () => _choose(option),
            ),
          row(
            key: const ValueKey('ai-route-connect'),
            mark: AiStationMark(
              icon: Icons.add_rounded,
              color: context.colors.onSurfaceVariant,
            ),
            title: 'Connect a provider',
            onTap: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push('/settings/brain/providers');
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _modelStage(BuildContext context, AiProviderConnection provider) {
    final query = _search.text.trim();
    final lower = query.toLowerCase();
    final found = lower.isEmpty
        ? _models
        : _models.where((m) => m.toLowerCase().contains(lower)).toList();
    final currentModel = widget.current?.providerId == provider.id
        ? widget.current?.model
        : null;
    // The model in use comes first, so long lists never hide it.
    final matches = [
      if (found.contains(currentModel)) currentModel!,
      ...found.where((m) => m != currentModel),
    ];
    final exact = _models.contains(query);
    final current = widget.current;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              key: const ValueKey('ai-route-model'),
              controller: _search,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                labelText: _models.isEmpty
                    ? 'Model name'
                    : 'Search ${_models.length} models',
              ),
              onSubmitted: (value) {
                final model = value.trim();
                if (model.isNotEmpty) {
                  _pick(AiRoute.provider(provider.id, model));
                }
              },
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(_message!),
            ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: matches.length + (query.isEmpty || exact ? 0 : 1),
              itemBuilder: (context, index) {
                if (query.isNotEmpty && !exact && index == 0) {
                  return ListTile(
                    key: const ValueKey('ai-route-model-use'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.keyboard_return_rounded),
                    title: Text('Use “$query”'),
                    onTap: () => _pick(AiRoute.provider(provider.id, query)),
                  );
                }
                final model = matches[index - (query.isEmpty || exact ? 0 : 1)];
                final selected =
                    current?.providerId == provider.id &&
                    current?.model == model;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(model),
                  selected: selected,
                  trailing: selected ? const Icon(Icons.check_rounded) : null,
                  onTap: () => _pick(AiRoute.provider(provider.id, model)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final tall = (media.size.height * .85 - inset).clamp(
      200.0,
      media.size.height,
    );
    final content = Column(
      mainAxisSize: provider == null ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(provider == null ? 20 : 8, 0, 20, 8),
          child: Row(
            children: [
              if (provider != null && widget.startAt == null)
                IconButton(
                  tooltip: 'Back to destinations',
                  onPressed: () => setState(() => _provider = null),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              if (provider != null) ...[
                const SizedBox(width: 8),
                AiStationMark(
                  name: provider.name,
                  providerId: provider.stationKey,
                  size: 32,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  provider == null
                      ? 'Where should ${widget.title} go?'
                      : 'Choose a ${provider.name} model',
                  style: studioTitle(context, size: 18),
                ),
              ),
            ],
          ),
        ),
        if (provider == null)
          _stationStage(context)
        else
          _modelStage(context, provider),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        child: provider == null
            ? ConstrainedBox(
                constraints: BoxConstraints(maxHeight: tall),
                child: content,
              )
            : SizedBox(height: tall, child: content),
      ),
    );
  }
}
