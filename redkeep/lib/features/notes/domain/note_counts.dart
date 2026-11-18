import 'package:flutter/foundation.dart';

/// How many notes sit in each collection: live notes, pinned live notes,
/// Trash, and live notes under each tag.
@immutable
class NoteCounts {
  const NoteCounts({
    this.all = 0,
    this.pinned = 0,
    this.trash = 0,
    this.tags = const {},
  });

  final int all;
  final int pinned;
  final int trash;

  /// Keyed by the tag as stored.
  final Map<String, int> tags;

  @override
  bool operator ==(Object other) =>
      other is NoteCounts &&
      other.all == all &&
      other.pinned == pinned &&
      other.trash == trash &&
      mapEquals(other.tags, tags);

  @override
  int get hashCode => Object.hash(
    all,
    pinned,
    trash,
    Object.hashAllUnordered(
      tags.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
