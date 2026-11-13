import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../data/tmdb_client.dart';
import '../domain/watch_title.dart';

/// Off in widget tests, which never reach the network or the image cache.
final watchPostersEnabledProvider = Provider<bool>((ref) => true);

/// A TMDB image, cached on disk once seen. Without a path it is a quiet
/// paper card, so offline titles need no network.
class WatchPoster extends ConsumerWidget {
  const WatchPoster({
    super.key,
    required this.path,
    this.size = 'w342',
    this.radius = 10,
    this.media,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final String? path;
  final String size;
  final double radius;
  final WatchMedia? media;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final path = ref.watch(watchPostersEnabledProvider) ? this.path : null;
    final fade = RenderingPolicyScope.of(context).animate
        ? const Duration(milliseconds: 320)
        : Duration.zero;
    final blank = ColoredBox(
      color: palette.cloth,
      child: Center(
        child: Icon(
          media == WatchMedia.tv ? Icons.tv_outlined : Icons.movie_outlined,
          color: palette.muted,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Semantics(
        image: true,
        label: semanticLabel,
        child: path == null
            ? blank
            : CachedNetworkImage(
                imageUrl: TmdbClient.image(path, size: size),
                fit: fit,
                fadeInDuration: fade,
                fadeInCurve: Curves.easeOut,
                fadeOutDuration: fade,
                placeholder: (_, _) => const WatchShimmer(),
                errorWidget: (_, _, _) => blank,
              ),
      ),
    );
  }
}

/// A soft band of light passing over a loading image. Still with reduced
/// motion or simpler effects.
class WatchShimmer extends StatefulWidget {
  const WatchShimmer({super.key});

  @override
  State<WatchShimmer> createState() => _WatchShimmerState();
}

class _WatchShimmerState extends State<WatchShimmer>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final policy = RenderingPolicyScope.of(context);
    if (policy.animate && !policy.simplerEffects) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final base = palette.cloth;
    final light = Color.lerp(base, palette.paper, .9)!;
    if (!_sweep.isAnimating) return ColoredBox(color: base);
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-1, -.3),
            end: const Alignment(1, .3),
            colors: [base, light, base],
            stops: const [.35, .5, .65],
            transform: _Sweep(_sweep.value),
          ),
        ),
      ),
    );
  }
}

class _Sweep extends GradientTransform {
  const _Sweep(this.t);
  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 3 - 1.5), 0, 0);
}

/// Warms the image cache for photos about to be shown, once each.
void preloadWatchPhotos(
  BuildContext context,
  WidgetRef ref,
  Iterable<(String, String)> photos,
) {
  if (!ref.read(watchPostersEnabledProvider)) return;
  if (_preloaded.length > 400) _preloaded.clear();
  for (final (path, size) in photos) {
    final url = TmdbClient.image(path, size: size);
    if (!_preloaded.add(url)) continue;
    precacheImage(
      CachedNetworkImageProvider(url),
      context,
      onError: (_, _) => _preloaded.remove(url),
    );
  }
}

/// URLs already asked for this run; the image cache keeps the pictures.
final _preloaded = <String>{};

/// Photos worth loading ahead: the next [ahead] after [index] on this card,
/// and the first [nextCard] of the card after it.
List<(String, String)> photosToPreload({
  required List<(String, String)> current,
  required int index,
  List<(String, String)> upNext = const [],
  int ahead = 3,
  int nextCard = 2,
}) => [...current.skip(index + 1).take(ahead), ...upNext.take(nextCard)];

/// Columns for a poster grid: fewer when space is narrow or text is large.
int posterColumns(BuildContext context, double width) {
  final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
    1.0,
    1.8,
  );
  return (width / (112 * scale)).floor().clamp(2, 6);
}

class PosterTile extends StatelessWidget {
  const PosterTile({
    super.key,
    required this.title,
    required this.media,
    this.posterPath,
    this.year,
    this.badge,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final WatchMedia media;
  final String? posterPath;
  final int? year;
  final String? badge;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final kind = media == WatchMedia.tv ? 'Series' : 'Film';
    return Semantics(
      button: true,
      label: [title, ?year?.toString(), kind, ?badge].join(', '),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  WatchPoster(path: posterPath, media: media),
                  if (badge != null)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      right: 6,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: WatchBadge(label: badge!),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.ink,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              year == null ? kind : '$year · $kind',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.muted, fontSize: 12, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class WatchBadge extends StatelessWidget {
  const WatchBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paper.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.ink,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A grid of posters that fits the width it is given.
class PosterGrid extends StatelessWidget {
  const PosterGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 32),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth - padding.horizontal;
      final columns = posterColumns(context, width);
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final tileWidth = (width - (columns - 1) * 12) / columns;
      // Poster plus two title lines and the year, at the current text size.
      final tileHeight =
          tileWidth * 1.5 + 6 + scale * (13 * 1.25 * 2 + 12 * 1.3) + 4;
      return GridView.builder(
        padding: padding,
        itemCount: itemCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          mainAxisExtent: tileHeight,
        ),
        itemBuilder: itemBuilder,
      );
    },
  );
}

/// A centred message, optionally with Redkeep's own artwork above it.
class WatchMessage extends StatelessWidget {
  const WatchMessage({
    super.key,
    required this.title,
    required this.body,
    this.artwork,
    this.action,
  });

  final String title;
  final String body;
  final Widget? artwork;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final showArtwork = MediaQuery.textScalerOf(context).scale(14) <= 28;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MoreSurface.contentWidth),
          child: Column(
            children: [
              if (showArtwork && artwork != null) ...[
                artwork!,
                const SizedBox(height: 20),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}

AppBar watchAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  Widget? leading,
}) {
  final palette = MorePalette.of(context);
  return AppBar(
    leading: leading,
    automaticallyImplyLeading: leading == null,
    backgroundColor: palette.ground,
    foregroundColor: palette.ink,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    centerTitle: false,
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        height: 1.2,
        letterSpacing: -.4,
        fontWeight: FontWeight.w600,
      ),
    ),
    actions: actions,
    bottom: bottom,
  );
}

/// Runs a change, reporting a refusal (such as an add-only device) quietly.
Future<T?> runWatchAction<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(watchErrorText(error))));
    }
    return null;
  }
}

String watchErrorText(Object error) => switch (error) {
  StateError(:final message) => message,
  WatchlistException(failure: WatchlistFailure.emptyName) =>
    'Give the list a name.',
  WatchlistException() => 'That is no longer available.',
  _ => error.toString(),
};

/// Asks for a list's name; null when cancelled or empty.
Future<String?> askListName(
  BuildContext context, {
  String title = 'New list',
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// A spinner, or still words when motion is reduced.
class WatchLoading extends StatelessWidget {
  const WatchLoading({super.key, this.label = 'Loading…'});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: RenderingPolicyScope.of(context).animate
        ? Semantics(label: label, child: const CircularProgressIndicator())
        : Text(label, style: TextStyle(color: MorePalette.of(context).muted)),
  );
}
