import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/voice/application/voice_coordination.dart';
import 'package:redkeep/features/voice/presentation/diary_conversation_page.dart';

import 'voice_migration_test.dart' show MemoryVoice;

class ReviewJobs extends AiJobs {
  ReviewJobs(this.initial);
  final AiJob initial;
  int starts = 0, clears = 0;
  @override
  AiJobState build() => AiJobState(job: initial, loaded: true);
  @override
  Future<void> restore() async {}
  @override
  Future<void> clear() async {
    clears++;
    state = const AiJobState(loaded: true);
  }

  @override
  Future<void> start(
    AiOperation operation,
    String key,
    String prompt,
    String source, {
    Object? voiceOwner,
  }) async {
    starts++;
    state = AiJobState(
      loaded: true,
      job: AiJob(
        id: 'retry-draft-11111111',
        operation: operation,
        key: key,
        created: DateTime.now().millisecondsSinceEpoch,
        provider: 'companion',
        source: source,
        text: 'I enjoyed walking home.',
        phase: 'completed',
      ),
    );
  }
}

void main() {
  for (final recovered in [true, false]) {
    testWidgets(
      recovered
          ? 'saved review applies recovered secondary draft at its verified first revision'
          : 'saved review explicitly retries its own failed task',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final date = CivilDate(2026, 11, 4);
        final repo = DriftDiaryRepository(
          db,
          clock: () => DateTime(2026, 11, 4),
        );
        final entry = await repo.saveConversation(
          id: 'a' * 32,
          date: date,
          conversation: DiaryAiConversation(
            turns: const [
              {'speaker': 'user', 'text': 'I enjoyed walking home.'},
            ],
            createdAt: DateTime.utc(2026, 11, 4),
          ),
          expectedRevision: 0,
        );
        final jobs = ReviewJobs(
          AiJob(
            id: 'original-draft-11111111',
            operation: AiOperation.conversation,
            key: entry.id,
            created: DateTime.now().millisecondsSinceEpoch,
            provider: 'companion',
            phase: recovered ? 'completed' : 'failed',
            text: recovered ? 'I enjoyed walking home.' : null,
            source: jsonEncode({
              'id': entry.id,
              'date': date.key,
              'revision': recovered ? 0 : entry.revision,
              'new': recovered,
              'turns': entry.conversation!.turns,
            }),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              diaryRepositoryProvider.overrideWithValue(repo),
              voiceStoreProvider.overrideWithValue(MemoryVoice()),
              syncEnabledProvider.overrideWithValue(false),
              aiJobsProvider.overrideWith(() => jobs),
            ],
            child: MaterialApp(
              home: DiaryConversationPage(address: (date: date, id: entry.id)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Generate draft'));
        await tester.tap(find.text('Generate draft'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('conversation-draft')),
              )
              .controller!
              .text,
          'I enjoyed walking home.',
        );
        expect(jobs.starts, recovered ? 0 : 1);
        expect(jobs.clears, recovered ? 1 : 2);
        await tester.ensureVisible(find.text('Update entry'));
        await tester.tap(find.text('Update entry'));
        await tester.pumpAndSettle();
        expect(
          (await repo.openDocument(entry.id)).entry!.text.body,
          'I enjoyed walking home.',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
