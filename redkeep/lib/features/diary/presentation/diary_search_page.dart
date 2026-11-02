import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../application/diary_providers.dart';
import '../domain/diary_document.dart';
import 'diary_widgets.dart';

class DiarySearchPage extends ConsumerStatefulWidget {
  const DiarySearchPage({super.key});
  @override
  ConsumerState<DiarySearchPage> createState() => _DiarySearchPageState();
}

class _DiarySearchPageState extends ConsumerState<DiarySearchPage> {
  String search = '';
  @override
  Widget build(BuildContext context) => DiaryFrame(
    slivers: [
      diaryBlock(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Search diary',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Keywords'),
              inputFormatters: [LengthLimitingTextInputFormatter(256)],
              onChanged: (value) => setState(() => search = value.trim()),
            ),
            const Text(
              'Every keyword must match the saved title or text. Recovery drafts are listed in the calendar.',
            ),
          ],
        ),
      ),
      if (search.isEmpty)
        diaryBlock(const Text('Enter keywords to find an entry.'))
      else
        ref
            .watch(diarySearchProvider(search))
            .when(
              loading: () =>
                  diaryBlock(const Text('Searching on this device…')),
              error: (_, _) => diaryBlock(
                TextButton(
                  onPressed: () => ref.invalidate(diarySearchProvider(search)),
                  child: const Text('Search failed. Retry'),
                ),
              ),
              data: (entries) => entries.isEmpty
                  ? diaryBlock(const Text('No matching entries.'))
                  : SliverList.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          title: Text(
                            diaryTitle(entry.title),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(entry.date.key),
                          onTap: () => context.go(
                            diaryEntryLocation(entry.date, entry.id),
                          ),
                        );
                      },
                    ),
            ),
    ],
  );
}
