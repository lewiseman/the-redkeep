import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'civil_date.dart';
import 'diary_document.dart';
import 'diary_ai_contract.dart';
import '../../recall/domain/search_terms.dart';

/// J02: one optional reflection question for the current civil day.
const dailyQuestionOperation = 'ask-diary-question';
const dailyQuestionContract = 1;
const dailyQuestionInputBytes = 2000;
const dailyQuestionOutputBytes = 1024;
const dailyQuestionChars = 200;

/// The disclosed selection: today's latest four text entries, then up to
/// eight whole earlier entries from the previous seven civil days, newest
/// first, while the request fits. Entries are never shortened; one that does
/// not fit is left out.
const dailyQuestionTodayEntries = 4;
const dailyQuestionPriorEntries = 8;
const dailyQuestionLookbackDays = 7;
const dailyQuestionAvoid = 5;

final _dateKey = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _control = RegExp(r'[\x00-\x1f\x7f]');

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[‘’‛`]'), "'")
    .replaceAll(RegExp('[“”„]'), '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
String _trimQuotes(String value) =>
    value.replaceAll(RegExp(r'''^[\s"'.,;:!?…-]+|[\s"'.,;:!?…-]+$'''), '');

class DailyQuestionEntry {
  const DailyQuestionEntry({
    required this.date,
    required this.uuid,
    required this.text,
    this.revision = 0,
  });
  final String date, uuid, text;
  final int revision;
  Map<String, dynamic> toJson() => {
    'date': date,
    'uuid': uuid,
    'text': text,
    'revision': revision,
  };
  factory DailyQuestionEntry.fromJson(Map<String, dynamic> json) {
    final date = json['date'], uuid = json['uuid'], text = json['text'];
    if (date is! String ||
        !_dateKey.hasMatch(date) ||
        uuid is! String ||
        uuid.isEmpty ||
        text is! String) {
      throw const FormatException('Invalid question entry');
    }
    return DailyQuestionEntry(
      date: date,
      uuid: uuid,
      text: text,
      revision: json['revision'] as int? ?? 0,
    );
  }
}

/// Today's text entries a question was asked against. Adding, removing or
/// clearing an entry changes it, which retires the question.
String entryQuestionText(DiaryEntry e) =>
    '${e.text.title}\n\n${e.text.body}'.trim();
List<DiaryEntry> _items(Iterable<DiaryEntry> entries) =>
    entries
        .where((e) => e.deletedAt == null && entryQuestionText(e).isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
String dailyQuestionBasis(String date, Iterable<DiaryEntry> entries) =>
    DiarySuggestionSource.fromEntries(
      CivilDate.tryParse(date)!,
      entries,
    ).fingerprint;
DateTime civil(String key) {
  final d = CivilDate.tryParse(key)!;
  return DateTime.utc(d.year, d.month, d.day);
}

/// The exact selection sent for one request. It stays in protected task
/// storage on the phone; only temporary IDs, text and day offsets are sent.
String dailyQuestionContextKey(String basis, List references) {
  final keys = [
    for (final e in references)
      '${e['id']}:${e['date']}:${e['revision']}:${e['hash']}',
  ]..sort();
  return sha256.convert(utf8.encode(jsonEncode([basis, keys]))).toString();
}

class DailyQuestionSource {
  const DailyQuestionSource(
    this.date,
    this.today,
    this.prior,
    this.avoid, [
    this.basis = '',
  ]);

  /// The civil day the question is for.
  final String date;
  final List<DailyQuestionEntry> today, prior;
  final List<String> avoid;

  /// [dailyQuestionBasis] when selected. Kept on the phone, never sent.
  final String basis;
  List<Map<String, dynamic>> get references => [
    for (final e in [...today, ...prior])
      {
        'id': e.uuid,
        'date': e.date,
        'revision': e.revision,
        'hash': sha256.convert(utf8.encode(e.text)).toString(),
      },
  ];
  String get contextKey => dailyQuestionContextKey(basis, references);

  static DailyQuestionSource select({
    required String today,
    required Iterable<DiaryEntry> Function(String date) day,
    List<String> avoid = const [],
  }) {
    final recent = [
      for (final q in avoid.take(dailyQuestionAvoid))
        if (!_control.hasMatch(q) && q.runes.length <= dailyQuestionChars) q,
    ];
    bool fits(DailyQuestionSource next) =>
        utf8.encode(next.request()).length <= dailyQuestionInputBytes;
    final todays = <DailyQuestionEntry>[];
    for (final item in _items(day(today))) {
      if (todays.length == dailyQuestionTodayEntries) break;
      final entry = DailyQuestionEntry(
        date: today,
        uuid: item.id,
        text: entryQuestionText(item),
        revision: item.revision,
      );
      final next = DailyQuestionSource(
        today,
        [...todays, entry],
        const [],
        recent,
      );
      if (fits(next)) todays.add(entry);
    }
    final prior = <DailyQuestionEntry>[];
    final lookback = [
      for (var ago = 1; ago <= dailyQuestionLookbackDays; ago++)
        CivilDate.tryParse(today)!.shift(-ago)?.key,
    ].whereType<String>();
    for (final date in lookback) {
      for (final item in _items(day(date))) {
        if (prior.length == dailyQuestionPriorEntries) break;
        final entry = DailyQuestionEntry(
          date: date,
          uuid: item.id,
          text: entryQuestionText(item),
          revision: item.revision,
        );
        final next = DailyQuestionSource(today, todays, [
          ...prior,
          entry,
        ], recent);
        if (fits(next)) prior.add(entry);
      }
    }
    // With no entries nothing personal is sent, not even earlier questions,
    // which a model could otherwise mistake for something to follow up on.
    // Repetition is still checked on the phone against local history.
    final basis = dailyQuestionBasis(today, day(today));
    if (todays.isEmpty && prior.isEmpty) {
      return DailyQuestionSource(today, const [], const [], const [], basis);
    }
    return DailyQuestionSource(today, todays, prior, recent, basis);
  }

  int ago(DailyQuestionEntry entry) =>
      civil(date).difference(civil(entry.date)).inDays;

  /// Distinct earlier days used, for the disclosure line.
  List<String> get priorDays => {for (final e in prior) e.date}.toList();

  String encode() => jsonEncode({
    'date': date,
    'today': [for (final e in today) e.toJson()],
    'prior': [for (final e in prior) e.toJson()],
    'avoid': avoid,
    'basis': basis,
  });

  factory DailyQuestionSource.decode(String raw) {
    if (utf8.encode(raw).length > 131072) {
      throw const FormatException('Invalid question snapshot');
    }
    final value = jsonDecode(raw);
    if (value is! Map ||
        value['date'] is! String ||
        !_dateKey.hasMatch(value['date'] as String) ||
        value['today'] is! List ||
        value['prior'] is! List ||
        value['avoid'] is! List ||
        (value['today'] as List).length > dailyQuestionTodayEntries ||
        (value['prior'] as List).length > dailyQuestionPriorEntries ||
        (value['avoid'] as List).length > dailyQuestionAvoid ||
        (value['avoid'] as List).any((q) => q is! String) ||
        (value['basis'] != null && value['basis'] is! String)) {
      throw const FormatException('Invalid question snapshot');
    }
    List<DailyQuestionEntry> entries(Object? list) => [
      for (final e in list as List)
        DailyQuestionEntry.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    return DailyQuestionSource(
      value['date'] as String,
      entries(value['today']),
      entries(value['prior']),
      List<String>.from(value['avoid'] as List),
      value['basis'] as String? ?? '',
    );
  }

  /// Only temporary IDs, entry text and day offsets: no dates, UUIDs, titles,
  /// moods, photos, device names or anything outside the selection.
  String request() => jsonEncode({
    'today': [
      for (var i = 0; i < today.length; i++)
        {'id': 't$i', 'text': today[i].text},
    ],
    'prior': [
      for (var i = 0; i < prior.length; i++)
        {'id': 'p$i', 'ago': ago(prior[i]), 'text': prior[i].text},
    ],
    'avoid': avoid,
  });

  DailyQuestionEntry? entry(String id) {
    final index = int.tryParse(id.length > 1 ? id.substring(1) : '');
    if (index == null) return null;
    final list = id.startsWith('t')
        ? today
        : id.startsWith('p')
        ? prior
        : const <DailyQuestionEntry>[];
    return index >= 0 && index < list.length ? list[index] : null;
  }
}

/// Why a returned question was not shown. The page then offers the plain
/// prompt and an explicit retry.
class DailyQuestionRejected implements Exception {
  const DailyQuestionRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

/// True when [question] repeats or closely rephrases one of [previous].
bool repeatsQuestion(String question, Iterable<String> previous) {
  final words = searchTerms(question);
  final plain = _trimQuotes(_normalize(question));
  for (final earlier in previous) {
    if (_trimQuotes(_normalize(earlier)) == plain) return true;
    final other = searchTerms(earlier);
    final union = words.union(other).length;
    if (union > 0 && words.intersection(other).length / union >= .6) {
      return true;
    }
  }
  return false;
}

// English-only safety nets after the prompt; they can miss paraphrases.
final _pastReference = RegExp(
  r"\b(yesterday|last (time|week|night)|earlier|before|you (said|mentioned|wrote|told|shared)|previous(ly)?)\b",
  caseSensitive: false,
);
final _yesterday = RegExp(r'\byesterday\b', caseSensitive: false);
// Conservative: a follow-up on an earlier day may not place it today, even
// though this also refuses some harmless wording.
final _sameDay = RegExp(
  r'\b(today|tonight|this (morning|afternoon|evening))\b',
  caseSensitive: false,
);
final _pressure = RegExp(
  r"\b(tell me (more|everything)|why (did|do|are|were|would) you|be honest|admit it|you (must|should) (tell|share|admit|explain))\b",
  caseSensitive: false,
);

/// A validated question with an optional link to the entry it follows up on.
class DailyQuestion {
  const DailyQuestion({
    required this.text,
    this.sourceDate,
    this.sourceItem,
    this.evidence = '',
    this.ago = 0,
  });
  final String text;
  final String? sourceDate, sourceItem;
  final String evidence;

  /// Civil days between the question's day and its source; 0 for today.
  final int ago;
  bool get grounded => sourceItem != null;

  static DailyQuestion parse(
    String raw,
    DailyQuestionSource source, {
    Iterable<String> history = const [],
  }) {
    if (utf8.encode(raw).length > dailyQuestionOutputBytes) {
      throw const FormatException('Oversized question');
    }
    final value = jsonDecode(raw);
    if (value is! Map ||
        value.length != 3 ||
        value['question'] is! String ||
        value['source'] is! String ||
        value['evidence'] is! String) {
      throw const FormatException('Invalid question');
    }
    final text = (value['question'] as String)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final id = value['source'] as String;
    final evidence = (value['evidence'] as String).trim();
    if (text.isEmpty ||
        text.runes.length > dailyQuestionChars ||
        _control.hasMatch(text)) {
      throw const FormatException('Invalid question');
    }
    if (!text.endsWith('?') && !text.endsWith('？')) {
      throw const DailyQuestionRejected('AI did not return a question.');
    }
    if (introducesSensitiveTerm(text) || _pressure.hasMatch(text)) {
      throw const DailyQuestionRejected(
        'The question was too personal, so it was not shown.',
      );
    }
    if (repeatsQuestion(text, [...source.avoid, ...history])) {
      throw const DailyQuestionRejected(
        'The question repeated a recent one, so it was not shown.',
      );
    }
    if (id.isEmpty) {
      // A general question must not claim anything about earlier entries.
      if (_pastReference.hasMatch(text)) {
        throw const DailyQuestionRejected(
          'The question referred to something it could not point to, so it was not shown.',
        );
      }
      return DailyQuestion(text: text);
    }
    final entry = source.entry(id);
    final needle = _trimQuotes(_normalize(evidence));
    if (entry == null ||
        needle.runes.length < 3 ||
        !_normalize(entry.text).contains(needle)) {
      throw const DailyQuestionRejected(
        'The question was not supported by your entries, so it was not shown.',
      );
    }
    final ago = source.ago(entry);
    if ((_yesterday.hasMatch(text) && ago != 1) ||
        (ago >= 1 && _sameDay.hasMatch(text))) {
      throw const DailyQuestionRejected(
        'The question got the timing of an entry wrong, so it was not shown.',
      );
    }
    return DailyQuestion(
      text: text,
      sourceDate: entry.date,
      sourceItem: entry.uuid,
      evidence: evidence,
      ago: ago,
    );
  }

  /// Rechecked whenever it is shown: an edited or deleted source hides it.
  bool stillGrounded(Iterable<DiaryEntry> Function(String date) day) {
    if (!grounded) return true;
    final item = day(sourceDate!)
        .where((i) => i.id == sourceItem && i.deletedAt == null)
        .firstOrNull;
    return item != null &&
        _normalize(entryQuestionText(item))
            .contains(_trimQuotes(_normalize(evidence)));
  }
}
