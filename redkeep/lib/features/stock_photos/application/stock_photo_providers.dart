import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/media/compress_image.dart';
import '../../notes/data/note_media_store.dart';
import '../data/unsplash_source.dart';
import '../domain/stock_photo.dart';
import '../domain/stock_photo_source.dart';

/// From `--dart-define-from-file=env.json`. Empty when not configured.
final unsplashAccessKeyProvider = Provider<String>(
  (ref) => const String.fromEnvironment('UNSPLASH_ACCESS_KEY'),
);

final stockPhotoHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The photo library in use, or null without a key. To change providers,
/// return a different [StockPhotoSource] here.
final stockPhotoSourceProvider = Provider<StockPhotoSource?>((ref) {
  final key = ref.watch(unsplashAccessKeyProvider).trim();
  if (key.isEmpty) return null;
  return UnsplashSource(
    ref.watch(stockPhotoHttpClientProvider),
    accessKey: key,
  );
});

/// Whether grid and preview images load from the network; off in tests.
final stockPhotoImagesEnabledProvider = Provider<bool>((ref) => true);

class StockPhotoResults {
  const StockPhotoResults({
    this.photos = const [],
    this.hasMore = true,
    this.loading = false,
    this.error,
  });

  final List<StockPhoto> photos;
  final bool hasMore;
  final bool loading;
  final Object? error;

  StockPhotoResults copyWith({
    List<StockPhoto>? photos,
    bool? hasMore,
    bool? loading,
    Object? error,
  }) => StockPhotoResults(
    photos: photos ?? this.photos,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    error: error,
  );
}

/// Pages of photos for a search. An empty query browses the starting feed.
class StockPhotoResultsNotifier extends Notifier<StockPhotoResults> {
  StockPhotoResultsNotifier(this.query);
  final String query;
  int _page = 0;

  @override
  StockPhotoResults build() {
    _page = 0;
    _busy = false;
    Future.microtask(more);
    return const StockPhotoResults(loading: true);
  }

  bool _busy = false;

  /// Loads the next page. Does nothing while loading, at the end, or after a
  /// failure until [retry].
  Future<void> more() async {
    final source = ref.read(stockPhotoSourceProvider);
    if (source == null || _busy || !state.hasMore || state.error != null) {
      return;
    }
    _busy = true;
    final next = _page + 1;
    state = state.copyWith(loading: true);
    try {
      final page = query.isEmpty
          ? await source.browse(page: next)
          : await source.search(query, page: next);
      if (!ref.mounted) return;
      final seen = {for (final p in state.photos) p.id};
      _page = next;
      state = StockPhotoResults(
        photos: [
          ...state.photos,
          for (final p in page.photos)
            if (seen.add(p.id)) p,
        ],
        hasMore: page.hasMore && page.photos.isNotEmpty,
      );
    } catch (e) {
      if (ref.mounted) state = state.copyWith(loading: false, error: e);
    } finally {
      _busy = false;
    }
  }

  /// Tries the failed page again.
  Future<void> retry() {
    state = state.copyWith();
    return more();
  }
}

final stockPhotoResultsProvider = NotifierProvider.autoDispose
    .family<StockPhotoResultsNotifier, StockPhotoResults, String>(
      StockPhotoResultsNotifier.new,
    );

/// Downloads [photo], compresses it like any attached photo and stores it in
/// note media. Returns the `note_media/` path to use as a background.
Future<String> importStockBackground(Ref ref, StockPhoto photo) async {
  final source = ref.read(stockPhotoSourceProvider);
  if (source == null) {
    throw const StockPhotoException(StockPhotoFailure.unauthorized);
  }
  final bytes = await source.download(photo);
  final compressed = await compressPhoto(
    bytes,
    encoder: ref.read(photoEncoderProvider),
  );
  return ref
      .read(noteMediaStoreProvider)
      .write(compressed.bytes, extension: compressed.ext);
}

final stockBackgroundImporterProvider =
    Provider<Future<String> Function(StockPhoto)>(
      (ref) =>
          (photo) => importStockBackground(ref, photo),
    );
