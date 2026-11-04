import '../../ai/application/ai_lifecycle.dart';
import '../../voice/application/voice_coordination.dart';
import '../../companion/application/companion_controller.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:redkeep/features/diary/domain/diary_photo_question_contract.dart';
import 'package:redkeep/features/diary/data/diary_photo_question_store.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';

import '../../ai/domain/ai_job.dart';

/// One photo to ask about: its saved-bytes hash, the bytes and its caption.
typedef DiaryPhotoAsk = ({String photoSha, Uint8List photo, String caption});

class DiaryPhotoQuestionState {
  const DiaryPhotoQuestionState({
    this.questions = const {},
    this.messages = const {},
    this.queued = const [],
    this.shuffling = const {},
    this.fresh = const {},
    this.revision = 0,
  });

  /// Cached results by photo SHA-256.
  final Map<String, DiaryPhotoQuestions> questions;

  /// Why the last request for a photo produced no questions.
  final Map<String, String> messages;

  /// Photos from **Generate questions** not yet held by the task slot.
  final List<String> queued;

  /// Photos waiting for one new question, by photo SHA-256: the group index.
  final Map<String, int> shuffling;

  /// The latest new question per photo from shuffle. [id] is the task that
  /// wrote it, so the page adds each one once.
  final Map<String, ({String id, int group, String question})> fresh;
  final int revision;
}

/// I02: moves finished photo questions out of the shared task slot into the
/// local cache, then frees the slot for the next photo. It runs app-wide, so
/// a result that arrives after the photo page closed is still kept.
class DiaryPhotoQuestionController extends Notifier<DiaryPhotoQuestionState> {
  DiaryPhotoQuestionStore get _store =>
      ref.read(diaryPhotoQuestionStoreProvider);
  bool _pruned = false;
  final _contexts = <String, String>{};
  String get _model =>
      (ref.read(companionControllerProvider).status?['capabilities'] as List? ??
                  [])
              .whereType<Map>()
              .where((c) => c['id'] == 'vision')
              .firstOrNull?['model']
          as String? ??
      '';
  String _context(DiaryPhotoAsk ask) =>
      diaryPhotoCacheKey(ask.photoSha, ask.caption, _model);
  bool currentCaption(String sha, String caption) =>
      _contexts[sha] == diaryPhotoCacheKey(sha, caption, _model);
  bool needsLoad(Iterable<DiaryPhotoAsk> asks) =>
      asks.any((a) => _contexts[a.photoSha] != _context(a));

  /// The task being moved to the cache, so repeated slot updates don't
  /// consume it twice.
  String? _consuming;

  /// Photos from **Generate questions** not yet sent. The shared task slot
  /// holds one request at a time, so they go one after another.
  final _queue = <DiaryPhotoAsk>[];
  String _queueDate = '';
  final _queueDates = <String, String>{};
  bool _sending = false;

  @override
  DiaryPhotoQuestionState build() {
    ref.listen(aiForegroundProvider, (_, active) {
      if (active) scheduleMicrotask(() => unawaited(_next()));
    });
    ref.listen(voiceActiveProvider, (_, active) {
      if (!active) scheduleMicrotask(() => unawaited(_next()));
    });
    ref.listen(
      aiJobsProvider,
      (_, next) => scheduleMicrotask(() {
        if (ref.mounted) unawaited(_consume(next));
      }),
      fireImmediately: true,
    );
    return const DiaryPhotoQuestionState();
  }

  /// Whether questions for [photoSha] are being asked in the shared slot.
  static bool asking(AiJobState summary, String photoSha) =>
      summary.handle?.isDiaryPhoto == true &&
      summary.handle!.noteId == photoSha &&
      (!summary.terminal || summary.busy);

  void _set({
    Map<String, DiaryPhotoQuestions>? questions,
    Map<String, String>? messages,
    Map<String, int>? shuffling,
    Map<String, ({String id, int group, String question})>? fresh,
  }) {
    state = DiaryPhotoQuestionState(
      questions: questions ?? state.questions,
      messages: messages ?? state.messages,
      queued: [for (final ask in _queue) ask.photoSha],
      shuffling: shuffling ?? state.shuffling,
      fresh: fresh ?? state.fresh,
      revision: state.revision + 1,
    );
  }

  Map<String, int> _withoutShuffle(String photoSha) => {
    for (final entry in state.shuffling.entries)
      if (entry.key != photoSha) entry.key: entry.value,
  };

  void _message(String photoSha, String? message) => _set(
    messages: {
      for (final entry in state.messages.entries)
        if (entry.key != photoSha) entry.key: entry.value,
      photoSha: ?message,
    },
  );

  /// Reads cached questions for [photoShas] not loaded yet.
  Future<void> load(Iterable<DiaryPhotoAsk> photos) async {
    for (final ask in photos) {
      final key = _context(ask);
      if (_contexts[ask.photoSha] == key) continue;
      _contexts[ask.photoSha] = key;
      _set(
        questions: {...state.questions}..remove(ask.photoSha),
        fresh: {...state.fresh}..remove(ask.photoSha),
      );
      try {
        final value = await _store.read(
          key,
          prefix: _model.isEmpty
              ? diaryPhotoCachePrefix(ask.photoSha, ask.caption)
              : null,
        );
        if (value != null && ref.mounted && _contexts[ask.photoSha] == key) {
          _set(questions: {...state.questions, ask.photoSha: value});
        }
      } catch (_) {
        /* Standard questions remain available. */
      }
    }
  }

  /// **Generate questions**: asks the computer about each of [photos] that has
  /// no questions yet, one at a time. Photos already being asked about or
  /// waiting are not asked twice.
  Future<void> generate({
    required String date,
    required List<DiaryPhotoAsk> photos,
  }) async {
    await load(photos);
    if (!ref.mounted) return;
    final summary = ref.read(aiJobsProvider);
    final waiting = {for (final ask in _queue) ask.photoSha};
    final fresh = [
      for (final ask in photos)
        if (ask.photo.isNotEmpty &&
            !state.questions.containsKey(ask.photoSha) &&
            !waiting.contains(ask.photoSha) &&
            !asking(summary, ask.photoSha))
          ask,
    ];
    if (fresh.isEmpty) return;
    if (summary.handle != null && !summary.handle!.isDiaryPhoto) {
      _set(
        messages: {
          ...state.messages,
          for (final ask in fresh) ask.photoSha: 'Another AI request is still open. Finish or clear it in More → Grand Maestar, then generate again.',
        },
      );
      return;
    }
    _queueDate = date;
    // Queued at once so the page shows it is working from the first frame.
    _queue.addAll(fresh);
    for (final ask in fresh) {
      _queueDates[ask.photoSha] = date;
    }
    _set(
      messages: {
        for (final entry in state.messages.entries)
          if (!fresh.any((ask) => ask.photoSha == entry.key))
            entry.key: entry.value,
      },
    );
    // Photos answered on an earlier visit are cached: don't ask again.
    await load(fresh);
    if (!ref.mounted) return;
    _queue.removeWhere(
      (ask) => !_sending && state.questions.containsKey(ask.photoSha),
    );
    _set();
    await _next();
  }

  /// Stops generating: drops waiting photos and cancels the one in progress.
  Future<void> stop() async {
    _queue.clear();
    _queueDates.clear();
    _set();
    final summary = ref.read(aiJobsProvider);
    if (summary.handle?.isDiaryPhoto == true && !summary.terminal) {
      await ref.read(aiJobsProvider.notifier).cancel();
    }
  }

  /// Sends the next waiting photo once the shared slot is free.
  Future<void> _next() async {
    if (_sending ||
        _queue.isEmpty ||
        !ref.mounted ||
        !ref.read(aiForegroundProvider) ||
        ref.read(voiceActiveProvider)) {
      return;
    }
    final summary = ref.read(aiJobsProvider);
    // Busy with the previous photo: [_consume] calls back when it's done.
    if (summary.handle != null || summary.busy) return;
    _sending = true;
    // Stays queued until the slot holds it, so nothing looks finished early.
    final ask = _queue.first;
    try {
      await request(
        date: _queueDates[ask.photoSha] ?? _queueDate,
        photoSha: ask.photoSha,
        photo: ask.photo,
        caption: ask.caption,
      );
    } finally {
      _sending = false;
      _queue.remove(ask);
      _queueDates.remove(ask.photoSha);
    }
    if (!ref.mounted) return;
    _set();
    final reason = state.messages[ask.photoSha];
    if (reason != null) {
      // Refused before sending (no model, not connected…): the rest would be
      // refused for the same reason, so say it once for each and stop.
      final rest = [for (final waiting in _queue) waiting.photoSha];
      _queue.clear();
      _set(messages: {...state.messages, for (final sha in rest) sha: reason});
    } else {
      await _next();
    }
  }

  /// Shuffle: asks for one new question in [group] for one photo, avoiding
  /// [shown]. Returns false when nothing was sent (no computer, no model, the
  /// slot busy), so the page can fall back to the questions it has.
  Future<bool> another({
    required String date,
    required String photoSha,
    required Uint8List photo,
    required int group,
    required List<String> shown,
    String caption = '',
  }) async {
    if (photo.isEmpty || state.shuffling.containsKey(photoSha)) return false;
    final summary = ref.read(aiJobsProvider);
    if (summary.handle != null || summary.busy || _queue.isNotEmpty) {
      return false;
    }
    // The newest questions matter most, and the request must stay within the
    // task slot's 2,000-byte input.
    final avoid = <String>[];
    for (final question in shown.reversed) {
      if (avoid.length == diaryPhotoAvoid) break;
      final next = [question, ...avoid];
      if (utf8.encode(jsonEncode({'caption': caption, 'avoid': next})).length >
          1900) {
        break;
      }
      avoid.insert(0, question);
    }
    if (avoid.isEmpty) return false;
    _set(shuffling: {...state.shuffling, photoSha: group});
    await ref
        .read(aiJobsProvider.notifier)
        .startDiaryPhotoQuestions(
          date: date,
          photoSha: photoSha,
          photo: photo,
          caption: caption,
          group: group,
          avoid: avoid,
        );
    if (!ref.mounted) return false;
    final next = ref.read(aiJobsProvider);
    if (next.handle?.noteId == photoSha && next.handle!.isDiaryPhoto) {
      return true;
    }
    _set(shuffling: _withoutShuffle(photoSha));
    return false;
  }

  /// Asks the computer about one photo.
  Future<void> request({
    required String date,
    required String photoSha,
    required Uint8List photo,
    String caption = '',
  }) async {
    _message(photoSha, null);
    final summary = ref.read(aiJobsProvider.notifier);
    await summary.startDiaryPhotoQuestions(
      date: date,
      photoSha: photoSha,
      photo: photo,
      caption: caption,
    );
    if (!ref.mounted) return;
    final next = ref.read(aiJobsProvider);
    if (next.handle == null && next.message != null) {
      _message(photoSha, next.message);
    } else if (next.handle?.noteId != photoSha) {
      _message(
        photoSha,
        next.handle == null
            ? 'Your computer is still finishing the previous request. Try again in a moment.'
            : 'Another AI request is still open. Finish or clear it in More → Grand Maestar, then ask again.',
      );
    }
  }

  /// Hides generated questions for [photoSha]; answers are kept.
  Future<void> forget(String photoSha) async {
    await _store.remove(_contexts[photoSha] ?? photoSha);
    if (ref.mounted) {
      _set(questions: {...state.questions}..remove(photoSha));
    }
  }

  Future<void> _consume(AiJobState summary) async {
    final handle = summary.handle;
    if (summary.phase == 'restoring') return;
    if (!_pruned) {
      _pruned = true;
      try {
        await _store.prune(
          active: handle?.isDiaryPhoto == true ? handle!.id : null,
        );
      } catch (_) {
        // Retried on the next start.
      }
    }
    if (handle == null || !handle.isDiaryPhoto || summary.busy) return;
    if (!summary.terminal || _consuming == handle.id) return;
    _consuming = handle.id;
    final controller = ref.read(aiJobsProvider.notifier);
    final sha = handle.noteId;
    String? message;
    DiaryPhotoQuestionSource? source;
    try {
      source = DiaryPhotoQuestionSource.decode(handle.localSource ?? '');
    } catch (_) {
      // Retrieved after the source was dropped: treat as a full request.
    }
    if (source != null && source.shuffle) {
      // One new question for one group; the cached set is left as it is.
      String? question;
      if (summary.phase == 'completed' && summary.text != null) {
        try {
          final seen = {for (final q in source.avoid) q.toLowerCase()};
          final result = DiaryPhotoQuestions.parse(summary.text!);
          question = result.groups[source.group]
              .where((q) => !seen.contains(q.toLowerCase()))
              .firstOrNull;
        } catch (_) {
          // Reported below.
        }
      }
      final matches = currentCaption(sha, source.caption);
      if (!matches) question = null;
      await controller.clear();
      try {
        await _store.prune();
      } catch (_) {
        // Removed on the next start.
      }
      if (!ref.mounted) return;
      _set(
        shuffling: _withoutShuffle(sha),
        fresh: question == null
            ? null
            : {
                ...state.fresh,
                sha: (id: handle.id, group: source.group, question: question),
              },
      );
      if (question == null) {
        _message(
          sha,
          summary.phase == 'cancelled' ? null : 'Your computer didn’t come up with a different question this time.',
        );
      }
      await _next();
      return;
    }
    if (summary.phase == 'completed' && summary.text != null) {
      try {
        final questions = DiaryPhotoQuestions.parse(summary.text!);
        final raw = jsonDecode(handle.localSource!) as Map;
        final key = raw['cache'] as String;
        await _store.write(key, questions);
        if (ref.mounted &&
            (_contexts[sha] == key ||
                _contexts[sha] ==
                    diaryPhotoCachePrefix(sha, source!.caption))) {
          _set(questions: {...state.questions, sha: questions});
        }
      } catch (_) {
        message = 'Your computer returned something that was not usable. The usual questions are still here.';
      }
    } else if (summary.phase != 'completed') {
      message = switch (summary.phase) {
        'cancelled' => 'Stopped. The usual questions are still here.',
        'expired' => 'That request expired. Ask again for new questions.',
        'interrupted' =>
          'Your computer stopped before finishing. Ask again when it’s ready.',
        // Vision not ready, or the prepared photo is gone: say exactly why.
        _
            when summary.message?.contains('Qwen3-VL') == true ||
                summary.message?.contains('photo prepared') == true =>
          summary.message!,
        _ => 'Your computer couldn’t look at this photo. The usual questions are still here.',
      };
    }
    await controller.clear();
    try {
      await _store.prune();
    } catch (_) {
      // Removed on the next start.
    }
    if (ref.mounted) {
      _message(sha, message);
      await _next();
    }
  }
}

final diaryPhotoQuestionProvider =
    NotifierProvider<DiaryPhotoQuestionController, DiaryPhotoQuestionState>(
      DiaryPhotoQuestionController.new,
    );

extension PhotoTaskState on AiJobState {
  PhotoTaskHandle? get handle => job == null ? null : PhotoTaskHandle(job!);
  bool get terminal => job?.terminal ?? false;
  String get phase => job?.phase ?? (loaded ? 'idle' : 'restoring');
  String? get text => job?.text;
}

class PhotoTaskHandle {
  PhotoTaskHandle(this.job);
  final AiJob job;
  bool get isDiaryPhoto => job.operation.name == 'photoQuestions';
  String get id => job.id;
  String get noteId => job.key;
  String? get localSource => job.source;
}
