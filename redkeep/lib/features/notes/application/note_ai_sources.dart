import 'dart:convert';

import '../domain/note_rich_markdown.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/domain/ai_operation.dart';
import '../domain/note_background_contract.dart';
import '../domain/note_help_contract.dart';
import '../domain/note_image_contract.dart';
import '../domain/note_question_contract.dart';
import '../domain/note_scan_contract.dart';
import '../domain/transform_contract.dart';
import 'note_editor_controller.dart';
import 'notes_providers.dart';

Map<String, dynamic> noteTaskSource(String raw) =>
    Map<String, dynamic>.from(jsonDecode(raw) as Map);

Future<bool> noteAiSourceCurrent(
  Ref ref,
  AiOperation operation,
  String raw,
) async {
  final source = noteTaskSource(raw);
  final repo = ref.read(notesRepositoryProvider);
  if (operation == AiOperation.noteQuestion) {
    final selection = RecallQuestionSelection.decode(
      source['payload'] as String,
    );
    for (final s in selection.sources) {
      final opened = await repo.openDocument(s.uuid);
      if (!opened.available ||
          RecallItem.note(opened.note!)!.version != s.version) {
        return false;
      }
    }
    return true;
  }
  final opened = await repo.openDocument(source['noteId'] as String);
  if (source['unsaved'] == true) {
    final editor = ref.exists(noteEditorProvider(source['noteId'] as String))
        ? ref.read(noteEditorProvider(source['noteId'] as String)).value
        : null;
    return opened.note == null &&
        editor != null &&
        editor.editVersion == source['editVersion'];
  }
  return opened.available && opened.note!.revision == source['revision'];
}

void validateNoteAiOutput(
  AiOperation operation,
  String text,
  String rawSource,
) {
  if (text.trim().isEmpty ||
      RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(text)) {
    throw const FormatException('The model returned invalid note content.');
  }
  final source = noteTaskSource(rawSource);
  switch (operation) {
    case AiOperation.noteMetadata:
      NoteMetadataSuggestions.parse(
        text,
        NoteMetadataSource.decode(source['payload'] as String),
      );
    case AiOperation.noteTags:
      NoteTagSuggestions.parse(
        text,
        NoteTagSource.decode(source['payload'] as String),
      );
    case AiOperation.noteTemplate:
      if (!richCompatible(NoteTemplate.parse(text).body)) {
        throw const FormatException(richIncompatibleMessage);
      }
    case AiOperation.noteDraft:
      final draft = NoteTemplate.parse(
        text,
        bodyBytes: noteDraftBodyBytes,
        lines: noteDraftLines,
      );
      if (!richCompatible(draft.body)) {
        throw const FormatException(richIncompatibleMessage);
      }
    case AiOperation.noteQuestion:
      RecallQuestionAnswer.parse(
        text,
        RecallQuestionSelection.decode(source['payload'] as String),
      );
    case AiOperation.noteImage:
      NoteImageAnswer.parse(text);
    case AiOperation.noteScan:
      NoteScanResult.parse(text);
    case AiOperation.noteBackground:
      NoteBackgroundResult.parse(text);
    case AiOperation.noteWebsiteRemix:
      if (!text.contains('>>>>>>> REPLACE') &&
          !RegExp(r'</html\s*>\s*$', caseSensitive: false).hasMatch(text)) {
        throw const FormatException(
          'The remix could not be applied. Your website is unchanged; try again.',
        );
      }
    case AiOperation.noteWebsite:
      // The page is checked and made safe in a worker before it is kept.
      if (!RegExp(r'</html\s*>\s*$', caseSensitive: false).hasMatch(text)) {
        throw const FormatException(
          'The website was cut off. Try again, or ask for a simpler page.',
        );
      }
    default:
      if (!validTransformOutput(text)) {
        throw const FormatException(
          'The model returned an invalid note result.',
        );
      }
      if (!richCompatible(text)) {
        throw const FormatException(richIncompatibleMessage);
      }
  }
}

String backgroundPreviewPath(String id, String output) =>
    'note_media/$id-${NoteBackgroundResult.parse(output).sha256}.png';
