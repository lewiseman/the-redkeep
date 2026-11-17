import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/diary_providers.dart';
import 'diary_style.dart';
import 'diary_search_paper.dart';
import 'diary_search_scene.dart';

class DiarySearchOpening extends ConsumerWidget {
  const DiarySearchOpening({
    super.key,
    required this.onSearch,
    required this.reduced,
    this.compact = false,
  });

  final ValueChanged<String> onSearch;
  final bool reduced;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent =
        ref.watch(diaryRecentSearchesProvider).value ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Center(
            // The keyboard shrinks the scene; ease it rather than jump.
            child: AnimatedContainer(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: compact ? 100 : 156,
              child: DiarySearchScene(reduced: reduced, compact: compact),
            ),
          ),
        ),
        if (recent.isNotEmpty)
          DiaryRecentSearches(
            searches: recent,
            onSearch: onSearch,
            reduced: reduced,
          ),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// The latest searches as paper cards, newest first. Tapping one runs it.
class DiaryRecentSearches extends StatelessWidget {
  const DiaryRecentSearches({
    super.key,
    required this.searches,
    required this.onSearch,
    required this.reduced,
  });

  final List<String> searches;
  final ValueChanged<String> onSearch;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    // The page's switcher already fades the opening in.
    return Column(
      children: [
        for (final (i, query) in searches.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          Transform.rotate(
            angle: reduced ? 0 : const [-.018, .012, -.01][i % 3],
            child: _QuestionCard(
              key: ValueKey('diary-search-recent-$i'),
              query: query,
              index: i,
              icon: Icons.history_rounded,
              onTap: () => onSearch(query),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.query,
    required this.index,
    required this.icon,
    required this.onTap,
  });

  final String query;
  final int index;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paper = [
      DiaryPaperPreset.lavender,
      DiaryPaperPreset.sage,
      DiaryPaperPreset.sand,
      DiaryPaperPreset.sky,
      DiaryPaperPreset.rose,
      DiaryPaperPreset.paper,
    ][index % 6].resolveColors(context.colors);
    return DiarySearchPaper(
      color: paper.background,
      variant: index,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            Icon(icon, size: 23, color: paper.secondary),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                query,
                semanticsLabel: 'Recent search: $query',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: paper.foreground,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.north_east_rounded, size: 17, color: paper.secondary),
          ],
        ),
      ),
    );
  }
}
