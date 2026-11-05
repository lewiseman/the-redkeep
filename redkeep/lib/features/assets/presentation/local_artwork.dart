import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_controller.dart';
import '../../../app/bootstrap/bootstrap_providers.dart';

const _standardWidth = 120, _highResolutionWidth = 360;

final _artworkProvider = FutureProvider.autoDispose.family<Uri, String>(
  (ref, key) async {
    final uri = await (await ref.watch(assetResolverProvider)).resolve(key);
    // FileImage's cache key omits file metadata; evict same-path replacements.
    for (final width in const [_standardWidth, _highResolutionWidth]) {
      await ResizeImage(FileImage(File.fromUri(uri)), width: width).evict();
    }
    return uri;
  },
  // Required-file errors must close entry immediately, before user-led repair.
  retry: (_, _) => null,
);

class LocalArtwork extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(_artworkProvider(assetKey));
    return SizedBox(
      width: dimension,
      height: dimension,
      child: asset.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => _failed(ref),
        data: (uri) => ExcludeSemantics(
          child: Image(
            image: ResizeImage(
              FileImage(File.fromUri(uri)),
              width: highResolution ? _highResolutionWidth : _standardWidth,
            ),
            errorBuilder: (_, _, _) => _failed(ref),
          ),
        ),
      ),
    );
  }

  Widget _failed(WidgetRef ref) {
    final controller = ref.read(bootstrapControllerProvider.notifier);
    Future.microtask(controller.artworkFailed);
    return const Icon(
      Icons.broken_image_outlined,
      semanticLabel: 'Artwork unavailable',
    );
  }
}
