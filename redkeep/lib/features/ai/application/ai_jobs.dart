import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../brain/application/brain_providers.dart';
import '../../brain/application/brain_executor.dart';
import '../../brain/domain/brain.dart';
import '../../companion/application/companion_controller.dart';
import '../../companion/data/companion_protocol.dart';
import '../../diary/domain/diary_ai_contract.dart';
import '../../diary/application/diary_ai_sources.dart';
import '../../diary/domain/civil_date.dart';
import '../../diary/domain/daily_question_contract.dart';
import '../../sync/application/sync_providers.dart'
    show writingSessionEpochProvider;
import '../data/ai_job_store.dart';
import '../domain/ai_job.dart';
import '../domain/ai_operation.dart';
import 'ai_preferences.dart';

final protectedAiTasksProvider = Provider<ProtectedAiTasks>(
  (ref) => SecureAiTasks(),
);
final aiJobStoreProvider = Provider<AiJobStore>(
  (ref) => AiJobStore(
    ref.watch(appDatabaseProvider),
    ref.watch(protectedAiTasksProvider),
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

AiMode chooseAiDestination({
  required AiMode mode,
  required bool connected,
  required bool deviceReady,
}) {
  if (mode == AiMode.companion || mode == AiMode.auto && connected) {
    if (!connected) {
      throw const CompanionFailure(
        'UNAVAILABLE',
        'Connect your trusted computer in Grand Maestar.',
      );
    }
    return AiMode.companion;
  }
  if (!deviceReady) {
    throw const CompanionFailure(
      'NOT_READY',
      'Download and assign a compatible phone model in Grand Maestar.',
    );
  }
  return AiMode.device;
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
  BrainExecutor? _executor;
  final _owner = Object();
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
      unawaited(_executor?.cancel(owner: _owner));
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
        job = job.copy(phase: 'expired');
      }
      if (job?.provider == 'device' && !job!.terminal) {
        job = job.copy(phase: 'interrupted');
      }
      state = AiJobState(job: job, loaded: true);
      if (job != null) {
        await _save(job, epoch);
        if (job.provider == 'companion' && (!job.terminal || job.ackPending)) {
          await _remote(job, epoch, submit: false);
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
      final prefs = await ref.read(aiPreferencesRepositoryProvider).read();
      final connection = ref.read(companionControllerProvider);
      final mode = prefs.modeFor(operation);
      if (mode == AiMode.companion ||
          mode == AiMode.auto && connection.phase == CompanionPhase.connected) {
        if (connection.phase != CompanionPhase.connected) return false;
        _checkCapability(operation);
        return true;
      }
      return await phoneModel(operation) != null;
    } catch (_) {
      return false;
    }
  }

  Future<BrainModel?> phoneModel(AiOperation operation) async {
    final assignments = await ref.read(brainAssignmentsProvider).read();
    final id = assignments
        .where((a) => a.capability == operation.capability)
        .firstOrNull
        ?.modelId;
    final model = ref
        .read(brainCatalogProvider)
        .where(
          (m) => m.id == id && m.capabilities.contains(operation.capability),
        )
        .firstOrNull;
    if (model == null) return null;
    final files = await ref.read(brainModelFilesProvider.future);
    return await files.inspect(model) == ModelFileState.available
        ? model
        : null;
  }

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
        .where((c) => c['id'] == 'text')
        .firstOrNull;
    if (status?['recovery'] != 1 ||
        capability?[operation.contractKey] != 1 ||
        capability?['operations'] is! List ||
        !(capability!['operations'] as List).contains(operation.wireName)) {
      throw const CompanionFailure(
        'INCOMPATIBLE_VERSION',
        'Update the companion to support this diary operation.',
      );
    }
    if (capability['implemented'] != true ||
        !['ready', 'busy'].contains(capability['status'])) {
      throw const CompanionFailure(
        'NOT_READY',
        'Load a writing model on your computer.',
      );
    }
  }

  Future<void> start(
    AiOperation operation,
    String key,
    String prompt,
    String source,
  ) async {
    if (_working || !_foreground) return;
    await restore();
    if (!ref.mounted || !state.loaded || state.job != null || _working) return;
    final epoch = ++_epoch;
    _working = true;
    state = const AiJobState(busy: true, loaded: true);
    try {
      if (prompt.trim().isEmpty ||
          utf8.encode(prompt).length > 2000 ||
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
      final mode = preferences.modeFor(operation);
      final phone =
          mode == AiMode.companion ||
              mode == AiMode.auto &&
                  connection.phase == CompanionPhase.connected
          ? null
          : await phoneModel(operation);
      if (!_alive(epoch)) return;
      final target = chooseAiDestination(
        mode: mode,
        connected: connection.phase == CompanionPhase.connected,
        deviceReady: phone != null,
      );
      if (target == AiMode.companion) _checkCapability(operation);
      final job = AiJob(
        id: ref.read(aiIdProvider)(),
        operation: operation,
        key: key,
        created: ref.read(aiClockProvider)().millisecondsSinceEpoch,
        provider: target.name,
        computerId: target == AiMode.companion ? connection.selected!.id : '',
        deviceId: target == AiMode.companion
            ? connection.selected!.deviceId
            : '',
        modelId: phone?.id ?? '',
        prompt: prompt,
        source: source,
      );
      final reader = ref.read(diaryAiSourcesProvider);
      final valid = operation == AiOperation.diaryDetails
          ? await reader.current(DiarySuggestionSource.decode(source))
          : CivilDate.fromComponents(ref.read(aiClockProvider)()).key == key &&
                await reader.questionCurrent(
                  DailyQuestionSource.decode(source),
                );
      if (!valid) {
        throw const FormatException(
          'Your entries changed. Nothing was sent; ask again.',
        );
      }
      await _save(job, epoch);
      if (!_alive(epoch)) return;
      if (target == AiMode.companion) {
        await _remote(job, epoch, submit: true);
      } else {
        await _local(job, phone!, epoch);
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
      case AiOperation.diaryDetails:
        DiarySuggestions.parse(text, DiarySuggestionSource.decode(job.source));
      case AiOperation.dailyQuestion:
        DailyQuestion.parse(text, DailyQuestionSource.decode(job.source));
    }
  }

  Future<void> _local(AiJob job, BrainModel model, int epoch) async {
    final executor = await ref.read(brainExecutorProvider.future);
    if (!_alive(epoch)) return;
    _executor = executor;
    final buffer = StringBuffer();
    await executor.execute(
      model: model,
      capability: job.operation.capability,
      text: job.prompt,
      preparedPrompt: job.prompt,
      owner: _owner,
      settings: job.operation.phoneSettings(),
      onChunk: (chunk) {
        if (_alive(epoch)) buffer.write(chunk);
      },
    );
    if (!_alive(epoch)) return;
    final text = buffer.toString();
    _validate(job, text);
    await _save(job.copy(phase: 'completed', text: text), epoch);
  }

  Future<void> _remote(AiJob job, int epoch, {required bool submit}) async {
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
      submit ? '/v1/jobs' : '/v1/jobs/${job.id}',
      body: submit
          ? {
              'id': job.id,
              'operation': job.operation.wireName,
              'prompt': job.prompt,
              'expires': job.expires,
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
      var next = job.copy(accepted: true, phase: phase);
      if (phase == 'completed') {
        final text = response['text'];
        if (text is! String) {
          throw const FormatException(
            'The result is no longer on the computer. Clear this task and ask again.',
          );
        }
        _validate(job, text);
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

  Future<void> retry() async {
    final job = state.job;
    if (job == null || _working || !_foreground) return;
    if (job.provider == 'companion' && !job.terminal) {
      final epoch = ++_epoch;
      _working = true;
      try {
        await _remote(
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
    await _executor?.cancel(owner: _owner);
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

  Future<void> clear() async {
    var job = state.job;
    if (job == null) return;
    if (!job.terminal) {
      await cancel();
      job = state.job;
    }
    if (!ref.mounted || job == null || !job.terminal) return;
    ++_epoch;
    await ref.read(aiJobStoreProvider).release(job);
    if (ref.mounted) state = const AiJobState(loaded: true);
    await _ackReceipts();
  }

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
    await _executor?.cancel(owner: _owner);
    if (ref.mounted) state = const AiJobState();
  }

  void foreground(bool value) {
    _foreground = value;
    if (!value) {
      ++_epoch;
      unawaited(_executor?.cancel(owner: _owner));
      if (ref.mounted) state = AiJobState(job: state.job, loaded: state.loaded);
    } else {
      unawaited(restore());
    }
  }

  String _message(Object error) => switch (error) {
    CompanionFailure() => error.message,
    BrainException() => error.message,
    FormatException() => error.message,
    DailyQuestionRejected() => error.message,
    _ => 'Could not finish the AI task. Your writing is safe. Unlock the phone and retry.',
  };
}
