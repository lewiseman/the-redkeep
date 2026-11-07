import 'dart:convert';

/// App-owned references only; file contents never enter writing sync.
class NoteAttachment {
  const NoteAttachment({
    required this.path,
    required this.type,
    this.name = '',
  });
  final String path, type, name;
  bool get isImage => type.startsWith('image/');
  String get filename => name.isEmpty ? path.split('/').last : name;
  Map<String, dynamic> toMap() => {'path': path, 'type': type, 'name': name};
  factory NoteAttachment.fromMap(Map<String, dynamic> value) {
    final path = value['path'];
    final type = value['type'];
    if (path is! String ||
        !RegExp(r'^note_media/[a-zA-Z0-9_.-]+$').hasMatch(path) ||
        type is! String ||
        type.length > 100 ||
        !type.contains('/') ||
        (value['name'] != null && value['name'] is! String)) {
      throw const FormatException('Invalid note attachment');
    }
    return NoteAttachment(
      path: path,
      type: type,
      name: value['name'] as String? ?? '',
    );
  }
}

class NoteDetails {
  const NoteDetails({
    this.tags = const [],
    this.attachments = const [],
    this.background = const {},
  });
  final List<String> tags;
  final List<NoteAttachment> attachments;
  final Map<String, dynamic> background;
  bool get hasWriting =>
      attachments.isNotEmpty || tags.isNotEmpty || background.isNotEmpty;
  NoteDetails copy({
    List<String>? tags,
    List<NoteAttachment>? attachments,
    Map<String, dynamic>? background,
  }) => NoteDetails(
    tags: tags ?? this.tags,
    attachments: attachments ?? this.attachments,
    background: background ?? this.background,
  );
  Map<String, dynamic> toJson() => {
    'tags': tags,
    'attachments': [for (final a in attachments) a.toMap()],
    'background': background,
  };
  String encode() => jsonEncode(toJson());
  factory NoteDetails.decode(String raw) {
    if (utf8.encode(raw).length > 300000) {
      throw const FormatException('Note details too large');
    }
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic>) {
      throw const FormatException('Invalid note details');
    }
    final tags = j['tags'] ?? <dynamic>[];
    final attachments = j['attachments'] ?? <dynamic>[];
    final bg = j['background'] ?? <String, dynamic>{};
    if (tags is! List ||
        tags.length > 24 ||
        tags.any(
          (t) => t is! String || t.isEmpty || t.length > 40 || t.contains(','),
        ) ||
        attachments is! List ||
        attachments.length > 40 ||
        bg is! Map<String, dynamic> ||
        !bg.keys.every({'type', 'asset', 'image', 'image_source'}.contains) ||
        bg.values.any((v) => v != null && v is! String)) {
      throw const FormatException('Invalid note details');
    }
    if (bg['image'] != null &&
        !RegExp(r'^note_media/[a-zA-Z0-9_.-]+$')
            .hasMatch(bg['image'] as String)) {
      throw const FormatException('Invalid note image');
    }
    return NoteDetails(
      tags: List<String>.unmodifiable(tags.cast<String>()),
      attachments: List.unmodifiable(
        attachments.map(
          (v) => NoteAttachment.fromMap(Map<String, dynamic>.from(v as Map)),
        ),
      ),
      background: Map.unmodifiable(bg),
    );
  }
}
