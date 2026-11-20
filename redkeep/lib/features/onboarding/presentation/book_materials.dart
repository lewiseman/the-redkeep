import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'book_artwork.dart';

/// Owns the two small decoded texture handles used by the retained painters.
class BookMaterials extends StatefulWidget {
  const BookMaterials({super.key, required this.builder});
  final Widget Function(BuildContext, ui.Image?, ui.Image?) builder;
  @override
  State<BookMaterials> createState() => _BookMaterialsState();
}

class _BookMaterialsState extends State<BookMaterials> {
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
      // The painters fall back to drawn materials without a texture.
      onError: (_, _) {},
    ),
  );

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
      bookImage('onboarding.material.paper', 1024),
      bookImage('onboarding.material.binding', 192),
    ];
    for (var i = 0; i < 2; i++) {
      final provider = providers[i];
      final stream = provider.resolve(createLocalImageConfiguration(context));
      if (stream.key == _streams[i]?.key) continue;
      _streams[i]?.removeListener(_listeners[i]);
      _streams[i] = stream;
      stream.addListener(_listeners[i]);
    }
    return widget.builder(context, _images[0]?.image, _images[1]?.image);
  }
}
