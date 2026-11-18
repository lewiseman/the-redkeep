import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/catalog_title.dart';
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
