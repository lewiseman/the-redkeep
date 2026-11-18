import 'dart:typed_data';

import 'stock_photo.dart';

enum StockPhotoFailure {
  offline,
  unauthorized,
  rateLimited,
  notFound,
  badResponse,
}

class StockPhotoException implements Exception {
  const StockPhotoException(
    this.failure, [
    this.provider = 'The photo library',
  ]);
  final StockPhotoFailure failure;
  final String provider;

  String get message => switch (failure) {
    StockPhotoFailure.offline => 'You seem to be offline.',
    StockPhotoFailure.unauthorized => '$provider refused the key in env.json.',
    StockPhotoFailure.rateLimited =>
      '$provider is busy right now. Try again in a little while.',
    StockPhotoFailure.notFound => '$provider no longer has this photo.',
    StockPhotoFailure.badResponse => '$provider could not be reached.',
  };

  @override
  String toString() => message;
}

/// A searchable stock photo library. Add an implementation to offer another
/// provider; nothing outside `stock_photos/` depends on which one is used.
abstract interface class StockPhotoSource {
  /// Shown in credits, for example "Photos from Unsplash".
  String get name;
  Uri get homeUrl;

  /// A starting selection before anything is searched.
  Future<StockPhotoPage> browse({int page = 1});
  Future<StockPhotoPage> search(String query, {int page = 1});

  /// Does whatever the provider requires when a photo is chosen and returns
  /// the image bytes.
  Future<Uint8List> download(StockPhoto photo);
}
