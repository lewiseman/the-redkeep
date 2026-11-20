import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/rendering_policy.dart';
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
    // Launches normally show only the logo; the sheet is for a failed open.
    if (state.stage != BootstrapStage.localError) {
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
            child: const _ArtworkStatus(),
          ),
        ),
      ],
    );
  }
}

class _ArtworkStatus extends ConsumerWidget {
  const _ArtworkStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bootstrapControllerProvider.notifier);
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
                "Redkeep couldn't open",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge!
                    .copyWith(color: _ink, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your writing is safe. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _mutedInk, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
          ),
          onPressed: controller.check,
          child: const Text('Try again', textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
