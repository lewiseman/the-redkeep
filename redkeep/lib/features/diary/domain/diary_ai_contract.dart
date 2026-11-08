import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'diary_period.dart';
import 'diary_document.dart';
import 'diary_day_details.dart';

/// J01: optional, reviewable diary-day metadata from the paired computer.
const diarySuggestionOperation = 'suggest-diary-day';
const diarySuggestionContract = 1;
const diaryInputBytes = 2000;
const diaryOutputBytes = 2048;
const diaryMaxEntries = 12;
const diaryTitleChars = 80;
const diaryThemeChars = 40;
const diaryMaxThemes = 3;

/// Words from contract 1 results that carry no single mood. Older queued or
/// stored results may still use them; new results use an empty string.
const _noMoodWords = {'mixed', 'unclear'};

final _control = RegExp(r'[\x00-\x1f\x7f]');

bool _plain(String value, int chars, {bool empty = false}) =>
    (empty || value.trim().isNotEmpty) &&
    value.runes.length <= chars &&
    !_control.hasMatch(value) &&
    !value.runes.any((r) => r >= 0xd800 && r <= 0xdfff);

/// Terms a suggestion must not introduce: diagnoses and sensitive facts.
/// This is a safety net after prompt instructions and evidence grounding,
/// not a classifier. Users can still type any of these words themselves.
final _sensitive = RegExp(
  r'\b(diagnos\w*|disorders?|syndromes?|depression|clinical\w*|ptsd|bipolar|'
  r'adhd|ocd|autis\w*|schizo\w*|psychos[ie]s|psychotic|anorexi\w*|bulimi\w*|'
  r'addict\w*|alcoholi\w*|suicid\w*|self[- ]harm|pregnan\w*|miscarriage|'
  r'sexual\w*|gay|lesbian|bisexual|transgender|religio\w*|disease|cancer|hiv|'
  r'mental illness|therapy|medication)\b',
  caseSensitive: false,
);
bool introducesSensitiveTerm(String value) => _sensitive.hasMatch(value);

const _stopwords = {
  'and',
  'the',
  'for',
  'but',
  'was',
  'are',
  'not',
  'had',
  'has',
  'you',
  'our',
  'its',
  'who',
  'how',
  'did',
  'all',
  'out',
  'with',
  'from',
  'that',
  'this',
  'have',
  'been',
  'were',
  'what',
  'when',
  'then',
  'than',
  'into',
  'just',
  'about',
  'after',
  'before',
  'there',
  'their',
  'they',
  'your',
  'some',
  'more',
  'very',
  'much',
  'over',
  'also',
  'day',
  'days',
  'today',
  'still',
  'while',
};

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[‘’‛`]'), "'")
    .replaceAll(RegExp('[“”„]'), '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
String _trimQuotes(String value) =>
    value.replaceAll(RegExp(r'''^[\s"'.,;:!?…-]+|[\s"'.,;:!?…-]+$'''), '');

/// The exact saved text of one day. It is the local recovery snapshot and the
/// stale-result fence: any edit, deletion or added entry changes [encode].
class DiarySuggestionSource {
  const DiarySuggestionSource(this.date, this.entries);
  final String date;

  /// Full serialized visible items, in reading order.
  final List<Map<String, dynamic>> entries;

  static DiarySuggestionSource fromEntries(
    DiaryPeriod date,
    Iterable<DiaryEntry> entries,
  ) {
    final sorted =
        entries.where((e) => e.deletedAt == null && e.date == date).toList()
          ..sort((a, b) {
            final order = a.createdAt.compareTo(b.createdAt);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
    return DiarySuggestionSource(date.key, [
      for (final e in sorted)
        {'id': e.id, 'revision': e.revision, 'content': e.text.body.trim()},
    ]);
  }

  String get fingerprint => sha256.convert(utf8.encode(encode())).toString();

  List<String> get texts => [for (final e in entries) e['content'] as String];

  String encode() => jsonEncode({'date': date, 'entries': entries});

  factory DiarySuggestionSource.decode(String raw) {
    final value = jsonDecode(raw) as Map<String, dynamic>;
    final date = value['date'];
    final entries = value['entries'];
    if (date is! String ||
        DiaryPeriod.tryParse(date) == null ||
        entries is! List ||
        entries.length > diaryMaxEntries ||
        utf8.encode(raw).length > 131072) {
      throw const FormatException('Invalid diary snapshot');
    }
    final parsed = [
      for (final e in entries) Map<String, dynamic>.from(e as Map),
    ];
    if (parsed.any((e) => e['content'] is! String)) {
      throw const FormatException('Invalid diary snapshot');
    }
    return DiarySuggestionSource(date, parsed);
  }

  /// Only temporary IDs and entry text: no date, UUIDs, title, mood,
  /// attachments, device names or any other day.
  String request() {
    if (entries.isEmpty) {
      throw const FormatException('Write an entry for this page first.');
    }
    if (entries.length > diaryMaxEntries) {
      throw const FormatException(
        'This page has more than 12 entries. Nothing was sent; pages are never shortened.',
      );
    }
    final text = jsonEncode({
      if (!DiaryPeriod.tryParse(date)!.isDay)
        'period': DiaryPeriod.tryParse(date)!.kind.name,
      'entries': [
        for (var i = 0; i < entries.length; i++)
          {'id': 'e$i', 'text': entries[i]['content']},
      ],
    });
    if (utf8.encode(text).length > diaryInputBytes) {
      throw const FormatException(
        'This page’s saved entries exceed 2,000 UTF-8 bytes. Nothing was sent; entries are never shortened.',
      );
    }
    return text;
  }

  bool supports(String evidence) {
    final needle = _trimQuotes(_normalize(evidence));
    if (needle.runes.length < 3) return false;
    return texts.any((t) => _normalize(t).contains(needle));
  }

  /// A title need not quote the entries, but must share wording with them.
  bool titleGrounded(String title) {
    final source = _normalize(texts.join('\n'));
    final tokens = _normalize(title)
        .split(RegExp(r"[^\p{L}\p{N}']+", unicode: true))
        .where((t) => t.runes.length >= 3 && !_stopwords.contains(t))
        .toList();
    final sourceWords = source
        .split(RegExp(r"[^\p{L}\p{N}']+", unicode: true))
        .toSet();
    if (tokens.any(
      (word) => word.runes.length == 3
          ? sourceWords.contains(word)
          : source.contains(word),
    )) {
      return true;
    }
    // A brief assessment can be paraphrased without inventing an event:
    // "today was a good day" -> "A happy day". Restrict this exception to
    // assessment-only titles; "Happy holiday in Paris" still needs its topic
    // to occur in the entries.
    const positive = {
      'good',
      'great',
      'nice',
      'happy',
      'happiness',
      'joy',
      'joyful',
      'positive',
      'positivity',
      'pleasant',
      'wonderful',
    };
    const framing = {
      'a',
      'an',
      'the',
      'day',
      'today',
      'of',
      'and',
      'feeling',
      'feelings',
    };
    final words = _normalize(title)
        .split(RegExp(r"[^\p{L}\p{N}']+", unicode: true))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.any(positive.contains) &&
        words.every((w) => positive.contains(w) || framing.contains(w))) {
      final assessment = RegExp(
        r"\b(?:(?:a|my|the) )?(?:good|great|nice|happy|joyful|positive|pleasant|wonderful) day\b",
      );
      for (final text in texts.map(_normalize)) {
        for (final match in assessment.allMatches(text)) {
          final before = text
              .substring(0, match.start)
              .split(RegExp(r'[.!?;\n]'))
              .last;
          if (!RegExp(
            r"\b(not|never|hardly|wasn't|wasnt|isn't|isnt|weren't|werent)\b",
          ).hasMatch(before)) {
            return true;
          }
        }
      }
    }
    // Scripts without spaces (for example Chinese or Japanese).
    final compact = _normalize(title).replaceAll(' ', '');
    final runes = compact.runes.toList();
    for (var i = 0; i + 1 < runes.length; i++) {
      final pair = String.fromCharCodes(runes.sublist(i, i + 2));
      if (RegExp(r'^[\p{L}\p{N}]{2}$', unicode: true).hasMatch(pair) &&
          !RegExp(r'^[\x00-\x7f]+$').hasMatch(pair) &&
          source.contains(pair)) {
        return true;
      }
    }
    return false;
  }
}

class DiaryMoodSuggestion {
  const DiaryMoodSuggestion(this.value, this.evidence);

  /// Exactly one emoji, or "mixed" / "unclear" when there is no mood.
  final String value;
  final String evidence;
  DiaryMood? get mood =>
      _noMoodWords.contains(value) ? null : DiaryMood.fromEmoji(value);
}

class DiaryThemeSuggestion {
  const DiaryThemeSuggestion(this.label, this.evidence);
  final String label, evidence;
}

/// Validated, grounded suggestions. Unsupported parts are removed and counted;
/// the whole result fails only when its envelope is invalid.
class DiarySuggestions {
  const DiarySuggestions({
    required this.title,
    required this.mood,
    required this.themes,
    required this.dropped,
    this.rejectedFields = const {},
  });
  final String? title;
  final DiaryMoodSuggestion mood;
  final List<DiaryThemeSuggestion> themes;
  final int dropped;
  final Set<String> rejectedFields;
  bool get empty => title == null && mood.mood == null && themes.isEmpty;

  static DiarySuggestions parse(String raw, DiarySuggestionSource source) {
    if (utf8.encode(raw).length > diaryOutputBytes) {
      throw const FormatException('Oversized diary suggestions');
    }
    final value = jsonDecode(raw);
    if (value is! Map ||
        (value.keys.toSet()..removeAll(['title', 'mood', 'themes']))
            .isNotEmpty ||
        value.length != 3) {
      throw const FormatException('Invalid diary suggestions');
    }
    final title = value['title'],
        mood = value['mood'],
        themes = value['themes'];
    if (title is! String ||
        !_plain(title, diaryTitleChars, empty: true) ||
        mood is! Map ||
        mood.length != 2 ||
        mood['value'] is! String ||
        mood['evidence'] is! String ||
        !_plain(mood['evidence'] as String, 160, empty: true) ||
        themes is! List ||
        themes.length > diaryMaxThemes) {
      throw const FormatException('Invalid diary suggestions');
    }
    var dropped = 0;
    final rejectedFields = <String>{};
    String? acceptedTitle = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (acceptedTitle.isEmpty) {
      acceptedTitle = null;
    } else if (introducesSensitiveTerm(acceptedTitle) ||
        !source.titleGrounded(acceptedTitle)) {
      acceptedTitle = null;
      rejectedFields.add('title');
      dropped++;
    }
    // One emoji (or a contract 1 mood word, mapped to its emoji). Anything
    // else is dropped like an ungrounded mood; the other fields survive.
    final rawMood = (mood['value'] as String).trim();
    var moodValue = rawMood.isEmpty || _noMoodWords.contains(rawMood)
        ? (rawMood == 'mixed' ? 'mixed' : 'unclear')
        : DiaryMood.tryParse(rawMood)?.emoji;
    final moodEvidence = (mood['evidence'] as String).trim();
    if (moodValue == null ||
        (!_noMoodWords.contains(moodValue) && !source.supports(moodEvidence))) {
      moodValue = 'unclear';
      rejectedFields.add('mood');
      dropped++;
    }
    final accepted = <DiaryThemeSuggestion>[];
    final seen = <String>{};
    for (final theme in themes) {
      if (theme is! Map ||
          theme.length != 2 ||
          theme['label'] is! String ||
          theme['evidence'] is! String ||
          !_plain(theme['label'] as String, diaryThemeChars) ||
          !_plain(theme['evidence'] as String, 160)) {
        throw const FormatException('Invalid diary theme');
      }
      final label = (theme['label'] as String)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final evidence = (theme['evidence'] as String).trim();
      if (introducesSensitiveTerm(label) ||
          !source.supports(evidence) ||
          !seen.add(label.toLowerCase())) {
        rejectedFields.add('themes');
        dropped++;
        continue;
      }
      accepted.add(DiaryThemeSuggestion(label, evidence));
    }
    return DiarySuggestions(
      title: acceptedTitle,
      mood: DiaryMoodSuggestion(
        moodValue,
        _noMoodWords.contains(moodValue) ? '' : moodEvidence,
      ),
      themes: accepted,
      dropped: dropped,
      rejectedFields: Set.unmodifiable(rejectedFields),
    );
  }
}

/// Stored day metadata formats. dayMood keeps the existing calendar JSON.
String encodeDayMood(DiaryMood mood) => jsonEncode({
  'emoji': mood.emoji,
  'name': mood.label,
  'category': mood.name,
});

DiaryMood? decodeDayMood(String? raw) {
  try {
    final decoded = jsonDecode(raw ?? 'null');
    if (decoded is Map) {
      for (final candidate in DiaryMood.values) {
        if (decoded['category'] == candidate.name ||
            decoded['name'] == candidate.label) {
          return candidate;
        }
      }
      if (decoded['emoji'] case final String emoji) {
        return DiaryMood.fromEmoji(emoji);
      }
    }
  } on FormatException {
    // Optional metadata never hides a day.
  }
  return null;
}

/// Validates user- or suggestion-provided themes before storage.
String encodeDayThemes(Iterable<String> themes) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in themes) {
    final theme = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (theme.isEmpty) continue;
    if (!_plain(theme, diaryThemeChars)) {
      throw ArgumentError('Themes are at most 40 characters.');
    }
    if (seen.add(theme.toLowerCase())) result.add(theme);
  }
  if (result.length > diaryMaxThemes) {
    throw ArgumentError('Choose at most three themes.');
  }
  return jsonEncode(result);
}

String normalizeDayTitle(String raw) {
  final title = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (!_plain(title, diaryTitleChars, empty: true)) {
    throw ArgumentError('Titles are at most 80 characters.');
  }
  return title;
}
