import 'dart:convert';

import '../domain/note_rich_markdown.dart';

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_job.dart';
import '../../ai/domain/ai_operation.dart';
import '../../diary/data/prepare_diary_image.dart';
import '../data/note_media_store.dart';
import '../domain/note_document.dart';
import '../domain/note_help_contract.dart';
import '../domain/note_image_contract.dart';
import '../domain/note_scan_contract.dart';
import '../domain/transform_contract.dart';
import 'note_ai_sources.dart';
import 'note_editor_controller.dart';
import 'notes_providers.dart';

final noteAiControllerProvider = Provider((ref) => NoteAiController(ref));

/// Each notes AI tool page owns its request; leaving the page cancels it.
String noteAiScope(String tool, String? noteId) =>
    'note-ai:$tool:${noteId ?? ''}';

class NoteAiController {
  NoteAiController(this.ref);
  final Ref ref;
  Future<List<NoteDocument>> notes() async {
    final repo = ref.read(notesRepositoryProvider);
    final listings = await repo.watchNotes().first;
    return [
      for (final listing in listings)
        if ((await repo.openDocument(listing.id)).note case final note?
            when note.deletedAt == null)
          note,
    ];
  }

  Future<void> start(
    AiOperation operation,
    String id, {
    required String scope,
    String intent = '',
    String topic = '',
    NoteAttachment? image,
    String mode = 'describe',
    String question = '',
    int? selectionStart,
    int? selectionEnd,
    List<String> currentTags = const [],
  }) async {
    final repo = ref.read(notesRepositoryProvider);
    // Open writing goes into the note first, so the tool sees what is shown.
    if (ref.exists(noteEditorProvider(id)) &&
        !await ref.read(noteEditorProvider(id).notifier).save()) {
      throw const FormatException(
        'This note could not be saved, so nothing was sent.',
      );
    }
    final opened = await repo.openDocument(id);
    final unsaved = opened.note == null;
    if (unsaved) {
      if (!{
        AiOperation.noteTemplate,
        AiOperation.noteDraft,
        AiOperation.noteScan,
      }.contains(operation)) {
        throw const FormatException('Write something in this note first.');
      }
      if (!ref.read(noteNewIdsProvider).contains(id)) {
        throw const FormatException('This note is unavailable.');
      }
    } else if (!opened.available) {
      throw const FormatException('This note is unavailable.');
    }
    final note = opened.note;
    final text = note?.text ?? const PlainTextDocument();
    final source = <String, dynamic>{
      'noteId': id,
      'revision': note?.revision ?? 0,
      'unsaved': unsaved,
      // A new note lives only in its editor; any later typing makes this
      // result stale.
      if (unsaved)
        'editVersion': ref.read(noteEditorProvider(id)).value?.editVersion,
      'title': text.title,
      'body': text.body,
    };
    String prompt;
    switch (operation) {
      case AiOperation.noteMetadata:
        final payload = NoteMetadataSource.fromNote(note!);
        prompt = payload.request();
        source['payload'] = payload.encode();
      case AiOperation.noteTags:
        // The picker's choices so far, which may not be saved yet.
        final payload = NoteTagSource.fromNote(
          note!,
          tags: currentTags,
          library: await repo.watchTags().first,
        );
        prompt = payload.request();
        source['payload'] = payload.encode();
      case AiOperation.noteTemplate:
        prompt = NoteTemplateSource(topic).request();
      case AiOperation.noteDraft:
        prompt = NoteDraftSource(topic).request();
      case AiOperation.noteImage || AiOperation.noteScan:
        if (image == null || !image.isImage) {
          throw const FormatException('Choose an image first.');
        }
        if (operation == AiOperation.noteImage &&
            !note!.details.attachments.any((a) => a.path == image.path)) {
          throw const FormatException('This image is no longer attached.');
        }
        final file = await ref.read(noteMediaStoreProvider).resolve(image.path);
        if (file == null) {
          throw const FormatException(
            'This image is unavailable. Reattach it here.',
          );
        }
        final Uint8List upload = await prepareImageBytes(
          await file.readAsBytes(),
        );
        final digest = sha256.convert(upload).toString();
        final path = await ref
            .read(noteMediaStoreProvider)
            .write(upload, identity: ref.read(aiIdProvider)());
        source.addAll({
          'upload': path,
          'imageSha': digest,
          'image': image.toMap(),
        });
        if (operation == AiOperation.noteImage) {
          NoteImageRequest.validate(mode, question);
          prompt = jsonEncode({'mode': mode, 'question': question});
        } else {
          prompt = noteScanPrompt;
        }
      default:
        if (!transformOperations.containsKey(operation.wireName)) {
          throw const FormatException('Unsupported notes tool.');
        }
        final range = TransformSource(
          content: text.body,
          version: note!.revision.toString(),
          start: selectionStart ?? 0,
          end: selectionEnd ?? text.body.length,
        );
        TransformSource.decode(range.encode());
        final instruction = operation == AiOperation.noteCustom
            ? intent.trim()
            : intent;
        if (operation == AiOperation.noteCustom && instruction.isEmpty) {
          throw const FormatException('Enter an instruction first.');
        }
        if (utf8.encode(instruction).length > transformIntentBytes) {
          throw const FormatException(
            'Use an instruction of at most $transformIntentBytes bytes.',
          );
        }
        prompt = jsonEncode({'text': range.selected, 'intent': instruction});
        source['range'] = range.encode();
    }
    await ref
        .read(aiJobsProvider(scope).notifier)
        .start(operation, id, prompt, jsonEncode(source));
  }

  Future<void> _clearReviewedJob(AiJob job, String scope) async {
    if (ref.mounted && ref.read(aiJobsProvider(scope)).job?.id == job.id) {
      await ref.read(aiJobsProvider(scope).notifier).clear();
    }
  }

  Future<NoteDocument?> apply(
    AiJob job, {
    required String scope,
    String? reviewedText,
  }) async {
    // Title and tag ideas are taken where they were asked for, in the
    // editor and the tag picker.
    if (job.phase != 'completed' ||
        job.text == null ||
        !job.operation.isNote ||
        job.operation == AiOperation.noteMetadata ||
        job.operation == AiOperation.noteTags) {
      return null;
    }
    validateNoteAiOutput(job.operation, job.text!, job.source);
    final source = noteTaskSource(job.source);
    final unsaved = source['unsaved'] == true;
    if (unsaved &&
        !ref.exists(noteEditorProvider(source['noteId'] as String))) {
      throw const FormatException(
        'Open this new note again to add the result.',
      );
    }
    final expectedEdit = source['editVersion'];
    if (!await noteAiSourceCurrent(ref, job.operation, job.source)) {
      throw const FormatException(
        'This note changed. The proposal was kept; nothing was applied.',
      );
    }
    final id = source['noteId'] as String;
    final repo = ref.read(notesRepositoryProvider);
    final opened = await repo.openDocument(id);
    final editing = unsaved ? ref.read(noteEditorProvider(id)).value : null;
    var text = opened.note?.text ?? editing?.text ?? const PlainTextDocument();
    var details =
        opened.note?.details.copy(tags: opened.note!.tags) ??
        editing?.details ??
        const NoteDetails();
    // AI answers and scanned pages are plain words, never formatting.
    String append(String value) => [
      if (text.body.isNotEmpty) text.body,
      markdownFromPlainText(value),
    ].join('\n\n');
    switch (job.operation) {
      case AiOperation.noteTemplate || AiOperation.noteDraft:
        final template = job.operation == AiOperation.noteDraft
            ? NoteTemplate.parse(
                job.text!,
                bodyBytes: noteDraftBodyBytes,
                lines: noteDraftLines,
              )
            : NoteTemplate.parse(job.text!);
        text = PlainTextDocument(
          title: text.title.trim().isEmpty ? template.title : text.title,
          body: [
            if (text.body.isNotEmpty) text.body,
            template.body,
          ].join('\n\n'),
        );
      case AiOperation.noteScan:
        final scan = NoteScanResult.parse(job.text!);
        final value = reviewedText ?? scan.text;
        if (value.replaceAll('[?]', '').trim().isEmpty ||
            value.runes.length > noteScanTextChars) {
          throw const FormatException('Check the scanned text first.');
        }
        text = PlainTextDocument(title: text.title, body: append(value));
        final image = NoteAttachment.fromMap(
          Map<String, dynamic>.from(source['image'] as Map),
        );
        details = details.copy(
          attachments: [
            ...details.attachments.where((a) => a.path != image.path),
            image,
          ],
        );
        await ref
            .read(noteMediaStoreProvider)
            .writeScanOriginal(image.path, scan.text);
      case AiOperation.noteImage:
        final answer = NoteImageAnswer.parse(job.text!);
        final value = reviewedText ?? answer.insertion;
        if (value.trim().isEmpty ||
            utf8.encode(value).length > noteImageOutputBytes) {
          throw const FormatException(
            'Use reviewed text of at most 4,096 UTF-8 bytes.',
          );
        }
        text = PlainTextDocument(title: text.title, body: append(value));
      default:
        final range = TransformSource.decode(source['range'] as String);
        if (range.replace(job.text!) == text.body) {
          throw const FormatException('This proposal makes no change.');
        }
        text = PlainTextDocument(
          title: text.title,
          body: range.replace(job.text!),
        );
    }
    if (!richCompatible(text.body)) {
      throw const FormatException(richIncompatibleMessage);
    }
    if (unsaved) {
      if (ref.read(noteEditorProvider(id)).value?.editVersion != expectedEdit ||
          !await noteAiSourceCurrent(ref, job.operation, job.source)) {
        throw const FormatException(
          'The note changed while reviewing. Nothing was applied.',
        );
      }
      final controller = ref.read(noteEditorProvider(id).notifier);
      controller.edit(text);
      controller.editDetails(details);
      if (!await controller.save()) {
        throw const FormatException(
          'The result is in this note but could not be saved yet.',
        );
      }
      await _clearReviewedJob(job, scope);
      return null;
    }
    final saved = await repo.applyProposal(
      id,
      source['revision'] as int,
      text: text,
      details: details,
    );
    await _clearReviewedJob(job, scope);
    return saved;
  }
}
