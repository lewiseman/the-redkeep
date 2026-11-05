import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/rendering_policy.dart';
import '../../features/assets/domain/asset_catalog.dart';
import '../../features/diary/presentation/diary_paper_stamp.dart';
import '../../features/diary/presentation/photos/diary_photo_entry_book.dart'
    show DiaryAlbumMarginPainter;
import 'bootstrap_controller.dart';
import 'startup_handoff.dart';

/// The tallest sheet at normal text size, used only to place the logo.
const _sheetHeight = 190.0;

const _sand = Color(0xFFF2E7D2);
const _paper = Color(0xFFFBF7EE);
const _ink = Color(0xFF433548);
const _mutedInk = Color(0xFF65576A);
const _purple = Color(0xFF715B83);
const _lavender = Color(0xFFE7DDEE);

class StartupPage extends ConsumerWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bootstrapControllerProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        systemNavigationBarColor: _sand,
      ),
      child: Scaffold(
        backgroundColor: _sand,
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
                  final logoGap = math.max(
                    0.0,
                    (constraints.maxHeight - logoHeight - 48 - _sheetHeight) /
                        2,
                  );
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                        minHeight: constraints.maxHeight,
                      ),
                      // The logo's gap ignores the sheet's current height, so it
                      // holds still as the sheet changes between states.
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24)
                                .add(EdgeInsets.only(top: logoGap)),
                            child: StartupHandoffLogo(
                              child: Image.asset(
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
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: StartupHandoffExit(
                                child: _ArtworkPaper(state: state),
                              ),
                            ),
                          ),
                        ],
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

/// The diary review page's sheet, in fixed colors because the artwork behind
/// it is the same light paper in every theme.
class _ArtworkPaper extends StatelessWidget {
  const _ArtworkPaper({required this.state});

  final BootstrapState state;

  @override
  Widget build(BuildContext context) {
    // Most launches finish here, so only the logo shows and no sheet flashes.
    if (state.stage == BootstrapStage.checking) {
      return Semantics(
        liveRegion: true,
        label: 'Opening Redkeep',
        child: const SizedBox.shrink(),
      );
    }
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!simple)
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(3, 5),
              child: Transform.rotate(
                angle: .008,
                child: const CustomPaint(
                  painter: DiaryPaperStamp(
                    paper: _lavender,
                    ink: _ink,
                    shadow: false,
                    edgeScale: .5,
                    variant: 2,
                  ),
                ),
              ),
            ),
          ),
        CustomPaint(
          painter: DiaryPaperStamp(
            paper: _paper,
            ink: _ink,
            edgeScale: simple ? 0 : .65,
            shadow: !simple,
            variant: 1,
          ),
          foregroundPainter: const DiaryAlbumMarginPainter(ink: _ink),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 22, 20),
            child: _ArtworkStatus(state: state),
          ),
        ),
      ],
    );
  }
}

class _ArtworkStatus extends ConsumerWidget {
  const _ArtworkStatus({required this.state});

  final BootstrapState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bootstrapControllerProvider.notifier);
    // A finished page stays visible briefly as onboarding fades in over it.
    final ready = state.stage == BootstrapStage.ready;
    final downloading = ready || state.stage == BootstrapStage.downloading;
    final localError = state.stage == BootstrapStage.localError;
    final progress = state.progress;
    final fraction = ready
        ? 1.0
        : progress == null || progress.totalBytes <= 0
        ? 0.0
        : (progress.completedBytes / progress.totalBytes).clamp(0.0, 1.0);
    final percent = '${(fraction * 100).floor()}%';
    final (title, line) = _copy(state);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge!
                    .copyWith(color: _ink, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                line,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _mutedInk,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // The bar and the button share a slot so the sheet keeps its height.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Center(
            child: downloading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(16),
                        color: _purple,
                        backgroundColor: _ink.withValues(alpha: .12),
                        stopIndicatorRadius: 0,
                        semanticsLabel: 'Setup progress',
                        semanticsValue: percent,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        progress != null
                            ? '$percent · ${_bytes(progress.completedBytes)} of ${_bytes(progress.totalBytes)}'
                            : ready
                            ? percent
                            : 'Connecting…',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _mutedInk,
                          fontSize: 13,
                          height: 1.4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                      ),
                      onPressed: localError
                          ? controller.repair
                          : controller.download,
                      child: const Text(
                        'Try again',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

String _bytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

(String, String) _copy(BootstrapState state) {
  const space = 'Free up some space, then try again.';
  if (state.stage == BootstrapStage.localError) {
    return (
      "Redkeep couldn't open",
      state.failure == AssetFailure.storage
          ? 'Your writing is safe. $space'
          : 'Your writing is safe. Please try again.',
    );
  }
  if (state.stage == BootstrapStage.download) {
    return switch (state.failure) {
      AssetFailure.storage => (
        'Not enough space',
        '$space Your progress is saved.',
      ),
      AssetFailure.configuration || AssetFailure.catalog => (
        'Redkeep needs an update',
        'Install the latest version to finish setting up.',
      ),
      AssetFailure.integrity => (
        'Setup paused',
        'Something went wrong. Please try again.',
      ),
      null => ('Getting things ready', 'This only happens once.'),
      _ => (
        'Setup paused',
        'Check your connection and try again. Your progress is saved.',
      ),
    };
  }
  return ('Getting things ready', 'This only happens once.');
}
