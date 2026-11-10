import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/bootstrap/bootstrap_controller.dart';

const diaryHeaderArtworkKey = 'diary.header';

double diaryHeaderArtworkWidth(double viewportWidth) =>
    viewportWidth.clamp(0.0, 700.0);

int diaryArtworkDecodeWidth(double width, double pixelRatio) =>
    (width * pixelRatio.clamp(1, 2)).ceil().clamp(1, 1400);

final diaryImageProvider = FutureProvider.autoDispose
    .family<ImageProvider, (String, int)>((ref, request) async {
      final uri = await (await ref.watch(assetResolverProvider))
          .resolve(request.$1);
      final provider = ResizeImage(
        FileImage(File.fromUri(uri)),
        width: request.$2,
      );
      if (ref.mounted) {
        await provider.evict();
        if (ref.mounted) ref.onDispose(provider.evict);
      }
      return provider;
    }, retry: (_, _) => null);

/// All diary raster artwork comes from verified downloaded storage.
class DiaryArtwork extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheWidth = diaryArtworkDecodeWidth(
      width ?? MediaQuery.sizeOf(context).width,
      MediaQuery.devicePixelRatioOf(context),
    );
    Widget failed() {
      Future.microtask(
        ref.read(bootstrapControllerProvider.notifier).artworkFailed,
      );
      return SizedBox(width: width, height: height);
    }

    return ref
        .watch(diaryImageProvider((assetKey, cacheWidth)))
        .when(
          loading: () => SizedBox(width: width, height: height),
          error: (_, _) => failed(),
          data: (image) => Image(
            image: image,
            width: width,
            height: height,
            fit: fit,
            color: color,
            colorBlendMode: colorBlendMode,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => failed(),
          ),
        );
  }
}
