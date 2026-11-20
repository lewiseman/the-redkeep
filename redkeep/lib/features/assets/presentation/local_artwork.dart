import 'package:flutter/material.dart';

import '../domain/app_artwork.dart';

const _standardWidth = 120, _highResolutionWidth = 360;

/// A bundled artwork image decoded at [width] pixels wide.
ImageProvider artworkImage(String key, {required int width}) {
  final path = appArtwork[key];
  if (path == null) throw ArgumentError.value(key, 'key', 'Unknown artwork');
  return ResizeImage(AssetImage(path), width: width);
}

ImageProvider localArtworkImage(String key, {bool highResolution = false}) =>
    artworkImage(
      key,
      width: highResolution ? _highResolutionWidth : _standardWidth,
    );

class LocalArtwork extends StatelessWidget {
  const LocalArtwork({
    super.key,
    required this.assetKey,
    this.dimension = 40,
    this.highResolution = false,
  });
  final String assetKey;
  final double dimension;

  /// For artwork shown large enough that the standard decode would look soft.
  final bool highResolution;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: dimension,
    height: dimension,
    child: ExcludeSemantics(
      child: Image(
        image: localArtworkImage(assetKey, highResolution: highResolution),
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          semanticLabel: 'Artwork unavailable',
        ),
      ),
    ),
  );
}
