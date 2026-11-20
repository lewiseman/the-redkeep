import 'package:flutter/material.dart';

import '../../assets/presentation/local_artwork.dart';

int diaryArtworkDecodeWidth(double width, double pixelRatio) =>
    (width * pixelRatio.clamp(1, 2)).ceil().clamp(1, 1400);

/// Diary raster artwork, bundled with the app.
class DiaryArtwork extends StatelessWidget {
  const DiaryArtwork({
    super.key,
    required this.assetKey,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.colorBlendMode,
  });
  final String assetKey;
  final double? width, height;
  final BoxFit fit;
  final Color? color;
  final BlendMode? colorBlendMode;
  @override
  Widget build(BuildContext context) {
    final cacheWidth = diaryArtworkDecodeWidth(
      width ?? MediaQuery.sizeOf(context).width,
      MediaQuery.devicePixelRatioOf(context),
    );
    return Image(
      image: artworkImage(assetKey, width: cacheWidth),
      width: width,
      height: height,
      fit: fit,
      color: color,
      colorBlendMode: colorBlendMode,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => SizedBox(width: width, height: height),
    );
  }
}
