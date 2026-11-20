import 'package:flutter/material.dart';

import '../../assets/presentation/local_artwork.dart';

/// Onboarding book artwork, bundled with the app, decoded at [width] pixels.
ImageProvider bookImage(String key, int width) =>
    artworkImage(key, width: width);

class BookFileImage extends StatelessWidget {
  const BookFileImage({
    super.key,
    required this.assetKey,
    required this.cacheWidth,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });
  final String assetKey;
  final int cacheWidth;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image(
      image: bookImage(assetKey, cacheWidth),
      fit: fit,
      alignment: alignment,
      // Keep the current frame while a new decode size resolves.
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const SizedBox.expand(),
    ),
  );
}
