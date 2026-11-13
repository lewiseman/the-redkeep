import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/watchlist_providers.dart';
import 'watch_list_sheet.dart';
import 'watch_widgets.dart';

/// Films and shows from TMDB, searched as the reader pauses typing.
class WatchSearchPage extends ConsumerStatefulWidget {
  const WatchSearchPage({super.key});

  static const debounce = Duration(milliseconds: 350);

  @override
  ConsumerState<WatchSearchPage> createState() => _WatchSearchPageState();
}

class _WatchSearchPageState extends ConsumerState<WatchSearchPage> {
  final _query = TextEditingController();
  Timer? _timer;
  String _asked = '';

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _timer?.cancel();
    _timer = Timer(WatchSearchPage.debounce, () {
      if (mounted) setState(() => _asked = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final configured = ref.watch(tmdbClientProvider) != null;
    final results = _asked.isEmpty
        ? null
        : ref.watch(watchSearchProvider(_asked));
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        backgroundColor: palette.ground,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: configured,
          enabled: configured,
          textInputAction: TextInputAction.search,
          onChanged: _changed,
          onSubmitted: (value) {
            _timer?.cancel();
            setState(() => _asked = value.trim());
          },
          decoration: const InputDecoration(
            hintText: 'Search films and shows',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.text.isNotEmpty || _asked.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () {
                _timer?.cancel();
                _query.clear();
                setState(() => _asked = '');
              },
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !configured
            ? WatchMessage(
                title: 'Search needs TMDB',
                body: const WatchlistSetupException().toString(),
              )
            : switch (results) {
                null => const WatchMessage(
                  title: 'Find a film or show',
                  body:
                      'Search by title. Tap one to see it, or hold it to save.',
                ),
                AsyncData(:final value) when value.isEmpty =>
                  const WatchMessage(
                    title: 'Nothing found',
                    body: 'Try another title or spelling.',
                  ),
                AsyncData(:final value) => PosterGrid(
                  itemCount: value.length,
                  itemBuilder: (context, i) {
                    final title = value[i];
                    return PosterTile(
                      key: ValueKey(title.key),
                      title: title.title,
                      media: title.media,
                      posterPath: title.posterPath,
                      year: title.year,
                      onTap: () => context.push(watchTitleLocation(title.key)),
                      onLongPress: () => showWatchListSheet(context, title),
                    );
                  },
                ),
                AsyncError(:final error) => WatchMessage(
                  title: 'Search did not finish',
                  body: error.toString(),
                  action: TextButton(
                    onPressed: () =>
                        ref.invalidate(watchSearchProvider(_asked)),
                    child: const Text('Try again'),
                  ),
                ),
                _ => const WatchLoading(label: 'Searching…'),
              },
      ),
    );
  }
}
