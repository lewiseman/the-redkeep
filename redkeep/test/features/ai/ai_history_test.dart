import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/data/ai_job_store.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';

import '../../support/fake_ai.dart';

void main() {
  late AppDatabase db;
  late AiJobStore store;
  late MemoryAiTasks protected;
  final now = DateTime(2026, 11, 5, 12);
  AiJob job(AiOperation operation, int index, {int? created}) => AiJob(
    id: 'history-task-$index',
    operation: operation,
    key: 'source-$index',
    created: created ?? now.millisecondsSinceEpoch + index,
    provider: index.isEven ? 'device' : 'companion',
    phase: 'completed',
    prompt: 'Private prompt $index',
    source: 'Private source $index',
    text: 'Private result $index',
    ackPending: index.isOdd,
  );
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    protected = MemoryAiTasks();
    store = AiJobStore(db, protected, clock: () => now);
  });
  tearDown(() => db.close());

  test('history includes all operations, sorts explicitly, and contains status metadata only', () async {
    var index = 0;
    for (final operation in AiOperation.values) {
      final value = job(operation, ++index);
      await store.save(value, 0);
      await store.release(value, 0);
    }
    final history = await store.watchHistory().first;
    expect(history.map((j) => j.operation), AiOperation.values.reversed);
    for (final value in history) {
      expect(value.prompt, isEmpty);
      expect(value.source, isEmpty);
      expect(value.text, isNull);
    }
    final metadata = (await db.select(db.aiJobReceipts).get())
        .map((r) => r.metadata)
        .join();
    expect(metadata, isNot(contains('Private')));
    expect(protected.value, isNull);
    expect(await store.pendingAcknowledgements(), isNotEmpty);
    for (final value in await store.pendingAcknowledgements()) {
      await store.acknowledge(value);
    }
    expect(await store.pendingAcknowledgements(), isEmpty);
  });

  test('seven-day history excludes old and malformed receipts and strips any leaked legacy fields', () async {
    final old = job(
      AiOperation.thoughtQuestion,
      1,
      created: now.subtract(const Duration(days: 8)).millisecondsSinceEpoch,
    );
    final current = job(AiOperation.diaryDetails, 2);
    await db
        .into(db.aiJobReceipts)
        .insert(
          AiJobReceiptsCompanion.insert(
            id: old.id,
            metadata: jsonEncode(old.json()),
            created: old.created,
          ),
        );
    await db
        .into(db.aiJobReceipts)
        .insert(
          AiJobReceiptsCompanion.insert(
            id: 'malformed-task',
            metadata: '{broken',
            created: current.created,
          ),
        );
    await db
        .into(db.aiJobReceipts)
        .insert(
          AiJobReceiptsCompanion.insert(
            id: current.id,
            metadata: jsonEncode(current.json()),
            created: current.created,
          ),
        );
    final history = await store.watchHistory().first;
    expect(history, hasLength(1));
    expect(history.single.operation, AiOperation.diaryDetails);
    expect(history.single.text, isNull);
    expect(history.single.prompt, isEmpty);
    expect(history.single.source, isEmpty);
  });

  test('releasing an old task cannot erase a newer protected snapshot; reset fences release', () async {
    final first = job(AiOperation.thoughtReflection, 1),
        second = job(AiOperation.thoughtQuestion, 2);
    await store.save(first, 0);
    await store.save(second, 0);
    await store.release(first, 0);
    expect((await store.load())!.id, second.id);
    db.writingGeneration++;
    await expectLater(store.release(second, 0), throwsStateError);
    expect((await store.load())!.id, second.id);
    await store.clear();
    expect(await store.watchHistory().first, isEmpty);
    expect(await store.load(), isNull);
  });
}
