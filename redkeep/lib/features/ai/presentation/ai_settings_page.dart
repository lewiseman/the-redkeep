import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../more/application/maestar_status.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/ai_cloud.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_provider_catalog.dart';
import 'maestar_chain_rows.dart';
import 'maestar_key_purse.dart';
import 'maestar_parts.dart';
import 'maestar_study.dart';

const _portrait = AssetImage('assets/branding/grand_maestar.png');

/// Grand Maestar: the one cloud AI provider, its models and the monthly
/// spending limit. Search by meaning lives in the Library, one page deeper.
/// Everything stays on this phone.
class AiSettingsPage extends ConsumerWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiCloudSettingsProvider);
    final palette = MorePalette.of(context);
    return Scaffold(
      backgroundColor: palette.ground,
      body: settings.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Grand Maestar')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('Grand Maestar')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not unlock your AI settings. Unlock the phone and retry.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(aiCloudSettingsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (value) => _AiSettingsForm(
          key: ValueKey(value == null ? 'new' : 'saved'),
          saved: value,
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

enum _Check { idle, checking, connected, failed }

class _AiSettingsFormState extends ConsumerState<_AiSettingsForm>
    with SingleTickerProviderStateMixin {
  late AiCloudSettings _draft =
      widget.saved ?? AiCloud.starter(aiProviderCatalog.first.id);
  late String _savedJson = jsonEncode((widget.saved ?? _draft).toJson());
  late final _baseUrl = TextEditingController(text: _draft.baseUrl);
  late final _token = TextEditingController(text: _draft.token);
  late final _limit = TextEditingController(
    text: _money(_draft.monthlyLimitUsd),
  );
  late final _models = {
    for (final capability in _modelCapabilities)
      capability: TextEditingController(text: _draft.models[capability] ?? ''),
  };
  late final _cardKeys = {
    for (final capability in maestarLinks) capability: GlobalKey(),
  };
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final _scroll = ScrollController();
  bool _busy = false;
  String? _message;
  _Check _check = _Check.idle;
  String? _checkMessage;
  List<String>? _available;
  Completer<void>? _abort;
  AiCapability? _selected;

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
  void initState() {
    super.initState();
    for (final controller in [_baseUrl, _token, _limit, ..._models.values]) {
      controller.addListener(_edited);
    }
  }

  void _edited() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cancelRequest();
    _baseUrl.dispose();
    _token.dispose();
    _limit.dispose();
    for (final controller in _models.values) {
      controller.dispose();
    }
    _pulse.dispose();
    _scroll.dispose();
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

  bool get _dirty =>
      widget.saved == null || jsonEncode(_read().toJson()) != _savedJson;

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
      _check = _Check.idle;
      _checkMessage = null;
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
      if (mounted) {
        setState(() {
          _savedJson = jsonEncode(next.toJson());
          _message = 'Saved.';
        });
      }
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
      _check = _Check.checking;
      _checkMessage = 'Checking your key…';
    });
    try {
      final models = await ref
          .read(aiCloudProvider)
          .listModels(_read(), abort: abort.future);
      if (!mounted) return;
      setState(() {
        _available = models;
        _check = _Check.connected;
        _checkMessage = 'Connected. ${models.length} models available.';
      });
    } on AiProviderFailure catch (failure) {
      if (mounted) {
        setState(() {
          _check = _Check.failed;
          _checkMessage = failure.message;
        });
      }
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
      builder: (context) =>
          ModelPicker(models: models, title: '${capability.label} model'),
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
    final result = await showDialog<AiPrice>(
      context: context,
      builder: (context) => _PriceDialog(
        model: model,
        capability: capability,
        price: _draft.priceFor(model),
      ),
    );
    if (result != null && mounted) {
      setState(
        () =>
            _draft = _draft.copyWith(prices: {..._draft.prices, model: result}),
      );
    }
  }

  String? _priceLabel(AiCapability capability) {
    final model = _models[capability]?.text.trim() ?? '';
    if (model.isEmpty) return null;
    final price = _draft.priceFor(model);
    String usd(double v) => '\$${v.toStringAsFixed(v < 1 ? 3 : 2)}';
    return switch (capability) {
      AiCapability.transcription => '${usd(price.unit)} per minute',
      AiCapability.image => '${usd(price.unit)} per image',
      AiCapability.embeddings => '${usd(price.input)} per M tokens',
      _ => '${usd(price.input)} in · ${usd(price.output)} out per M tokens',
    };
  }

  Widget _chainRow(
    AiCapability capability,
    AiProviderPreset preset, {
    required bool first,
    required bool last,
    required double highlight,
  }) {
    final offered = preset.capabilities.contains(capability);
    if (capability == AiCapability.vision) {
      final writing = _models[AiCapability.chat]!.text.trim();
      return ModelChainRow(
        capability: capability,
        model: offered && writing.isNotEmpty ? writing : null,
        detail: offered
            ? 'Rides on the writing model'
            : 'Not offered by ${preset.name}',
        offered: offered,
        first: first,
        last: last,
        highlight: highlight,
      );
    }
    final model = _models[capability]!.text.trim();
    return ModelChainRow(
      capability: capability,
      model: model.isEmpty ? null : model,
      detail: !offered
          ? 'Not offered by ${preset.name}'
          : _priceLabel(capability) ??
                (capability == AiCapability.chat
                    ? 'Required'
                    : 'Off until you add a model'),
      offered: offered,
      first: first,
      last: last,
      highlight: highlight,
      onTap: offered && !_busy ? () => _openEditor(capability) : null,
    );
  }

  Future<void> _openEditor(AiCapability capability) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => ModelEditorSheet(
          capability: capability,
          controller: _models[capability]!,
          priceLabel: () => _priceLabel(capability),
          onPick: () => _pickModel(capability),
          onPrice: () async {
            final model = _models[capability]!.text.trim();
            if (model.isNotEmpty) await _editPrice(model, capability);
          },
        ),
      );

  String _keyStatus(AiProviderPreset preset, bool rejected) {
    if (_check != _Check.idle && _checkMessage != null) return _checkMessage!;
    if (rejected) return 'Your provider rejected this key.';
    if (_token.text.trim().isEmpty) {
      return preset.tokenRequired
          ? 'Needed before the Maestar can answer.'
          : 'Optional for ${preset.name}.';
    }
    return 'Not checked yet.';
  }

  Future<void> _openKeyEditor(AiProviderPreset preset) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => KeyEditorSheet(
        providerName: preset.name,
        baseUrl: _baseUrl,
        token: _token,
        tokenRequired: preset.tokenRequired,
        onGetKey: preset.keyUrl == null
            ? null
            : () => _openKeyPage(preset.keyUrl!),
      ),
    );
    // A changed key has not been checked.
    if (mounted && _check != _Check.checking) {
      setState(() {
        _check = _Check.idle;
        _checkMessage = null;
        _available = null;
      });
    }
  }

  Future<void> _otherLimit() async {
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => _LimitDialog(initial: _limit.text),
    );
    if (amount != null && mounted) _limit.text = _money(amount);
  }

  /// A link of the chain was touched: bring its card into view and let it glow.
  void _showLink(AiCapability capability) {
    final policy = RenderingPolicyScope.of(context);
    setState(() => _selected = capability);
    final card = _cardKeys[capability]!.currentContext;
    if (card != null) {
      unawaited(
        Scrollable.ensureVisible(
          card,
          alignment: .3,
          duration: policy.animate
              ? const Duration(milliseconds: 650)
              : Duration.zero,
          curve: Curves.easeInOutCubic,
        ),
      );
    }
    if (policy.animate) _pulse.forward(from: 0);
  }

  String _linkCaption(AiCloudSettings draft) {
    final selected = _selected;
    if (selected == null) return 'Your own key, kept on this phone.';
    final model = selected == AiCapability.vision
        ? draft.model(AiCapability.chat)
        : draft.model(selected);
    final metal = maestarMetalName(selected);
    return draft.supports(selected)
        ? '${selected.label} · $metal · $model'
        : !draft.preset.capabilities.contains(selected)
        ? '${selected.label} · $metal · not offered by ${draft.name}'
        : '${selected.label} · $metal · unforged';
  }

  @override
  Widget build(BuildContext context) {
    final draft = _read();
    final preset = _draft.preset;
    final saved = widget.saved;
    final keyRejected = ref.watch(aiKeyStatusProvider);
    final spent = ref.watch(aiMonthSpendProvider).value ?? 0;
    final savedLimit = saved?.monthlyLimitUsd ?? 0;
    final liveLimit = double.tryParse(_limit.text.trim()) ?? 0;
    final status = ref.watch(maestarStatusProvider);
    final embeddings = ref
        .watch(aiCapabilitiesProvider)
        .contains(AiCapability.embeddings);
    final palette = MorePalette.of(context);
    final policy = RenderingPolicyScope.of(context);
    final media = MediaQuery.of(context);
    final heroHeight =
        (media.size.height < 700 ? 300.0 : 380.0) + media.padding.top;
    final forged = {...maestarLinks.where(draft.supports)};
    final typography = DiaryTypography.of(context);

    final content = <Widget>[
      // The Maestar's name and the state of the chain.
      Text(
        'Grand Maestar',
        textAlign: TextAlign.center,
        style: typography.title.copyWith(color: palette.ink, fontSize: 40),
      ),
      const SizedBox(height: 8),
      Center(
        child: Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: (status.ready ? palette.accent : palette.muted).withValues(
                alpha: .1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status.ready ? palette.accent : palette.muted,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    status.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: status.ready ? palette.accent : palette.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      AnimatedSwitcher(
        duration: policy.duration,
        child: Text(
          _linkCaption(draft),
          key: ValueKey(_selected),
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.muted, fontSize: 13, height: 1.45),
        ),
      ),
      if (keyRejected)
        const MaestarNotice(
          icon: Icons.key_off_outlined,
          text: 'Your provider rejected the key. Check it below, then save. Search indexing is paused until then.',
        ),
      if (saved != null && savedLimit > 0 && spent >= savedLimit)
        const MaestarNotice(
          icon: Icons.savings_outlined,
          text: 'This month’s spending limit is reached, so AI requests are paused. Raise the limit to continue.',
        ),

      MaestarSection(
        numeral: 'I',
        eyebrow: 'The seal',
        title: 'Choose a provider',
        subtitle: 'The pips under each seal show which links that provider can forge.',
        child: ProviderSeals(
          selected: _draft.presetId,
          onSelect: _busy ? null : _choosePreset,
        ),
      ),

      MaestarSection(
        numeral: 'II',
        eyebrow: 'The key',
        title: 'Address and key',
        child: KeyRow(
          providerName: preset.name,
          token: _token.text.trim(),
          address: _baseUrl.text.trim().replaceFirst(RegExp(r'^https?://'), ''),
          status: _keyStatus(preset, keyRejected),
          checking: _check == _Check.checking,
          accepted: _check == _Check.connected,
          rejected: _check == _Check.failed || keyRejected,
          onEdit: _busy ? null : () => _openKeyEditor(preset),
          onTest: _busy ? null : _test,
          onGetKey: _token.text.trim().isEmpty && preset.keyUrl != null
              ? () => _openKeyPage(preset.keyUrl!)
              : null,
        ),
      ),

      MaestarSection(
        numeral: 'III',
        eyebrow: 'The chain',
        title: 'Forge the links',
        subtitle: 'One model per skill. Touch a link to change it.',
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final glow = policy.animate
                ? Curves.easeOut.transform(1 - (2 * _pulse.value - 1).abs())
                : .6;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, capability) in maestarLinks.indexed)
                  KeyedSubtree(
                    key: _cardKeys[capability],
                    child: _chainRow(
                      capability,
                      preset,
                      first: i == 0,
                      last: i == maestarLinks.length - 1,
                      highlight: _selected == capability ? glow : 0,
                    ),
                  ),
              ],
            );
          },
        ),
      ),

      MaestarSection(
        numeral: 'IV',
        eyebrow: 'The purse',
        title: 'Monthly spending',
        subtitle: 'An estimate. Your provider’s bill is the final word.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: PurseGauge(spent: spent, limit: liveLimit),
              ),
            ),
            const SizedBox(height: 24),
            LimitCoins(
              limit: liveLimit,
              onChoose: (value) => _limit.text = _money(value),
              onOther: _otherLimit,
            ),
          ],
        ),
      ),

      MaestarSection(
        numeral: 'V',
        eyebrow: 'The library',
        title: 'Search by meaning',
        child: LibraryDoorCard(
          ready: embeddings,
          onOpen: () => context.push('/settings/brain/library'),
        ),
      ),

      if (saved != null) ...[
        const SizedBox(height: 28),
        Center(
          child: TextButton.icon(
            onPressed: _busy ? null : _remove,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.link_off_rounded, size: 18),
            label: const Text('Remove provider'),
          ),
        ),
      ],
    ];

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            key: const ValueKey('ai-settings'),
            controller: _scroll,
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: heroHeight,
                backgroundColor: palette.ground,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                foregroundColor: palette.ink,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final min = media.padding.top + kToolbarHeight;
                    final collapse =
                        (1 - (constraints.maxHeight - min) / (heroHeight - min))
                            .clamp(0.0, 1.0);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: media.padding.top + kToolbarHeight * .4,
                          ),
                          child: MaestarStudy(
                            portrait: _portrait,
                            forged: forged,
                            selected: _selected,
                            onLink: _showLink,
                            collapse: collapse,
                          ),
                        ),
                        Positioned(
                          left: 56,
                          right: 56,
                          top: media.padding.top,
                          height: kToolbarHeight,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: ((collapse - .6) / .4).clamp(0.0, 1.0),
                              child: Center(
                                child: Text(
                                  'Grand Maestar',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: palette.ink),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: MoreSurface.contentWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: content,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _SaveBar(
          dirty: _dirty,
          busy: _busy,
          isNew: saved == null,
          message: _message,
          onSave: _busy ? null : _save,
        ),
      ],
    );
  }
}

/// Always within reach: what is unsaved, and the button that seals it.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirty,
    required this.busy,
    required this.isNew,
    required this.message,
    required this.onSave,
  });

  final bool dirty, busy, isNew;
  final String? message;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final text =
        message ??
        (isNew
            ? 'Not saved yet'
            : dirty
            ? 'Unsaved changes'
            : 'Everything is saved');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paper,
        border: Border(top: BorderSide(color: palette.rule)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: MoreSurface.contentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
              child: Row(
                children: [
                  if (dirty && message == null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.muted, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  dirty
                      ? FilledButton(
                          key: const ValueKey('ai-provider-save'),
                          onPressed: onSave,
                          child: Text(busy ? 'Saving…' : 'Save'),
                        )
                      : OutlinedButton(
                          key: const ValueKey('ai-provider-save'),
                          onPressed: onSave,
                          child: const Text('Save'),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns its fields, so they outlive the dialog's closing animation.
class _LimitDialog extends StatefulWidget {
  const _LimitDialog({required this.initial});
  final String initial;
  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _use() {
    final amount = double.tryParse(_field.text.trim());
    if (amount == null || amount.isNaN || amount < 0) return;
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Monthly limit'),
    content: TextField(
      key: const ValueKey('ai-monthly-limit'),
      controller: _field,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'USD per month (0 for no limit)',
        prefixText: r'$',
      ),
      onSubmitted: (_) => _use(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _use, child: const Text('Use limit')),
    ],
  );
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog({
    required this.model,
    required this.capability,
    required this.price,
  });
  final String model;
  final AiCapability capability;
  final AiPrice price;
  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  bool get _perUnit =>
      widget.capability == AiCapability.transcription ||
      widget.capability == AiCapability.image;
  late final _first = TextEditingController(
    text: '${_perUnit ? widget.price.unit : widget.price.input}',
  );
  late final _second = TextEditingController(text: '${widget.price.output}');

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Price for ${widget.model}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _first,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: widget.capability == AiCapability.transcription
                ? 'USD per minute of audio'
                : widget.capability == AiCapability.image
                ? 'USD per image'
                : 'USD per million input tokens',
          ),
        ),
        if (!_perUnit && widget.capability != AiCapability.embeddings)
          TextField(
            controller: _second,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          final a = double.tryParse(_first.text.trim());
          final b = double.tryParse(_second.text.trim()) ?? 0;
          if (a == null || a < 0 || b < 0) return;
          Navigator.pop(
            context,
            _perUnit ? AiPrice(unit: a) : AiPrice(input: a, output: b),
          );
        },
        child: const Text('Use price'),
      ),
    ],
  );
}
