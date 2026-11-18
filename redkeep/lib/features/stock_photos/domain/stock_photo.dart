import 'dart:ui' show Color;

/// One photo offered by a stock provider. Held in memory while browsing only;
/// once picked, the note keeps nothing but the downloaded file.
class StockPhoto {
  const StockPhoto({
    required this.id,
    required this.thumbUrl,
    required this.previewUrl,
    required this.downloadUrl,
    required this.width,
    required this.height,
    required this.photographerName,
    required this.photographerUrl,
    required this.photoUrl,
    this.color,
    this.description,
    this.trackUrl,
  });

  final String id;

  /// Small image for the results grid.
  final String thumbUrl;

  /// Screen-sized image for the preview page.
  final String previewUrl;

  /// The image fetched when the photo is chosen, already sized for a note.
  final String downloadUrl;

  /// Called first when the photo is chosen, where the provider asks for it.
  final String? trackUrl;
  final int width;
  final int height;

  /// The photo's average colour, shown while it loads.
  final Color? color;
  final String? description;
  final String photographerName;
  final String photographerUrl;
  final String photoUrl;

  double get aspectRatio => width > 0 && height > 0 ? width / height : 2 / 3;
}

class StockPhotoPage {
  const StockPhotoPage({required this.photos, required this.hasMore});
  final List<StockPhoto> photos;
  final bool hasMore;
}
