import 'dart:convert';

import 'note_document.dart';
import 'note_tag.dart';

/// N02: optional title/tag suggestions.
const noteMetadataOperation = 'suggest-note-metadata';
const noteHelpContract = 1;
const noteHelpInputBytes = 2000;
const noteHelpOutputBytes = 1536;
const noteTitleChars = 80;
const noteTagChars = 24;

/// The tag picker's palette; suggested tags must use one of these.
const noteTagEmojis = [
  '🏷️',
  '💡',
  '📝',
  '💼',
  '🌱',
  '🏡',
  '❤️',
  '✨',
  '📚',
  '🎯',
  '🧠',
  '☕',
  '🎨', //
  '🎵',
  '📷',
  '🌍',
  '🏃',
  '🍜',
  '💰',
  '🛠️',
  '🌿',
  '🌙',
  '☀️',
  '🔥',
  '🧘',
  '🎉',
  '🐾',
  '💭',
];

final _control = RegExp(r'[\x00-\x1f\x7f]');
bool _plain(Object? value, int chars, {bool empty = false}) =>
    value is String &&
    (empty || value.trim().isNotEmpty) &&
    value.runes.length <= chars &&
    !_control.hasMatch(value) &&
    !value.runes.any((unit) => unit >= 0xd800 && unit <= 0xdfff);
String _collapse(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Tags naming sensitive personal attributes are never suggested, even when
/// the note (or text injected into it) asks; the user can still add them.
final _sensitiveTag = RegExp(
  r'\b(depress\w*|anxi\w*|adhd|autis\w*|bipolar|cancer|diabet\w*|pregnan\w*|hiv|'
  r'mental|therap\w*|diagnos\w*|medicat\w*|illness|disab\w*|religio\w*|christian|'
  r'muslim|jewish|hindu|buddhis\w*|atheis\w*|gay|lesbian|bisexual|trans\w*|queer|'
  r'sexual\w*|politic\w*|democrat\w*|republican\w*|ethnic\w*|racial|race)\b',
  caseSensitive: false,
);

/// Notes shorter than this many words get no suggestions: a few words are
/// not enough to describe without inventing.
const noteMetadataMinWords = 4;

/// Whether [name] is usable as the name half of an `emoji#name` tag.
bool validNoteTagName(String name) =>
    _plain(name, noteTagChars) &&
    !name.contains('#') &&
    name.trim().toLowerCase() != 'all';

/// The saved note a metadata request was made from. It stays in protected
/// task storage on the phone; only title, body and tag names are sent.
class NoteMetadataSource {
  const NoteMetadataSource({
    required this.noteId,
    required this.title,
    required this.content,
    required this.tags,
    required this.version,
  });
  final String noteId, title, content, version;
  final List<String> tags;

  factory NoteMetadataSource.fromNote(NoteDocument note) => NoteMetadataSource(
    noteId: note.id,
    title: note.text.title,
    content: note.text.body,
    tags: List.of(note.tags),
    version: note.revision.toString(),
  );

  List<NoteTag> get parsedTags =>
      tags.map(NoteTag.tryParse).whereType<NoteTag>().toList();

  /// Throws [FormatException] when the body is empty or the request would
  /// exceed the limit. Nothing is shortened.
  String request() {
    if (content.trim().isEmpty) {
      throw const FormatException(
        'Write something in the note body first. Suggestions are based only on what it says.',
      );
    }
    if (content.trim().split(RegExp(r'\s+')).length < noteMetadataMinWords) {
      throw const FormatException(
        'This note is too short to suggest a title or tags without guessing. Add a little more first.',
      );
    }
    // The placeholder and very long titles carry no useful context.
    final current = _collapse(title);
    final value = jsonEncode({
      'title':
          current.toLowerCase() == 'untitled note' || current.runes.length > 200
          ? ''
          : current,
      'text': content.trim(),
      'tags': [for (final tag in parsedTags.take(12)) tag.name],
    });
    if (utf8.encode(value).length > noteHelpInputBytes) {
      throw const FormatException(
        'This note is longer than 2,000 UTF-8 bytes including its title. Nothing was sent; notes are never shortened.',
      );
    }
    return value;
  }

  bool matches(NoteDocument? note) =>
      note != null &&
      note.deletedAt == null &&
      note.text.title == title &&
      note.text.body == content &&
      note.revision.toString() == version &&
      note.tags.length == tags.length &&
      note.tags.every(tags.contains);

  String encode() => jsonEncode({
    'noteId': noteId,
    'title': title,
    'content': content,
    'tags': tags,
    'version': version,
  });
  factory NoteMetadataSource.decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map ||
        json['noteId'] is! String ||
        json['title'] is! String ||
        json['content'] is! String ||
        json['version'] is! String ||
        json['tags'] is! List ||
        (json['tags'] as List).any((t) => t is! String) ||
        utf8.encode(json['content'] as String).length > noteHelpInputBytes) {
      throw const FormatException('Invalid metadata source');
    }
    return NoteMetadataSource(
      noteId: json['noteId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      tags: (json['tags'] as List).cast<String>(),
      version: json['version'] as String,
    );
  }
}

/// Suggestions after the phone's checks: no repeats of the current title or
/// existing tags, no duplicates, palette emoji only. A suggested tag whose
/// name matches a tag used elsewhere reuses that tag's spelling and emoji.
class NoteMetadataSuggestions {
  const NoteMetadataSuggestions(this.titles, this.tags);
  final List<String> titles;
  final List<NoteTag> tags;
  bool get isEmpty => titles.isEmpty && tags.isEmpty;

  /// Throws [FormatException] for a broken envelope.
  factory NoteMetadataSuggestions.parse(
    String text,
    NoteMetadataSource source, {
    Iterable<NoteTag> library = const [],
  }) {
    final json = jsonDecode(text);
    if (json is! Map ||
        json.keys.toSet().difference({'titles', 'tags'}).isNotEmpty ||
        json['titles'] is! List ||
        json['tags'] is! List) {
      throw const FormatException('Invalid suggestions');
    }
    final titles = <String>[];
    final seenTitles = {_collapse(source.title).toLowerCase(), ''};
    for (final value in json['titles'] as List) {
      if (!_plain(value, noteTitleChars)) {
        throw const FormatException('Invalid title');
      }
      final title = _collapse(value as String)
          .replaceAll(RegExp(r'''^["'“‘]+|["'”’]+$'''), '');
      if (title.isNotEmpty && seenTitles.add(title.toLowerCase())) {
        titles.add(title);
      }
    }
    final known = {for (final tag in library) tag.key: tag};
    final seenTags = {for (final tag in source.parsedTags) tag.key};
    final tags = <NoteTag>[];
    for (final value in json['tags'] as List) {
      if (value is! Map ||
          !_plain(value['name'], noteTagChars) ||
          !noteTagEmojis.contains(value['emoji'])) {
        throw const FormatException('Invalid tag');
      }
      final name = _collapse(value['name'] as String)
          .replaceAll(RegExp(r'^#+'), '');
      if (!validNoteTagName(name) || _sensitiveTag.hasMatch(name)) continue;
      final tag =
          known[name.toLowerCase()] ??
          NoteTag(name: name, emoji: value['emoji'] as String);
      if (NoteTag.tryParse(tag.encoded)?.key == tag.key &&
          seenTags.add(tag.key)) {
        tags.add(tag);
      }
    }
    return NoteMetadataSuggestions(titles, tags);
  }
}

/// A starting skeleton for a new, unsaved note. Only [topic] is sent.
const noteTemplateOperation = 'suggest-note-template';
const noteTemplateOutputBytes = 1800;
const noteTemplateBodyBytes = 1200;
const noteTemplateLines = 30;
const noteTemplateTopicChars = 120;

class NoteTemplateSource {
  const NoteTemplateSource(this.topic);
  final String topic;

  /// Throws [FormatException] for an empty, long or multi-line purpose.
  String request() {
    final clean = _collapse(topic);
    if (!_plain(clean, noteTemplateTopicChars)) {
      throw const FormatException(
        'Describe what the note is for in one line of at most 120 characters.',
      );
    }
    return jsonEncode({'topic': clean});
  }
}

/// The model's template, re-checked here: an exact envelope, a plain title
/// and a short body of ordinary lines.
class NoteTemplate {
  const NoteTemplate({required this.title, required this.body});
  final String title, body;

  /// Throws [FormatException] for anything outside the contract.
  factory NoteTemplate.parse(String text) {
    final json = jsonDecode(text);
    if (json is! Map ||
        json.keys.length != 2 ||
        !_plain(json['title'], noteTitleChars) ||
        json['body'] is! String) {
      throw const FormatException('Invalid template');
    }
    final body = (json['body'] as String).trimRight();
    if (body.trim().isEmpty ||
        utf8.encode(body).length > noteTemplateBodyBytes ||
        body.split('\n').length > noteTemplateLines ||
        RegExp(r'[\x00-\x09\x0b-\x1f\x7f]').hasMatch(body)) {
      throw const FormatException('Invalid template body');
    }
    return NoteTemplate(title: _collapse(json['title'] as String), body: body);
  }
}
