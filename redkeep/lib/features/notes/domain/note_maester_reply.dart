/// How the Maester marks what it changes: a new title, new text, or both.
const noteMaesterTitleMarker = '<<TITLE>>';
const noteMaesterTextMarker = '<<TEXT>>';

/// The longest title the Maester may give a note, in characters.
const noteMaesterTitleChars = 120;

/// What the Maester's reply changes. Null leaves that part as it is.
class NoteMaesterReply {
  const NoteMaesterReply({this.title, this.text});
  final String? title, text;

  /// Reads a reply, whole or still streaming. While streaming, a marker
  /// that is only partly written yet shows nothing; the title so far is
  /// shown as it arrives. A reply without markers is taken as new text.
  factory NoteMaesterReply.read(String raw, {bool complete = false}) {
    // An opening code fence some models add is not part of the reply.
    var rest = raw.replaceFirst(
      RegExp(r'^\s*```[A-Za-z0-9_-]*[ \t]*(\r?\n|$)'),
      '',
    );
    rest = rest.replaceAll('\r\n', '\n').trimLeft();
    String? title;
    if (rest.startsWith(noteMaesterTitleMarker)) {
      final end = rest.indexOf('\n');
      title = rest
          .substring(noteMaesterTitleMarker.length, end < 0 ? null : end)
          .trim();
      rest = end < 0 ? '' : rest.substring(end + 1).trimLeft();
    } else if (!complete && _partly(rest, noteMaesterTitleMarker)) {
      return const NoteMaesterReply();
    }
    String? text;
    if (rest.startsWith(noteMaesterTextMarker)) {
      final end = rest.indexOf('\n');
      text = end < 0 ? '' : rest.substring(end + 1);
    } else if (!complete && _partly(rest, noteMaesterTextMarker)) {
      text = null;
    } else if (rest.trim().isNotEmpty) {
      text = rest;
    }
    if (complete && text != null) {
      // A closing fence some models add is not part of the text either.
      text = text.replaceFirst(RegExp(r'\n?```\s*$'), '');
    }
    return NoteMaesterReply(title: title, text: text);
  }

  /// Whether [value] is the start of [marker], still being written.
  static bool _partly(String value, String marker) =>
      value.isEmpty || value.length < marker.length && marker.startsWith(value);
}

/// The new title, checked like any title the person could type.
String checkedNoteMaesterTitle(String title) {
  final value = title.trim();
  if (value.isEmpty ||
      value.runes.length > noteMaesterTitleChars ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value) ||
      RegExp(r'</?[a-z][^>]*>', caseSensitive: false).hasMatch(value)) {
    throw const FormatException(
      'The Maester returned a title that could not be used. Try again.',
    );
  }
  return value;
}
