import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/domain/ai_operation.dart';
import '../domain/note_background_contract.dart';
import '../domain/note_help_contract.dart';
import '../domain/note_image_contract.dart';
import '../domain/note_question_contract.dart';
import '../domain/note_scan_contract.dart';
import '../domain/transform_contract.dart';
import '../domain/website/website_contract.dart';
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
  if (operation == AiOperation.noteIdeas) {
    for (final entry in (source['selected'] as Map? ?? {}).entries) {
      final opened = await repo.openDocument(entry.key as String);
      if (!opened.available || opened.note!.revision != entry.value) {
        return false;
      }
    }
    return true;
  }
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
  if (source['draft'] == true) {
    return opened.note == null &&
        opened.draft?.draftRevision == source['draftRevision'];
  }
  return opened.available &&
      opened.note!.revision == source['revision'] &&
      opened.draft == null;
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
    case AiOperation.noteIdeas:
      parseNoteIdeas(text);
    case AiOperation.noteTemplate:
      NoteTemplate.parse(text);
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
    case AiOperation.noteWebsite:
      WebsiteSpec.decode(text, photos: source['photos'] as int? ?? 0);
    default:
      if (!validTransformOutput(text)) {
        throw const FormatException(
          'The model returned an invalid note result.',
        );
      }
  }
}

String backgroundPreviewPath(String id, String output) =>
    'note_media/$id-${NoteBackgroundResult.parse(output).sha256}.png';
