import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../domain/catalog_title.dart';
import 'watch_list_sheet.dart';
import 'watch_widgets.dart';

/// Opens a trailer or official site in the browser or YouTube app.
Future<void> openTitleLink(BuildContext context, Uri url) async {
  var opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Object {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('That link could not open.')),
      );
  }
}

/// How much taller a row gets for large text, kept within reason.
double _rowScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

/// A picture in the gallery: its TMDB path, and whether it is a poster.
typedef TitlePicture = ({String path, bool poster});

List<TitlePicture> titlePictures(CatalogTitle title) {
  final backdrops = {?title.backdropPath, ...title.backdrops};
  final posters = {?title.posterPath, ...title.posters};
  return [
    for (final p in backdrops) (path: p, poster: false),
    for (final p in posters) (path: p, poster: true),
  ];
}

/// Scene stills, then posters, in one row; each opens full screen.
class TitlePictures extends StatelessWidget {
  const TitlePictures({super.key, required this.title});
  final CatalogTitle title;

  @override
  Widget build(BuildContext context) {
    final pictures = titlePictures(title);
    const height = 120.0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pictures.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final picture = pictures[i];
          return Semantics(
            button: true,
            label:
                '${picture.poster ? 'Poster' : 'Still'} ${i + 1} of '
                '${pictures.length}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => TitleGalleryPage(
                    title: title.title,
                    pictures: pictures,
                    initial: i,
                  ),
                ),
              ),
              child: SizedBox(
                width: picture.poster ? height * 2 / 3 : height * 16 / 9,
                child: WatchPoster(
                  path: picture.path,
                  size: picture.poster ? 'w342' : 'w780',
                  radius: 6,
                  media: title.media,
                  icon: Icons.image_outlined,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Every picture, one at a time, pinch to zoom.
class TitleGalleryPage extends StatefulWidget {
  const TitleGalleryPage({
    super.key,
    required this.title,
    required this.pictures,
    required this.initial,
  });
  final String title;
  final List<TitlePicture> pictures;
  final int initial;

  @override
  State<TitleGalleryPage> createState() => _TitleGalleryPageState();
}

class _TitleGalleryPageState extends State<TitleGalleryPage> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.pictures.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '${widget.title} · ${_index + 1} of $count',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: count,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final picture = widget.pictures[i];
          return InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: WatchPoster(
                path: picture.path,
                size: picture.poster ? 'w780' : 'w1280',
                radius: 0,
                fit: BoxFit.contain,
                icon: Icons.image_outlined,
                semanticLabel:
                    '${widget.title}, ${picture.poster ? 'poster' : 'still'} '
                    '${i + 1} of $count',
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Actors with their faces and parts, in billing order.
class CastRow extends StatelessWidget {
  const CastRow({super.key, required this.cast});
  final List<Credit> cast;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final scale = _rowScale(context);
    const face = 76.0;
    final width = 92 * scale.clamp(1.0, 1.4);
    // The face, then up to two lines each for the name and the part.
    final height = face + 8 + scale * (13 * 1.25 * 2 + 12 * 1.3 * 2);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cast.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final person = cast[i];
          return Semantics(
            label: [person.name, ?person.role].join(', as '),
            excludeSemantics: true,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: face,
                    child: ClipOval(
                      child: WatchPoster(
                        path: person.profilePath,
                        size: 'w185',
                        radius: 0,
                        icon: Icons.person_outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    person.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (person.role != null)
                    Text(
                      person.role!,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Titles TMDB suggests alongside this one; each opens its own page.
class MoreLikeThisRow extends StatelessWidget {
  const MoreLikeThisRow({super.key, required this.titles});
  final List<CatalogTitle> titles;

  @override
  Widget build(BuildContext context) {
    final scale = _rowScale(context);
    final width = 104 * scale.clamp(1.0, 1.4);
    final height = width * 1.5 + 10 + scale * (13 * 1.25 * 2 + 12 * 1.3);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: titles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final title = titles[i];
          return SizedBox(
            width: width,
            child: PosterTile(
              key: ValueKey(title.key),
              title: title.title,
              media: title.media,
              posterPath: title.posterPath,
              year: title.year,
              onTap: () => context.push(watchTitleLocation(title.key)),
              onLongPress: () => showWatchListSheet(context, title),
            ),
          );
        },
      ),
    );
  }
}

/// Small paper labels, such as a title's keywords.
class TitleTags extends StatelessWidget {
  const TitleTags({super.key, required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.cloth,
              borderRadius: BorderRadius.circular(simple ? 4 : 12),
              border: Border.all(color: palette.rule, width: .8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                tag,
                style: TextStyle(color: palette.ink, fontSize: 12.5),
              ),
            ),
          ),
      ],
    );
  }
}
