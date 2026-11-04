import 'dart:convert';

/// I04: transcribe a photographed or scanned page into editable text.
const noteScanOperation = 'scan-note-image';
const noteScanContract = 1;
const noteScanOutputBytes = 12288;
const noteScanTextChars = 6000;

/// The exact prompt for every scan; the image is the only other input.
const noteScanPrompt = '{"mode":"transcribe"}';

/// What a scan request was made from. Kept in protected task storage.
class NoteScanRequest {
  const NoteScanRequest({
    required this.noteId,
    required this.version,
    required this.path,
    required this.imageSha,
  });
  final String noteId, version, path, imageSha;

  String encode() => jsonEncode({
    'noteId': noteId,
    'version': version,
    'path': path,
    'imageSha': imageSha,
  });
  factory NoteScanRequest.decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map ||
        [
          'noteId',
          'version',
          'path',
          'imageSha',
        ].any((k) => json[k] is! String) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(json['imageSha'] as String)) {
      throw const FormatException('Invalid scan request');
    }
    return NoteScanRequest(
      noteId: json['noteId'] as String,
      version: json['version'] as String,
      path: json['path'] as String,
      imageSha: json['imageSha'] as String,
    );
  }
}

class NoteScanCheckLine {
  const NoteScanCheckLine(this.text, this.confidence);
  final String text;
  final double confidence;
}

/// A validated transcription. [check] is an independent EasyOCR reading,
/// or null when the computer has no second reader.
class NoteScanResult {
  const NoteScanResult({
    required this.text,
    required this.readable,
    required this.check,
  });
  final String text;
  final bool readable;
  final List<NoteScanCheckLine>? check;

  factory NoteScanResult.parse(String raw) {
    final json = jsonDecode(raw);
    final control = RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]');
    if (json is! Map ||
        json.length != 3 ||
        json['text'] is! String ||
        json['readable'] is! bool ||
        (json['text'] as String).runes.length > noteScanTextChars ||
        control.hasMatch(json['text'] as String) ||
        (json['check'] != null && json['check'] is! List)) {
      throw const FormatException('Invalid scan result');
    }
    List<NoteScanCheckLine>? check;
    if (json['check'] case final List lines) {
      check = [
        for (final line in lines)
          if (line is Map &&
              line['text'] is String &&
              line['confidence'] is num &&
              !control.hasMatch(line['text'] as String))
            NoteScanCheckLine(
              line['text'] as String,
              (line['confidence'] as num).toDouble().clamp(0, 1),
            )
          else
            throw const FormatException('Invalid check line'),
      ];
    }
    return NoteScanResult(
      text: (json['text'] as String).trim(),
      readable: json['readable'] as bool,
      check: check,
    );
  }

  bool get empty => text.replaceAll('[?]', '').trim().isEmpty;

  /// Places the reader marked as unreadable.
  int get unreadableMarks => '[?]'.allMatches(text).length;

  /// Words most costly to get wrong (containing digits, or capitalised mid
  /// line, e.g. names) that the second reader did not read the same way.
  /// Empty when there is no second reader; nothing is ever changed.
  List<String> get disagreements {
    final checkLines = check;
    if (checkLines == null) return const [];
    final seen = {
      for (final line in checkLines)
        for (final word in _words(line.text)) _key(word),
    };
    final flagged = <String>{};
    for (final line in text.split('\n')) {
      final words = _words(line);
      for (final (i, word) in words.indexed) {
        final risky =
            word.contains(RegExp(r'\d')) ||
            (i > 0 && RegExp(r'^\p{Lu}', unicode: true).hasMatch(word));
        if (risky && !seen.contains(_key(word))) flagged.add(word);
      }
    }
    return flagged.toList();
  }

  static List<String> _words(String line) => [
    for (final word in line.split(RegExp(r'\s+')))
      if (_key(word).isNotEmpty)
        word.replaceAll(RegExp(r'''^[("'“‘]+|[)"'”’.,;:!?]+$'''), ''),
  ];

  /// Case-insensitive, ignoring surrounding punctuation only: "3:15pm" and
  /// "315pm" differ.
  static String _key(String word) => word.toLowerCase().replaceAll(
    RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
    '',
  );
}
