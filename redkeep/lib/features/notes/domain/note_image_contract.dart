import 'dart:convert';

/// I03: one bounded question about one image attached to a saved note.
const noteImageOperation = 'ask-note-image';
const noteImageContract = 1;
const noteImageQuestionChars = 300;
const noteImageOutputBytes = 4096;

/// Source files above this are not read at all.
const noteImageSourceBytes = 40 * 1024 * 1024;

/// Upload budget after re-encoding; the desktop accepts up to 3 MiB.
const noteImageUploadBytes = 2560 * 1024;

const noteImageModes = {
  'describe': 'Describe',
  'explain': 'Explain',
  'question': 'Ask a question',
};

final _control = RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]');

/// What was asked, and about which exact attachment and note version. Kept in
/// protected task storage; only [mode], [question] and the re-encoded image
/// are sent.
class NoteImageRequest {
  const NoteImageRequest({
    required this.noteId,
    required this.version,
    required this.path,
    required this.mode,
    required this.question,
    required this.imageSha,
  });
  final String noteId, version, path, mode, question;

  /// SHA-256 of the re-encoded upload, so a retry sends identical bytes.
  final String imageSha;

  String request() => jsonEncode({'mode': mode, 'question': question});

  String encode() => jsonEncode({
    'noteId': noteId,
    'version': version,
    'path': path,
    'mode': mode,
    'question': question,
    'imageSha': imageSha,
  });
  factory NoteImageRequest.decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map ||
        [
          'noteId',
          'version',
          'path',
          'mode',
          'question',
          'imageSha',
        ].any((k) => json[k] is! String) ||
        !noteImageModes.containsKey(json['mode']) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(json['imageSha'] as String)) {
      throw const FormatException('Invalid image source');
    }
    return NoteImageRequest(
      noteId: json['noteId'] as String,
      version: json['version'] as String,
      path: json['path'] as String,
      mode: json['mode'] as String,
      question: json['question'] as String,
      imageSha: json['imageSha'] as String,
    );
  }

  /// Throws [FormatException] for an invalid mode/question combination.
  static void validate(String mode, String question) {
    if (!noteImageModes.containsKey(mode) ||
        (mode == 'question') != question.trim().isNotEmpty ||
        question.runes.length > noteImageQuestionChars ||
        _control.hasMatch(question)) {
      throw const FormatException(
        'Ask a question of at most 300 characters, or choose Describe or Explain.',
      );
    }
  }
}

/// A validated answer. Each part is shown separately so visible evidence,
/// text read from the image and interpretation are never mixed.
class NoteImageAnswer {
  const NoteImageAnswer({
    required this.observations,
    required this.text,
    required this.inference,
    required this.answer,
  });
  final String observations, text, inference, answer;

  factory NoteImageAnswer.parse(String raw) {
    final json = jsonDecode(raw);
    String field(String key, int max, {bool empty = true}) {
      final value = json is Map ? json[key] : null;
      if (value is! String ||
          (!empty && value.trim().isEmpty) ||
          value.runes.length > max ||
          _control.hasMatch(value)) {
        throw const FormatException('Invalid image answer');
      }
      return value.trim();
    }

    if (json is! Map || json.length != 4) {
      throw const FormatException('Invalid image answer');
    }
    final inference = field('inference', 500);
    final text = field('text', 900);
    // The model sometimes repeats the "cannot answer" phrase in other fields.
    const unanswerable = 'The image does not show this.';
    return NoteImageAnswer(
      observations: field('observations', 900, empty: false),
      text: text == unanswerable ? '' : text,
      inference: inference,
      answer: field('answer', 600),
    );
  }

  /// The default text offered for insertion: the answer, else observations.
  String get insertion => answer.isNotEmpty ? answer : observations;
}
