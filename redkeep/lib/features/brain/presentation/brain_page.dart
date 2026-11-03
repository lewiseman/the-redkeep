import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_shell.dart';
import '../../../core/presentation/paper_surface.dart';
import '../application/brain_controller.dart';
import '../application/brain_providers.dart';
import '../domain/brain.dart';

class BrainPage extends ConsumerStatefulWidget {
  const BrainPage({super.key});
  @override
  ConsumerState<BrainPage> createState() => _BrainPageState();
}

class _BrainPageState extends ConsumerState<BrainPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(brainControllerProvider.notifier)
        .setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _remove(BrainModel model) async {
    final controller = ref.read(brainControllerProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Remove optional model?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                'This removes downloaded weights. Your writing and capability assignments stay saved. AI will need another download.',
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep model'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove model files'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) await controller.remove(model.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brainControllerProvider);
    final controller = ref.read(brainControllerProvider.notifier);
    final models = ref.watch(brainCatalogProvider);
    final canEdit = state.loaded && !state.busy;
    return AppShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Brain', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Optional AI on this device. Writing works without a model. Nothing loads until you explicitly run a test or request assistance.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Responses may be inaccurate or cut short. The small model uses CPU, with up to 96 output tokens. Review all output.',
          ),
          if (state.busy) ...[
            const SizedBox(height: 16),
            Text(
              state.operation ?? 'Finishing operation…',
              semanticsLabel: state.operation,
            ),
            if (state.operation == 'Downloading optional model')
              Text(
                '${(state.received / 1048576).toStringAsFixed(1)} MiB received; verification follows the download.',
              ),
            TextButton(
              onPressed: controller.cancel,
              child: const Text('Cancel operation'),
            ),
          ],
          if (state.failure != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(BrainException(state.failure!).message),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: state.busy ? null : controller.refresh,
            child: const Text('Check model files again'),
          ),
          for (final model in models) ...[
            const SizedBox(height: 16),
            PaperSurface(
              child: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      model.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${(model.bytes / 1048576).toStringAsFixed(2)} MiB download · Apache-2.0',
                    ),
                    const Text(
                      'Extra working memory and runtime cache space are needed. Installation does not prove this device can run it.',
                    ),
                    const SizedBox(height: 8),
                    Text(switch (state.files[model.id]) {
                      null => 'Files not checked',
                      ModelFileState.missing => 'Not installed',
                      ModelFileState.interrupted => 'Download interrupted. Retry starts a fresh verified download.',
                      ModelFileState.corrupt =>
                        'Damaged model file. Remove or download again.',
                      ModelFileState.available =>
                        'File verified · Ready for an explicit device test',
                    }),
                    if (state.files[model.id] != ModelFileState.available)
                      FilledButton(
                        onPressed: canEdit
                            ? () => controller.install(model.id)
                            : null,
                        child: const Text('Download optional model'),
                      ),
                    if (state.files[model.id] != null &&
                        state.files[model.id] != ModelFileState.missing)
                      OutlinedButton(
                        onPressed: canEdit ? () => _remove(model) : null,
                        child: const Text('Remove model'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          for (final capability in BrainCapability.values) ...[
            const SizedBox(height: 24),
            Text(
              capability.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(_assignmentLabel(state, models, capability)),
            for (final model in models.where(
              (m) => m.capabilities.contains(capability),
            ))
              OutlinedButton(
                onPressed: canEdit && state.assignments[capability] != model.id
                    ? () => controller.assign(capability, model.id)
                    : null,
                child: Text('Assign ${model.label}'),
              ),
            if (state.assignments[capability] != null) ...[
              TextButton(
                onPressed: canEdit
                    ? () => controller.assign(capability, null)
                    : null,
                child: Text('Clear ${capability.label.toLowerCase()}'),
              ),
              FilledButton(
                onPressed: canEdit && _ready(state, models, capability)
                    ? () => controller.testAssignment(capability)
                    : null,
                child: Text('Test ${capability.label.toLowerCase()}'),
              ),
            ],
          ],
          if (state.output.isNotEmpty || state.testPassed) ...[
            const SizedBox(height: 24),
            Text(
              state.testPassed
                  ? 'Synthetic test finished · Model released'
                  : 'Synthetic test output · Incomplete',
            ),
            const Text(
              'Test text: Mira planted a tree. She watered it each morning. New leaves appeared.',
            ),
            SelectableText(state.output),
          ],
        ],
      ),
    );
  }

  bool _ready(
    BrainState state,
    List<BrainModel> models,
    BrainCapability capability,
  ) => models.any(
    (model) =>
        model.id == state.assignments[capability] &&
        model.capabilities.contains(capability) &&
        state.files[model.id] == ModelFileState.available,
  );

  String _assignmentLabel(
    BrainState state,
    List<BrainModel> models,
    BrainCapability capability,
  ) {
    final id = state.assignments[capability];
    if (id == null) return 'No model assigned';
    for (final model in models) {
      if (model.id == id) {
        if (!model.capabilities.contains(capability)) {
          return 'Incompatible assignment. Choose another model.';
        }
        return 'Device · ${model.label} · ${state.files[id] == ModelFileState.available ? 'File ready' : 'Needs a verified download'}';
      }
    }
    return 'Assigned model is unavailable. Choose another model.';
  }
}
