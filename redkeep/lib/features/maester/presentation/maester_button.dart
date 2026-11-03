import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../brain/domain/brain.dart';
import '../application/maester_controller.dart';
import '../domain/maester_source.dart';

/// The floating control owns the dialog, provenance and lifecycle together.
/// Its provider is not created until the user opens it.
class MaesterButton extends ConsumerStatefulWidget {
  const MaesterButton({
    super.key,
    required this.source,
    required this.validate,
    this.accept,
    this.openEditor,
    this.isCurrent,
  });
  final MaesterSource? source;
  final Future<bool> Function(MaesterSource) validate;
  final Future<bool> Function(MaesterProposal, bool Function())? accept;
  final VoidCallback? openEditor;
  final bool Function()? isCurrent;
  @override
  ConsumerState<MaesterButton> createState() => _MaesterButtonState();
}

class _MaesterButtonState extends ConsumerState<MaesterButton>
    with WidgetsBindingObserver {
  late final _context = MaesterContext(
    current: () => widget.isCurrent?.call() == false ? null : widget.source,
    validate: (source) => widget.validate(source),
    accept: (proposal, valid) async =>
        await widget.accept?.call(proposal, valid) ?? false,
  );
  late final _provider = maesterControllerProvider(_context);
  MaesterController? _controller;
  ProviderSubscription<MaesterState>? _subscription;
  DialogRoute<void>? _dialog;
  GoRouter? _router;
  String? _location;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(MaesterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source?.matches(widget.source) != true) {
      // Providers may be publishing the new feature snapshot during this build.
      scheduleMicrotask(() {
        if (mounted) _controller?.sourceChanged();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller?.setForeground(state == AppLifecycleState.resumed);
  }

  void _routeChanged() {
    if (_router?.routeInformationProvider.value.uri.toString() != _location) {
      unawaited(_controller?.cancel());
      _closeDialog();
    }
  }

  void _closeDialog() {
    final dialog = _dialog;
    if (dialog == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routeInformationProvider.removeListener(_routeChanged);
    // Do not retain private generated text or a provider after its source view.
    _controller?.detach();
    _closeDialog();
    super.dispose();
  }

  Future<void> _open() async {
    if (_dialog != null) return;
    _subscription = ref.listenManual(_provider, (_, _) {});
    _router = GoRouter.of(context);
    _location = _router!.routeInformationProvider.value.uri.toString();
    _router!.routeInformationProvider.addListener(_routeChanged);
    final dialog = DialogRoute<void>(
      context: context,
      requestFocus: false,
      animationStyle: AnimationStyle.noAnimation,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(_provider);
          final controller = ref.read(_provider.notifier);
          _controller = controller;
          return _MaesterDialog(
            state: state,
            source: widget.source,
            run: controller.run,
            refresh: controller.refresh,
            cancel: controller.cancel,
            accept: widget.accept == null
                ? null
                : () async {
                    if (await controller.accept() && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
            close: () => Navigator.of(dialogContext).pop(),
            setup: () {
              Navigator.of(dialogContext).pop();
              _router!.go('/settings/brain');
            },
            openEditor: widget.openEditor == null
                ? null
                : () {
                    Navigator.of(dialogContext).pop();
                    widget.openEditor!();
                  },
          );
        },
      ),
    );
    _dialog = dialog;
    final closed = Navigator.of(context).push(dialog);
    // Readiness is checked only after opening the explicit helper surface.
    scheduleMicrotask(() {
      if (mounted && _dialog == dialog) {
        final controller = ref.read(_provider.notifier);
        _controller = controller;
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        controller.setForeground(
          lifecycle == null || lifecycle == AppLifecycleState.resumed,
        );
        unawaited(controller.refresh());
      }
    });
    await closed;
    _router?.routeInformationProvider.removeListener(_routeChanged);
    if (mounted) {
      await _controller?.cancel();
      _controller = null;
      _subscription?.close();
      _subscription = null;
      ref.invalidate(_provider);
    }
    _dialog = null;
  }

  @override
  Widget build(BuildContext context) => FloatingActionButton(
    heroTag: null,
    tooltip: 'Grand Maester',
    onPressed: _open,
    child: const Icon(Icons.auto_fix_high_outlined),
  );
}

class _MaesterDialog extends StatefulWidget {
  const _MaesterDialog({
    required this.state,
    required this.source,
    required this.run,
    required this.refresh,
    required this.cancel,
    required this.close,
    required this.setup,
    this.accept,
    this.openEditor,
  });
  final MaesterState state;
  final MaesterSource? source;
  final Future<void> Function(BrainCapability) run;
  final Future<void> Function() refresh;
  final Future<void> Function() cancel;
  final Future<void> Function()? accept;
  final VoidCallback close;
  final VoidCallback setup;
  final VoidCallback? openEditor;
  @override
  State<_MaesterDialog> createState() => _MaesterDialogState();
}

class _MaesterDialogState extends State<_MaesterDialog> {
  String? _copyStatus;
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final source = widget.source;
    final proposal = state.proposal;
    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Grand Maester',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Optional assistance on this device. Responses can invent details or end early. Review before using them.',
            ),
            if (source == null)
              const Text('No available writing on this screen.')
            else if (source.text.trim().isEmpty)
              const Text('Write some text first.')
            else ...[
              Text(
                '${source.selected ? 'Selected passage' : 'Body text'} · ${source.text.length} / 2,000 characters',
              ),
              if (!source.bounded)
                const Text(
                  'Select a shorter passage in the editor. Up to 2,000 characters can be used at once.',
                ),
              for (final capability in source.actions) ...[
                FilledButton(
                  onPressed:
                      state.busy ||
                          !source.bounded ||
                          !state.ready.containsKey(capability)
                      ? null
                      : () {
                          setState(() => _copyStatus = null);
                          unawaited(widget.run(capability));
                        },
                  child: Text(_label(capability, state.failure != null)),
                ),
                if (!state.busy && !state.ready.containsKey(capability))
                  Text('${capability.label}: needs setup in Brain.'),
              ],
            ],
            if (state.busy)
              Text(
                state.checking
                    ? 'Checking Brain readiness…'
                    : 'Working on this device…',
              ),
            if (state.expired)
              Semantics(
                liveRegion: true,
                child: Text(
                  'The source or selection changed. This result has expired. Request assistance again for the current text.',
                ),
              ),
            if (state.failure != null)
              Semantics(
                liveRegion: true,
                child: Text(BrainException(state.failure!).message),
              ),
            if (widget.openEditor != null)
              OutlinedButton(
                onPressed: state.busy ? null : widget.openEditor,
                child: Text(
                  source?.kind == MaesterKind.note
                      ? 'Rewrite in editor'
                      : 'Select text in editor',
                ),
              ),
            if (state.output.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                proposal == null
                    ? 'Response · incomplete'
                    : proposal.capability == BrainCapability.rewrite
                    ? 'Proposed replacement'
                    : 'Response · review before copying',
              ),
              SelectableText(state.output),
            ],
            if (proposal != null) ...[
              if (proposal.capability == BrainCapability.rewrite) ...[
                const SizedBox(height: 12),
                const Text('Captured source passage'),
                SelectableText(proposal.source.text),
                const Text(
                  'Accept replaces this passage in your recovery draft. Save the note separately to commit it.',
                ),
                FilledButton(
                  onPressed: state.busy ? null : widget.accept,
                  child: const Text('Accept replacement'),
                ),
              ],
              OutlinedButton(
                onPressed: state.busy
                    ? null
                    : () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(text: proposal.output),
                          );
                          if (mounted) {
                            setState(() => _copyStatus = 'Response copied.');
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => _copyStatus = 'Copy failed. Select the response to copy it again.',
                            );
                          }
                        }
                      },
                child: const Text('Copy response'),
              ),
            ],
            if (_copyStatus != null)
              Semantics(liveRegion: true, child: Text(_copyStatus!)),
            if (state.busy)
              TextButton(
                onPressed: widget.cancel,
                child: const Text('Cancel response'),
              ),
            OutlinedButton(
              onPressed: state.busy ? null : widget.setup,
              child: const Text('Open Brain'),
            ),
            TextButton(
              onPressed: state.busy ? null : widget.refresh,
              child: const Text('Check readiness again'),
            ),
            TextButton(
              onPressed: widget.close,
              child: Text(
                proposal?.capability == BrainCapability.rewrite
                    ? 'Reject proposal'
                    : 'Close helper',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(BrainCapability capability, bool retry) =>
      '${retry ? 'Retry: ' : ''}${switch (capability) {
        BrainCapability.rewrite => 'Rewrite passage',
        BrainCapability.summarize => 'Summarize text',
        BrainCapability.reflect => 'Reflect on thought',
      }}';
}
