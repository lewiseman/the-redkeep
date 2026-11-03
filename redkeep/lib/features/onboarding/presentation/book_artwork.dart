import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_controller.dart';
import '../../../app/bootstrap/bootstrap_providers.dart';

final bookImageProvider = FutureProvider.autoDispose
    .family<ImageProvider, (String, int)>((ref, request) async {
      final uri = await (await ref.watch(assetResolverProvider))
          .resolve(request.$1);
      final provider = ResizeImage(
        FileImage(File.fromUri(uri)),
        width: request.$2,
      );
      await provider.evict();
      if (ref.mounted) {
        ref.onDispose(() {
          provider.evict();
        });
      }
      return provider;
    }, retry: (_, _) => null);

class BookFileImage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) => ExcludeSemantics(
    child: ref
        .watch(bookImageProvider((assetKey, cacheWidth)))
        .when(
          loading: () => const SizedBox.expand(),
          error: (_, _) => const BookArtworkFailure(),
          data: (provider) => Image(
            image: provider,
            fit: fit,
            alignment: alignment,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const BookArtworkFailure(),
          ),
        ),
  );
}

class BookArtworkFailure extends ConsumerWidget {
  const BookArtworkFailure({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bootstrapControllerProvider.notifier);
    Future.microtask(controller.artworkFailed);
    return const SizedBox.expand();
  }
}
