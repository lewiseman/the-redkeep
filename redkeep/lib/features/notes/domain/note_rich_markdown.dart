import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as md;

/// Notes are stored as Markdown; the editor shows them as rich text.
///
/// Only a small, stable core round-trips: headings 1–3, bullet, numbered and
/// check lists, bold and italic, and plain paragraphs. A note is offered to the
/// rich editor only when converting it there and back renders exactly as it
/// does now, so nothing a reader sees can change by opening it for editing.

/// The rich document for [markdown], or null when the note uses anything the
/// rich editor cannot represent faithfully. AI writing that fails this check
/// is rejected; see [richIncompatibleMessage].
Delta? richFromMarkdown(String markdown) {
  if (markdown.contains('\r') || markdown.contains('\t')) return null;
  final lines = <_Line>[];
  for (final source in markdown.split('\n')) {
    final line = _parseLine(source);
    if (line == null) return null;
    lines.add(line);
  }
  final rendered = _html(markdown);
  if (!_onlyCore(markdown, rendered)) return null;
  final delta = _toDelta(lines);
  final written = markdownFromRich(delta);
  if (written != markdown && _html(written) != rendered) return null;
  return delta;
}

/// Shown when AI writing uses Markdown the editor can't show.
const richIncompatibleMessage =
    'The AI used formatting the note editor can’t show, so nothing was '
    'applied. Try again.';

/// Whether [markdown] opens in the rich editor exactly as it reads.
bool richCompatible(String markdown) => richFromMarkdown(markdown) != null;

/// [text] as plain paragraphs, escaped so nothing in it reads as formatting.
/// Use it for words that are not Markdown, such as speech or a scanned page.
String markdownFromPlainText(String text) {
  final delta = Delta();
  for (final line in _plainLines(text)) {
    if (line.isNotEmpty) delta.insert(line);
    delta.insert('\n');
  }
  return markdownFromRich(delta);
}

/// The rich document for any stored note. Markdown outside the core opens
/// as its literal text, so every note can be edited in the rich editor.
Delta richDocumentFor(String markdown) {
  final rich = richFromMarkdown(markdown);
  if (rich != null) return rich;
  final delta = Delta();
  for (final line in markdown.replaceAll('\r\n', '\n').split('\n')) {
    if (line.isNotEmpty) delta.insert(line.replaceAll('\r', ''));
    delta.insert('\n');
  }
  return delta;
}

Iterable<String> _plainLines(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\t', ' ')
    .split('\n')
    .map((line) => line.trim());

RegExp _unescaped(String pattern) => RegExp('(^|[^\\\\])$pattern');
final _tag = RegExp(r'<([a-zA-Z][a-zA-Z0-9]*)');
const _coreTags = {
  'p',
  'h1',
  'h2',
  'h3',
  'ul',
  'ol',
  'li',
  'input',
  'strong',
  'em',
  'a',
};

/// Rendering may only use the core. Links are allowed only as bare web
/// addresses, which read the same as typed text.
bool _onlyCore(String markdown, String rendered) {
  for (final match in _tag.allMatches(rendered)) {
    if (!_coreTags.contains(match.group(1)!.toLowerCase())) return false;
  }
  return !_unescaped(r'\]\(').hasMatch(markdown) &&
      !_unescaped(r'\]\[').hasMatch(markdown) &&
      !_unescaped('<').hasMatch(markdown);
}

/// The Markdown that [delta] stands for. Formatting outside the core is
/// dropped, never the text.
String markdownFromRich(Delta delta) {
  final lines = _fromDelta(delta);
  final out = <String>[];
  var number = 0;
  for (final line in lines) {
    number = line.block == _Block.ordered ? number + 1 : 0;
    final content = _writeInline(line.segments, line.block);
    out.add(switch (line.block) {
      _Block.h1 => '# $content',
      _Block.h2 => '## $content',
      _Block.h3 => '### $content',
      _Block.bullet => '- $content',
      _Block.ordered => '$number. $content',
      _Block.checked => '- [x] $content',
      _Block.unchecked => '- [ ] $content',
      _Block.paragraph => content,
    });
  }
  return out.join('\n');
}

String _html(String markdown) =>
    md.markdownToHtml(markdown, extensionSet: md.ExtensionSet.gitHubFlavored);

enum _Block { paragraph, h1, h2, h3, bullet, ordered, checked, unchecked }

class _Segment {
  _Segment(this.text, {this.bold = false, this.italic = false});
  String text;
  final bool bold;
  final bool italic;
  bool sameStyle(_Segment other) =>
      bold == other.bold && italic == other.italic;
}

class _Line {
  _Line(this.block, this.segments);
  final _Block block;
  final List<_Segment> segments;
}

final _heading = RegExp(r'^(#{1,3}) (.*)$');
final _task = RegExp(r'^- \[([ xX])\] (.*)$');
final _emptyTask = RegExp(r'^- \[([ xX])\]$');
final _bullet = RegExp(r'^[-*] (.*)$');
final _ordered = RegExp(r'^\d{1,9}\. (.*)$');

_Line? _parseLine(String source) {
  // Indented lines are nested lists or code; both stay plain text.
  if (source.startsWith(' ')) return null;
  RegExpMatch? m;
  if ((m = _heading.firstMatch(source)) != null) {
    final block = [_Block.h1, _Block.h2, _Block.h3][m!.group(1)!.length - 1];
    return _Line(block, _parseInline(m.group(2)!));
  }
  if ((m = _task.firstMatch(source)) != null) {
    final done = m!.group(1)!.trim().isNotEmpty;
    return _Line(
      done ? _Block.checked : _Block.unchecked,
      _parseInline(m.group(2)!),
    );
  }
  if ((m = _emptyTask.firstMatch(source)) != null) {
    final done = m!.group(1)!.trim().isNotEmpty;
    return _Line(done ? _Block.checked : _Block.unchecked, []);
  }
  if ((m = _bullet.firstMatch(source)) != null) {
    return _Line(_Block.bullet, _parseInline(m!.group(1)!));
  }
  if ((m = _ordered.firstMatch(source)) != null) {
    return _Line(_Block.ordered, _parseInline(m!.group(1)!));
  }
  return _Line(_Block.paragraph, _parseInline(source));
}

// ---------------------------------------------------------------------------
// Inline emphasis: a compact take on CommonMark delimiter runs for `*` and `_`.

const _punctuation = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';
bool _isPunct(String? c) => c != null && _punctuation.contains(c);
bool _isSpace(String? c) => c == null || c.trim().isEmpty;
bool _isWord(String? c) =>
    c != null && RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(c);

class _Token {
  _Token.text(this.text) : delimiter = null, canOpen = false, canClose = false;
  _Token.delimiter(this.text, {required this.canOpen, required this.canClose})
    : delimiter = text[0];
  String text;
  final String? delimiter;
  final bool canOpen;
  final bool canClose;
  int bold = 0;
  int italic = 0;
}

List<_Segment> _parseInline(String source) {
  final tokens = <_Token>[];
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isEmpty) return;
    tokens.add(_Token.text(buffer.toString()));
    buffer.clear();
  }

  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (c == r'\' && i + 1 < source.length && _isPunct(source[i + 1])) {
      buffer.write(source[i + 1]);
      i += 2;
      continue;
    }
    if (c == '*' || c == '_') {
      var end = i;
      while (end < source.length && source[end] == c) {
        end++;
      }
      final before = i == 0 ? null : source[i - 1];
      final after = end >= source.length ? null : source[end];
      final left =
          !_isSpace(after) &&
          (!_isPunct(after) || _isSpace(before) || _isPunct(before));
      final right =
          !_isSpace(before) &&
          (!_isPunct(before) || _isSpace(after) || _isPunct(after));
      flush();
      tokens.add(
        _Token.delimiter(
          source.substring(i, end),
          canOpen: c == '*' ? left : left && (!right || _isPunct(before)),
          canClose: c == '*' ? right : right && (!left || _isPunct(after)),
        ),
      );
      i = end;
      continue;
    }
    buffer.write(c);
    i++;
  }
  flush();

  // Match each closer with the nearest compatible opener.
  for (var close = 0; close < tokens.length; close++) {
    final closer = tokens[close];
    if (closer.delimiter == null || !closer.canClose) continue;
    var open = close - 1;
    while (closer.text.isNotEmpty && open >= 0) {
      final opener = tokens[open];
      if (opener.delimiter == closer.delimiter &&
          opener.canOpen &&
          opener.text.isNotEmpty) {
        final use = closer.text.length >= 2 && opener.text.length >= 2 ? 2 : 1;
        for (var k = open + 1; k < close; k++) {
          if (use == 2) {
            tokens[k].bold++;
          } else {
            tokens[k].italic++;
          }
        }
        opener.text = opener.text.substring(use);
        closer.text = closer.text.substring(use);
        // What remains of the opener now sits outside this pair.
        continue;
      }
      open--;
    }
  }

  final segments = <_Segment>[];
  for (final token in tokens) {
    if (token.text.isEmpty) continue;
    final segment = _Segment(
      token.text,
      bold: token.bold > 0,
      italic: token.italic > 0,
    );
    if (segments.isNotEmpty && segments.last.sameStyle(segment)) {
      segments.last.text += segment.text;
    } else {
      segments.add(segment);
    }
  }
  return segments;
}

// ---------------------------------------------------------------------------
// Delta conversion.

Delta _toDelta(List<_Line> lines) {
  final delta = Delta();
  for (final line in lines) {
    for (final segment in line.segments) {
      delta.insert(segment.text, {
        if (segment.bold) 'bold': true,
        if (segment.italic) 'italic': true,
      });
    }
    delta.insert('\n', switch (line.block) {
      _Block.paragraph => null,
      _Block.h1 => {'header': 1},
      _Block.h2 => {'header': 2},
      _Block.h3 => {'header': 3},
      _Block.bullet => {'list': 'bullet'},
      _Block.ordered => {'list': 'ordered'},
      _Block.checked => {'list': 'checked'},
      _Block.unchecked => {'list': 'unchecked'},
    });
  }
  return delta;
}

List<_Line> _fromDelta(Delta delta) {
  final lines = <_Line>[];
  var segments = <_Segment>[];
  for (final op in delta.toList()) {
    if (!op.isInsert || op.data is! String) continue; // Embeds carry no text.
    final attributes = op.attributes ?? const {};
    final parts = (op.data! as String).split('\n');
    for (var p = 0; p < parts.length; p++) {
      if (parts[p].isNotEmpty) {
        final segment = _Segment(
          parts[p],
          bold: attributes['bold'] == true,
          italic: attributes['italic'] == true,
        );
        if (segments.isNotEmpty && segments.last.sameStyle(segment)) {
          segments.last.text += segment.text;
        } else {
          segments.add(segment);
        }
      }
      if (p < parts.length - 1) {
        lines.add(_Line(_blockOf(attributes), segments));
        segments = [];
      }
    }
  }
  // A document always ends with its last line's newline; anything after is
  // an unterminated tail.
  if (segments.isNotEmpty) lines.add(_Line(_Block.paragraph, segments));
  return lines;
}

_Block _blockOf(Map<String, dynamic> attributes) =>
    switch ((attributes['header'], attributes['list'])) {
      (1, _) => _Block.h1,
      (2, _) => _Block.h2,
      (3, _) => _Block.h3,
      (_, 'bullet') => _Block.bullet,
      (_, 'ordered') => _Block.ordered,
      (_, 'checked') => _Block.checked,
      (_, 'unchecked') => _Block.unchecked,
      _ => _Block.paragraph,
    };

// ---------------------------------------------------------------------------
// Writing Markdown.

final _entity = RegExp(r'^&(#\d+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);');
final _blockStart = RegExp(r'^(#{1,6}(\s|$)|[-*+](\s|$)|>|=+\s*$)');
final _orderedStart = RegExp(r'^(\d{1,9})([.)])(\s|$)');
final _rule = RegExp(r'^([-*_])(\s*\1){2,}\s*$');
final _taskStart = RegExp(r'^\[[ xX]\](\s|$)');

String _escapeText(String text) {
  final out = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    final before = i == 0 ? null : text[i - 1];
    final after = i + 1 < text.length ? text[i + 1] : null;
    final escape = switch (c) {
      r'\' => after == null || _isPunct(after),
      '*' || '~' => !(_isSpace(before) && _isSpace(after)),
      '_' => !(_isWord(before) && _isWord(after)),
      '`' => true,
      '[' => text.indexOf('](', i) >= 0 || text.indexOf('][', i) >= 0,
      '<' => after != null && RegExp(r'[A-Za-z/!?]').hasMatch(after),
      '&' => _entity.hasMatch(text.substring(i)),
      _ => false,
    };
    if (escape) out.write(r'\');
    out.write(c);
  }
  return out.toString();
}

String _writeInline(List<_Segment> segments, _Block block) {
  String wrap(String text, String marker) {
    // Markers must hug the text; surrounding spaces stay outside them.
    final start = text.length - text.trimLeft().length;
    final end = text.trimRight().length;
    if (end <= start) return text;
    return '${text.substring(0, start)}$marker'
        '${text.substring(start, end)}$marker${text.substring(end)}';
  }

  final out = StringBuffer();
  var i = 0;
  while (i < segments.length) {
    final bold = segments[i].bold;
    final run = StringBuffer();
    while (i < segments.length && segments[i].bold == bold) {
      final escaped = _escapeText(segments[i].text);
      run.write(segments[i].italic ? wrap(escaped, '*') : escaped);
      i++;
    }
    out.write(bold ? wrap(run.toString(), '**') : run.toString());
  }
  var line = out.toString();

  // Plain text that would read as Markdown structure stays plain text.
  if (block == _Block.paragraph) {
    if (_blockStart.hasMatch(line) || _rule.hasMatch(line)) {
      line = '\\$line';
    } else if (_orderedStart.firstMatch(line) case final m?) {
      line = '${m.group(1)}\\${line.substring(m.group(1)!.length)}';
    }
    // Four leading spaces would turn the line into code.
    final indent = line.length - line.trimLeft().length;
    if (indent >= 4) line = line.trimLeft();
  } else if (block == _Block.bullet && _taskStart.hasMatch(line)) {
    line = '\\$line';
  }
  return line;
}
