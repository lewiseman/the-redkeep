import 'ai_provider.dart';
import 'note_operation_prompts.dart';
import 'vision_operation_prompts.dart';

enum AiOperation {
  noteRewrite('rewrite-note', true, '', 768, 4096, noteRewriteSystem),
  noteExpand('expand-note', true, '', 768, 4096, noteExpandSystem),
  noteTone('tone-note', true, '', 768, 4096, noteToneSystem),
  noteClarify('clarify-note', true, '', 768, 4096, noteClarifySystem),
  noteMarkdown('markdown-note', true, '', 768, 4096, noteMarkdownSystem),
  noteCustom('custom-note', true, '', 768, 4096, noteCustomSystem),
  noteMetadata(
    'suggest-note-metadata',
    true,
    'noteHelpContract',
    320,
    1536,
    noteMetadataSystem,
  ),
  // Asked from the tag picker; reuses the person's existing tags.
  noteTags(
    'suggest-note-tags',
    true,
    'noteHelpContract',
    320,
    1536,
    noteTagsSystem,
  ),
  noteTemplate(
    'suggest-note-template',
    true,
    'noteHelpContract',
    480,
    1800,
    noteTemplateSystem,
  ),
  // Writes a new note from an idea.
  noteDraft(
    'draft-note',
    true,
    'noteHelpContract',
    4000,
    16384,
    noteDraftSystem,
  ),
  noteImage(
    'ask-note-image',
    true,
    'visionContract',
    768,
    4096,
    '$noteImageSystem\nReturn exactly these four string keys: {"observations":"…","text":"…","inference":"…","answer":"…"}',
  ),
  noteScan(
    'scan-note-image',
    true,
    'scanContract',
    2048,
    12288,
    '$noteScanSystem\nReturn exactly: {"text":"…","readable":true}',
  );

  const AiOperation(
    this.wireName,
    this.available,
    this.contractKey,
    this.outputTokens,
    this.outputBytes,
    this.system,
  );
  final String wireName, contractKey, system;

  /// False for paused features that never run.
  final bool available;
  bool get isNote => name.startsWith('note');
  bool get imageInput => this == noteImage || this == noteScan;
  String get label => switch (this) {
    noteRewrite => 'Rewrite note',
    noteExpand => 'Expand note',
    noteTone => 'Note tone',
    noteClarify => 'Grammar / clarity',
    noteMarkdown => 'Format note',
    noteCustom => 'Custom writing help',
    noteMetadata => 'Title ideas',
    noteTags => 'Tag ideas',
    noteTemplate => 'Starting template',
    noteDraft => 'Draft a note',
    noteImage => 'Ask about an image',
    noteScan => 'Scan a page',
  };
  int get inputBytes => switch (this) {
    noteTags => 6000,
    _ => 2000,
  };
  AiCapability get capability =>
      imageInput ? AiCapability.vision : AiCapability.chat;
  final int outputTokens, outputBytes;

  double get temperature => switch (this) {
    noteTemplate => .7,
    noteDraft => .5,
    _ => 0,
  };

  double get topP => this == noteTemplate ? .95 : 1;
}
