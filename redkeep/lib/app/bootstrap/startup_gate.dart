import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assets/domain/asset_catalog.dart';
import '../app_shell.dart';
import 'bootstrap_controller.dart';

class StartupGate extends ConsumerWidget {
  const StartupGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bootstrapControllerProvider);
    if (state.stage == BootstrapStage.ready) return child;
    final controller = ref.read(bootstrapControllerProvider.notifier);
    final downloading = state.stage == BootstrapStage.downloading;
    final checking = state.stage == BootstrapStage.checking;
    final localError = state.stage == BootstrapStage.localError;
    final progress = state.progress;
    return AppShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            checking
                ? 'Opening Redkeep'
                : localError
                ? 'Redkeep could not open'
                : 'Prepare your artwork',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              checking
                  ? 'Checking saved settings and local artwork…'
                  : localError
                  ? state.failure == null
                        ? 'Local checks could not finish. Retry when your device is ready. Your saved writing is kept.'
                        : _failureMessage(state.failure!)
                  : downloading
                  ? 'Downloading and verifying artwork…'
                  : state.failure == null
                  ? 'Required artwork must finish downloading before you can enter. Completed files stay on your device for offline use.'
                  : _failureMessage(state.failure!),
            ),
          ),
          if (downloading) ...[
            const SizedBox(height: 16),
            if (progress != null) ...[
              LinearProgressIndicator(
                value: progress.completedBytes / progress.totalBytes,
              ),
              const SizedBox(height: 8),
              Text(
                '${progress.completedBytes} of ${progress.totalBytes} bytes',
              ),
            ] else
              const Text('Connecting to the artwork service…'),
          ],
          if (!checking && !downloading) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: localError ? controller.repair : controller.download,
              child: Text(
                localError
                    ? 'Retry local checks'
                    : state.failure == null
                    ? 'Download artwork'
                    : 'Retry download',
              ),
            ),
            if (!localError)
              TextButton(
                onPressed: controller.check,
                child: const Text('Check local files again'),
              ),
          ],
        ],
      ),
    );
  }
}

String _failureMessage(AssetFailure failure) => switch (failure) {
  AssetFailure.configuration => 'This build has no usable artwork service. Install a build with a configured service, or retry when it is available.',
  AssetFailure.storage => 'Artwork could not be saved. Free some device storage and retry. Your saved writing is kept.',
  AssetFailure.integrity => 'An artwork download was incomplete or damaged. Retry to verify a fresh copy.',
  AssetFailure.catalog =>
    'The artwork catalog is invalid. Install an updated build and retry.',
  _ => 'Artwork could not be downloaded. Check your connection and retry. Completed artwork is kept.',
};
