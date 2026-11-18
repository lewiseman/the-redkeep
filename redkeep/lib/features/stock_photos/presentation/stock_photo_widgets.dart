import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../application/stock_photo_providers.dart';
import '../domain/stock_photo.dart';

bool stockPhotoAnimate(BuildContext context) =>
    context
        .dependOnInheritedWidgetOfExactType<RenderingPolicyScope>()
        ?.policy
        .animate ??
    !MediaQuery.disableAnimationsOf(context);

Future<void> openStockLink(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    // Credits are a courtesy; a missing browser is not an error to show.
  }
}

/// A photo loaded from the provider's own image link, its average colour
/// standing in until it arrives.
class StockPhotoImage extends ConsumerWidget {
  const StockPhotoImage({
    super.key,
    required this.photo,
    required this.url,
    this.fit = BoxFit.cover,
  });

  final StockPhoto photo;
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fill = ColoredBox(
      color:
          photo.color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const SizedBox.expand(),
    );
    if (!ref.watch(stockPhotoImagesEnabledProvider)) return fill;
    final fade = stockPhotoAnimate(context)
        ? const Duration(milliseconds: 220)
        : Duration.zero;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: fade,
      fadeOutDuration: fade,
      placeholder: (_, _) => fill,
      errorWidget: (_, _, _) => Stack(
        fit: StackFit.expand,
        children: [
          fill,
          Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// "Photo by {name} on {provider}", each name a link, wrapping at large text.
class StockPhotoCredit extends StatelessWidget {
  const StockPhotoCredit({
    super.key,
    required this.photo,
    required this.provider,
    required this.providerUrl,
  });

  final StockPhoto photo;
  final String provider;
  final String providerUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final link = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        Text('Photo by', style: muted),
        TextButton(
          style: link,
          onPressed: () => openStockLink(photo.photographerUrl),
          child: Text(photo.photographerName),
        ),
        Text('on', style: muted),
        TextButton(
          style: link,
          onPressed: () => openStockLink(photo.photoUrl),
          child: Text(provider),
        ),
      ],
    );
  }
}
