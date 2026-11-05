import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../companion/presentation/ai_studio_material.dart';
import '../../companion/presentation/companion_hub_widgets.dart';
import '../application/ai_jobs.dart';
import '../application/ai_providers.dart';
import '../data/http_ai_provider_client.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_provider_catalog.dart';

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
  bool _loading = true, _missing = false, _busy = false;
  String? _message;

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
      if (widget.id != null) {
        _saved = saved.where((p) => p.id == widget.id).firstOrNull;
        _missing = _saved == null;
        _preset = aiProviderPreset(_saved?.presetId ?? '');
        _name.text = _saved?.name ?? '';
        _url.text = _saved?.baseUrl ?? '';
      } else {
        _preset = aiProviderPreset(widget.presetId ?? '');
        _missing = _preset == null;
        _name.text = _preset == customAiProviderPreset
            ? ''
            : _preset?.name ?? '';
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
      id: ref.read(aiIdProvider)(),
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
      return 'Enter the token from your provider account.';
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

  Future<void> _test(AiProviderConnection draft) async {
    final models = await ref
        .read(aiProviderClientProvider)
        .listModels(draft, abort: _abort.future);
    if (mounted) {
      setState(() {
        _message = models.isEmpty
            ? 'Connected. This provider listed no models, so type a model name when you assign a task.'
            : 'Connected. ${models.length} models available.';
      });
    }
  }

  Future<void> _save(AiProviderConnection draft) async {
    await ref.read(aiProvidersProvider.notifier).save(draft);
    if (mounted) context.pop();
  }

  Future<void> _remove() async {
    final saved = _saved!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${saved.name}?'),
        content: const Text(
          'Its token is deleted from this phone. Tasks using it return to your default, and a default using it returns to your computer.',
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

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    final hasSavedToken = saved != null && saved.token.isNotEmpty;
    return CompanionDetailLayout(
      title: saved?.name ?? _preset?.name ?? 'AI provider',
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_missing)
          const Text('This provider is no longer saved on this phone.')
        else ...[
          const CompanionDetailHeading(
            icon: Icons.key_outlined,
            title: 'Connect with your own token',
            description: 'Tasks you assign here send their text to this provider, under your account and its terms.',
          ),
          AiStudioCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('ai-provider-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('ai-provider-url'),
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    helperText: 'Must start with https://',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('ai-provider-token'),
                  controller: _token,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Token',
                    helperMaxLines: 3,
                    helperText: hasSavedToken
                        ? 'A token is saved and can’t be shown. Type a new one to replace it.'
                        : _preset?.tokenRequired == false
                        ? 'Leave empty if this server needs none.'
                        : null,
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _message!,
                      key: const ValueKey('ai-provider-message'),
                    ),
                  ),
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
                      child: const Text('Test connection'),
                    ),
                    if (saved != null)
                      TextButton(
                        key: const ValueKey('ai-provider-remove'),
                        onPressed: _busy ? null : _remove,
                        child: const Text('Remove'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
