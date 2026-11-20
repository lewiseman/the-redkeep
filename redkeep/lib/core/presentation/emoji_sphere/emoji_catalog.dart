import 'dart:async';
import 'dart:io' show Platform;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'
    show Category, defaultEmojiSet;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// One emoji the sphere can show, with the words search looks through.
final class EmojiEntry {
  EmojiEntry(this.emoji, this.name, this.group) : _words = name.toLowerCase();

  final String emoji;
  final String name;

  /// The emoji's [Category] index; -1 for one the bundled set lacks.
  final int group;
  final String _words;

  @override
  String toString() => 'EmojiEntry($emoji $name)';
}

/// Every emoji the device can draw, in a browsing order that keeps faces
/// first, and a word search over their names.
final class EmojiCatalog {
  EmojiCatalog(List<EmojiEntry> entries)
    : entries = List.unmodifiable(entries),
      _byBare = {for (final entry in entries) _bare(entry.emoji): entry};

  /// The bundled set, unfiltered. Used where the device can't be asked.
  factory EmojiCatalog.bundled() => EmojiCatalog([
    for (final category in defaultEmojiSet)
      for (final emoji in category.emoji)
        EmojiEntry(emoji.emoji, emoji.name, category.category.index),
  ]);

  final List<EmojiEntry> entries;
  final Map<String, EmojiEntry> _byBare;

  static EmojiCatalog? _loaded;
  static Future<EmojiCatalog>? _loading;

  /// The catalog, without glyphs this Android version can't draw. Resolves
  /// synchronously once loaded, and always off Android (tests included).
  static FutureOr<EmojiCatalog> load() {
    if (_loaded case final catalog?) return catalog;
    if (kIsWeb || !Platform.isAndroid) return _loaded = EmojiCatalog.bundled();
    return _loading ??= _filterUnsupported(EmojiCatalog.bundled())
        .then((catalog) => _loaded = catalog);
  }

  static Future<EmojiCatalog> _filterUnsupported(EmojiCatalog all) async {
    try {
      // The picker package's own channel answers with Paint.hasGlyph.
      final supported = await const MethodChannel('emoji_picker_flutter')
          .invokeListMethod<bool>('getSupportedEmojis', {
            'source': [for (final entry in all.entries) entry.emoji],
          });
      if (supported == null || supported.length != all.entries.length) {
        return all;
      }
      return EmojiCatalog([
        for (final (index, entry) in all.entries.indexed)
          if (supported[index]) entry,
      ]);
    } on Exception {
      return all;
    }
  }

  static String _bare(String emoji) => emoji.replaceAll('\u{FE0F}', '');

  /// The entry for [emoji], ignoring variation selectors.
  EmojiEntry? find(String emoji) => _byBare[_bare(emoji.trim())];

  /// [favorites] first, then the first faces, then every other group taken
  /// in turn so any slice of the order holds a little of everything.
  List<EmojiEntry> browseOrder([List<String> favorites = const []]) {
    final seen = <EmojiEntry>{};
    final order = <EmojiEntry>[];
    void add(EmojiEntry? entry) {
      if (entry != null && seen.add(entry)) order.add(entry);
    }

    favorites.map(find).forEach(add);
    final groups = <int, List<EmojiEntry>>{};
    for (final entry in entries) {
      (groups[entry.group] ??= []).add(entry);
    }
    final faces = groups.remove(Category.SMILEYS.index) ?? const [];
    faces.take(_leadingFaces).forEach(add);
    final queues = [
      faces.skip(_leadingFaces).iterator,
      for (final group in groups.keys.toList()..sort()) groups[group]!.iterator,
    ];
    while (queues.isNotEmpty) {
      queues.removeWhere((queue) {
        if (!queue.moveNext()) return true;
        add(queue.current);
        return false;
      });
    }
    return order;
  }

  /// The smileys set opens with faces before hands and people.
  static const _leadingFaces = 110;

  /// Entries with a name word starting with every word of [query] (or a
  /// word it stands for, so "happy" finds grins). Names starting with the
  /// query come first.
  List<EmojiEntry> search(String query) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];
    if (terms.length == 1) {
      if (find(terms.single) case final exact?) return [exact];
    }
    // Words match from their start: "tea" finds teacups, not steam.
    final options = [
      for (final term in terms)
        [
          for (final word in _expand(term))
            RegExp('(^|[^a-z])${RegExp.escape(word)}'),
        ],
    ];
    final matches = entries
        .where(
          (entry) => options.every(
            (words) => words.any((word) => word.hasMatch(entry._words)),
          ),
        )
        .toList();
    final wordStart = RegExp('\\b${RegExp.escape(terms.first)}');
    int rank(EmojiEntry entry) => entry._words.startsWith(terms.first)
        ? 0
        : wordStart.hasMatch(entry._words)
        ? 1
        : 2;
    final ranks = [for (final entry in matches) rank(entry)];
    // Bundled order is kept within each rank.
    return [
      for (var level = 0; level < 3; level++)
        for (final (index, entry) in matches.indexed)
          if (ranks[index] == level) entry,
    ];
  }

  static List<String> _expand(String term) => [
    term,
    for (final MapEntry(key: word, value: words) in _related.entries)
      if (term.length >= 3 && word.startsWith(term)) ...words,
  ];

  /// Feelings people type that the bundled names don't use.
  static const _related = {
    'happy': ['smil', 'grin', 'joy', 'beam', 'laugh'],
    'joy': ['laugh', 'tears of joy', 'grin'],
    'sad': ['cry', 'frown', 'pensive', 'disappointed', 'tear', 'sad'],
    'unhappy': ['frown', 'disappointed', 'pensive'],
    'angry': ['angry', 'pout', 'rage', 'steam', 'symbols on mouth'],
    'mad': ['angry', 'pout', 'rage'],
    'love': ['heart', 'kiss', 'love'],
    'tired': ['sleep', 'yawn', 'weary', 'tired'],
    'sleepy': ['sleep', 'yawn'],
    'calm': ['relieved', 'halo', 'peace', 'lotus'],
    'relaxed': ['relieved', 'smiling face'],
    'excited': ['star-struck', 'party', 'grin', 'hugging'],
    'party': ['party', 'confetti', 'balloon'],
    'scared': ['fear', 'scream', 'anxious', 'grimac'],
    'anxious': ['anxious', 'worried', 'sweat', 'grimac'],
    'worried': ['worried', 'anxious', 'confused'],
    'sick': ['sick', 'mask', 'thermometer', 'nause', 'vomit', 'sneez'],
    'cool': ['sunglasses', 'cool'],
    'funny': ['laugh', 'joy', 'rolling'],
    'bored': ['neutral', 'expressionless', 'unamused'],
    'surprised': ['astonished', 'open mouth', 'hushed', 'surprise'],
    'shocked': ['astonished', 'scream', 'exploding'],
    'proud': ['star-struck', 'trophy', 'medal', 'flexed'],
    'thanks': ['folded hands', 'pray'],
    'work': ['briefcase', 'office', 'laptop', 'computer'],
    'idea': ['light bulb', 'idea'],
    'study': ['book', 'graduation', 'pencil', 'memo'],
    'money': ['money', 'dollar', 'coin', 'bank'],
    'travel': ['airplane', 'globe', 'luggage', 'map', 'travel'],
    'coffee': ['beverage', 'coffee', 'tea'],
    'food': ['food', 'pizza', 'burger', 'bowl', 'fork'],
    'music': ['music', 'musical', 'headphone', 'guitar'],
    'sport': ['ball', 'running', 'trophy', 'medal'],
    'fitness': ['running', 'lifting', 'flexed', 'bicycl'],
    'home': ['house', 'home'],
    'nature': ['tree', 'leaf', 'herb', 'flower', 'seedling'],
  };
}
