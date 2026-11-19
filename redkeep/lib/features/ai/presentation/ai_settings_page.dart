import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/pen_squiggle.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/ai_cloud.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_provider_catalog.dart';
import 'maestar_chain_rows.dart';
import '../../more/presentation/notifications_switch.dart';
import 'maestar_key.dart';
import 'maestar_study.dart';
import 'settings_parts.dart';

const _portrait = AssetImage('assets/branding/grand_maestar.png');

/// Settings: the Maestar's study, the one OpenAI-compatible service and its
/// models, notifications, the small print and the maker's mark. Each change
/// is kept the moment it is made; there is nothing to remember to save.
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
          appBar: AppBar(title: const Text('Settings')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
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
        data: (value) => _AiSettingsForm(saved: value),
      ),
    );
  }
}

class _AiSettingsForm extends ConsumerStatefulWidget {
  const _AiSettingsForm({required this.saved});

  /// The settings on the phone; null until a service is first kept.
  final AiCloudSettings? saved;
  @override
  ConsumerState<_AiSettingsForm> createState() => _AiSettingsFormState();
}

class _AiSettingsFormState extends ConsumerState<_AiSettingsForm>
    with SingleTickerProviderStateMixin {
  late final _cardKeys = {
    for (final capability in _modelCapabilities) capability: GlobalKey(),
  };
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final _scroll = ScrollController();
  KeyState _check = KeyState.idle;
  String? _checkMessage;
  List<String>? _available;
  Completer<void>? _abort;
  AiCapability? _selected;

  /// The links that can be forged. Images ride on the writing model, so they
  /// have no model of their own and no row here.
  static const _modelCapabilities = [
    AiCapability.chat,
    AiCapability.transcription,
  ];

  /// What is on the phone, or what a first service starts from.
  AiCloudSettings get _settings =>
      widget.saved ?? AiCloud.starter(aiProviderCatalog.first.id);

  @override
  void didUpdateWidget(_AiSettingsForm old) {
    super.didUpdateWidget(old);
    final before = old.saved, after = widget.saved;
    // A different address or key has not been checked.
    if (before?.baseUrl != after?.baseUrl || before?.token != after?.token) {
      _cancelRequest();
      _check = KeyState.idle;
      _checkMessage = null;
      _available = null;
    }
  }

  @override
  void dispose() {
    _cancelRequest();
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _cancelRequest() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _abort = null;
  }

  /// Keeps [next] on the phone; returns a message when it could not.
  Future<String?> _keep(AiCloudSettings next) async {
    try {
      await ref.read(aiCloudSettingsProvider.notifier).save(next);
      return null;
    } on AiProviderFailure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'Could not keep it. Unlock the phone and try again.';
    }
  }

  /// Keeps a new address and key, recognising the service from the
  /// address, then checks the key straight away.
  Future<String?> _keepKey(String address, String token) async {
    final current = _settings;
    final preset = aiProviderPresetForAddress(address);
    final changedService = preset.id != current.presetId;
    final next = AiCloudSettings(
      presetId: preset.id,
      baseUrl: address,
      token: token,
      // A different service starts from its own models, when it has any.
      models: changedService && preset.defaultModels.isNotEmpty
          ? preset.defaultModels
          : current.models,
    );
    final error = await _keep(next);
    if (error == null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_models());
      });
    }
    return error;
  }

  Future<String?> _keepModel(AiCapability capability, String? model) {
    final current = _settings;
    return _keep(
      current.copyWith(
        models: {
          for (final e in current.models.entries)
            if (e.key != capability) e.key: e.value,
          if (model != null && model.trim().isNotEmpty)
            capability: model.trim(),
        },
      ),
    );
  }

  Future<void> _forget() async {
    _cancelRequest();
    await ref.read(aiCloudSettingsProvider.notifier).clear();
  }

  /// Lists the provider's models, which also checks the address and key.
  Future<List<String>> _models() async {
    final known = _available;
    if (known != null) return known;
    _cancelRequest();
    final abort = _abort = Completer<void>();
    if (mounted) {
      setState(() {
        _check = KeyState.checking;
        _checkMessage = 'Checking your key…';
      });
    }
    try {
      final models = [
        ...await ref
            .read(aiCloudProvider)
            .listModels(_settings, abort: abort.future),
      ]..sort();
      if (mounted) {
        setState(() {
          _available = models;
          _check = KeyState.accepted;
          _checkMessage = models.length == 1
              ? 'Accepted. 1 model to choose from.'
              : 'Accepted. ${models.length} models to choose from.';
        });
      }
      return models;
    } on AiProviderFailure catch (failure) {
      if (mounted) {
        setState(() {
          _check = KeyState.rejected;
          _checkMessage = failure.message;
        });
      }
      rethrow;
    } catch (_) {
      if (mounted) {
        setState(() {
          _check = KeyState.rejected;
          _checkMessage = 'Could not reach your service. Try again.';
        });
      }
      rethrow;
    } finally {
      if (identical(_abort, abort)) _abort = null;
    }
  }

  Future<void> _recheck() async {
    _available = null;
    try {
      await _models();
    } catch (_) {
      /* Shown in the key's status line. */
    }
  }

  Future<void> _openKey() => showPaperSheet<void>(
    context,
    (context) => KeySheet(
      address: _settings.baseUrl,
      token: _settings.token,
      onKeep: _keepKey,
      onForget: widget.saved == null ? null : _forget,
    ),
  );

  Future<void> _openModel(AiCapability capability) => showPaperSheet<void>(
    context,
    (context) => ModelSheet(
      capability: capability,
      current: _settings.model(capability),
      providerName: _serviceName,
      load: _models,
      onChoose: (model) => _keepModel(capability, model),
    ),
  );

  String get _serviceName {
    final preset = aiProviderPresetForAddress(_settings.baseUrl);
    return preset == customAiProviderPreset ? 'your service' : preset.name;
  }

  String _keyStatus(bool rejected) {
    final message = _checkMessage;
    if (_check != KeyState.idle && message != null) return message;
    if (rejected) return 'Your service turned this key away. Check it.';
    if (_settings.token.isEmpty) {
      return _settings.preset.tokenRequired
          ? 'Add a key before the Maestar can answer.'
          : 'A key is optional for this service.';
    }
    return 'Not checked yet.';
  }

  Widget _chainRow(
    AiCapability capability, {
    required bool first,
    required bool last,
    required double highlight,
  }) {
    final settings = _settings;
    final offered = settings.preset.capabilities.contains(capability);
    final model = settings.model(capability);
    return ModelChainRow(
      capability: capability,
      model: model,
      detail: !offered
          ? 'Not offered by ${settings.preset.name}'
          : model != null
          ? 'Forged'
          : capability == AiCapability.chat
          ? 'Needed for writing help'
          : 'Off until you choose a model',
      offered: offered,
      first: first,
      last: last,
      highlight: highlight,
      onTap: offered ? () => _openModel(capability) : null,
    );
  }

  /// A link of the chain was touched: bring its row into view and let it
  /// glow. Images ride on the writing link.
  void _showLink(AiCapability capability) {
    final shown = capability == AiCapability.vision
        ? AiCapability.chat
        : capability;
    final policy = RenderingPolicyScope.of(context);
    setState(() => _selected = capability);
    final card = _cardKeys[shown]?.currentContext;
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

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final keyRejected = ref.watch(aiKeyStatusProvider);
    final palette = MorePalette.of(context);
    final policy = RenderingPolicyScope.of(context);
    final media = MediaQuery.of(context);
    final heroHeight =
        (media.size.height < 700 ? 300.0 : 380.0) + media.padding.top;
    final forged = {...maestarLinks.where(settings.supports)};
    final typography = DiaryTypography.of(context);

    final content = <Widget>[
      // Just the page's name: the study above is decoration, and what
      // follows says what each part is for.
      Semantics(
        header: true,
        child: Text(
          'Settings',
          textAlign: TextAlign.center,
          style: typography.title.copyWith(color: palette.ink, fontSize: 44),
        ),
      ),
      Center(
        child: ExcludeSemantics(
          child: CustomPaint(
            size: const Size(120, 12),
            painter: PenSquiggle(palette.accent, 1),
          ),
        ),
      ),

      const SettingsHeading(
        'Your key',
        note: 'Any OpenAI-compatible service. Your key never leaves this phone, except to reach it.',
      ),
      KeyCard(
        address: settings.baseUrl,
        token: settings.token,
        status: _keyStatus(keyRejected),
        state: keyRejected && _check == KeyState.idle
            ? KeyState.rejected
            : _check,
        onEdit: _openKey,
        onCheck: _check == KeyState.checking ? null : _recheck,
      ),

      const SettingsHeading(
        'The chain',
        note: 'One model for each skill. Touch a link to change it.',
      ),
      SettingsCushion(
        padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final glow = policy.animate
                ? Curves.easeOut.transform(1 - (2 * _pulse.value - 1).abs())
                : .6;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, capability) in _modelCapabilities.indexed)
                  KeyedSubtree(
                    key: _cardKeys[capability],
                    child: _chainRow(
                      capability,
                      first: i == 0,
                      last: i == _modelCapabilities.length - 1,
                      highlight:
                          _selected == capability ||
                              (_selected == AiCapability.vision &&
                                  capability == AiCapability.chat)
                          ? glow
                          : 0,
                    ),
                  ),
              ],
            );
          },
        ),
      ),

      const SettingsHeading(
        'Ravens',
        note: 'What may reach you when Redkeep is closed.',
      ),
      const SettingsCushion(
        padding: EdgeInsets.fromLTRB(18, 4, 10, 4),
        child: NotificationsSwitch(),
      ),

      const SettingsHeading('The small print'),
      const SmallPrint(),

      const BuiltBy(),
    ];

    final barBottom = media.padding.top + kToolbarHeight;
    final scrollAway = heroHeight - barBottom;
    return Stack(
      children: [
        Positioned.fill(
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
                                  'Settings',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.title.copyWith(
                                    color: palette.ink,
                                    fontSize: 26,
                                  ),
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: MoreSurface.contentWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
        // Once the study has gone, the bar thins away below its edge, so the
        // page passes under it without a line.
        Positioned(
          top: barBottom,
          left: 0,
          right: 0,
          height: 30,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _scroll,
              builder: (context, _) {
                final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                final shown = ((offset - scrollAway + 24) / 24).clamp(0.0, 1.0);
                if (shown == 0) return const SizedBox.shrink();
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, .25, .5, .75, 1],
                      colors: [
                        for (final a in const [1.0, .82, .5, .18, 0.0])
                          palette.ground.withValues(alpha: a * shown),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
