import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart';
import '../data/local_watch_reminders.dart';
import '../data/tmdb_client.dart';
import '../domain/catalog_title.dart';
import '../domain/recommender/deck.dart';
import '../domain/recommender/feature_space.dart';
import '../domain/recommender/taste.dart';
import '../domain/reminders.dart';
import '../domain/watch_title.dart';
import '../domain/watchlist_repository.dart';
import 'watchlist_providers.dart';

/// How long the deck is kept while the reader is elsewhere.
const discoverKeptFor = Duration(minutes: 30);

/// How long a match waits for a planned night.
const matchLifetime = Duration(days: 7);

/// Enough titles for a varied deck without fetching details for each.
const catalogTarget = 200;

final deckRandomProvider = Provider<Random>((ref) => Random());

final watchProfileProvider = StreamProvider.autoDispose<WatchProfile>(
  (ref) => ref
      .watch(watchlistRepositoryProvider)
      .watchProfile()
      .map(
        (state) =>
            state == null ? WatchProfile() : WatchProfile.fromJson(state),
      ),
  retry: (_, _) => null,
);

final watchRemindersProvider = Provider<WatchReminders>(
  (ref) => LocalWatchReminders(),
);

enum DiscoverPhase { loading, filling, ready, empty, needsKey, failed }

class DiscoverState {
  const DiscoverState({
    this.phase = DiscoverPhase.loading,
    this.cards = const [],
    this.progress = 0,
    this.canUndo = false,
    this.coldStartLeft = 0,
    this.match,
    this.error,
  });

  final DiscoverPhase phase;
  final List<DeckCard> cards;

  /// 0 to 1 while the catalog fills.
  final double progress;
  final bool canUndo;

  /// Swipes until match percentages appear.
  final int coldStartLeft;

  /// The card that just matched, until the reader dismisses it.
  final DeckCard? match;
  final String? error;

  DiscoverState copyWith({
    DiscoverPhase? phase,
    List<DeckCard>? cards,
    double? progress,
    bool? canUndo,
    int? coldStartLeft,
    DeckCard? match,
    bool clearMatch = false,
    String? error,
  }) => DiscoverState(
    phase: phase ?? this.phase,
    cards: cards ?? this.cards,
    progress: progress ?? this.progress,
    canUndo: canUndo ?? this.canUndo,
    coldStartLeft: coldStartLeft ?? this.coldStartLeft,
    match: clearMatch ? null : match ?? this.match,
    error: error ?? this.error,
  );
}

class _Undo {
  const _Undo(this.card, this.before, this.profile);
  final DeckCard card;
  final WatchTitle? before;
  final Map<String, dynamic> profile;
}

final discoverProvider =
    NotifierProvider.autoDispose<DiscoverController, DiscoverState>(
      DiscoverController.new,
    );

class DiscoverController extends Notifier<DiscoverState> {
  late WatchlistRepository _repository;
  late WatchProfile _profile;
  final _undo = <_Undo>[];
  bool _disposed = false;

  @override
  DiscoverState build() {
    _repository = ref.watch(watchlistRepositoryProvider);
    ref.onDispose(() => _disposed = true);
    // The same deck, top card and undo when the reader comes back.
    keepWhileAway(
      ref,
      discoverKeptFor,
      // Outside the life-cycle callback, where state may be read.
      onReturn: () => scheduleMicrotask(() => unawaited(_prune())),
    );
    unawaited(_start());
    return const DiscoverState();
  }

  /// Drops cards saved or swiped elsewhere while Discover was away.
  Future<void> _prune() async {
    if (state.cards.isEmpty) return;
    final seen = {for (final t in await _repository.titles()) t.id};
    final kept = [
      for (final c in state.cards)
        if (!seen.contains(c.title.key.id)) c,
    ];
    if (_disposed || kept.length == state.cards.length) return;
    if (kept.isEmpty) {
      await _deal();
    } else {
      _emit(state.copyWith(cards: kept));
    }
  }

  void _emit(DiscoverState next) {
    if (!_disposed) state = next;
  }

  Future<void> _start() async {
    try {
      _profile = WatchProfile.fromJson(await _repository.readProfile() ?? {});
      await _fillCatalog();
      await _deal();
    } on _Stop {
      return;
    } on Object catch (error) {
      _emit(
        state.copyWith(
          phase: DiscoverPhase.failed,
          error: error is TmdbException ? error.message : '$error',
        ),
      );
    }
  }

  /// Popular, acclaimed and lesser-known films and shows, fetched once.
  Future<void> _fillCatalog() async {
    if (await _repository.catalogSize() >= catalogTarget) return;
    final client = ref.read(tmdbClientProvider);
    if (client == null) {
      if (await _repository.catalogSize() == 0) {
        _emit(state.copyWith(phase: DiscoverPhase.needsKey));
        throw const _Stop();
      }
      return;
    }
    final requests = <Future<List<CatalogTitle>> Function()>[
      client.trending,
      for (final media in WatchMedia.values)
        for (final chart in ['popular', 'top_rated'])
          for (var page = 1; page <= 3; page++)
            () => client.chart(media, chart, page: page),
      for (var page = 1; page <= 2; page++)
        () => client.discover(WatchMedia.movie, {
          'sort_by': 'vote_average.desc',
          'vote_average.gte': '7.2',
          'vote_count.gte': '150',
          'vote_count.lte': '2500',
        }, page: page),
    ];
    for (var i = 0; i < requests.length; i++) {
      _emit(
        state.copyWith(
          phase: DiscoverPhase.filling,
          progress: i / requests.length,
        ),
      );
      try {
        await _repository.cacheTitles(await requests[i]());
      } on TmdbException catch (e) {
        // A few missing pages still leave a deck; no key or no network don't.
        if (e.failure == TmdbFailure.unauthorized ||
            (e.failure == TmdbFailure.offline && i == 0)) {
          rethrow;
        }
      }
      if (_disposed) throw const _Stop();
    }
  }

  Future<void> _deal() async {
    final titles = await _repository.titles();
    final catalog = await _repository.catalog();
    final byId = {for (final c in catalog) c.key.id: c};
    final seen = {for (final t in titles) t.id};
    final liked = [
      for (final t in titles)
        if (t.swipe == SwipeChoice.like ||
            t.status == WatchStatus.completed ||
            t.outcome == NightOutcome.loved)
          byId[t.id] ?? catalogFromWatchTitle(t),
    ];
    final cards = DeckBuilder(
      random: ref.read(deckRandomProvider),
    ).build(candidates: catalog, profile: _profile, seen: seen, liked: liked);
    _undo.clear();
    _emit(
      state.copyWith(
        phase: cards.isEmpty ? DiscoverPhase.empty : DiscoverPhase.ready,
        cards: cards,
        canUndo: false,
        coldStartLeft: max(0, WatchProfile.coldStartSwipes - _profile.swipes),
      ),
    );
  }

  Future<void> swipe(SwipeChoice choice) async {
    if (state.cards.isEmpty) return;
    final card = state.cards.first;
    final before = await _repository.title(card.title.key.id);
    final saved = _profile.toJson();
    final matched = _profile.swipe(FeatureSpace.vector(card.title), choice);
    final now = ref.read(watchClockProvider)().toUtc();
    try {
      await _repository.edit(
        card.title,
        (_) => WatchTitlesCompanion(
          swipe: Value(choice.name),
          // Seen already: straight into the Library as watched.
          status: choice == SwipeChoice.watched
              ? Value(WatchStatus.completed.name)
              : const Value.absent(),
          matchState: matched
              ? Value(MatchState.active.name)
              : const Value.absent(),
          matchedAt: matched
              ? Value(now.millisecondsSinceEpoch)
              : const Value.absent(),
          expiresAt: matched
              ? Value(now.add(matchLifetime).millisecondsSinceEpoch)
              : const Value.absent(),
        ),
      );
    } on Object {
      _profile = WatchProfile.fromJson(saved);
      rethrow;
    }
    await _saveProfile();
    _undo.add(_Undo(card, before, saved));
    final rest = state.cards.skip(1).toList();
    _emit(
      state.copyWith(
        cards: rest,
        canUndo: true,
        match: matched ? card : null,
        coldStartLeft: max(0, WatchProfile.coldStartSwipes - _profile.swipes),
      ),
    );
    if (matched) unawaited(resyncReminders(ref));
    if (rest.isEmpty) await _deal();
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final last = _undo.removeLast();
    final before = last.before;
    if (before == null) {
      await _repository.removeTitle(last.card.title.key.id);
    } else {
      await _repository.edit(
        last.card.title,
        (_) => WatchTitlesCompanion(
          swipe: Value(before.swipe?.name),
          status: Value(before.status?.name),
          matchState: Value(before.matchState?.name),
          matchedAt: Value(before.matchedAt?.millisecondsSinceEpoch),
          expiresAt: Value(before.expiresAt?.millisecondsSinceEpoch),
        ),
      );
    }
    _profile = WatchProfile.fromJson(last.profile);
    await _saveProfile();
    _emit(
      state.copyWith(
        phase: DiscoverPhase.ready,
        cards: [last.card, ...state.cards],
        canUndo: _undo.isNotEmpty,
        clearMatch: true,
        coldStartLeft: max(0, WatchProfile.coldStartSwipes - _profile.swipes),
      ),
    );
    unawaited(resyncReminders(ref));
  }

  void dismissMatch() => _emit(state.copyWith(clearMatch: true));

  /// After dealbreakers change.
  Future<void> redeal() async {
    _profile = WatchProfile.fromJson(await _repository.readProfile() ?? {});
    await _deal();
  }

  /// Retry after a failed start.
  Future<void> retry() async {
    _emit(const DiscoverState());
    await _start();
  }

  /// Taste stays on an add-only device until it is primary again.
  Future<void> _saveProfile() async {
    try {
      await _repository.saveProfile(_profile.toJson());
    } on StateError {
      // The swipe itself is saved; only learning waits.
    }
  }
}

class _Stop implements Exception {
  const _Stop();
}

/// Reads, changes and saves the taste document, keeping the change local
/// when this device may not edit it.
Future<void> updateProfile(
  WatchlistRepository repository,
  void Function(WatchProfile profile) change,
) async {
  final profile = WatchProfile.fromJson(await repository.readProfile() ?? {});
  change(profile);
  try {
    await repository.saveProfile(profile.toJson());
  } on StateError {
    // Add-only device: nothing more to do.
  }
}

/// Schedules reminders for every live match and night.
Future<void> resyncReminders(Ref ref) async {
  try {
    final repository = ref.read(watchlistRepositoryProvider);
    final titles = await repository.titles();
    final runtimes = <String, int>{};
    for (final t in titles) {
      if (t.matchState != MatchState.dated) continue;
      final runtime = (await repository.cachedTitle(t.key))?.runtime;
      if (runtime != null) runtimes[t.id] = runtime;
    }
    final plan = const ReminderPlanner().plan(
      titles,
      now: ref.read(watchClockProvider)(),
      runtimes: runtimes,
    );
    await ref.read(watchRemindersProvider).replaceAll(plan);
  } on Object {
    // Reminders are a courtesy; the Likes page shows everything regardless.
  }
}

final watchNightsProvider = Provider<WatchNights>(WatchNights.new);

/// Matches, planned nights and how they went.
class WatchNights {
  WatchNights(this._ref);
  final Ref _ref;

  WatchlistRepository get _repository => _ref.read(watchlistRepositoryProvider);
  DateTime get _now => _ref.read(watchClockProvider)().toUtc();

  Future<CatalogTitle> _catalog(WatchTitle title) async =>
      await _repository.cachedTitle(title.key) ?? catalogFromWatchTitle(title);

  /// Matches left without a night past their time become ghosts.
  Future<void> expireMatches() async {
    final now = _now;
    for (final t in await _repository.titles()) {
      if (t.matchState != MatchState.active ||
          t.expiresAt == null ||
          t.expiresAt!.isAfter(now)) {
        continue;
      }
      try {
        final catalog = await _catalog(t);
        await _repository.edit(
          catalog,
          (_) =>
              WatchTitlesCompanion(matchState: Value(MatchState.ghosted.name)),
        );
        await updateProfile(
          _repository,
          (p) => p.lost(FeatureSpace.vector(catalog)),
        );
      } on StateError {
        return; // Add-only device: the primary will tidy up.
      }
    }
  }

  /// Plans a night; asks for notification permission the first time.
  Future<void> planNight(WatchTitle title, DateTime at) async {
    await _repository.edit(
      await _catalog(title),
      (current) => WatchTitlesCompanion(
        matchState: Value(MatchState.dated.name),
        nightAt: Value(at.toUtc().millisecondsSinceEpoch),
        expiresAt: const Value(null),
        status: current?.status == null
            ? Value(WatchStatus.planned.name)
            : const Value.absent(),
      ),
    );
    try {
      await _ref.read(watchRemindersProvider).requestPermission();
    } on Object {
      // Without permission the night is still planned.
    }
    await resyncReminders(_ref);
  }

  /// Back to an open match with a fresh week.
  Future<void> cancelNight(WatchTitle title) async {
    await _repository.edit(
      await _catalog(title),
      (_) => WatchTitlesCompanion(
        matchState: Value(MatchState.active.name),
        nightAt: const Value(null),
        expiresAt: Value(_now.add(matchLifetime).millisecondsSinceEpoch),
      ),
    );
    await resyncReminders(_ref);
  }

  Future<void> unmatch(WatchTitle title) async {
    final catalog = await _catalog(title);
    await _repository.edit(
      catalog,
      (_) => WatchTitlesCompanion(
        matchState: Value(MatchState.unmatched.name),
        nightAt: const Value(null),
        expiresAt: const Value(null),
      ),
    );
    await updateProfile(
      _repository,
      (p) => p.lost(FeatureSpace.vector(catalog)),
    );
    await resyncReminders(_ref);
  }

  /// How the night went: it is watched, and taste learns from it.
  Future<void> checkIn(WatchTitle title, NightOutcome outcome) async {
    final catalog = await _catalog(title);
    final now = _now;
    await _repository.edit(
      catalog,
      (current) => WatchTitlesCompanion(
        outcome: Value(outcome.name),
        checkedInAt: Value(now.millisecondsSinceEpoch),
        // Checking in early moves the night to now.
        nightAt: current?.nightAt != null && current!.nightAt!.isAfter(now)
            ? Value(now.millisecondsSinceEpoch)
            : const Value.absent(),
        status: Value(WatchStatus.completed.name),
      ),
    );
    await updateProfile(
      _repository,
      (p) => p.night(FeatureSpace.vector(catalog), outcome),
    );
    await resyncReminders(_ref);
  }

  Future<void> resync() => resyncReminders(_ref);
}

/// Likes, grouped as the page shows them.
class LikesGroups {
  LikesGroups(List<WatchTitle> titles, DateTime now)
    : checkIn = [
        for (final t in titles)
          if (t.matchState == MatchState.dated &&
              t.outcome == null &&
              t.nightAt != null &&
              !t.nightAt!.isAfter(now))
            t,
      ],
      matches = [
        for (final t in titles)
          if (t.matchState == MatchState.active) t,
      ]..sort((a, b) => (a.expiresAt ?? now).compareTo(b.expiresAt ?? now)),
      upcoming = [
        for (final t in titles)
          if (t.matchState == MatchState.dated &&
              t.outcome == null &&
              t.nightAt != null &&
              t.nightAt!.isAfter(now))
            t,
      ]..sort((a, b) => a.nightAt!.compareTo(b.nightAt!)),
      loved = [
        for (final t in titles)
          if (t.outcome == NightOutcome.loved) t,
      ],
      exes = [
        for (final t in titles)
          if (t.outcome == NightOutcome.neverAgain ||
              t.matchState == MatchState.ghosted ||
              t.matchState == MatchState.unmatched)
            t,
      ];

  final List<WatchTitle> checkIn, matches, upcoming, loved, exes;

  bool get isEmpty =>
      checkIn.isEmpty &&
      matches.isEmpty &&
      upcoming.isEmpty &&
      loved.isEmpty &&
      exes.isEmpty;

  /// For the section switcher's badge.
  int get waiting => checkIn.length + matches.length;
}
