import 'dart:typed_data';

import 'package:redkeep/features/stock_photos/domain/stock_photo.dart';
import 'package:redkeep/features/stock_photos/domain/stock_photo_source.dart';

StockPhoto fakeStockPhoto(String id, {String name = 'Ada Lens'}) => StockPhoto(
  id: id,
  thumbUrl: 'https://images.example/$id/thumb',
  previewUrl: 'https://images.example/$id/preview',
  downloadUrl: 'https://images.example/$id/full',
  width: 2000,
  height: 3000,
  photographerName: name,
  photographerUrl: 'https://photos.example/@ada',
  photoUrl: 'https://photos.example/photo/$id',
  description: 'Photo $id',
);

/// An offline photo library: [browse] and [search] answer from [photos].
class FakeStockPhotoSource implements StockPhotoSource {
  FakeStockPhotoSource({
    List<StockPhoto>? photos,
    required this.bytes,
    this.pages = 1,
  }) : photos = photos ?? [for (var i = 0; i < 6; i++) fakeStockPhoto('p$i')];

  final List<StockPhoto> photos;
  final Uint8List bytes;
  final int pages;
  final searches = <(String, int)>[];
  final downloads = <String>[];
  StockPhotoFailure? failure;

  @override
  String get name => 'Unsplash';

  @override
  Uri get homeUrl => Uri.parse('https://photos.example/');

  StockPhotoPage _page(int page) {
    final failure = this.failure;
    if (failure != null) throw StockPhotoException(failure, name);
    return StockPhotoPage(
      photos: [
        for (final p in photos) page == 1 ? p : fakeStockPhoto('${p.id}-$page'),
      ],
      hasMore: page < pages,
    );
  }

  @override
  Future<StockPhotoPage> browse({int page = 1}) async {
    searches.add(('', page));
    return _page(page);
  }

  @override
  Future<StockPhotoPage> search(String query, {int page = 1}) async {
    searches.add((query, page));
    return query == 'nothing'
        ? const StockPhotoPage(photos: [], hasMore: false)
        : _page(page);
  }

  @override
  Future<Uint8List> download(StockPhoto photo) async {
    downloads.add(photo.id);
    final failure = this.failure;
    if (failure != null) throw StockPhotoException(failure, name);
    return bytes;
  }
}
