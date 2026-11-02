import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_controller.dart';
import '../../../app/bootstrap/bootstrap_providers.dart';

final _artworkProvider = FutureProvider.autoDispose.family<Uri, String>(
  (ref, key) async {
    final uri = await (await ref.watch(assetResolverProvider)).resolve(key);
    // FileImage's cache key omits file metadata; evict same-path replacements.
    await ResizeImage(FileImage(File.fromUri(uri)), width: 120).evict();
    return uri;
  },
  // Required-file errors must close entry immediately, before user-led repair.
  retry: (_, _) => null,
);

class LocalArtwork extends ConsumerWidget {
  const LocalArtwork({super.key, required this.assetKey});
  final String assetKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(_artworkProvider(assetKey));
    return SizedBox(
      width: 40,
      height: 40,
      child: asset.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => _failed(ref),
        data: (uri) => ExcludeSemantics(
          child: Image(
            image: ResizeImage(FileImage(File.fromUri(uri)), width: 120),
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
