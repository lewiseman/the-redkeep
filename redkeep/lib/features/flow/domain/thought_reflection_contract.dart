import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../diary/domain/diary_ai_contract.dart' show introducesSensitiveTerm;
import 'thought.dart';

/// L01: one optional, one-line reflection on a single saved thought.
const thoughtReflectionOperation = 'reflect-thought';
const thoughtReflectionContract = 1;
const thoughtReflectionInputBytes = 2000;
const thoughtReflectionOutputBytes = 512;
const thoughtReflectionChars = 200;

/// Exact source identity, including edits with unchanged timestamps.
String thoughtRevision(Thought thought) => sha256
    .convert(
      utf8.encode(
        jsonEncode([
          thought.id,
          thought.revision,
          thought.createdAt.toUtc().toIso8601String(),
          thought.updatedAt.toUtc().toIso8601String(),
          thought.body,
        ]),
      ),
    )
    .toString();

bool validSummaryText(String text, int limit) =>
    text.trim().isNotEmpty &&
    utf8.encode(text).length <= limit &&
    !RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(text) &&
    !text.runes.any((r) => r >= 0xd800 && r <= 0xdfff);

final _lineBreak = RegExp(r'[\r\n\u2028\u2029]');

/// The envelope: one nonempty, well-formed line within the limits.
bool validThoughtReflectionLine(String text) {
  final line = text.trim();
  return validSummaryText(line, thoughtReflectionOutputBytes) &&
      line.runes.length <= thoughtReflectionChars &&
      !_lineBreak.hasMatch(line);
}

class ThoughtReflectionRejected implements Exception {
  const ThoughtReflectionRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[‘’‛`]'), "'")
    .replaceAll(RegExp(r'''[\s"“”„'.,;:!?…-]+'''), ' ')
    .trim();

// English-only safety nets after the prompt; they can miss paraphrases.
// A term the person wrote themselves is allowed back.
final _dramatic = RegExp(
  r"\b(always|never|every(one|body|thing)|nothing|truly|deeply|profound(ly)?|"
  r"forever|destiny|destined|meant to be|life[- ]changing|incredibl[ey]|no matter what|"
  r"(your|the) (whole|entire) life|everything will|you are (so|a|an|the|truly|clearly)|"
  r"you're (so|a|an|the|truly|clearly)|clearly you)\b",
  caseSensitive: false,
);
final _directive = RegExp(
  r"\b(you (must|should|need to|have to)|it's (important|essential|crucial) to|tell me|be honest|admit it|make sure|don't forget)\b",
  caseSensitive: false,
);

// The model speaking as an assistant rather than reflecting.
final _assistant = RegExp(
  r"\b(i('m| am) sorry|i can('t|not) (help|assist)|as an ai|language model|here is|here's a)\b",
  caseSensitive: false,
);

/// Phone-side checks on a reflection for [thought]. The phone holds the
/// thought text, so these checks are authoritative; the companion only
/// bounds the envelope.
String parseThoughtReflection(String text, String thought) {
  if (!validThoughtReflectionLine(text)) {
    throw const FormatException('Not one short line');
  }
  final line = text.trim();
  // Patterns are written with straight apostrophes.
  final plain = line.replaceAll(RegExp('[‘’‛`]'), "'");
  bool introduced(RegExp pattern) =>
      pattern.allMatches(plain).any((m) => !_wrote(thought, m.group(0)!));
  if (_assistant.hasMatch(plain)) {
    throw const ThoughtReflectionRejected(
      'Your computer did not return a reflection, so nothing was shown.',
    );
  }
  // Copying the thought, or a sentence of it, is not a reflection.
  if (_normalize(thought).contains(_normalize(line))) {
    throw const ThoughtReflectionRejected(
      'The reflection only repeated your thought, so it was not shown.',
    );
  }
  if (_sensitiveIntroduced(line, thought)) {
    throw const ThoughtReflectionRejected(
      'The reflection raised something too personal, so it was not shown.',
    );
  }
  if (introduced(_dramatic)) {
    throw const ThoughtReflectionRejected(
      'The reflection sounded more sweeping than your thought, so it was not shown.',
    );
  }
  if (introduced(_directive) || '?'.allMatches(line).length > 1) {
    throw const ThoughtReflectionRejected(
      'The reflection pushed instead of reflecting, so it was not shown.',
    );
  }
  return line;
}

/// Whether [thought] contains [term] as whole words, ignoring case.
bool _wrote(String thought, String term) =>
    RegExp('\\b${RegExp.escape(_normalize(term))}\\b')
        .hasMatch(_normalize(thought));

/// A sensitive one- or two-word term in [line] that [thought] lacks.
bool _sensitiveIntroduced(String line, String thought) {
  if (!introducesSensitiveTerm(line)) return false;
  final words = _normalize(line).split(' ');
  for (var i = 0; i < words.length; i++) {
    final one = words[i];
    if (introducesSensitiveTerm(one)) {
      if (!_wrote(thought, one)) return true;
    } else if (i + 1 < words.length &&
        !introducesSensitiveTerm(words[i + 1]) &&
        introducesSensitiveTerm('$one ${words[i + 1]}') &&
        !_wrote(thought, '$one ${words[i + 1]}')) {
      return true;
    }
  }
  return false;
}

class ThoughtReflectionSource {
  const ThoughtReflectionSource({
    required this.id,
    required this.version,
    required this.body,
  });
  factory ThoughtReflectionSource.fromThought(Thought thought) =>
      ThoughtReflectionSource(
        id: thought.id,
        version: thoughtRevision(thought),
        body: thought.body,
      );
  final String id, version, body;
  String encode() => jsonEncode({'id': id, 'version': version, 'body': body});
  factory ThoughtReflectionSource.decode(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['id'] is! String ||
        !isThoughtId(data['id'] as String) ||
        data['version'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['version'] as String) ||
        data['body'] is! String) {
      throw const FormatException('Invalid reflection source');
    }
    return ThoughtReflectionSource(
      id: data['id'] as String,
      version: data['version'] as String,
      body: data['body'] as String,
    );
  }
  bool matches(Thought? thought) =>
      thought != null &&
      thought.deletedAt == null &&
      thought.id == id &&
      thoughtRevision(thought) == version &&
      thought.body == body;
}
