import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'book_artwork.dart';

/// Owns the two small decoded texture handles used by the retained painters.
class BookMaterials extends ConsumerStatefulWidget {
  const BookMaterials({super.key, required this.builder});
  final Widget Function(BuildContext, ui.Image?, ui.Image?) builder;
  @override
  ConsumerState<BookMaterials> createState() => _BookMaterialsState();
}

class _BookMaterialsState extends ConsumerState<BookMaterials> {
  final _streams = <ImageStream?>[null, null];
  final _images = <ImageInfo?>[null, null];
  late final _listeners = List.generate(
    2,
    (index) => ImageStreamListener(
      (image, synchronous) {
        if (!mounted) {
          image.dispose();
          return;
        }
        final previous = _images[index];
        if (synchronous) {
          _images[index] = image;
        } else {
          setState(() => _images[index] = image);
        }
        if (previous != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => previous.dispose(),
          );
        }
      },
      onError: (_, _) {
        if (!mounted || _failed) return;
        _failed = true;
        // Cached stream errors can arrive during build; report after it ends.
        Future.microtask(() {
          if (mounted) setState(() {});
        });
      },
    ),
  );
  bool _failed = false;

  @override
  void dispose() {
    for (var i = 0; i < 2; i++) {
      _streams[i]?.removeListener(_listeners[i]);
      _images[i]?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providers = [
      ref.watch(bookImageProvider(('onboarding.material.paper', 1024))),
      ref.watch(bookImageProvider(('onboarding.material.binding', 192))),
    ];
    for (var i = 0; i < 2; i++) {
      final provider = providers[i].asData?.value;
      if (provider == null) continue;
      final stream = provider.resolve(createLocalImageConfiguration(context));
      if (stream.key == _streams[i]?.key) continue;
      _streams[i]?.removeListener(_listeners[i]);
      _streams[i] = stream;
      stream.addListener(_listeners[i]);
    }
    if (_failed || providers.any((p) => p.hasError)) {
      return const BookArtworkFailure();
    }
    return widget.builder(context, _images[0]?.image, _images[1]?.image);
  }
}
