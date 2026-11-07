import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_job.dart';
import '../../ai/domain/ai_operation.dart';
import '../../diary/data/prepare_diary_image.dart';
import '../../recall/application/recall_controller.dart';
import '../../sync/application/sync_providers.dart';
import '../data/note_media_store.dart';
import '../domain/note_document.dart';
import '../domain/note_help_contract.dart';
import '../domain/note_tag.dart';
import '../domain/note_image_contract.dart';
import '../domain/note_question_contract.dart';
import '../domain/note_scan_contract.dart';
import '../domain/transform_contract.dart';
import '../domain/website/website_contract.dart';
import '../domain/website/website_render.dart';
import 'note_ai_sources.dart';
import 'note_editor_controller.dart';
import 'notes_providers.dart';

final noteAiControllerProvider = Provider((ref) => NoteAiController(ref));

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

  Future<void> search(String question) async {
    final items = await notes();
    final result = await ref
        .read(recallControllerProvider.notifier)
        .search(question, 'note');
    final selection = RecallQuestionSelection.select(
      kind: RecallKind.note,
      question: question,
      today: ref.read(aiClockProvider)(),
      items: RecallItem.notes(items),
      ranked: result.sources.isEmpty
          ? null
          : result.sources.map((s) => s.id).toList(),
    );
    if (!selection.sendable) {
      throw const FormatException(
        'No notes match this question, so nothing was sent. Add a topic or a time.',
      );
    }
    await ref
        .read(aiJobsProvider.notifier)
        .start(
          AiOperation.noteQuestion,
          'note-search',
          selection.request(),
          jsonEncode({'payload': selection.encode()}),
        );
  }

  Future<void> start(
    AiOperation operation,
    String id, {
    String intent = '',
    String topic = '',
    String description = '',
    String theme = 'auto',
    String tone = 'light',
    NoteAttachment? image,
    String mode = 'describe',
    String question = '',
    int? selectionStart,
    int? selectionEnd,
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
        AiOperation.noteScan,
        AiOperation.noteBackground,
      }.contains(operation)) {
        throw const FormatException('Write something in this note first.');
      }
      if (!ref.read(noteNewIdsProvider).contains(id)) {
        throw const FormatException('This note is unavailable.');
      }
    } else if (!opened.available) {
      throw const FormatException('This note is unavailable.');
    }
    if (!unsaved &&
        !ref.read(syncCanEditProvider) &&
        {
          AiOperation.noteMetadata,
          AiOperation.noteScan,
          AiOperation.noteBackground,
          AiOperation.noteWebsite,
        }.contains(operation)) {
      throw const FormatException(
        'This device is add-only. Reclaim primary in Sync & devices to change this note.',
      );
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
      case AiOperation.noteSummary:
        prompt = '${text.title}\n\n${text.body}'.trim();
      case AiOperation.noteMetadata:
        final payload = NoteMetadataSource.fromNote(note!);
        prompt = payload.request();
        source['payload'] = payload.encode();
      case AiOperation.noteTemplate:
        prompt = NoteTemplateSource(topic).request();
      case AiOperation.noteWebsite:
        final photos = note!.details.attachments
            .where((a) => a.isImage)
            .take(6)
            .length;
        final payload = WebsiteRequest(
          noteId: id,
          version: note.revision.toString(),
          title: text.title,
          content: text.body,
          description: description,
          theme: theme,
          photos: photos,
        );
        prompt = payload.request();
        source['payload'] = payload.encode();
        source['photos'] = photos;
      case AiOperation.noteBackground:
        if (description.trim().isEmpty ||
            description.runes.length > 240 ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(description) ||
            !{'light', 'dark'}.contains(tone)) {
          throw const FormatException(
            'Describe a background in one line of at most 240 characters.',
          );
        }
        prompt = jsonEncode({'prompt': description.trim(), 'tone': tone});
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
        if (utf8.encode(intent).length > 240) {
          throw const FormatException(
            'Use an instruction of at most 240 bytes.',
          );
        }
        prompt = jsonEncode({'text': range.selected, 'intent': intent});
        source['range'] = range.encode();
    }
    await ref
        .read(aiJobsProvider.notifier)
        .start(operation, id, prompt, jsonEncode(source));
  }

  Future<void> _clearReviewedJob(AiJob job) async {
    if (ref.mounted && ref.read(aiJobsProvider).job?.id == job.id) {
      await ref.read(aiJobsProvider.notifier).clear();
    }
  }

  Future<NoteDocument?> apply(
    AiJob job, {
    String? title,
    List<String> tags = const [],
    String? reviewedText,
  }) async {
    if (job.phase != 'completed' || job.text == null || !job.operation.isNote) {
      return null;
    }
    if (ref.read(aiClockProvider)().millisecondsSinceEpoch >= job.expires) {
      throw const FormatException(
        'This preview expired. Clear it and generate a new preview.',
      );
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
    String append(String value) =>
        [if (text.body.isNotEmpty) text.body, value].join('\n\n');
    switch (job.operation) {
      case AiOperation.noteMetadata:
        final suggestions = NoteMetadataSuggestions.parse(
          job.text!,
          NoteMetadataSource.decode(source['payload'] as String),
          library: (await repo.watchTags().first)
              .map(NoteTag.tryParse)
              .whereType<NoteTag>(),
        );
        if (title != null && !suggestions.titles.contains(title) ||
            tags.any((t) => !suggestions.tags.any((s) => s.encoded == t))) {
          throw const FormatException('Choose a suggested title or tag.');
        }
        if (title == null && tags.isEmpty) return null;
        text = PlainTextDocument(title: title ?? text.title, body: text.body);
        details = details.copy(tags: {...details.tags, ...tags}.toList());
      case AiOperation.noteTemplate:
        final template = NoteTemplate.parse(job.text!);
        text = PlainTextDocument(
          title: text.title.trim().isEmpty ? template.title : text.title,
          body: append(template.body),
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
      case AiOperation.noteBackground:
        final path = backgroundPreviewPath(job.id, job.text!);
        if (await ref.read(noteMediaStoreProvider).resolve(path) == null) {
          throw const FormatException('The background preview is unavailable.');
        }
        final background = Map<String, dynamic>.from(details.background)
          ..remove('asset');
        details = details.copy(
          background: {...background, 'image': path, 'image_source': 'local'},
        );
      case AiOperation.noteWebsite:
        final page = await websitePageFromOutput(
          job.operation.wireName,
          job.text!,
          source: source['payload'] as String,
        );
        details = details.copy(
          website: page,
          websiteSourceHash: websiteContentHash(text.body),
        );
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
      await _clearReviewedJob(job);
      return null;
    }
    final saved = await repo.applyProposal(
      id,
      source['revision'] as int,
      text: text,
      details: details,
      taskId: job.id,
      operation: job.operation.wireName,
    );
    await _clearReviewedJob(job);
    return saved;
  }
}
