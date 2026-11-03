import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assets/domain/asset_catalog.dart';
import 'bootstrap_controller.dart';

class StartupPage extends ConsumerWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bootstrapControllerProvider);
    final controller = ref.read(bootstrapControllerProvider.notifier);
    final downloading = state.stage == BootstrapStage.downloading;
    final checking = state.stage == BootstrapStage.checking;
    final localError = state.stage == BootstrapStage.localError;
    final progress = state.progress;
    final fraction = progress == null || progress.totalBytes <= 0
        ? 0.0
        : (progress.completedBytes / progress.totalBytes).clamp(0.0, 1.0);
    const ink = Color(0xFF433548);
    const mutedInk = Color(0xFF65576A);
    const purple = Color(0xFF715B83);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        systemNavigationBarColor: const Color(0xFFF2E7D2),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2E7D2),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/branding/ink-paper.webp',
              key: const ValueKey('startup-background'),
              cacheWidth: 1024,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              excludeFromSemantics: true,
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final logoHeight = (constraints.maxHeight * .22).clamp(
                    88.0,
                    160.0,
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.maxHeight - 48),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Image.asset(
                                'assets/branding/grand_maestar.png',
                                key: const ValueKey('startup-logo'),
                                height: logoHeight,
                                cacheHeight:
                                    (logoHeight *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
                                        .ceil(),
                                excludeFromSemantics: true,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'REDKEEP',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: mutedInk,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                checking
                                    ? 'Opening Redkeep'
                                    : localError
                                    ? 'Redkeep could not open'
                                    : 'Prepare your artwork',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall!
                                    .copyWith(
                                      color: ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  checking
                                      ? 'Checking your saved settings and local artwork…'
                                      : localError
                                      ? state.failure == null
                                            ? 'Local checks could not finish. Retry when your device is ready. Your saved writing is kept.'
                                            : _failureMessage(state.failure!)
                                      : downloading
                                      ? 'Downloading and verifying artwork…'
                                      : state.failure == null
                                      ? 'A little preparation for your pages. Download your artwork once, then enjoy it offline.'
                                      : _failureMessage(state.failure!),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: mutedInk,
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              if (!localError) ...[
                                const SizedBox(height: 28),
                                LinearProgressIndicator(
                                  value: fraction,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(16),
                                  color: purple,
                                  backgroundColor: const Color(0xFFD9CFCC),
                                  stopIndicatorRadius: 0,
                                  semanticsLabel: 'Artwork download progress',
                                  semanticsValue:
                                      '${(fraction * 100).floor()}%',
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  progress != null
                                      ? '${(fraction * 100).floor()}% · ${_bytes(progress.completedBytes)} of ${_bytes(progress.totalBytes)}'
                                      : downloading
                                      ? 'Connecting to the artwork service…'
                                      : checking
                                      ? 'Checking local files'
                                      : 'Ready when you are',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: mutedInk,
                                    fontSize: 13,
                                    height: 1.5,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                              if (!checking && !downloading) ...[
                                const SizedBox(height: 28),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: purple,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 52),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: localError
                                      ? controller.repair
                                      : controller.download,
                                  child: Text(
                                    localError
                                        ? 'Retry local checks'
                                        : state.failure == null
                                        ? 'Download artwork'
                                        : 'Retry download',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (!localError)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: ink,
                                      minimumSize: const Size(0, 48),
                                    ),
                                    onPressed: controller.check,
                                    child: const Text(
                                      'Check local files again',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _bytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _failureMessage(AssetFailure failure) => switch (failure) {
  AssetFailure.configuration => 'This build has no usable artwork service. Install a build with a configured service, or retry when it is available.',
  AssetFailure.storage => 'Artwork could not be saved. Free some device storage and retry. Your saved writing is kept.',
  AssetFailure.integrity => 'An artwork download was incomplete or damaged. Retry to verify a fresh copy.',
  AssetFailure.catalog =>
    'The artwork catalog is invalid. Install an updated build and retry.',
  _ => 'Artwork could not be downloaded. Check your connection and retry. Completed artwork is kept.',
};
