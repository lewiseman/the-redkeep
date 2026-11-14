import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/navigation_destination.dart';
import '../../ai/application/ai_cloud.dart';
import '../../ai/domain/ai_provider.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/discover_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/watch_title.dart';
import 'night_planner.dart';
import 'watch_widgets.dart';

/// The Library's Likes tab: live matches waiting for a night.
class LikesTabView extends ConsumerStatefulWidget {
  const LikesTabView({super.key});

  @override
  ConsumerState<LikesTabView> createState() => _LikesTabViewState();
}

class _LikesTabViewState extends ConsumerState<LikesTabView> {
  @override
  void initState() {
    super.initState();
    final nights = ref.read(watchNightsProvider);
    unawaited(nights.expireMatches().then((_) => nights.resync()));
  }

  @override
  Widget build(BuildContext context) {
    final titles = ref.watch(watchTitlesProvider);
    final now = ref.watch(watchClockProvider)().toUtc();
    final value = titles.value;
    if (value == null) {
      return titles.hasError
          ? const WatchMessage(
              title: 'Likes could not open',
              body: 'Close the Watchlist and try again.',
            )
          : const WatchLoading();
    }
    final matches = LikesGroups(value, now).matches;
    if (matches.isEmpty) {
      return const WatchMessage(
        title: 'No matches yet',
        body: 'Like titles in Discover. When one likes you back, plan a night.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _Group('New matches', [
          for (final t in matches) _LikeTile(title: t, kind: _Kind.match),
        ]),
      ],
    );
  }
}

/// Above the Planned tab's posters: nights to check in on and to come.
class PlannedNights extends StatelessWidget {
  const PlannedNights({super.key, required this.likes});
  final LikesGroups likes;

  /// Titles shown here, kept out of the poster grid below.
  static Set<String> idsOf(LikesGroups likes) => {
    for (final t in [...likes.checkIn, ...likes.upcoming]) t.id,
  };

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _Group('How did it go?', [
        for (final t in likes.checkIn) _LikeTile(title: t, kind: _Kind.checkIn),
      ]),
      _Group('Upcoming nights', [
        for (final t in likes.upcoming) _LikeTile(title: t, kind: _Kind.night),
      ]),
    ],
  );
}

class _Group extends StatelessWidget {
  const _Group(this.label, this.children);
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final palette = MorePalette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MoreSurface.contentWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Semantics(
                header: true,
                child: Text(
                  label,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

enum _Kind { checkIn, match, night }

class _LikeTile extends ConsumerWidget {
  const _LikeTile({required this.title, required this.kind});
  final WatchTitle title;
  final _Kind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final now = ref.watch(watchClockProvider)().toUtc();
    final nights = ref.read(watchNightsProvider);
    final chat = ref.watch(aiCapabilitiesProvider).contains(AiCapability.chat);
    final format = DateFormat('EEE d MMM, HH:mm');
    final subtitle = switch (kind) {
      _Kind.checkIn => 'Watched ${format.format(title.nightAt!.toLocal())}?',
      _Kind.match => _expiry(title.expiresAt, now),
      _Kind.night => format.format(title.nightAt!.toLocal()),
    };
    final urgent =
        kind == _Kind.match &&
        title.expiresAt != null &&
        title.expiresAt!.difference(now) < const Duration(days: 2);
    final menu = <(String, Future<void> Function())>[
      if (chat)
        ('Chat', () async => context.push(watchChatLocation(title.key))),
      if (kind == _Kind.night) ...[
        ('Reschedule', () async => planNightFlow(context, ref, title)),
        ('Cancel night', () => nights.cancelNight(title)),
      ],
      if (kind != _Kind.checkIn) ('Unmatch', () => nights.unmatch(title)),
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push(watchTitleLocation(title.key)),
      leading: SizedBox(
        width: 44,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: WatchPoster(
            path: title.posterPath,
            media: title.media,
            radius: 6,
          ),
        ),
      ),
      title: Text(title.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: urgent ? Theme.of(context).colorScheme.error : palette.muted,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kind == _Kind.match)
            TextButton(
              onPressed: () => planNightFlow(context, ref, title),
              child: const Text('Plan'),
            ),
          if (kind == _Kind.checkIn || kind == _Kind.night)
            TextButton(
              onPressed: () => checkInFlow(context, ref, title),
              child: Text(kind == _Kind.checkIn ? 'Check in' : 'Watched'),
            ),
          if (menu.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: 'More for ${title.title}',
              onSelected: (i) => runWatchAction(context, menu[i].$2),
              itemBuilder: (_) => [
                for (var i = 0; i < menu.length; i++)
                  PopupMenuItem(value: i, child: Text(menu[i].$1)),
              ],
            ),
        ],
      ),
    );
  }

  static String _expiry(DateTime? at, DateTime now) {
    if (at == null) return 'Matched';
    final left = at.difference(now);
    if (left.inDays >= 1) {
      return left.inDays == 1
          ? '1 day to plan a night'
          : '${left.inDays} days to plan a night';
    }
    final hours = left.inHours.clamp(1, 24);
    return hours == 1 ? 'Ends within the hour' : 'Ends in $hours hours';
  }
}
