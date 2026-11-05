import '../../voice/application/voice_coordination.dart';
import '../../../core/storage/app_database.dart';

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/application/ai_preferences.dart';
import '../../ai/application/ai_lifecycle.dart';
import '../../ai/domain/ai_operation.dart';
import '../../companion/application/companion_controller.dart';
import '../../recall/domain/recall.dart' show recallHash;
import '../domain/diary_period.dart';
import '../domain/daily_question_contract.dart';
import 'diary_ai_sources.dart';
import 'diary_providers.dart';

final dailyQuestionProvider = NotifierProvider.autoDispose
    .family<DailyQuestionController, DailyQuestionView, DiaryPeriod>(
      DailyQuestionController.new,
    );

class DailyQuestionView {
  const DailyQuestionView({
    this.id,
    this.question,
    this.busy = false,
    this.message,
  });
  final String? id;
  final DailyQuestion? question;
  final bool busy;
  final String? message;
}

class DailyQuestionController extends Notifier<DailyQuestionView> {
  DailyQuestionController(this.date);
  final DiaryPeriod date;
  bool _active = false, _working = false, _consuming = false;
  int _epoch = 0;
  final _attempted = <String>{};
  Timer? _refresh;
  Completer<void>? _requestDone;
  bool get _enabled =>
      ref.read(aiPreferencesProvider).value?.dailyQuestions == true;
  bool get _today =>
      date.isDay && date.isCurrent(ref.read(diaryClockProvider)());
  bool get _canAuto =>
      _active &&
      _today &&
      _enabled &&
      ref.read(aiForegroundProvider) &&
      !ref.read(voiceActiveProvider);
  @override
  DailyQuestionView build() {
    final db = ref.read(appDatabaseProvider);
    final changes = db
        .tableUpdates(TableUpdateQuery.onAllTables([db.diaryEntries]))
        .listen((_) {
          _refresh?.cancel();
          _refresh = Timer(
            const Duration(milliseconds: 700),
            () => unawaited(refresh()),
          );
        });
    ref.listen(aiJobsProvider, (_, next) {
      if (_active) scheduleMicrotask(() => unawaited(_consume()));
    });
    ref.listen(companionControllerProvider, (_, _) {
      if (_canAuto) scheduleMicrotask(ensure);
    });
    ref.listen(voiceActiveProvider, (_, active) {
      if (!active && _canAuto) scheduleMicrotask(ensure);
    });
    ref.listen(aiForegroundProvider, (_, next) {
      if (next && _active) scheduleMicrotask(() => unawaited(refresh()));
    });
    ref.listen(aiPreferencesProvider, (_, next) {
      if (next.value?.dailyQuestions == false) {
        _epoch++;
        state = const DailyQuestionView();
      } else if (_active) {
        scheduleMicrotask(() => unawaited(refresh()));
      }
    });
    ref.onDispose(() {
      _epoch++;
      _refresh?.cancel();
      unawaited(changes.cancel());
    });
    return const DailyQuestionView();
  }

  void activate(bool value) {
    if (_active == value) return;
    _active = value;
    if (value) unawaited(refresh());
  }

  Future<List<String>> _recent() async {
    final db = ref.read(appDatabaseProvider);
    final rows =
        await (db.select(db.dailyQuestions)
              ..orderBy([(r) => OrderingTerm.desc(r.created)])
              ..limit(5))
            .get();
    return rows.map((r) => r.question).toList();
  }

  Future<void> refresh() async {
    if (!ref.mounted || !_active) return;
    final epoch = ++_epoch;
    if (!_enabled || !_today) {
      state = const DailyQuestionView();
      return;
    }
    try {
      final db = ref.read(appDatabaseProvider);
      final row =
          await (db.select(db.dailyQuestions)
                ..where((r) => r.day.equals(date.key) & r.shown.equals(true))
                ..orderBy([(r) => OrderingTerm.desc(r.created)])
                ..limit(1))
              .getSingleOrNull();
      final source = await ref.read(diaryAiSourcesProvider).day(date);
      final previous =
          await (db.select(db.dailyQuestions)
                ..where(
                  (r) =>
                      r.day.equals(date.key) &
                      r.basis.equals(source.fingerprint),
                )
                ..limit(30))
              .get();
      for (final cached in previous) {
        _attempted.add(
          dailyQuestionContextKey(
            cached.basis,
            jsonDecode(cached.sources) as List,
          ),
        );
      }
      var valid = row != null && row.basis == source.fingerprint;
      if (valid) {
        for (final source in jsonDecode(row.sources) as List) {
          final opened = await ref
              .read(diaryRepositoryProvider)
              .openDocument(source['id'] as String);
          if (!opened.available ||
              opened.entry!.revision != source['revision'] ||
              opened.entry!.date.key != source['date'] ||
              recallHash(entryQuestionText(opened.entry!)) != source['hash']) {
            valid = false;
            break;
          }
        }
      }
      if (valid && row != null && row.sourceId.isNotEmpty) {
        final opened = await ref
            .read(diaryRepositoryProvider)
            .openDocument(row.sourceId);
        valid =
            opened.available &&
            recallHash(entryQuestionText(opened.entry!)) == row.sourceHash;
      }
      if (!ref.mounted || epoch != _epoch) return;
      state = valid
          ? DailyQuestionView(
              id: row!.id,
              question: DailyQuestion(
                text: row.question,
                sourceDate: row.sourceDate.isEmpty ? null : row.sourceDate,
                sourceItem: row.sourceId.isEmpty ? null : row.sourceId,
                evidence: row.evidence,
                ago: row.ago,
              ),
            )
          : const DailyQuestionView();
      await _consume();
      if (ref.mounted && state.question == null) ensure();
    } catch (_) {
      if (ref.mounted && epoch == _epoch) {
        state = const DailyQuestionView(
          message: 'Your writing lines are ready. The daily question could not be loaded.',
        );
      }
    }
  }

  void ensure() {
    if (_canAuto && !_working && state.question == null) {
      unawaited(request(automatic: true));
    }
  }

  Future<void> request({bool automatic = false}) async {
    if (_working) {
      if (!automatic) {
        await _requestDone?.future;
        if (ref.mounted) await request();
      }
      return;
    }
    if (!_canAuto || ref.read(appDatabaseProvider).writingBlocked) {
      return;
    }
    _working = true;
    final done = Completer<void>();
    _requestDone = done;
    final epoch = _epoch;
    final previous = state;
    try {
      final jobs = ref.read(aiJobsProvider.notifier);
      final currentJob = ref.read(aiJobsProvider);
      if (currentJob.busy || currentJob.job != null) {
        final task = currentJob.job;
        if (!automatic &&
            !currentJob.busy &&
            task?.operation == AiOperation.dailyQuestion &&
            task?.key == date.key) {
          await jobs.retry();
        }
        await _consume();
        return;
      }
      final source = await ref
          .read(diaryAiSourcesProvider)
          .question(date, await _recent());
      if (!ref.mounted || !_canAuto || epoch != _epoch) return;
      if (automatic && _attempted.contains(source.contextKey)) return;
      // Opening a diary never sends its text to a provider without opt-in.
      if (automatic &&
          !(await ref.read(aiPreferencesRepositoryProvider).read())
              .dailyQuestionMayRunAutomatically) {
        return;
      }
      if (!await jobs.available(AiOperation.dailyQuestion)) {
        if (ref.mounted && !automatic) {
          state = const DailyQuestionView(
            message: 'Connect your computer or choose a provider in Grand Maestar to ask a question.',
          );
        }
        return;
      }
      if (!ref.mounted || !_canAuto || epoch != _epoch) return;
      _attempted.add(source.contextKey);
      state = DailyQuestionView(
        id: previous.id,
        question: previous.question,
        busy: true,
      );
      await jobs.start(
        AiOperation.dailyQuestion,
        date.key,
        source.request(),
        source.encode(),
      );
      if (!ref.mounted || !_canAuto) return;
      await _consume();
      if (state.busy) {
        state = DailyQuestionView(
          id: previous.id,
          question: previous.question,
          message:
              ref.read(aiJobsProvider).message ??
              'The question is waiting. You can keep writing.',
        );
      }
    } catch (_) {
      if (ref.mounted && epoch == _epoch) {
        state = DailyQuestionView(
          id: previous.id,
          question: previous.question,
          message: 'Could not ask a question just now. You can keep writing.',
        );
      }
    } finally {
      _working = false;
      _requestDone = null;
      done.complete();
    }
  }

  Future<void> _consume() async {
    if (!ref.mounted || !_active || _consuming) return;
    final task = ref.read(aiJobsProvider).job;
    if (task == null ||
        task.operation != AiOperation.dailyQuestion ||
        task.key != date.key ||
        !task.terminal) {
      return;
    }
    _consuming = true;
    try {
      if (!_enabled || !_today) {
        await ref.read(aiJobsProvider.notifier).clear();
        return;
      }
      if (task.phase == 'interrupted' && task.provider != 'companion') {
        state = const DailyQuestionView(
          message: 'Generating the question was interrupted. Tap Ask for a question to retry explicitly.',
        );
        return;
      }
      if (task.phase != 'completed' || task.text == null) {
        try {
          _attempted.add(DailyQuestionSource.decode(task.source).contextKey);
        } catch (_) {}
        state = DailyQuestionView(
          id: state.id,
          question: state.question,
          message: 'No new question was generated. Keep writing, or ask again.',
        );
        await ref.read(aiJobsProvider.notifier).clear();
        return;
      }
      final source = DailyQuestionSource.decode(task.source);
      _attempted.add(source.contextKey);
      if (!await ref.read(diaryAiSourcesProvider).questionCurrent(source)) {
        throw const DailyQuestionRejected(
          'Your entries changed while AI was thinking. Ask again for today.',
        );
      }
      final db = ref.read(appDatabaseProvider);
      final generation = db.writingGeneration;
      final existing = await (db.select(
        db.dailyQuestions,
      )..where((r) => r.id.equals(task.id))).getSingleOrNull();
      if (existing == null) {
        final question = DailyQuestion.parse(
          task.text!,
          source,
          history: await _recent(),
        );
        final entry = [
          ...source.today,
          ...source.prior,
        ].where((e) => e.uuid == question.sourceItem).firstOrNull;
        if (!ref.mounted ||
            !_enabled ||
            !_today ||
            db.writingBlocked ||
            generation != db.writingGeneration) {
          return;
        }
        await db.transaction(() async {
          if (db.writingBlocked || generation != db.writingGeneration) {
            throw StateError('Expired question');
          }
          await (db.update(db.dailyQuestions)
                ..where((r) => r.day.equals(date.key)))
              .write(const DailyQuestionsCompanion(shown: Value(false)));
          await db
              .into(db.dailyQuestions)
              .insert(
                DailyQuestionsCompanion.insert(
                  id: task.id,
                  day: date.key,
                  question: question.text,
                  basis: source.basis,
                  sources: Value(jsonEncode(source.references)),
                  created: task.created,
                  sourceDate: Value(question.sourceDate ?? ''),
                  sourceId: Value(question.sourceItem ?? ''),
                  sourceHash: Value(
                    entry == null ? '' : recallHash(entry.text),
                  ),
                  evidence: Value(question.evidence),
                  ago: Value(question.ago),
                ),
              );
          await db.customStatement(
            'DELETE FROM daily_questions WHERE created < ? OR id NOT IN (SELECT id FROM daily_questions ORDER BY created DESC LIMIT 30)',
            [
              ref
                  .read(diaryClockProvider)()
                  .subtract(const Duration(days: 30))
                  .millisecondsSinceEpoch,
            ],
          );
        });
        if (ref.mounted) {
          state = DailyQuestionView(id: task.id, question: question);
        }
      }
      await ref.read(aiJobsProvider.notifier).clear();
    } catch (error) {
      if (ref.mounted) {
        state = DailyQuestionView(
          id: state.id,
          question: state.question,
          message: error is DailyQuestionRejected
              ? error.message
              : 'The question did not pass its checks. You can ask again.',
        );
      }
      if (ref.mounted) await ref.read(aiJobsProvider.notifier).clear();
    } finally {
      _consuming = false;
    }
  }

  Future<void> skip() async {
    final id = state.id;
    if (id == null) return;
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.dailyQuestions)..where((r) => r.id.equals(id))).write(
      const DailyQuestionsCompanion(shown: Value(false)),
    );
    if (ref.mounted) state = const DailyQuestionView();
  }
}
