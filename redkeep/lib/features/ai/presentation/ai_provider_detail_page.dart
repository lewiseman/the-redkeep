import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../companion/presentation/ai_studio_material.dart';
import '../../companion/presentation/companion_hub_widgets.dart';
import '../application/ai_jobs.dart';
import '../application/ai_preferences.dart';
import '../application/ai_providers.dart';
import '../data/http_ai_provider_client.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_provider_catalog.dart';
import 'ai_route_board.dart';
import 'ai_route_picker.dart';

String _modelCount(int count) =>
    count == 1 ? '1 model available' : '$count models available';

/// Adds a provider from [presetId], or edits the saved provider [id].
class AiProviderDetailPage extends ConsumerStatefulWidget {
  const AiProviderDetailPage({super.key, this.id, this.presetId});
  final String? id, presetId;
  @override
  ConsumerState<AiProviderDetailPage> createState() =>
      _AiProviderDetailPageState();
}

class _AiProviderDetailPageState extends ConsumerState<AiProviderDetailPage> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _token = TextEditingController();
  final _abort = Completer<void>();
  AiProviderConnection? _saved;
  AiProviderPreset? _preset;
  bool _loading = true, _missing = false, _busy = false, _checkFailed = false;
  String? _message, _newId;

  /// Set once a new provider is saved, which swaps the form for what's next.
  int? _connectedModels;

  bool get _adding => widget.id == null;
  bool get _custom => _preset == customAiProviderPreset;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    List<AiProviderConnection> saved = const [];
    try {
      saved = await ref.read(aiProvidersProvider.future);
    } catch (_) {
      /* Reported as missing below; nothing can be overwritten from here. */
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!_adding) {
        _saved = saved.where((p) => p.id == widget.id).firstOrNull;
        _missing = _saved == null;
        _preset = aiProviderPreset(_saved?.presetId ?? '');
        _name.text = _saved?.name ?? '';
        _url.text = _saved?.baseUrl ?? '';
      } else {
        _preset = aiProviderPreset(widget.presetId ?? '');
        _missing = _preset == null;
        _name.text = _custom ? '' : _preset?.name ?? '';
        _url.text = _preset?.baseUrl ?? '';
      }
    });
  }

  @override
  void dispose() {
    if (!_abort.isCompleted) _abort.complete();
    _name.dispose();
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  AiProviderConnection _draft() {
    final typed = _token.text.trim();
    final saved = _saved;
    if (saved != null) {
      return saved.copyWith(
        name: _name.text.trim(),
        baseUrl: _url.text.trim(),
        token: typed.isEmpty ? null : typed,
      );
    }
    final preset = _preset!;
    return AiProviderConnection(
      id: _newId ??= ref.read(aiIdProvider)(),
      presetId: preset.id,
      name: _name.text.trim(),
      format: preset.format,
      baseUrl: _url.text.trim(),
      token: typed,
      tokenLimitParameter: preset.tokenLimitParameter,
    );
  }

  String? _problem(AiProviderConnection draft) {
    if (draft.name.isEmpty) return 'Give this provider a name.';
    try {
      parseAiProviderBaseUrl(draft.baseUrl);
    } on AiProviderFailure catch (error) {
      return error.message;
    }
    if (_preset?.tokenRequired != false && draft.token.isEmpty) {
      return 'Enter the key from your provider account.';
    }
    return null;
  }

  Future<void> _run(Future<void> Function(AiProviderConnection) action) async {
    final draft = _draft();
    final problem = _problem(draft);
    if (problem != null) {
      setState(() => _message = problem);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action(draft);
    } on AiProviderFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not save this provider. Retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A new provider is only saved once the check passes, unless asked otherwise.
  Future<void> _connect(AiProviderConnection draft) async {
    final List<String> models;
    try {
      models = await ref
          .read(aiProviderClientProvider)
          .listModels(draft, abort: _abort.future);
    } on AiProviderFailure {
      if (mounted) setState(() => _checkFailed = true);
      rethrow;
    }
    await ref.read(aiProvidersProvider.notifier).save(draft);
    if (mounted) setState(() => _connectedModels = models.length);
  }

  Future<void> _test(AiProviderConnection draft) async {
    final models = await ref
        .read(aiProviderClientProvider)
        .listModels(draft, abort: _abort.future);
    if (mounted) {
      setState(() {
        _message = models.isEmpty
            ? 'Connected. This provider listed no models, so type a model name when you route a task.'
            : 'Connected. ${_modelCount(models.length)}.';
      });
    }
  }

  Future<void> _save(AiProviderConnection draft) async {
    await ref.read(aiProvidersProvider.notifier).save(draft);
    if (mounted) context.pop();
  }

  Future<void> _useForAll(AiProviderConnection provider) async {
    final pick = await pickAiRoute(
      context,
      title: 'all your tasks',
      canFollowDefault: false,
      startAt: provider,
    );
    final route = pick?.route;
    if (route == null || !mounted) return;
    await changeAiRoutes(
      context,
      ref,
      () => ref.read(aiPreferencesRepositoryProvider).setDefaultRoute(route),
    );
    if (mounted) context.pushReplacement('/settings/brain/tasks');
  }

  Future<void> _openKeyPage(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      /* Reported below. */
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  Future<void> _remove() async {
    final saved = _saved!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${saved.name}?'),
        content: const Text(
          'Its key is deleted from this phone. Tasks using it return to your default, and a default using it returns to your computer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            key: const ValueKey('ai-provider-remove-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(aiProvidersProvider.notifier).remove(saved.id);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = 'Could not remove this provider. Retry.';
        });
      }
    }
  }

  Widget _nameField() => TextField(
    key: const ValueKey('ai-provider-name'),
    controller: _name,
    decoration: const InputDecoration(labelText: 'Name'),
  );

  Widget _urlField() => TextField(
    key: const ValueKey('ai-provider-url'),
    controller: _url,
    keyboardType: TextInputType.url,
    autocorrect: false,
    enableSuggestions: false,
    decoration: const InputDecoration(
      labelText: 'Base URL',
      helperText: 'Must start with https://',
    ),
  );

  Widget _tokenField({required bool hasSaved}) => TextField(
    key: const ValueKey('ai-provider-token'),
    controller: _token,
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      labelText: 'API key',
      helperMaxLines: 3,
      helperText: hasSaved
          ? 'A key is saved and can’t be shown. Type a new one to replace it.'
          : _preset?.tokenRequired == false
          ? 'Leave empty if this server needs none.'
          : 'Kept in protected storage on this phone only.',
    ),
  );

  Widget _status() => _message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(_message!, key: const ValueKey('ai-provider-message')),
          ),
        );

  Widget _step({
    required Color color,
    required String label,
    required Widget child,
    bool first = false,
    bool last = false,
    bool dashed = false,
  }) => AiRailRow(
    color: color,
    connectTop: !first,
    connectBottom: !last,
    dashed: dashed,
    nodeY: 12,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );

  List<Widget> _addFlow() {
    final preset = _preset!;
    final color = context.colors.primary;
    final keyUrl = preset.keyUrl;
    return [
      Row(
        children: [
          _custom
              ? AiStationMark(
                  icon: Icons.settings_ethernet_rounded,
                  color: context.colors.onSurfaceVariant,
                  size: 52,
                )
              : AiStationMark(
                  name: preset.name,
                  color: context.colors.onSurfaceVariant,
                  size: 52,
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _custom ? 'Connect a custom server' : 'Connect ${preset.name}',
              style: studioTitle(context, size: 22),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      if (_custom)
        _step(
          color: color,
          first: true,
          label: 'Where is it?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_nameField(), const SizedBox(height: 12), _urlField()],
          ),
        ),
      _step(
        color: color,
        first: !_custom,
        label: _custom ? 'Does it need a key?' : 'Add your key',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (keyUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('ai-provider-key-page'),
                  onPressed: () => _openKeyPage(keyUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text('Get a key from ${preset.name}'),
                ),
              ),
            _tokenField(hasSaved: false),
          ],
        ),
      ),
      _step(
        color: color,
        dashed: true,
        last: true,
        label: 'Check it works',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Redkeep asks ${_custom ? 'the server' : preset.name} for its model list. None of your writing is sent.',
              style: TextStyle(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('ai-provider-connect'),
              onPressed: _busy ? null : () => _run(_connect),
              child: Text(_busy ? 'Checking…' : 'Check and connect'),
            ),
            _status(),
            if (_checkFailed)
              TextButton(
                key: const ValueKey('ai-provider-save'),
                onPressed: _busy ? null : () => _run(_save),
                child: const Text('Save without checking'),
              ),
          ],
        ),
      ),
      if (!_custom)
        ExpansionTile(
          key: const ValueKey('ai-provider-advanced'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Name and address'),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          children: [_nameField(), const SizedBox(height: 12), _urlField()],
        ),
    ];
  }

  List<Widget> _connectedView() {
    final provider = _draft();
    final count = _connectedModels!;
    return [
      const SizedBox(height: 12),
      Center(
        child: AiStationMark(
          name: provider.name,
          providerId: provider.stationKey,
          size: 72,
        ),
      ),
      const SizedBox(height: 18),
      Text(
        '${provider.name} is connected',
        key: const ValueKey('ai-provider-connected'),
        textAlign: TextAlign.center,
        style: studioTitle(context, size: 22),
      ),
      const SizedBox(height: 6),
      Text(
        count == 0
            ? 'It listed no models, so you’ll type a model name.'
            : '${_modelCount(count)}. No tasks use it yet.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colors.onSurfaceVariant),
      ),
      const SizedBox(height: 28),
      FilledButton.icon(
        key: const ValueKey('ai-connected-all'),
        onPressed: () => _useForAll(provider),
        icon: const Icon(Icons.call_split_rounded),
        label: const Text('Use it for all writing tasks'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const ValueKey('ai-connected-choose'),
        onPressed: () => context.pushReplacement('/settings/brain/tasks'),
        icon: const Icon(Icons.alt_route_rounded),
        label: const Text('Choose task by task'),
      ),
      const SizedBox(height: 4),
      TextButton(
        key: const ValueKey('ai-connected-done'),
        onPressed: () => context.pop(),
        child: const Text('Decide later'),
      ),
    ];
  }

  List<Widget> _editView(AiProviderConnection saved) {
    final prefs = ref.watch(aiPreferencesProvider).value;
    final tasks = prefs == null
        ? 0
        : aiRoutesByStation(prefs.routeFor)[saved.id]?.length ?? 0;
    return [
      Row(
        children: [
          AiStationMark(
            name: saved.name,
            providerId: saved.stationKey,
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(saved.name, style: studioTitle(context, size: 22)),
                Text(
                  tasks == 0 ? 'No tasks routed here' : aiTaskCount(tasks),
                  style: TextStyle(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      AiStudioCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _nameField(),
            const SizedBox(height: 12),
            _urlField(),
            const SizedBox(height: 12),
            _tokenField(hasSaved: saved.token.isNotEmpty),
            _status(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const ValueKey('ai-provider-save'),
                  onPressed: _busy ? null : () => _run(_save),
                  child: const Text('Save'),
                ),
                OutlinedButton(
                  key: const ValueKey('ai-provider-test'),
                  onPressed: _busy ? null : () => _run(_test),
                  child: Text(_busy ? 'Checking…' : 'Test connection'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        key: const ValueKey('ai-provider-remove'),
        onPressed: _busy ? null : _remove,
        style: TextButton.styleFrom(foregroundColor: context.colors.error),
        icon: const Icon(Icons.link_off_rounded),
        label: const Text('Remove this provider'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    return CompanionDetailLayout(
      title: _adding ? 'Connect' : 'Provider',
      children: _loading
          ? const [Center(child: CircularProgressIndicator())]
          : _missing
          ? const [Text('This provider is no longer saved on this phone.')]
          : _connectedModels != null
          ? _connectedView()
          : saved != null
          ? _editView(saved)
          : _addFlow(),
    );
  }
}
