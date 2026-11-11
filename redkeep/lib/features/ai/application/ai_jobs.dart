import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../diary/application/diary_ai_sources.dart';
import '../../diary/application/diary_providers.dart';
import '../../diary/data/diary_photo_question_store.dart';
import '../../diary/data/diary_photo_store.dart';
import '../../diary/data/prepare_diary_image.dart';
import '../../diary/domain/diary_ai_contract.dart';
import '../../diary/domain/diary_history_contract.dart';
import '../../diary/domain/diary_photo_question_contract.dart';
import '../../flow/application/flow_providers.dart';
import '../../flow/domain/thought_reflection_contract.dart';
import '../../notes/application/note_ai_sources.dart';
import '../../notes/data/note_media_store.dart';
import '../../notes/domain/note_background_contract.dart';
import '../../recall/domain/recall_question_contract.dart';
import '../../sync/application/sync_providers.dart'
    show writingSessionEpochProvider;
import '../domain/ai_job.dart';
import '../domain/ai_operation.dart';
import '../domain/ai_provider.dart';
import 'ai_cloud.dart';

export 'ai_cloud.dart' show aiClockProvider, aiIdProvider;

/// One request per page. [scope] names the page that owns it; when nothing
/// watches that page's jobs any more, the request is aborted and its result
/// discarded. Nothing is persisted or resumed.
final aiJobsProvider = NotifierProvider.autoDispose
    .family<AiJobs, AiJobState, String>(AiJobs.new);
typedef AiJobsProvider = NotifierProvider<AiJobs, AiJobState>;

class AiJobState {
  const AiJobState({this.job, this.busy = false, this.message});
  final AiJob? job;
  final bool busy;
  final String? message;
}

class AiJobs extends Notifier<AiJobState> {
  AiJobs(this.scope);
  final String scope;
  int _epoch = 0;
  late int _dataGeneration;
  Completer<void>? _abort;

  void _abortRequest() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _abort = null;
  }

  bool _alive(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      !ref.read(appDatabaseProvider).writingBlocked &&
      ref.read(appDatabaseProvider).writingGeneration == _dataGeneration;

  @override
  AiJobState build() {
    ref.watch(writingSessionEpochProvider);
    _dataGeneration = ref.read(appDatabaseProvider).writingGeneration;
    ref.onDispose(() {
      _epoch++;
      _abortRequest();
    });
    return const AiJobState();
  }

  Future<void> start(
    AiOperation operation,
    String key,
    String prompt,
    String source,
  ) async {
    if (state.busy) return;
    final epoch = ++_epoch;
    _abortRequest();
    final abort = _abort = Completer<void>();
    var job = AiJob(
      id: ref.read(aiIdProvider)(),
      operation: operation,
      key: key,
      prompt: prompt,
      source: source,
      phase: 'running',
    );
    state = AiJobState(job: job, busy: true);
    try {
      if (!operation.available) {
        throw const AiProviderFailure(AiProviderFailureKind.unsupported);
      }
      if (prompt.trim().isEmpty ||
          utf8.encode(prompt).length > operation.inputBytes ||
          source.length > 131072) {
        throw const FormatException(
          'This request is too large. Nothing was shortened or sent.',
        );
      }
      if (!await _current(operation, source)) {
        throw const FormatException(
          'Your writing changed. Nothing was sent; ask again.',
        );
      }
      if (!_alive(epoch)) return;
      final text = await _send(job, abort.future);
      if (!_alive(epoch)) return;
      _validate(job, text);
      job = job.copy(phase: 'completed', text: text);
      state = AiJobState(job: job);
    } catch (error) {
      if (!_alive(epoch)) return;
      final cancelled =
          error is AiProviderFailure &&
          error.kind == AiProviderFailureKind.cancelled;
      state = AiJobState(
        job: job.copy(phase: cancelled ? 'cancelled' : 'failed'),
        message: cancelled ? null : aiErrorMessage(error),
      );
    } finally {
      if (identical(_abort, abort)) _abort = null;
    }
  }

  Future<String> _send(AiJob job, Future<void> abort) async {
    final cloud = ref.read(aiCloudProvider);
    final operation = job.operation;
    if (operation == AiOperation.noteBackground) {
      return _noteBackground(job, abort);
    }
    final images = switch (operation) {
      AiOperation.noteImage || AiOperation.noteScan => [
        AiImageInput(await _noteUpload(job), mime: 'image/png'),
      ],
      AiOperation.photoQuestions => [
        AiImageInput(await _photoUpload(job), mime: 'image/png'),
      ],
      _ => const <AiImageInput>[],
    };
    final text = await cloud.chat(
      system: operation.system,
      user: _userMessage(operation, job.prompt),
      outputTokens: operation.outputTokens,
      temperature: operation.temperature,
      topP: operation.topP,
      images: images,
      abort: abort,
      timeout: operation.timeout,
    );
    return operation == AiOperation.noteScan ? _scanResult(text) : text;
  }

  static String _userMessage(AiOperation operation, String prompt) {
    switch (operation) {
      case AiOperation.noteSummary:
        return jsonEncode({'note': prompt});
      case AiOperation.thoughtReflection:
        return jsonEncode({'thought': prompt});
      case AiOperation.noteScan:
        return 'Transcribe this page.';
      case AiOperation.noteImage:
        final value = jsonDecode(prompt) as Map;
        return switch (value['mode']) {
          'question' =>
            'Question about the image (answer in "answer"): ${jsonEncode(value['question'])}',
          'explain' =>
            'Explain what this image appears to show (put it in "answer").',
          _ => 'Describe this image. Leave "answer" empty.',
        };
      case AiOperation.photoQuestions:
        final value = jsonDecode(prompt) as Map;
        final caption = (value['caption'] as String? ?? '').trim();
        final avoid = (value['avoid'] as List? ?? const []).cast<String>();
        return [
          caption.isEmpty
              ? 'The person gave no caption.'
              : "The person's own caption (context from them, not from the photo; use it only for the questions, never in observations): ${jsonEncode(caption)}",
          if (avoid.isNotEmpty) ...[
            'The person has already seen these questions. Write different ones that ask about something else:',
            for (final question in avoid) '- ${jsonEncode(question)}',
          ],
          'Write reflection questions for this photo.',
        ].join('\n');
      default:
        return prompt;
    }
  }

  /// Cloud models only read the page; there is no second reader to compare.
  static String _scanResult(String text) {
    try {
      final value = jsonDecode(text);
      if (value is Map) {
        return jsonEncode({
          'text': value['text'],
          'readable': value['readable'],
          'check': null,
        });
      }
    } on FormatException {
      /* Rejected by validation. */
    }
    return text;
  }

  Future<String> _noteBackground(AiJob job, Future<void> abort) async {
    final request = jsonDecode(job.prompt) as Map;
    final tone = request['tone'] == 'dark'
        ? 'Dark and low in contrast, so light text stays readable.'
        : 'Light, soft and low in contrast, so dark text stays readable.';
    final png = await ref
        .read(aiCloudProvider)
        .generateImage(
          'A calm, subtle full-page background for a personal note: '
          '${request['prompt']}. $tone Portrait composition for a tall phone '
          'screen. No text, letters, logos or watermarks.',
          // Notes are read on a phone held upright.
          size: noteBackgroundImageSize,
          abort: abort,
        );
    if (png.length < 24 || png[0] != 0x89 || png[1] != 0x50) {
      throw const FormatException(
        'The generated image was not a PNG. Nothing was applied.',
      );
    }
    final data = ByteData.sublistView(png);
    final text = jsonEncode({
      'width': data.getUint32(16),
      'height': data.getUint32(20),
      'bytes': png.length,
      'sha256': sha256.convert(png).toString(),
      'seed': 0,
    });
    final meta = NoteBackgroundResult.parse(text);
    if (!meta.matches(png, meta.sha256)) {
      throw const FormatException(
        'The generated image failed verification. Nothing was applied.',
      );
    }
    await ref.read(noteMediaStoreProvider).write(png, identity: job.id);
    return text;
  }

  Future<Uint8List> _noteUpload(AiJob job) async {
    final source = noteTaskSource(job.source);
    final file = await ref
        .read(noteMediaStoreProvider)
        .resolve(source['upload'] as String);
    if (file == null) {
      throw const FormatException(
        'The prepared image is missing. Choose the image again.',
      );
    }
    final bytes = await file.readAsBytes();
    if (sha256.convert(bytes).toString() != source['imageSha']) {
      throw const FormatException(
        'The prepared image changed. Nothing was sent.',
      );
    }
    return bytes;
  }

  Future<Uint8List> _photoUpload(AiJob job) async {
    final source = jsonDecode(job.source) as Map;
    final bytes = await ref
        .read(diaryPhotoQuestionStoreProvider)
        .readUpload(source['upload'] as String);
    if (bytes == null ||
        await DiaryPhotoStore.digest(bytes) != source['imageSha']) {
      throw const FormatException(
        'The photo prepared for this request is missing. Generate questions again.',
      );
    }
    return bytes;
  }

  Future<bool> _current(AiOperation operation, String source) async {
    final reader = ref.read(diaryAiSourcesProvider);
    return switch (operation) {
      AiOperation.diaryDetails => await reader.current(
        DiarySuggestionSource.decode(source),
      ),
      AiOperation.photoQuestions => true,
      AiOperation.thoughtReflection => await _reflectionCurrent(
        ThoughtReflectionSource.decode(source),
      ),
      AiOperation.thoughtQuestion => await _thoughtQuestionCurrent(
        RecallQuestionSelection.decode(source),
      ),
      AiOperation.history => await _historyCurrent(
        DiaryHistorySelection.decode(source),
      ),
      _ => await noteAiSourceCurrent(ref, operation, source),
    };
  }

  void _validate(AiJob job, String text) {
    if (utf8.encode(text).length > job.operation.outputBytes) {
      throw const FormatException('AI returned an oversized result.');
    }
    switch (job.operation) {
      case AiOperation.thoughtReflection:
        parseThoughtReflection(
          text,
          ThoughtReflectionSource.decode(job.source).body,
        );
      case AiOperation.thoughtQuestion:
        RecallQuestionAnswer.parse(
          text,
          RecallQuestionSelection.decode(job.source),
        );
      case AiOperation.diaryDetails:
        DiarySuggestions.parse(text, DiarySuggestionSource.decode(job.source));
      case AiOperation.photoQuestions:
        DiaryPhotoQuestions.parse(text);
      case AiOperation.history:
        DiaryHistoryAnswer.parse(
          text,
          DiaryHistorySelection.decode(job.source),
        );
      default:
        validateNoteAiOutput(job.operation, text, job.source);
    }
  }

  Future<void> startDiaryPhotoQuestions({
    required String date,
    required String photoSha,
    required Uint8List photo,
    String caption = '',
    int group = -1,
    List<String> avoid = const [],
  }) async {
    if (state.busy) return;
    final generation = ref.read(appDatabaseProvider).writingGeneration;
    try {
      final settings = await ref.read(aiCloudSettingsProvider.future);
      if (settings == null || !settings.supports(AiCapability.vision)) {
        throw AiProviderFailure(
          settings == null
              ? AiProviderFailureKind.notConfigured
              : AiProviderFailureKind.unsupported,
        );
      }
      final bytes = await prepareImageBytes(photo);
      if (!ref.mounted ||
          generation != ref.read(appDatabaseProvider).writingGeneration ||
          ref.read(appDatabaseProvider).writingBlocked) {
        return;
      }
      final upload = ref.read(aiIdProvider)();
      await ref
          .read(diaryPhotoQuestionStoreProvider)
          .writeUpload(upload, bytes);
      final source = DiaryPhotoQuestionSource(
        date: date,
        photoSha: photoSha,
        imageSha: await DiaryPhotoStore.digest(bytes),
        caption: caption.trim(),
        group: group,
        avoid: avoid,
      );
      DiaryPhotoQuestionSource.decode(source.encode());
      final model = settings.model(AiCapability.chat) ?? '';
      await start(
        AiOperation.photoQuestions,
        photoSha,
        source.request(),
        jsonEncode({
          ...jsonDecode(source.encode()) as Map<String, dynamic>,
          'upload': upload,
          'model': model,
          'cache': diaryPhotoCacheKey(photoSha, caption, model),
        }),
      );
    } catch (e) {
      if (ref.mounted &&
          generation == ref.read(appDatabaseProvider).writingGeneration) {
        state = AiJobState(job: state.job, message: aiErrorMessage(e));
      }
    }
  }

  Future<bool> _reflectionCurrent(ThoughtReflectionSource source) async =>
      source.matches(
        (await ref.read(flowRepositoryProvider).openDocument(source.id))
            .thought,
      );

  Future<bool> _thoughtQuestionCurrent(RecallQuestionSelection source) async {
    if (source.kind != RecallKind.thought || !source.sendable) return false;
    for (final selected in source.sources) {
      final thought =
          (await ref.read(flowRepositoryProvider).openDocument(selected.uuid))
              .thought;
      if (thought == null ||
          thought.deletedAt != null ||
          RecallItem.thought(thought)!.version != selected.version) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _historyCurrent(DiaryHistorySelection source) async {
    for (final s in source.sources) {
      final entry =
          (await ref.read(diaryRepositoryProvider).openDocument(s.uuid)).entry;
      if (entry == null ||
          entry.deletedAt != null ||
          entry.date.key != s.date) {
        return false;
      }
      // Selection versions include exact text and update time.
      if (itemVersion(entry) != s.version) return false;
    }
    return true;
  }

  /// Sends the same request again. Only failed or cancelled requests retry.
  Future<void> retry() async {
    final job = state.job;
    if (job == null || state.busy || job.phase == 'completed') return;
    if (job.operation == AiOperation.photoQuestions) {
      // The prepared upload is still on disk under the same source.
      state = const AiJobState();
    }
    await start(job.operation, job.key, job.prompt, job.source);
  }

  Future<void> cancel() async {
    final job = state.job;
    _epoch++;
    _abortRequest();
    if (job == null || !ref.mounted) return;
    state = AiJobState(job: job.terminal ? job : job.copy(phase: 'cancelled'));
  }

  Future<void> clear() async {
    final job = state.job;
    _epoch++;
    _abortRequest();
    if (!ref.mounted) return;
    state = const AiJobState();
    if (job?.operation == AiOperation.photoQuestions) {
      try {
        await ref
            .read(diaryPhotoQuestionStoreProvider)
            .deleteUpload(jsonDecode(job!.source)['upload'] as String);
      } catch (_) {
        /* Expiry cleanup retries. */
      }
    }
  }

  Future<void> clearIfCurrent(String id) async {
    if (state.job?.id == id) await clear();
  }
}

String aiErrorMessage(Object error) => switch (error) {
  AiProviderFailure() => error.message,
  FormatException() => error.message,
  RecallAnswerRejected() => error.message,
  ThoughtReflectionRejected() => error.message,
  StateError() => error.message,
  _ => 'Could not finish the AI request. Your writing is safe. Try again.',
};
