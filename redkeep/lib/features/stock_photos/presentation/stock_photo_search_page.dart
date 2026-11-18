import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../application/stock_photo_providers.dart';
import '../domain/stock_photo.dart';
import 'stock_photo_widgets.dart';

/// Browse and search the stock photo library for a note background. Pops
/// with the stored `note_media/` path once a photo is chosen.
class StockPhotoSearchPage extends ConsumerStatefulWidget {
  const StockPhotoSearchPage({super.key, required this.noteId});

  final String noteId;

  static const debounce = Duration(milliseconds: 350);
  static const ideas = [
    ('Ocean', Icons.waves_rounded),
    ('Leaves', Icons.spa_outlined),
    ('Sunset', Icons.wb_twilight),
    ('Stars', Icons.nights_stay_outlined),
    ('Mountains', Icons.landscape_outlined),
    ('Flowers', Icons.local_florist_outlined),
    ('Paper texture', Icons.texture_rounded),
    ('Minimal', Icons.crop_portrait_rounded),
  ];

  @override
  ConsumerState<StockPhotoSearchPage> createState() =>
      _StockPhotoSearchPageState();
}

class _StockPhotoSearchPageState extends ConsumerState<StockPhotoSearchPage> {
  final _query = TextEditingController();
  Timer? _timer;
  String _asked = '';

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _ask(String value) {
    _timer?.cancel();
    setState(() => _asked = value.trim());
  }

  void _changed(String value) {
    _timer?.cancel();
    _timer = Timer(StockPhotoSearchPage.debounce, () {
      if (mounted) setState(() => _asked = value.trim());
    });
  }

  Future<void> _open(StockPhoto photo) async {
    FocusScope.of(context).unfocus();
    final path = await context.push<String>(
      noteBackgroundPhotoLocation(widget.noteId),
      extra: photo,
    );
    if (path != null && mounted) context.pop(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = ref.watch(stockPhotoSourceProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const ValueKey('stock-photo-search'),
          controller: _query,
          autofocus: false,
          enabled: source != null,
          textInputAction: TextInputAction.search,
          onChanged: _changed,
          onSubmitted: _ask,
          decoration: InputDecoration(
            hintText: source == null
                ? 'Search photos'
                : 'Search ${source.name} photos',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.text.isNotEmpty || _asked.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () {
                _query.clear();
                _ask('');
              },
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: source == null
            ? const _Message(
                icon: Icons.key_off_outlined,
                title: 'Photo search is not set up',
                body:
                    'Add UNSPLASH_ACCESS_KEY to env.json to browse photos. '
                    'You can still use a photo of your own.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Ideas(
                    selected: _asked,
                    onSelected: (idea) {
                      _query.text = idea;
                      _ask(idea);
                    },
                  ),
                  Expanded(
                    child: _Results(
                      key: ValueKey(_asked),
                      query: _asked,
                      provider: source.name,
                      providerUrl: source.homeUrl.toString(),
                      onOpen: _open,
                    ),
                  ),
                ],
              ),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}

class _Ideas extends StatelessWidget {
  const _Ideas({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    child: Row(
      children: [
        for (final (label, icon) in StockPhotoSearchPage.ideas) ...[
          FilterChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            selected: selected.toLowerCase() == label.toLowerCase(),
            showCheckmark: false,
            onSelected: (_) => onSelected(label),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

class _Results extends ConsumerWidget {
  const _Results({
    super.key,
    required this.query,
    required this.provider,
    required this.providerUrl,
    required this.onOpen,
  });

  final String query;
  final String provider;
  final String providerUrl;
  final ValueChanged<StockPhoto> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final results = ref.watch(stockPhotoResultsProvider(query));
    final notifier = ref.read(stockPhotoResultsProvider(query).notifier);
    final animate = stockPhotoAnimate(context);
    final error = results.error;
    if (results.photos.isEmpty) {
      if (error != null) {
        return _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Photos did not load',
          body: error.toString(),
          action: TextButton(
            onPressed: notifier.retry,
            child: const Text('Try again'),
          ),
        );
      }
      if (results.loading) {
        return Center(
          child: animate
              ? const CircularProgressIndicator(
                  semanticsLabel: 'Loading photos',
                )
              : const Text('Loading photos…'),
        );
      }
      return const _Message(
        icon: Icons.image_search_outlined,
        title: 'Nothing found',
        body: 'Try another word, like a colour, place or season.',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 800) notifier.more();
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                childAspectRatio: 2 / 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: results.photos.length,
              itemBuilder: (context, i) {
                final photo = results.photos[i];
                return _Tile(
                  key: ValueKey(photo.id),
                  photo: photo,
                  onTap: () => onOpen(photo),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  if (error != null) ...[
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: notifier.retry,
                      child: const Text('Try again'),
                    ),
                  ] else if (results.loading)
                    animate
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Loading more…'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => openStockLink(providerUrl),
                    child: Text('Photos from $provider'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.photo, required this.onTap});
  final StockPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: [
      photo.description,
      'Photo by ${photo.photographerName}',
    ].nonNulls.join('. '),
    excludeSemantics: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          StockPhotoImage(photo: photo, url: photo.thumbUrl),
          Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap),
          ),
        ],
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}
