import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../recall/application/recall_search.dart';
import '../../recall/domain/recall.dart';

class FlowSearchPage extends ConsumerStatefulWidget {
  const FlowSearchPage({super.key});
  @override
  ConsumerState<FlowSearchPage> createState() => _FlowSearchPageState();
}

class _FlowSearchPageState extends ConsumerState<FlowSearchPage> {
  final _search = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(flowSearchSourcesProvider);
    final meaning = _query.isEmpty
        ? null
        : ref.watch(recallSearchProvider((query: _query, kind: 'thought')));
    final terms = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final keywords = [
      for (final source in sources.value ?? const <RecallSource>[])
        if (terms.every(source.text.toLowerCase().contains)) source,
    ];
    final current = {
      for (final s in sources.value ?? const <RecallSource>[]) s.id: s,
    };
    final matches = fuseRecall(keywords, [
      for (final source
          in meaning == null
              ? const <RecallSource>[]
              : currentRecallSources(meaning))
        if (current[source.id] case final live?)
          if (live.hash == source.hash && live.revision == source.revision)
            live,
    ], (source) => source.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Search Flow')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('flow-search-field'),
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'Find a thought',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                  if (meaning?.value?.message case final message?)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(message),
                    ),
                  Expanded(
                    child: sources.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => Center(
                        child: TextButton(
                          onPressed: () =>
                              ref.invalidate(flowSearchSourcesProvider),
                          child: const Text('Could not search thoughts. Retry'),
                        ),
                      ),
                      data: (_) => matches.isEmpty
                          ? const Center(child: Text('No matching thoughts.'))
                          : ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final thought = matches[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  title: Text(
                                    thought.text,
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(thought.date),
                                  onTap: () =>
                                      context.go(thoughtLocation(thought.id)),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
