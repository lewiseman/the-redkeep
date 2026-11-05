import '../../flow/application/flow_providers.dart';
import '../../flow/domain/thought_reflection_contract.dart';
import '../../recall/domain/recall_question_contract.dart';
import '../../notes/application/note_ai_sources.dart';
import '../../notes/domain/note_background_contract.dart';
import '../../notes/data/note_media_store.dart';
import '../../voice/application/voice_coordination.dart';
import '../../diary/domain/diary_photo_question_contract.dart';
import '../../diary/domain/diary_history_contract.dart';
import '../../diary/data/diary_photo_question_store.dart';
import '../../diary/data/prepare_diary_image.dart';
import '../../diary/data/diary_photo_store.dart';
import '../../diary/application/diary_providers.dart';

import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../companion/application/companion_controller.dart';
import '../../companion/data/companion_protocol.dart';
import '../../diary/domain/diary_ai_contract.dart';
import '../../diary/application/diary_ai_sources.dart';
import '../../diary/domain/diary_period.dart';
import '../../diary/domain/daily_question_contract.dart';
import '../../sync/application/sync_providers.dart'
    show writingSessionEpochProvider;
import '../data/ai_job_store.dart';
import '../domain/ai_job.dart';
import '../domain/ai_operation.dart';
import '../domain/ai_preferences.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_route.dart';
import 'ai_preferences.dart';
import 'ai_providers.dart';

final protectedAiTasksProvider = Provider<ProtectedAiTasks>(
  (ref) => SecureAiTasks(),
);
final aiJobStoreProvider = Provider<AiJobStore>(
  (ref) => AiJobStore(
    ref.watch(appDatabaseProvider),
    ref.watch(protectedAiTasksProvider),
    clock: ref.watch(aiClockProvider),
  ),
);
final aiClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final aiIdProvider = Provider<String Function()>(
  (ref) => () {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  },
);
final aiJobsProvider = NotifierProvider<AiJobs, AiJobState>(AiJobs.new);

/// Picks one destination for this task. A failed or unready destination is
/// reported, never replaced by another one.
({AiRoute route, AiProviderConnection? provider}) resolveAiRoute({
  required AiOperation operation,
  required AiPreferences preferences,
  required bool connected,
  required List<AiProviderConnection> providers,
}) {
  final route = preferences.routeFor(operation);
  if (route.isCompanion) {
    if (!connected) {
      throw CompanionFailure(
        operation.supportsProvider ? 'UNAVAILABLE' : 'UNSUPPORTED',
        operation.supportsProvider
            ? 'Connect your computer or choose a provider in Grand Maestar.'
            : 'This feature needs your computer. Connect it in Grand Maestar.',
      );
    }
    return (route: route, provider: null);
  }
  final provider = providers.where((p) => p.id == route.providerId).firstOrNull;
  if (provider == null) {
    throw const CompanionFailure(
      'NOT_READY',
      'The provider for this task is gone. Choose another in Grand Maestar.',
    );
  }
  return (route: route, provider: provider);
}

class AiJobState {
  const AiJobState({
    this.job,
    this.busy = false,
    this.message,
    this.loaded = false,
  });
  final AiJob? job;
  final bool busy, loaded;
  final String? message;
}

class AiJobs extends Notifier<AiJobState> {
  int _epoch = 0;
  late int _dataGeneration;
  bool _foreground = true;
  bool _working = false;
  Completer<void>? _providerAbort;
  void _abortProvider() {
    final abort = _providerAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  Future<void>? _restore;
  bool _alive(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      _foreground &&
      !ref.read(appDatabaseProvider).writingBlocked &&
      ref.read(appDatabaseProvider).writingGeneration == _dataGeneration;

  @override
  AiJobState build() {
    ref.watch(writingSessionEpochProvider);
    _dataGeneration = ref.read(appDatabaseProvider).writingGeneration;
    ref.onDispose(() {
      _epoch++;
      _abortProvider();
    });
    return const AiJobState();
  }

  Future<void> restore() =>
      _restore ??= _restoreTask().whenComplete(() => _restore = null);
  Future<void> _restoreTask() async {
    if (_working || !_foreground) return;
    final epoch = _epoch;
    _working = true;
    try {
      var job = state.loaded
          ? state.job
          : await ref.read(aiJobStoreProvider).load();
      if (!_alive(epoch)) return;
      if (job != null &&
          ref.read(aiClockProvider)().millisecondsSinceEpoch >= job.expires) {
        job = AiJob.fromJson({
          ...job.json(sensitive: false),
          'phase': 'expired',
        });
      }
      // Only the companion can resume work. Nothing is ever resent silently.
      if (job != null && job.provider != 'companion' && !job.terminal) {
        job = job.copy(phase: 'interrupted');
      }
      state = AiJobState(job: job, loaded: true);
      if (job != null) {
        await _save(job, epoch);
        if (job.provider == 'companion' && (!job.terminal || job.ackPending)) {
          await _companion(job, epoch, submit: false);
        }
      }
      await _ackReceipts();
    } catch (error) {
      if (_alive(epoch)) {
        state = AiJobState(job: state.job, message: _message(error));
      }
    } finally {
      _working = false;
    }
  }

  Future<bool> available(AiOperation operation) async {
    try {
      final preferences = await ref
          .read(aiPreferencesRepositoryProvider)
          .read();
      final target = resolveAiRoute(
        operation: operation,
        preferences: preferences,
        connected:
            ref.read(companionControllerProvider).phase ==
            CompanionPhase.connected,
        providers: await _providersFor(operation, preferences),
      );
      if (target.provider == null) _checkCapability(operation);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Companion tasks must keep working if protected storage is unavailable.
  Future<List<AiProviderConnection>> _providersFor(
    AiOperation operation,
    AiPreferences preferences,
  ) async => preferences.routeFor(operation).isCompanion
      ? const []
      : await ref.read(aiProvidersProvider.future);

  TrustedComputer _computer(AiJob job) {
    final connection = ref.read(companionControllerProvider);
    final computer = connection.selected;
    if (connection.phase != CompanionPhase.connected ||
        computer == null ||
        !computer.enabled ||
        computer.id != job.computerId ||
        computer.deviceId != job.deviceId) {
      throw const CompanionFailure(
        'UNAVAILABLE',
        'Reconnect the computer that accepted this task to retrieve it.',
      );
    }
    return computer;
  }

  void _checkCapability(AiOperation operation) {
    final status = ref.read(companionControllerProvider).status;
    final capability = (status?['capabilities'] as List? ?? [])
        .whereType<Map>()
        .where((c) => c['id'] == operation.capabilityId)
        .firstOrNull;
    if (status?['recovery'] != 1 ||
        (operation.contractKey.isNotEmpty &&
            capability?[operation.contractKey] != operation.contractVersion) ||
        capability?['operations'] is! List ||
        !(capability!['operations'] as List).contains(operation.wireName)) {
      throw const CompanionFailure(
        'INCOMPATIBLE_VERSION',
        'Update the companion to support this AI operation.',
      );
    }
    if (capability['implemented'] != true ||
        !['ready', 'busy'].contains(capability['status'])) {
      throw CompanionFailure(
        'NOT_READY',
        operation == AiOperation.photoQuestions
            ? 'Load Qwen3-VL in Journal Companion for photo questions.'
            : 'Load a writing model on your computer.',
      );
    }
  }

  Future<void> start(
    AiOperation operation,
    String key,
    String prompt,
    String source, {
    Object? voiceOwner,
  }) async {
    if (_working || !_foreground) return;
    if (ref.read(voiceActiveProvider) &&
        !(operation == AiOperation.conversation &&
            ref.read(voiceActiveProvider.notifier).owns(voiceOwner))) {
      state = AiJobState(
        job: state.job,
        loaded: state.loaded,
        message: 'Finish the voice session before starting another AI task.',
      );
      return;
    }
    await restore();
    if (!ref.mounted || !state.loaded || state.job != null || _working) return;
    final epoch = ++_epoch;
    _working = true;
    state = const AiJobState(busy: true, loaded: true);
    try {
      if (prompt.trim().isEmpty ||
          utf8.encode(prompt).length > operation.inputBytes ||
          source.length > 131072) {
        throw const FormatException(
          'This request is too large. Nothing was shortened or sent.',
        );
      }
      final preferences = await ref
          .read(aiPreferencesRepositoryProvider)
          .read();
      if (!_alive(epoch)) return;
      final connection = ref.read(companionControllerProvider);
      final providers = await _providersFor(operation, preferences);
      if (!_alive(epoch)) return;
      final target = resolveAiRoute(
        operation: operation,
        preferences: preferences,
        connected: connection.phase == CompanionPhase.connected,
        providers: providers,
      );
      final provider = target.provider;
      if (provider == null) _checkCapability(operation);
      final job = AiJob(
        id: ref.read(aiIdProvider)(),
        operation: operation,
        key: key,
        created: ref.read(aiClockProvider)().millisecondsSinceEpoch,
        provider: provider == null ? 'companion' : 'provider',
        computerId: provider == null ? connection.selected!.id : '',
        deviceId: provider == null ? connection.selected!.deviceId : '',
        modelId: target.route.model ?? '',
        providerId: provider?.id ?? '',
        providerName: provider?.name ?? '',
        prompt: prompt,
        source: source,
      );
      final reader = ref.read(diaryAiSourcesProvider);
      final valid = switch (operation) {
        AiOperation.diaryDetails => await reader.current(
          DiarySuggestionSource.decode(source),
        ),
        AiOperation.dailyQuestion =>
          DiaryPeriod.fromComponents(ref.read(aiClockProvider)()).key == key &&
              await reader.questionCurrent(DailyQuestionSource.decode(source)),
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
        AiOperation.conversation => await _conversationCurrent(source),
        _ => await noteAiSourceCurrent(ref, operation, source),
      };
      if (!valid) {
        throw const FormatException(
          'Your entries changed. Nothing was sent; ask again.',
        );
      }
      await _save(job, epoch);
      if (!_alive(epoch)) return;
      if (provider == null) {
        await _companion(job, epoch, submit: true);
      } else {
        await _provider(job, provider, epoch);
      }
    } catch (error) {
      if (_alive(epoch)) {
        state = AiJobState(
          job: state.job,
          loaded: true,
          message: _message(error),
        );
      }
    } finally {
      _working = false;
      if (_alive(epoch) && state.busy) {
        state = AiJobState(
          job: state.job,
          loaded: true,
          message: state.message,
        );
      }
    }
  }

  Future<void> _save(AiJob job, int epoch) async {
    if (!_alive(epoch)) return;
    await ref.read(aiJobStoreProvider).save(job, _dataGeneration);
    if (_alive(epoch)) {
      state = AiJobState(job: job, busy: !job.terminal, loaded: true);
    }
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
      case AiOperation.dailyQuestion:
        DailyQuestion.parse(text, DailyQuestionSource.decode(job.source));
      case AiOperation.photoQuestions:
        DiaryPhotoQuestions.parse(text);
      case AiOperation.history:
        DiaryHistoryAnswer.parse(
          text,
          DiaryHistorySelection.decode(job.source),
        );
      default:
        if (job.operation.isNote) {
          validateNoteAiOutput(job.operation, text, job.source);
          return;
        }
        if (text.trim().isEmpty ||
            RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]').hasMatch(text)) {
          throw const FormatException('Invalid conversation draft');
        }
    }
  }

  Future<void> _provider(
    AiJob job,
    AiProviderConnection connection,
    int epoch,
  ) async {
    final abort = Completer<void>();
    _providerAbort = abort;
    try {
      final operation = job.operation;
      final answer = await ref
          .read(aiProviderClientProvider)
          .complete(
            connection,
            AiCompletionRequest(
              model: job.modelId,
              system: operation.system,
              user: switch (operation) {
                AiOperation.noteSummary => jsonEncode({'note': job.prompt}),
                AiOperation.thoughtReflection => jsonEncode({
                  'thought': job.prompt,
                }),
                _ => job.prompt,
              },
              outputTokens: operation.outputTokens,
              temperature: operation.temperature,
              topP: operation.topP,
            ),
            abort: abort.future,
          );
      if (!_alive(epoch)) return;
      final text = stripSurroundingCodeFence(answer);
      _validate(job, text);
      await _save(job.copy(phase: 'completed', text: text), epoch);
    } finally {
      if (identical(_providerAbort, abort)) _providerAbort = null;
    }
  }

  Future<void> _companion(AiJob job, int epoch, {required bool submit}) async {
    final client = CompanionClient(ref.read(companionTransportProvider));
    final computer = _computer(job);
    if (job.terminal) {
      await client.authenticated(computer, 'POST', '/v1/jobs/${job.id}/ack');
      await _save(job.copy(ackPending: false), epoch);
      return;
    }
    if (job.cancelWanted) {
      await client.authenticated(
        computer,
        'POST',
        '/v1/jobs/${job.id}/cancel',
        body: {'operation': job.operation.wireName},
      );
      submit = false;
    }
    var response = await client.authenticated(
      computer,
      submit ? 'POST' : 'GET',
      submit
          ? (job.operation.imageInput ? '/v1/image-jobs' : '/v1/jobs')
          : '/v1/jobs/${job.id}',
      body: submit
          ? {
              'id': job.id,
              'operation': job.operation.wireName,
              'prompt': job.prompt,
              'expires': job.expires,
              if (job.operation.imageInput)
                'image': job.operation.isNote
                    ? await _noteUpload(job)
                    : await _photoUpload(job),
            }
          : null,
    );
    while (_alive(epoch)) {
      if (response['id'] != job.id ||
          response['operation'] != job.operation.wireName ||
          response['device'] != job.deviceId) {
        throw const FormatException('The computer returned a mismatched task.');
      }
      final phase = response['state'];
      if (phase is! String ||
          !{
            'queued',
            'running',
            'completed',
            'failed',
            'cancelled',
            'expired',
            'interrupted',
          }.contains(phase)) {
        throw const FormatException(
          'The computer returned an invalid task state.',
        );
      }
      if (job.operation == AiOperation.photoQuestions &&
          response['model'] != jsonDecode(job.source)['model']) {
        throw const FormatException(
          'The computer returned a different photo model. Generate questions again.',
        );
      }
      var next = job.copy(accepted: true, phase: phase);
      if (phase == 'completed') {
        final text = response['text'];
        if (text is! String) {
          throw const FormatException(
            'The result is no longer on the computer. Clear this task and ask again.',
          );
        }
        _validate(job, text);
        if (job.operation == AiOperation.noteBackground) {
          await _collectNoteBackground(job, text, client, computer);
          if (!_alive(epoch)) return;
        }
        next = next.copy(text: text);
      }
      if (next.terminal) {
        next = next.copy(ackPending: response['acknowledged'] != true);
      }
      await _save(next, epoch);
      job = next;
      if (next.terminal) {
        if (next.ackPending && _alive(epoch)) {
          try {
            await client.authenticated(
              computer,
              'POST',
              '/v1/jobs/${job.id}/ack',
            );
            await _save(job.copy(ackPending: false), epoch);
          } catch (_) {
            /* Protected result and pending receipt survive. */
          }
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!_alive(epoch)) return;
      response = await client.authenticated(
        _computer(job),
        'GET',
        '/v1/jobs/${job.id}',
      );
    }
  }

  Future<String> _noteUpload(AiJob job) async {
    final source = noteTaskSource(job.source);
    final file = await ref
        .read(noteMediaStoreProvider)
        .resolve(source['upload'] as String);
    if (file == null) {
      throw const FormatException(
        'The prepared image is missing. Clear this task and choose the image again.',
      );
    }
    final bytes = await file.readAsBytes();
    if (await hexHash(bytes) != source['imageSha']) {
      throw const FormatException(
        'The prepared image changed. Nothing was sent.',
      );
    }
    return base64Encode(bytes);
  }

  Future<void> _collectNoteBackground(
    AiJob job,
    String text,
    CompanionClient client,
    TrustedComputer computer,
  ) async {
    final meta = NoteBackgroundResult.parse(text);
    final store = ref.read(noteMediaStoreProvider);
    final path = backgroundPreviewPath(job.id, text);
    final existing = await store.resolve(path);
    if (existing != null &&
        meta.matches(
          await existing.readAsBytes(),
          await hexHash(await existing.readAsBytes()),
        )) {
      return;
    }
    final result = await client.authenticated(
      computer,
      'GET',
      '/v1/image-jobs/${job.id}/result',
    );
    final bytes = result['image'] is String
        ? base64Decode(result['image'] as String)
        : Uint8List(0);
    if (result['id'] != job.id || !meta.matches(bytes, await hexHash(bytes))) {
      throw const FormatException(
        'The generated image failed verification. Nothing was applied.',
      );
    }
    await store.write(bytes, identity: job.id);
  }

  Future<String> _photoUpload(AiJob job) async {
    final bytes = await ref
        .read(diaryPhotoQuestionStoreProvider)
        .readUpload(jsonDecode(job.source)['upload'] as String);
    if (bytes == null ||
        await DiaryPhotoStore.digest(bytes) !=
            jsonDecode(job.source)['imageSha']) {
      throw const FormatException(
        'The photo prepared for this task is missing. Generate questions again.',
      );
    }
    return base64Encode(bytes);
  }

  Future<void> startDiaryPhotoQuestions({
    required String date,
    required String photoSha,
    required Uint8List photo,
    String caption = '',
    int group = -1,
    List<String> avoid = const [],
  }) async {
    final generation = ref.read(appDatabaseProvider).writingGeneration;
    try {
      if (state.job != null ||
          _working ||
          !_foreground ||
          ref.read(voiceActiveProvider)) {
        throw StateError(
          'Another AI session is open. Finish it before asking about photos.',
        );
      }
      if (ref.read(companionControllerProvider).phase !=
          CompanionPhase.connected) {
        throw const CompanionFailure(
          'UNSUPPORTED',
          'Photo questions need your computer. Connect it in Grand Maestar.',
        );
      }
      _checkCapability(AiOperation.photoQuestions);
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
      final model =
          (ref.read(companionControllerProvider).status?['capabilities']
                          as List? ??
                      [])
                  .whereType<Map>()
                  .where((c) => c['id'] == 'vision')
                  .firstOrNull?['model']
              as String? ??
          '';
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
        state = AiJobState(
          job: state.job,
          loaded: state.loaded,
          message: _message(e),
        );
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

  Future<bool> _conversationCurrent(String raw) async {
    final source = jsonDecode(raw) as Map;
    final entry =
        (await ref
                .read(diaryRepositoryProvider)
                .openDocument(source['id'] as String))
            .entry;
    if (source['new'] == true && entry == null) return true;
    return entry != null &&
        entry.deletedAt == null &&
        entry.revision == source['revision'] &&
        jsonEncode(entry.conversation?.turns) == jsonEncode(source['turns']);
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

  Future<void> retry() async {
    final job = state.job;
    if (job == null || _working || !_foreground) return;
    if (job.provider == 'companion' && !job.terminal) {
      final epoch = ++_epoch;
      _working = true;
      try {
        await _companion(
          job,
          epoch,
          submit: !job.accepted && job.prompt.isNotEmpty,
        );
      } catch (error) {
        if (_alive(epoch)) {
          state = AiJobState(
            job: state.job,
            loaded: true,
            message: _message(error),
          );
        }
      } finally {
        _working = false;
      }
    } else if (job.prompt.isNotEmpty) {
      await clear();
      if (ref.mounted && state.job == null) {
        await start(job.operation, job.key, job.prompt, job.source);
      }
    }
  }

  Future<void> cancel() async {
    final job = state.job;
    final epoch = ++_epoch;
    _abortProvider();
    if (job == null || !_alive(epoch)) return;
    var next = job.copy(cancelWanted: true);
    await _save(next, epoch);
    if (job.provider == 'companion' && !job.terminal) {
      try {
        await CompanionClient(ref.read(companionTransportProvider))
            .authenticated(
              _computer(job),
              'POST',
              '/v1/jobs/${job.id}/cancel',
              body: {'operation': job.operation.wireName},
            );
        next = next.copy(phase: 'cancelled', ackPending: true);
      } catch (error) {
        if (_alive(epoch)) {
          state = AiJobState(job: next, loaded: true, message: _message(error));
        }
        return;
      }
    } else {
      next = next.copy(phase: job.terminal ? job.phase : 'cancelled');
    }
    await _save(next, epoch);
  }

  Future<void> clear() => _clear();

  Future<void> clearIfCurrent(String id) => _clear(expectedId: id);

  Future<void> _clear({String? expectedId}) async {
    var job = state.job;
    if (job == null || expectedId != null && job.id != expectedId) return;
    final targetId = job.id;
    final generation = _dataGeneration;
    if (!job.terminal) {
      await cancel();
      job = state.job;
    }
    if (!ref.mounted ||
        job == null ||
        !job.terminal ||
        job.id != targetId ||
        state.job?.id != targetId ||
        !_alive(_epoch)) {
      return;
    }
    final epoch = ++_epoch;
    await ref.read(aiJobStoreProvider).release(job, generation);
    if (!_alive(epoch) || state.job?.id != targetId) return;
    if (job.operation == AiOperation.photoQuestions) {
      try {
        await ref
            .read(diaryPhotoQuestionStoreProvider)
            .deleteUpload(jsonDecode(job.source)['upload'] as String);
      } catch (_) {
        /* Expiry cleanup retries. */
      }
    }
    if (ref.mounted) state = const AiJobState(loaded: true);
    await _ackReceipts();
  }

  Future<void> retryAcknowledgements() => _ackReceipts();

  Future<void> _ackReceipts() async {
    for (final job
        in await ref.read(aiJobStoreProvider).pendingAcknowledgements()) {
      if (!_foreground || !ref.mounted) return;
      try {
        await CompanionClient(ref.read(companionTransportProvider))
            .authenticated(_computer(job), 'POST', '/v1/jobs/${job.id}/ack');
        await ref.read(aiJobStoreProvider).acknowledge(job);
      } catch (_) {
        /* Try after the original computer reconnects. */
      }
    }
  }

  Future<void> stopForReset() async {
    _foreground = false;
    _epoch++;
    _abortProvider();
    if (ref.mounted) state = const AiJobState();
  }

  void foreground(bool value) {
    _foreground = value;
    if (!value) {
      ++_epoch;
      _abortProvider();
      if (ref.mounted) state = AiJobState(job: state.job, loaded: state.loaded);
    } else {
      unawaited(restore());
    }
  }

  String _message(Object error) => switch (error) {
    CompanionFailure() => error.message,
    AiProviderFailure() => error.message,
    FormatException() => error.message,
    DailyQuestionRejected() => error.message,
    RecallAnswerRejected() => error.message,
    ThoughtReflectionRejected() => error.message,
    _ => 'Could not finish the AI task. Your writing is safe. Unlock the phone and retry.',
  };
}
