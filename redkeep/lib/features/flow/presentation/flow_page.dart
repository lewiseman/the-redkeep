import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'flow_maester_button.dart';
import '../../../app/navigation_destination.dart';
import '../application/flow_providers.dart';
import '../domain/thought.dart';
import 'flow_editor.dart';

class FlowPage extends ConsumerWidget {
  const FlowPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    floatingActionButton: const FlowMaesterButton(editing: true),
    appBar: AppBar(title: const Text('Flow')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(child: FlowEditor()),
              ),
              _block(
                Text(
                  'Unfinished edits',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _section(context, ref, ref.watch(thoughtDraftsProvider), true),
              _block(
                Text(
                  'Newest thoughts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _section(context, ref, ref.watch(thoughtsProvider), false),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _block(Widget child) => SliverPadding(
    padding: const EdgeInsets.all(16),
    sliver: SliverToBoxAdapter(child: child),
  );
  Widget _section(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ThoughtListing>> items,
    bool drafts,
  ) => items.when(
    loading: () => _block(const Text('Loading…')),
    error: (_, _) => _block(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            drafts
                ? 'Unfinished edits could not be loaded.'
                : 'Thoughts could not be loaded.',
          ),
          OutlinedButton(
            onPressed: () => drafts
                ? ref.invalidate(thoughtDraftsProvider)
                : ref.invalidate(thoughtsProvider),
            child: const Text('Retry loading'),
          ),
        ],
      ),
    ),
    data: (rows) => rows.isEmpty
        ? _block(
            Text(
              drafts
                  ? 'No unfinished edits.'
                  : 'No thoughts yet. Capture a thought whenever you’re ready.',
            ),
          )
        : SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                title: Text(
                  row.preview.trim().isEmpty
                      ? 'Unfinished thought'
                      : row.preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  drafts
                      ? 'Recovery draft'
                      : row.createdAt.toLocal().toString(),
                ),
                onTap: () => context.go(thoughtLocation(row.id, edit: drafts)),
              );
            },
          ),
  );
}
