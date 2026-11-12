import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../data/note_media_store.dart';
import '../domain/note_document.dart';
import '../domain/note_colors.dart';
import 'edit_note_page_bg.dart';
import 'note_ai_palette.dart';

final noteBackgroundImageProvider = FutureProvider.autoDispose
    .family<ImageProvider?, String>((ref, key) async {
      File? file;
      if (key.startsWith('note_media/')) {
        file = await ref.watch(noteMediaStoreProvider).resolve(key);
      } else {
        final uri = await (await ref.watch(assetResolverProvider)).resolve(key);
        file = File.fromUri(uri);
      }
      return file == null
          ? null
          : ResizeImage(
              FileImage(file),
              width: 2048,
              height: 2048,
              policy: ResizeImagePolicy.fit,
            );
    });

class NoteScene extends ConsumerWidget {
  const NoteScene({
    super.key,
    required this.details,
    required this.seed,
    required this.child,
  });
  final NoteDetails details;
  final int seed;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NoteColors.fromBackground(
      Theme.of(context).colorScheme,
      details.background,
    );
    final key = details.background['image'] ?? details.background['asset'];
    final image = key is String
        ? ref.watch(noteBackgroundImageProvider(key)).value
        : null;
    final base = Theme.of(context);
    return EditNotepageBg(
      seed: seed,
      color: colors.background,
      image: image,
      builder: (context, opacity, header) => Theme(
        data: base.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          colorScheme: noteSceneScheme(base.colorScheme, colors),
          textTheme: base.textTheme.apply(
            bodyColor: colors.foreground,
            displayColor: colors.foreground,
          ),
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: colors.background,
            foregroundColor: colors.foreground,
            surfaceTintColor: Colors.transparent,
            // Artwork shows untinted behind the status bar; its icons follow
            // the top of the image so they stay visible.
            systemOverlayStyle: header == null
                ? base.appBarTheme.systemOverlayStyle
                : ThemeData.estimateBrightnessForColor(header) ==
                      Brightness.light
                ? SystemUiOverlayStyle.dark
                : SystemUiOverlayStyle.light,
          ),
        ),
        child: NotePaperOpacity(
          opacity: opacity,
          frosted: image != null,
          child: child,
        ),
      ),
    );
  }
}

/// The whole color scheme of a note's page, matched to its paper.
///
/// Swapping only the text color leaves the app's light surfaces, grey
/// secondary text and red behind, which break on bold paper (light ink on
/// white buttons, red on green). Every pair here is checked for contrast.
ColorScheme noteSceneScheme(ColorScheme base, NoteColors colors) {
  final paper = colors.background, ink = colors.foreground;
  Color layer(double amount) =>
      Color.alphaBlend(ink.withValues(alpha: amount), paper);
  Color on(Color color) =>
      noteAiContrast(Colors.white, color) >=
          noteAiContrast(const Color(0xFF1C1B19), color)
      ? Colors.white
      : const Color(0xFF1C1B19);
  // Floating controls (bar buttons, the format capsule) lift off the paper.
  final surface = layer(.07);
  // Readable both on the paper (menus, sheets) and on lifted controls.
  Color legible(Color color) =>
      noteAiLegible(noteAiLegible(color, surface), paper);
  final primary = legible(base.primary);
  final secondary = legible(base.secondary);
  final error = legible(base.error);
  final variant = legible(colors.secondary);
  final primaryContainer = Color.alphaBlend(
    primary.withValues(alpha: .18),
    paper,
  );
  return base.copyWith(
    primary: primary,
    onPrimary: on(primary),
    primaryContainer: primaryContainer,
    onPrimaryContainer: noteAiLegible(ink, primaryContainer),
    secondary: secondary,
    onSecondary: on(secondary),
    secondaryContainer: layer(.12),
    onSecondaryContainer: ink,
    error: error,
    onError: on(error),
    errorContainer: Color.alphaBlend(error.withValues(alpha: .16), paper),
    onErrorContainer: noteAiLegible(error, paper),
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: variant,
    surfaceDim: paper,
    surfaceBright: layer(.1),
    surfaceContainerLowest: paper,
    surfaceContainerLow: paper,
    surfaceContainer: layer(.04),
    // Plain paper is the app's surfaceContainerHigh; keeping it lets papers
    // resolved inside the scene stay exactly the scene's color.
    surfaceContainerHigh: paper,
    surfaceContainerHighest: layer(.12),
    outline: Color.lerp(variant, paper, .3),
    outlineVariant: Color.lerp(variant, paper, .65),
  );
}

/// Shares the original painting's readable paper opacity with the folded paper.
class NotePaperOpacity extends InheritedWidget {
  const NotePaperOpacity({
    super.key,
    required this.opacity,
    this.frosted = false,
    required super.child,
  });
  final Animation<double> opacity;

  /// Artwork lies behind the paper; it frosts what shows through so the
  /// lighter paper keeps writing readable.
  final bool frosted;
  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotePaperOpacity>()?.opacity ??
      const AlwaysStoppedAnimation(1);
  static bool frostedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotePaperOpacity>()?.frosted ??
      false;
  @override
  bool updateShouldNotify(NotePaperOpacity oldWidget) =>
      opacity != oldWidget.opacity || frosted != oldWidget.frosted;
}

/// Full frost strength behind a note's writing over artwork.
const notePaperFrostSigma = 10.0;

/// One blur over the artwork behind the whole note page (bar and body), so
/// immersive paper and its bar read as one continuous frosted sheet instead
/// of two blurs meeting at a seam. [amount] is the paper's expansion: the
/// folded preview leaves the scene sharp around the card.
class NotePageFrost extends StatelessWidget {
  const NotePageFrost({super.key, required this.amount, required this.child});

  final double amount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sigma = notePaperFrostSigma * amount.clamp(0.0, 1.0);
    if (sigma <= 0 ||
        !NotePaperOpacity.frostedOf(context) ||
        RenderingPolicyScope.of(context).simplerEffects) {
      return child;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }

  /// The paper's own extra blur, so it always totals full strength on top of
  /// the page frost (stacked Gaussian blurs add in quadrature).
  static double paperSigma(double expansion) {
    final page = notePaperFrostSigma * expansion.clamp(0.0, 1.0);
    return math.sqrt(
      math.max(0.0, notePaperFrostSigma * notePaperFrostSigma - page * page),
    );
  }
}
