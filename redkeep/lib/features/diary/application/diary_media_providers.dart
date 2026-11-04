import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../data/diary_photo_store.dart';
import '../data/diary_photo_stories.dart';
import 'diary_providers.dart';

final diaryPhotoStoreProvider = Provider<DiaryPhotoStore>((ref) {
  final store = DiaryPhotoStore(db: ref.watch(appDatabaseProvider));
  return store;
});
final diaryPhotoStoriesProvider = Provider<DiaryPhotoStories>(
  (ref) => DiaryPhotoStories(
    ref.watch(diaryRepositoryProvider),
    ref.watch(diaryPhotoStoreProvider),
  ),
);
