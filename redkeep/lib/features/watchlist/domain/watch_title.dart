import 'dart:convert';

import 'package:crypto/crypto.dart';

enum WatchMedia {
  movie,
  tv;

  static WatchMedia? tryParse(String? value) => switch (value) {
    'movie' => movie,
    'tv' => tv,
    _ => null,
  };
}

/// A TMDB title. Movie and TV ids overlap, so the media type is part of it.
class WatchKey {
  const WatchKey(this.media, this.tmdbId);

  final WatchMedia media;
  final int tmdbId;

  /// `movie:123` or `tv:456`.
  String get value => '${media.name}:$tmdbId';

  /// The synced document id. Deterministic, so two devices adding the same
  /// title arrive at the same document.
  String get id => watchTitleId(value);

  static final _pattern = RegExp(r'^(movie|tv):([1-9][0-9]{0,8})$');

  static WatchKey? tryParse(String? value) {
    final match = _pattern.firstMatch(value ?? '');
    if (match == null) return null;
    return WatchKey(WatchMedia.tryParse(match[1])!, int.parse(match[2]!));
  }

  static WatchKey? fromRoute(String? media, String? tmdbId) =>
      tryParse('$media:$tmdbId');

  @override
  bool operator ==(Object other) =>
      other is WatchKey && other.media == media && other.tmdbId == tmdbId;

  @override
  int get hashCode => Object.hash(media, tmdbId);

  @override
  String toString() => value;
}

String watchTitleId(String key) => md5.convert(utf8.encode(key)).toString();

bool isWatchId(String value) => RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

/// Stored by name; never reorder-sensitive.
enum WatchStatus {
  planned('Planned', 'Plan to watch'),
  watching('Watching', 'Watching'),
  completed('Completed', 'Watched'),
  paused('Paused', 'Paused'),
  dropped('Dropped', 'Dropped');

  const WatchStatus(this.label, this.action);
  final String label;
  final String action;

  static WatchStatus? tryParse(String? value) =>
      values.where((s) => s.name == value).firstOrNull;
}

/// Left passes, right likes, up says it has already been watched.
enum SwipeChoice {
  nope,
  like,
  watched;

  static SwipeChoice? tryParse(String? value) =>
      values.where((s) => s.name == value).firstOrNull;
}

enum MatchState {
  active,
  dated,
  ghosted,
  unmatched;

  static MatchState? tryParse(String? value) =>
      values.where((s) => s.name == value).firstOrNull;
}

enum NightOutcome {
  loved('Loved it'),
  fine('It was fine'),
  neverAgain('Never again');

  const NightOutcome(this.label);
  final String label;

  static NightOutcome? tryParse(String? value) =>
      values.where((s) => s.name == value).firstOrNull;
}

/// An episode's place in a show, stored as `s1e4`.
String episodeCode(int season, int episode) => 's${season}e$episode';

final episodeCodePattern = RegExp(r'^s([0-9]{1,3})e([0-9]{1,4})$');

/// Everything the reader has done with one title. Synced as one document.
class WatchTitle {
  const WatchTitle({
    required this.id,
    required this.key,
    required this.title,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.posterPath,
    this.year,
    this.status,
    this.rating,
    this.note = '',
    this.swipe,
    this.matchState,
    this.matchedAt,
    this.expiresAt,
    this.nightAt,
    this.outcome,
    this.checkedInAt,
    this.episodes = const {},
    this.deletedAt,
  });

  final String id;
  final WatchKey key;
  final String title;
  final String? posterPath;
  final int? year;
  final WatchStatus? status;

  /// 1 to 10.
  final int? rating;
  final String note;
  final SwipeChoice? swipe;
  final MatchState? matchState;
  final DateTime? matchedAt;
  final DateTime? expiresAt;
  final DateTime? nightAt;
  final NightOutcome? outcome;
  final DateTime? checkedInAt;
  final Set<String> episodes;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get removed => deletedAt != null;
  WatchMedia get media => key.media;
}

class WatchList {
  const WatchList({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Title ids, newest first.
  final List<String> items;
  final DateTime createdAt;
}

enum WatchlistFailure { unavailable, emptyName, readOnly }

class WatchlistException implements Exception {
  const WatchlistException(this.failure);
  final WatchlistFailure failure;
}
