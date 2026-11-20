import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../../core/presentation/system_overlay.dart';
import '../../assets/domain/app_artwork.dart';
import '../../sync/application/sync_providers.dart';
import '../data/note_media_store.dart';
import '../domain/note_document.dart';
import '../domain/note_colors.dart';
import 'edit_note_page_bg.dart';
import 'note_ai_palette.dart';

final noteBackgroundImageProvider = FutureProvider.autoDispose
    .family<ImageProvider?, String>((ref, key) async {
      if (!key.startsWith('note_media/')) {
        final path = appArtwork[key];
        return path == null ? null : _sized(AssetImage(path));
      }
      final file = await ref.watch(noteMediaStoreProvider).resolve(key);
      // A restore brings backgrounds back after the journal itself.
      if (file == null) {
        ref.listen(restoredMediaProvider, (_, next) {
          if (next.value == key) ref.invalidateSelf();
        });
      }
      return file == null ? null : _sized(FileImage(file));
    });

ImageProvider _sized(ImageProvider image) => ResizeImage(
  image,
  width: 2048,
  height: 2048,
  policy: ResizeImagePolicy.fit,
);

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
            // Status bar icons follow what is behind them: the top of the
            // artwork, or else the paper.
            // The navigation bar sits over the paper itself.
            systemOverlayStyle: systemOverlayOn(header ?? colors.background)
                .copyWith(
                  systemNavigationBarIconBrightness: systemOverlayOn(
                    colors.background,
                  ).systemNavigationBarIconBrightness,
                ),
          ),
        ),
        child: NoteChrome(
          theme: base,
          child: NotePaperOpacity(
            // Without artwork the paper fills the page over a soft wash;
            // it lets the wash show only as far as the writing stays clear.
            opacity: image == null
                ? AlwaysStoppedAnimation(
                    notePaperOpacity(
                      paper: colors.background,
                      ink: colors.foreground,
                      behind: base.colorScheme.surface,
                      preferred: opacity.value,
                    ),
                  )
                : opacity,
            frosted: image != null,
            child: child,
          ),
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

/// The most see-through [paper] can be, from [preferred] up to solid, while
/// [ink] keeps [ratio] contrast with the paper as seen over [behind].
///
/// Pale paper barely changes over the cream wash and keeps its translucency.
/// Bold paper (crimson, cobalt) would blend into a mid tone that light ink
/// no longer reads on, so it turns nearly solid.
double notePaperOpacity({
  required Color paper,
  required Color ink,
  required Color behind,
  double preferred = .78,
  double ratio = 7,
}) {
  for (var opacity = preferred; opacity < 1; opacity += .02) {
    final seen = Color.alphaBlend(paper.withValues(alpha: opacity), behind);
    if (noteAiContrast(ink, seen) >= ratio) return opacity;
  }
  return 1;
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
/// the paper and its bar read as one continuous frosted sheet instead of two
/// blurs meeting at a seam.
class NotePageFrost extends StatelessWidget {
  const NotePageFrost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!NotePaperOpacity.frostedOf(context) ||
        RenderingPolicyScope.of(context).simplerEffects) {
      return child;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: notePaperFrostSigma,
              sigmaY: notePaperFrostSigma,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}

/// The app's own theme, kept for a note page's controls.
///
/// Only the paper takes the note's color; buttons, the dock and the format
/// tools stay neutral so they never compete with the writing.
class NoteChrome extends InheritedWidget {
  const NoteChrome({super.key, required this.theme, required super.child});
  final ThemeData theme;

  /// The neutral theme, or the current one outside a note scene.
  static ThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NoteChrome>()?.theme ??
      Theme.of(context);

  @override
  bool updateShouldNotify(NoteChrome oldWidget) => theme != oldWidget.theme;
}

/// Shows [child] in the note page's neutral control theme.
class NoteChromeTheme extends StatelessWidget {
  const NoteChromeTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: NoteChrome.of(context), child: child);
}
