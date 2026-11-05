import '../../companion/application/companion_controller.dart';
import '../../companion/data/companion_protocol.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../../core/storage/app_database.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_operation.dart';
import '../../diary/application/diary_ai_sources.dart';
import '../../diary/application/diary_providers.dart';
import '../../diary/domain/diary_period.dart';
import '../../diary/domain/diary_ai_conversation.dart';
import '../../diary/domain/diary_repository.dart';
import '../../sync/data/drift_sync_store.dart';
import '../data/voice_store.dart';
import 'diary_conversation.dart';
import 'voice_coordination.dart';

final diaryVoiceSessionProvider = Provider.autoDispose
    .family<DiaryVoiceSession, DiaryPeriod>((ref, date) {
      final session = DiaryVoiceSession(ref, date);
      return session;
    });

class DiaryVoiceSession {
  DiaryVoiceSession(this.ref, this.date)
    : db = ref.read(appDatabaseProvider),
      repository = ref.read(diaryRepositoryProvider) {
    _generation = db.writingGeneration;
    conversation = DiaryConversation(
      computer: () => ref.read(voiceComputerProvider)(conversation: true),
      dateString: date.key,
      diary: () => recent,
      writeDraft: _draft,
      saveTurns: _protect,
    );
  }
  final Ref ref;
  final DiaryPeriod date;
  final AppDatabase db;
  late final int _generation;
  final DiaryRepository repository;
  late final VoiceStore store = ref.read(voiceStoreProvider);
  late final DiaryConversation conversation;
  bool primary = true;
  bool closed = false;
  Object? voiceOwner;
  int revision = 0;
  Future<void> _writes = Future.value();
  List<Map<String, Object>> recent = [];
  Future<void> initialize() async {
    final role = await DriftSyncKeyValueStore(db).read('role');
    final identity = await DriftSyncKeyValueStore(db).read('deviceId');
    primary =
        role == null ||
        identity == null ||
        (jsonDecode(role) as Map)['device_id'] == identity;
    final source = await ref.read(diaryAiSourcesProvider).question(date, []);
    recent = [
      for (final e in [...source.today, ...source.prior])
        {'daysAgo': source.ago(e), 'text': e.text},
    ];
    final retained = await store.load('diary');
    if (retained != null) {
      final oldDate = DiaryPeriod.tryParse(retained['date'] as String? ?? '');
      final record = DiaryAiConversation.tryParse(retained['conversation']);
      if (oldDate != null && record?.hasUserTurn == true) {
        final existing = (await repository.openDocument(
          retained['id'] as String,
        )).entry;
        if (existing == null || existing.revision == retained['revision']) {
          await repository.saveConversation(
            id: retained['id'] as String,
            date: oldDate,
            conversation: record!,
            expectedRevision: existing?.revision ?? 0,
          );
          await store.clear('diary');
        } else if (jsonEncode(existing.conversation?.turns) ==
            jsonEncode(record!.turns)) {
          await store.clear('diary');
        } else {
          throw StateError(
            'A retained conversation changed elsewhere. Open its diary entry before starting another conversation.',
          );
        }
      } else {
        await store.clear('diary');
      }
    }
  }

  DiaryAiConversation get record => DiaryAiConversation(
    turns: [for (final t in conversation.turns) Map.of(t)],
    createdAt: DateTime.fromMillisecondsSinceEpoch(conversation.created),
  );
  Future<void> _protect() {
    if (!record.hasUserTurn) return Future.value();
    if (db.writingBlocked || db.writingGeneration != _generation) {
      return Future.error(StateError('Voice session expired'));
    }
    return store.save('diary', {
      'id': conversation.id,
      'date': date.key,
      'created': conversation.created,
      'revision': revision,
      'conversation': record.toJson(),
    });
  }

  Future<bool> commit({String? content, bool closing = false}) {
    final snapshot = record;
    if (!snapshot.hasUserTurn || !primary && content == null && !closing) {
      return Future.value(false);
    }
    final completer = Completer<bool>();
    _writes = _writes
        .then((_) async {
          try {
            final existing = (await repository.openDocument(conversation.id))
                .entry;
            if (existing?.deletedAt != null) throw StateError('Entry deleted');
            if (existing != null &&
                existing.revision == revision &&
                jsonEncode(existing.conversation?.turns) ==
                    jsonEncode(snapshot.turns) &&
                (content == null || existing.text.body == content)) {
              if (content != null) {
                await store.clear('diary-review-${conversation.id}');
              }
              completer.complete(true);
              return;
            }
            final saved = await repository.saveConversation(
              id: conversation.id,
              date: date,
              conversation: content == null
                  ? snapshot
                  : snapshot.copyWith(draftedAt: DateTime.now()),
              expectedRevision: revision,
              body: content,
            );
            revision = saved.revision;
            if (content != null) {
              await store.clear('diary-review-${conversation.id}');
            }
            if (jsonEncode(conversation.turns) == jsonEncode(snapshot.turns)) {
              await store.clear('diary');
            }
            completer.complete(true);
          } catch (_) {
            await _protect();
            completer.complete(false);
          }
        })
        .catchError((Object _) {
          if (!completer.isCompleted) completer.complete(false);
        });
    return completer.future;
  }

  Future<String> _draft() async {
    await _writes;
    if (primary && !await commit()) {
      throw StateError('Conversation could not be saved');
    }
    final jobs = ref.read(aiJobsProvider.notifier);
    await jobs.restore();
    var job = ref.read(aiJobsProvider).job;
    if (job != null &&
        (job.operation != AiOperation.conversation ||
            job.key != conversation.id)) {
      throw StateError(
        'Another AI task is waiting. Finish or clear it in Grand Maestar.',
      );
    }
    if (job != null && job.terminal && job.phase != 'completed') {
      await jobs.clear();
      job = null;
    }
    if (job == null) {
      if (closed || !ref.mounted) {
        throw StateError(
          'The conversation is kept. Open its saved entry to generate a draft.',
        );
      }
      final original = conversation.computerId;
      final selected = ref.read(companionControllerProvider).selected;
      if (original != null &&
          (selected?.id != original ||
              selected?.deviceId != conversation.deviceId)) {
        throw const CompanionFailure(
          'ORIGINAL_COMPUTER',
          'Reconnect the computer that started this conversation before finishing.',
        );
      }
      // A secondary device has not appended yet. Its protected turns are the
      // authority for this one creation and are checked by the caller.
      final source = jsonEncode({
        'id': conversation.id,
        'date': date.key,
        'revision': revision,
        'turns': conversation.turns,
        'new': !primary,
      });
      await jobs.start(
        AiOperation.conversation,
        conversation.id,
        jsonEncode({'action': 'draft', 'turns': conversation.turns}),
        source,
        voiceOwner: voiceOwner,
      );
    } else if (!job.terminal) {
      await jobs.retry();
    }
    job = ref.read(aiJobsProvider).job;
    if (job?.phase != 'completed' || job?.text == null) {
      throw StateError(ref.read(aiJobsProvider).message ?? 'Draft unavailable');
    }
    final text = job!.text!;
    final source = jsonDecode(job.source) as Map<String, dynamic>;
    if (source['id'] != conversation.id ||
        source['date'] != date.key ||
        source['revision'] != revision ||
        jsonEncode(source['turns']) != jsonEncode(conversation.turns)) {
      throw StateError(
        'The conversation changed after this draft was requested. Your turns are kept.',
      );
    }
    // Keep generated words before acknowledging the accepted task. A save
    // conflict or app exit can then reopen them in the saved review screen.
    await store.save('diary-review-${conversation.id}', {
      'id': conversation.id,
      'created': DateTime.now().millisecondsSinceEpoch,
      'revision': revision,
      'source': source,
      'draft': text,
    });
    await jobs.clear();
    return text;
  }

  Future<void> get settled => _writes;
}
