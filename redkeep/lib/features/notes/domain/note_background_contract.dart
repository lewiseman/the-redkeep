import 'dart:convert';
import 'dart:typed_data';

/// I06: an optional generated note background.
const noteBackgroundOperation = 'generate-note-background';
const noteBackgroundContract = 1;
const noteBackgroundPromptChars = 240;
const noteBackgroundTones = {'light': 'Light', 'dark': 'Dark'};

/// Previews the user has not accepted are deleted after this long.
const noteBackgroundPreviewLifetime = Duration(hours: 24);

final _control = RegExp(r'[\x00-\x1f\x7f]');

/// Canonical JSON so equal backgrounds compare equal regardless of key order.
String canonicalBackground(Map<String, dynamic> background) => jsonEncode({
  for (final key in background.keys.toList()..sort()) key: background[key],
});

/// What was requested, and the note's background at that moment. Only
/// [prompt] and [tone] are sent.
class NoteBackgroundRequest {
  const NoteBackgroundRequest({
    required this.noteId,
    required this.prompt,
    required this.tone,
    required this.background,
  });
  final String noteId, prompt, tone;
  final Map<String, dynamic> background;

  /// Throws [FormatException] for an empty, long or multi-line description.
  String request() {
    final text = prompt.trim();
    if (text.isEmpty ||
        text.runes.length > noteBackgroundPromptChars ||
        _control.hasMatch(text) ||
        !noteBackgroundTones.containsKey(tone)) {
      throw const FormatException(
        'Describe the background in one line of at most 240 characters.',
      );
    }
    return jsonEncode({'prompt': text, 'tone': tone});
  }

  String encode() => jsonEncode({
    'noteId': noteId,
    'prompt': prompt,
    'tone': tone,
    'background': background,
  });
  factory NoteBackgroundRequest.decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map ||
        json['noteId'] is! String ||
        json['prompt'] is! String ||
        !noteBackgroundTones.containsKey(json['tone']) ||
        json['background'] is! Map) {
      throw const FormatException('Invalid background request');
    }
    return NoteBackgroundRequest(
      noteId: json['noteId'] as String,
      prompt: json['prompt'] as String,
      tone: json['tone'] as String,
      background: (json['background'] as Map).cast<String, dynamic>(),
    );
  }
}

/// The computer's description of a finished image (not the image itself).
class NoteBackgroundResult {
  const NoteBackgroundResult({
    required this.width,
    required this.height,
    required this.bytes,
    required this.sha256,
    required this.seed,
  });
  final int width, height, bytes, seed;
  final String sha256;

  factory NoteBackgroundResult.parse(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map ||
        json['width'] is! int ||
        json['height'] is! int ||
        json['bytes'] is! int ||
        json['seed'] is! int ||
        json['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(json['sha256'] as String) ||
        (json['width'] as int) < 64 ||
        (json['width'] as int) > 2048 ||
        (json['height'] as int) < 64 ||
        (json['height'] as int) > 2048 ||
        (json['bytes'] as int) <= 0 ||
        (json['bytes'] as int) > 4 * 1024 * 1024) {
      throw const FormatException('Invalid background result');
    }
    return NoteBackgroundResult(
      width: json['width'] as int,
      height: json['height'] as int,
      bytes: json['bytes'] as int,
      sha256: json['sha256'] as String,
      seed: json['seed'] as int,
    );
  }

  /// Whether [png] is the promised image.
  bool matches(Uint8List png, String digest) =>
      digest == sha256 &&
      png.length == bytes &&
      png.length > 24 &&
      png[0] == 0x89 &&
      png[1] == 0x50 &&
      ByteData.sublistView(png).getUint32(16) == width &&
      ByteData.sublistView(png).getUint32(20) == height;
}
