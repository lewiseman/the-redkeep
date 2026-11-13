import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/presentation/sync_material.dart';
import '../application/discover_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/recommender/feature_space.dart';
import '../domain/recommender/taste.dart';
import 'watch_widgets.dart';

/// What Discover should never deal.
class WatchPreferencesPage extends ConsumerWidget {
  const WatchPreferencesPage({super.key});

  static const _runtimes = [
    (0, 'Any length'),
    (100, 'Under 1h 40m'),
    (130, 'Under 2h 10m'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final profile = ref.watch(watchProfileProvider).value;
    final rules = profile?.dealbreakers ?? const Dealbreakers();
    Future<void> save(Dealbreakers next) => runWatchAction(context, () async {
      await updateProfile(
        ref.read(watchlistRepositoryProvider),
        (p) => p.dealbreakers = next,
      );
      if (ref.exists(discoverProvider)) {
        await ref.read(discoverProvider.notifier).redeal();
      }
    });
    final heading = TextStyle(
      color: palette.muted,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: watchAppBar(context, title: 'Dealbreakers'),
      body: SafeArea(
        top: false,
        child: profile == null
            ? const WatchLoading()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Films'),
                    value: rules.films,
                    onChanged: rules.films && !rules.shows
                        ? null
                        : (v) => save(rules.copyWith(films: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Shows'),
                    value: rules.shows,
                    onChanged: rules.shows && !rules.films
                        ? null
                        : (v) => save(rules.copyWith(shows: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Any language'),
                    subtitle: const Text(
                      'Off keeps to English-language titles',
                    ),
                    value: rules.anyLanguage,
                    onChanged: (v) => save(rules.copyWith(anyLanguage: v)),
                  ),
                  const SizedBox(height: 16),
                  Text('Film length', style: heading),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (minutes, label) in _runtimes)
                        ChoiceChip(
                          label: Text(label),
                          selected: rules.maxRuntime == minutes,
                          onSelected: (_) =>
                              save(rules.copyWith(maxRuntime: minutes)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Never deal', style: heading),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final genre in FeatureSpace.genres)
                        FilterChip(
                          label: Text(genre),
                          selected: rules.excludedGenres.contains(genre),
                          onSelected: (excluded) => save(
                            rules.copyWith(
                              excludedGenres: excluded
                                  ? {...rules.excludedGenres, genre}
                                  : ({...rules.excludedGenres}..remove(genre)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
