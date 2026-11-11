import 'dart:convert';

import 'note_document.dart';
import 'note_tag.dart';

/// N02: optional title suggestions; tag suggestions live in the tag picker.
const noteMetadataOperation = 'suggest-note-metadata';
const noteHelpContract = 1;
const noteHelpInputBytes = 2000;
const noteHelpOutputBytes = 1536;
const noteTitleChars = 80;
const noteTagChars = 24;

/// A tag request also lists the person's existing tags so the model can
/// reuse them; the note part alone stays within [noteHelpInputBytes].
const noteTagsInputBytes = 6000;
const noteTagsLibraryMax = 80;

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

/// Throws [FormatException] when [content] is too short to describe.
void _checkDescribable(String content, String what) {
  if (content.trim().isEmpty) {
    throw const FormatException(
      'Write something in the note body first. Suggestions are based only on what it says.',
    );
  }
  if (content.trim().split(RegExp(r'\s+')).length < noteMetadataMinWords) {
    throw FormatException(
      'This note is too short to suggest $what without guessing. Add a little more first.',
    );
  }
}

/// The placeholder and very long titles carry no useful context.
String _requestTitle(String title) {
  final current = _collapse(title);
  return current.toLowerCase() == 'untitled note' || current.runes.length > 200
      ? ''
      : current;
}

const _tooLong =
    'This note is longer than 2,000 UTF-8 bytes including its title. Nothing was sent; notes are never shortened.';

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
    _checkDescribable(content, 'a title');
    final value = jsonEncode({
      'title': _requestTitle(title),
      'text': content.trim(),
      'tags': [for (final tag in parsedTags.take(12)) tag.name],
    });
    if (utf8.encode(value).length > noteHelpInputBytes) {
      throw const FormatException(_tooLong);
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

/// Title suggestions after the phone's checks: no repeat of the current
/// title and no duplicates.
class NoteMetadataSuggestions {
  const NoteMetadataSuggestions(this.titles);
  final List<String> titles;
  bool get isEmpty => titles.isEmpty;

  /// Throws [FormatException] for a broken envelope.
  factory NoteMetadataSuggestions.parse(
    String text,
    NoteMetadataSource source,
  ) {
    final json = jsonDecode(text);
    if (json is! Map ||
        json.keys.toSet().difference({'titles'}).isNotEmpty ||
        json['titles'] is! List) {
      throw const FormatException('Invalid suggestions');
    }
    final titles = <String>[];
    final seen = {_collapse(source.title).toLowerCase(), ''};
    for (final value in json['titles'] as List) {
      if (!_plain(value, noteTitleChars)) {
        throw const FormatException('Invalid title');
      }
      final title = _collapse(value as String)
          .replaceAll(RegExp(r'''^["'“‘]+|["'”’]+$'''), '');
      if (title.isNotEmpty && seen.add(title.toLowerCase())) {
        titles.add(title);
      }
    }
    return NoteMetadataSuggestions(titles);
  }
}

/// What the tag picker asks about: the saved note's title and body, the
/// tags chosen in the picker so far, and the person's other tags, which the
/// model should reuse when they fit.
class NoteTagSource {
  const NoteTagSource({
    required this.noteId,
    required this.title,
    required this.content,
    required this.version,
    required this.tags,
    required this.library,
  });
  final String noteId, title, content, version;

  /// Encoded `emoji#name` tags already chosen for the note.
  final List<String> tags;

  /// Encoded tags used anywhere in the person's notes.
  final List<String> library;

  factory NoteTagSource.fromNote(
    NoteDocument note, {
    required List<String> tags,
    required Iterable<String> library,
  }) => NoteTagSource(
    noteId: note.id,
    title: note.text.title,
    content: note.text.body,
    version: note.revision.toString(),
    tags: List.of(tags),
    library: List.of(library),
  );

  List<NoteTag> get parsedTags =>
      tags.map(NoteTag.tryParse).whereType<NoteTag>().toList();

  /// Existing tags the note does not have yet, in a stable order.
  List<NoteTag> get candidates {
    final chosen = {for (final tag in parsedTags) tag.key};
    final byKey = <String, NoteTag>{
      for (final tag in library.map(NoteTag.tryParse).whereType<NoteTag>())
        if (validNoteTagName(tag.name) && !chosen.contains(tag.key))
          tag.key: tag,
    };
    return byKey.values.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  /// Throws [FormatException] when the body is empty or the note is over
  /// the limit. Existing tags past the limit are left out of the request.
  String request() {
    _checkDescribable(content, 'tags');
    final note = {
      'title': _requestTitle(title),
      'text': content.trim(),
      'tags': [for (final tag in parsedTags.take(12)) tag.name],
    };
    if (utf8.encode(jsonEncode(note)).length > noteHelpInputBytes) {
      throw const FormatException(_tooLong);
    }
    final existing = <Map<String, String>>[];
    for (final tag in candidates.take(noteTagsLibraryMax)) {
      final entry = {'name': tag.name, 'emoji': tag.emoji};
      final size = utf8
          .encode(
            jsonEncode({
              ...note,
              'existing': [...existing, entry],
            }),
          )
          .length;
      if (size > noteTagsInputBytes) break;
      existing.add(entry);
    }
    return jsonEncode({...note, 'existing': existing});
  }

  String encode() => jsonEncode({
    'noteId': noteId,
    'title': title,
    'content': content,
    'version': version,
    'tags': tags,
    'library': library,
  });

  factory NoteTagSource.decode(String raw) {
    final json = jsonDecode(raw);
    bool strings(Object? v) => v is List && v.every((t) => t is String);
    if (json is! Map ||
        json['noteId'] is! String ||
        json['title'] is! String ||
        json['content'] is! String ||
        json['version'] is! String ||
        !strings(json['tags']) ||
        !strings(json['library']) ||
        utf8.encode(json['content'] as String).length > noteHelpInputBytes) {
      throw const FormatException('Invalid tag source');
    }
    return NoteTagSource(
      noteId: json['noteId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      version: json['version'] as String,
      tags: (json['tags'] as List).cast<String>(),
      library: (json['library'] as List).cast<String>(),
    );
  }
}

/// Tag suggestions after the phone's checks. A suggestion naming an existing
/// tag becomes that tag, with its own spelling and emoji; a new tag must use
/// the picker's palette and never names a sensitive personal attribute.
/// Tags the note already has and duplicates are dropped.
class NoteTagSuggestions {
  const NoteTagSuggestions(this.tags, this.existing);
  final List<NoteTag> tags;

  /// Keys of [tags] that the person already uses on other notes.
  final Set<String> existing;
  bool get isEmpty => tags.isEmpty;

  /// Throws [FormatException] for a broken envelope.
  factory NoteTagSuggestions.parse(String text, NoteTagSource source) {
    final json = jsonDecode(text);
    if (json is! Map ||
        json.keys.toSet().difference({'tags'}).isNotEmpty ||
        json['tags'] is! List) {
      throw const FormatException('Invalid suggestions');
    }
    final known = {for (final tag in source.candidates) tag.key: tag};
    final seen = {for (final tag in source.parsedTags) tag.key};
    final tags = <NoteTag>[];
    final existing = <String>{};
    for (final value in json['tags'] as List) {
      if (value is! Map ||
          !_plain(value['name'], noteTagChars) ||
          value['emoji'] is! String) {
        throw const FormatException('Invalid tag');
      }
      final name = _collapse(value['name'] as String)
          .replaceAll(RegExp(r'^#+'), '');
      if (!validNoteTagName(name)) continue;
      final reused = known[name.toLowerCase()];
      final NoteTag tag;
      if (reused != null) {
        tag = reused;
      } else if (_sensitiveTag.hasMatch(name) ||
          !noteTagEmojis.contains(value['emoji'])) {
        continue;
      } else {
        tag = NoteTag(name: name, emoji: value['emoji'] as String);
      }
      if (NoteTag.tryParse(tag.encoded)?.key == tag.key && seen.add(tag.key)) {
        tags.add(tag);
        if (reused != null) existing.add(tag.key);
      }
    }
    return NoteTagSuggestions(tags, existing);
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

const noteDraftIdeaChars = 240;
const noteDraftBodyBytes = 12000;
const noteDraftLines = 300;

/// What a new note should be, for the Maester to draft it, e.g. before
/// building its website.
class NoteDraftSource {
  const NoteDraftSource(this.idea);
  final String idea;

  /// Throws [FormatException] for an empty, long or multi-line idea.
  String request() {
    final clean = _collapse(idea);
    if (!_plain(clean, noteDraftIdeaChars)) {
      throw const FormatException(
        'Describe the note in one line of at most 240 characters.',
      );
    }
    return jsonEncode({'idea': clean});
  }
}

/// The model's template, re-checked here: an exact envelope, a plain title
/// and a short body of ordinary lines.
class NoteTemplate {
  const NoteTemplate({required this.title, required this.body});
  final String title, body;

  /// Throws [FormatException] for anything outside the contract. A drafted
  /// note ([NoteDraftSource]) may be longer than a template.
  factory NoteTemplate.parse(
    String text, {
    int bodyBytes = noteTemplateBodyBytes,
    int lines = noteTemplateLines,
  }) {
    final json = jsonDecode(text);
    if (json is! Map ||
        json.keys.length != 2 ||
        !_plain(json['title'], noteTitleChars) ||
        json['body'] is! String) {
      throw const FormatException('Invalid template');
    }
    final body = (json['body'] as String).trimRight();
    if (body.trim().isEmpty ||
        utf8.encode(body).length > bodyBytes ||
        body.split('\n').length > lines ||
        RegExp(r'[\x00-\x09\x0b-\x1f\x7f]').hasMatch(body)) {
      throw const FormatException('Invalid template body');
    }
    return NoteTemplate(title: _collapse(json['title'] as String), body: body);
  }
}
