import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../recall/application/recall_controller.dart';
import '../application/ai_cloud.dart';
import '../application/ai_preferences.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_provider_catalog.dart';

/// Grand Maestar: the one cloud AI provider, its models, the monthly
/// spending limit and the search index. Everything stays on this phone.
class AiSettingsPage extends ConsumerWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiCloudSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Grand Maestar')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: settings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not unlock your AI settings. Unlock the phone and retry.',
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(aiCloudSettingsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (value) => _AiSettingsForm(
                key: ValueKey(value == null ? 'new' : 'saved'),
                saved: value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiSettingsForm extends ConsumerStatefulWidget {
  const _AiSettingsForm({super.key, required this.saved});
  final AiCloudSettings? saved;
  @override
  ConsumerState<_AiSettingsForm> createState() => _AiSettingsFormState();
}

class _AiSettingsFormState extends ConsumerState<_AiSettingsForm> {
  late AiCloudSettings _draft =
      widget.saved ?? AiCloud.starter(aiProviderCatalog.first.id);
  late final _baseUrl = TextEditingController(text: _draft.baseUrl);
  late final _token = TextEditingController(text: _draft.token);
  late final _limit = TextEditingController(
    text: _money(_draft.monthlyLimitUsd),
  );
  late final _models = {
    for (final capability in _modelCapabilities)
      capability: TextEditingController(text: _draft.models[capability] ?? ''),
  };
  bool _hideToken = true, _busy = false;
  String? _message;
  List<String>? _available;
  Completer<void>? _abort;

  /// Vision uses the chat model, so it has no field of its own.
  static const _modelCapabilities = [
    AiCapability.chat,
    AiCapability.embeddings,
    AiCapability.transcription,
    AiCapability.image,
  ];

  static String _money(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  @override
  void dispose() {
    _cancelRequest();
    _baseUrl.dispose();
    _token.dispose();
    _limit.dispose();
    for (final controller in _models.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _cancelRequest() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _abort = null;
  }

  AiCloudSettings _read() => _draft.copyWith(
    baseUrl: _baseUrl.text.trim(),
    token: _token.text.trim(),
    models: {
      for (final entry in _models.entries)
        if (entry.value.text.trim().isNotEmpty)
          entry.key: entry.value.text.trim(),
    },
    monthlyLimitUsd: double.tryParse(_limit.text.trim()) ?? 0,
  );

  void _choosePreset(String id) {
    if (id == _draft.presetId) return;
    final preset = aiProviderPreset(id) ?? customAiProviderPreset;
    setState(() {
      _draft = AiCloudSettings.fromPreset(preset)
          .copyWith(monthlyLimitUsd: _draft.monthlyLimitUsd);
      _baseUrl.text = preset.baseUrl;
      _token.clear();
      for (final capability in _modelCapabilities) {
        _models[capability]!.text = preset.defaultModels[capability] ?? '';
      }
      _available = null;
      _message = null;
    });
  }

  Future<void> _save() async {
    final next = _read();
    final limit = double.tryParse(_limit.text.trim());
    if (limit == null || limit.isNaN || limit < 0) {
      setState(() => _message = 'Enter a monthly limit in dollars, or 0.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(aiCloudSettingsProvider.notifier).save(next);
      if (mounted) setState(() => _message = 'Saved.');
    } on AiProviderFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not save. Unlock the phone and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Lists the provider's models, which also checks the URL and key.
  Future<void> _test() async {
    _cancelRequest();
    final abort = _abort = Completer<void>();
    setState(() {
      _busy = true;
      _message = 'Checking your key…';
    });
    try {
      final models = await ref
          .read(aiCloudProvider)
          .listModels(_read(), abort: abort.future);
      if (!mounted) return;
      setState(() {
        _available = models;
        _message = 'Connected. ${models.length} models available.';
      });
    } on AiProviderFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } finally {
      if (identical(_abort, abort)) _abort = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickModel(AiCapability capability) async {
    if (_available == null) await _test();
    final models = _available;
    if (!mounted || models == null || models.isEmpty) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ModelPicker(models: models),
    );
    if (chosen != null && mounted) {
      setState(() => _models[capability]!.text = chosen);
    }
  }

  Future<void> _openKeyPage(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Open $url in your browser.')));
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this provider?'),
        content: const Text(
          'Its key is deleted from this phone. AI features stop until you add a provider again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(aiCloudSettingsProvider.notifier).clear();
    }
  }

  Future<void> _editPrice(String model, AiCapability capability) async {
    final price = _draft.priceFor(model);
    final perUnit =
        capability == AiCapability.transcription ||
        capability == AiCapability.image;
    final first = TextEditingController(
      text: '${perUnit ? price.unit : price.input}',
    );
    final second = TextEditingController(text: '${price.output}');
    final result = await showDialog<AiPrice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Price for $model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: capability == AiCapability.transcription
                    ? 'USD per minute of audio'
                    : capability == AiCapability.image
                    ? 'USD per image'
                    : 'USD per million input tokens',
              ),
            ),
            if (!perUnit && capability != AiCapability.embeddings)
              TextField(
                controller: second,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'USD per million output tokens',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final a = double.tryParse(first.text.trim());
              final b = double.tryParse(second.text.trim()) ?? 0;
              if (a == null || a < 0 || b < 0) return;
              Navigator.pop(
                context,
                perUnit ? AiPrice(unit: a) : AiPrice(input: a, output: b),
              );
            },
            child: const Text('Use price'),
          ),
        ],
      ),
    );
    first.dispose();
    second.dispose();
    if (result != null && mounted) {
      setState(
        () =>
            _draft = _draft.copyWith(prices: {..._draft.prices, model: result}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = _draft.preset;
    final saved = widget.saved;
    final keyRejected = ref.watch(aiKeyStatusProvider);
    final spent = ref.watch(aiMonthSpendProvider).value ?? 0;
    final limit = saved?.monthlyLimitUsd ?? 0;
    final text = Theme.of(context).textTheme;
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Text(label, style: text.titleMedium),
    );
    return ListView(
      key: const ValueKey('ai-settings'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Redkeep uses one AI provider with your own key. Features your provider does not offer simply stay off. Your key stays on this phone.',
          style: text.bodyMedium,
        ),
        if (keyRejected)
          _Notice(
            icon: Icons.key_off_outlined,
            text: 'Your provider rejected the key. Check it below, then save. Search indexing is paused until then.',
          ),
        if (saved != null && limit > 0 && spent >= limit)
          _Notice(
            icon: Icons.savings_outlined,
            text: 'This month’s spending limit is reached, so AI requests are paused. Raise the limit to continue.',
          ),
        heading('Provider'),
        DropdownButtonFormField<String>(
          key: const ValueKey('ai-provider-preset'),
          initialValue: _draft.presetId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Provider'),
          items: [
            for (final item in aiProviderCatalog)
              DropdownMenuItem(value: item.id, child: Text(item.name)),
          ],
          onChanged: _busy ? null : (id) => _choosePreset(id!),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('ai-provider-url'),
          controller: _baseUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'API address (https://)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('ai-provider-token'),
          controller: _token,
          obscureText: _hideToken,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: preset.tokenRequired ? 'API key' : 'API key (optional)',
            suffixIcon: IconButton(
              tooltip: _hideToken ? 'Show key' : 'Hide key',
              onPressed: () => setState(() => _hideToken = !_hideToken),
              icon: Icon(
                _hideToken
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        if (preset.keyUrl case final url?)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _openKeyPage(url),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Get a ${preset.name} key'),
            ),
          ),
        heading('Models'),
        for (final capability in _modelCapabilities)
          _ModelField(
            capability: capability,
            controller: _models[capability]!,
            offered: preset.capabilities.contains(capability),
            providerName: preset.name,
            onPick: _busy ? null : () => _pickModel(capability),
            onPrice: _models[capability]!.text.trim().isEmpty
                ? null
                : () =>
                      _editPrice(_models[capability]!.text.trim(), capability),
          ),
        Text(
          preset.capabilities.contains(AiCapability.vision)
              ? 'Questions about images use the writing model.'
              : 'Image questions and photo prompts stay off: ${preset.name} has no image input here.',
          style: text.bodySmall,
        ),
        heading('Spending'),
        TextField(
          key: const ValueKey('ai-monthly-limit'),
          controller: _limit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly limit in USD (0 for no limit)',
            prefixText: r'$',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'About \$${spent.toStringAsFixed(spent < 1 ? 4 : 2)} used this month. '
          'This is an estimate from each response and the prices for your models; your provider’s bill is the final word.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 20),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(liveRegion: true, child: Text(_message!)),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const ValueKey('ai-provider-save'),
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
            OutlinedButton(
              key: const ValueKey('ai-provider-test'),
              onPressed: _busy ? null : _test,
              child: const Text('Test key'),
            ),
            if (saved != null)
              TextButton(
                onPressed: _busy ? null : _remove,
                child: const Text('Remove provider'),
              ),
          ],
        ),
        heading('Search by meaning'),
        const _RecallSettings(),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _ModelField extends StatelessWidget {
  const _ModelField({
    required this.capability,
    required this.controller,
    required this.offered,
    required this.providerName,
    required this.onPick,
    required this.onPrice,
  });
  final AiCapability capability;
  final TextEditingController controller;
  final bool offered;
  final String providerName;
  final VoidCallback? onPick, onPrice;

  @override
  Widget build(BuildContext context) {
    if (!offered) {
      return ListTile(
        key: ValueKey('ai-model-${capability.name}'),
        contentPadding: EdgeInsets.zero,
        enabled: false,
        title: Text(capability.label),
        subtitle: Text('Not offered by $providerName, so this stays off.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey('ai-model-${capability.name}'),
            controller: controller,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: '${capability.label} model',
              helperText: capability == AiCapability.chat
                  ? 'Required'
                  : 'Leave empty to turn this off',
              suffixIcon: IconButton(
                tooltip: 'Choose from your provider',
                onPressed: onPick,
                icon: const Icon(Icons.list_rounded),
              ),
            ),
          ),
          if (onPrice != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(onPressed: onPrice, child: const Text('Price')),
            ),
        ],
      ),
    );
  }
}

class _ModelPicker extends StatefulWidget {
  const _ModelPicker({required this.models});
  final List<String> models;
  @override
  State<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<_ModelPicker> {
  String _filter = '';
  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final model in widget.models)
        if (model.toLowerCase().contains(_filter.toLowerCase())) model,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Find a model',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _filter = value.trim()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(shown[i]),
                onTap: () => Navigator.pop(context, shown[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecallSettings extends ConsumerWidget {
  const _RecallSettings();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(aiPreferencesProvider).value;
    final index = ref.watch(recallControllerProvider);
    final controller = ref.read(recallControllerProvider.notifier);
    final embeddings = ref
        .watch(aiCapabilitiesProvider)
        .contains(AiCapability.embeddings);
    Future<void> change(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save this preference. Retry.'),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          embeddings
              ? 'Find notes, diary entries and Flow thoughts by what they mean. Saved text is sent to your provider in batches about 45 seconds after you stop writing, or soon after you leave an editor. Vectors stay on this phone. Searches by meaning run when you press search.'
              : 'Your provider has no embedding model, so search uses keywords only.',
        ),
        const SizedBox(height: 8),
        for (final item in [
          ('note', 'Notes'),
          ('diary', 'Diary entries'),
          ('thought', 'Flow thoughts'),
        ])
          SwitchListTile(
            key: ValueKey('recall-${item.$1}'),
            contentPadding: EdgeInsets.zero,
            title: Text(item.$2),
            subtitle: Text(
              '${index.counts[item.$1] ?? 0} saved sources indexed',
            ),
            value: prefs?.collections.contains(item.$1) ?? true,
            onChanged: prefs == null
                ? null
                : (v) => change(() => controller.setEnabled(item.$1, v)),
          ),
        if (index.running) ...[
          LinearProgressIndicator(
            value: index.total == 0 ? null : index.done / index.total,
          ),
          Text('Indexing ${index.done} of ${index.total}…'),
        ],
        if (prefs?.paused == true) const Text('Indexing is paused.'),
        if (index.message != null) Text(index.message!),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: prefs == null
                  ? null
                  : () => change(() => controller.pause(!prefs.paused)),
              child: Text(
                prefs?.paused == true ? 'Resume indexing' : 'Pause indexing',
              ),
            ),
            TextButton(
              onPressed: index.running || !embeddings
                  ? null
                  : () => change(controller.run),
              child: const Text('Index now'),
            ),
            TextButton(
              onPressed: index.running || !embeddings
                  ? null
                  : () => change(controller.rebuild),
              child: const Text('Rebuild search index'),
            ),
          ],
        ),
      ],
    );
  }
}
