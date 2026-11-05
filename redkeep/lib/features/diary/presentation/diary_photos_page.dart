import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/application/sync_providers.dart';
import '../application/diary_providers.dart';
import '../domain/diary_document.dart';
import 'add_diary_photos_page.dart';

/// An addressable media editor uses the same repository authority as text.
class DiaryPhotosPage extends ConsumerWidget {
  const DiaryPhotosPage({super.key, required this.address});
  final DiaryAddress address;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(diaryDocumentProvider(address.id))
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => const Scaffold(
          body: Center(child: Text('Could not open this photo story.')),
        ),
        data: (opened) {
          final entry = opened.entry;
          final creating =
              entry == null &&
              ref.watch(diaryNewIdsProvider).contains(address.id);
          if (!creating &&
              (!opened.available ||
                  entry!.date != address.date ||
                  entry.photos.isEmpty)) {
            return const Scaffold(
              body: Center(child: Text('Photo story unavailable.')),
            );
          }
          return AddDiaryPhotosPage(
            key: ValueKey(address.id),
            date: address.date,
            story: entry,
            newItemUuid: address.id,
            readOnly: !creating && !ref.watch(syncCanEditProvider),
          );
        },
      );
}
