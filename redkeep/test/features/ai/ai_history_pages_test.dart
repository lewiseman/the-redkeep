import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/data/ai_job_store.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';

import '../../support/fake_ai.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;
  late MemoryAiTasks tasks;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tasks = MemoryAiTasks();
  });
  tearDown(() => db.close());
  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).hitTestable().last,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'unified history shows every operation and cleared receipt detail contains no result',
    (tester) async {
      final store = AiJobStore(db, tasks);
      var i = 0;
      for (final operation in AiOperation.values) {
        final job = AiJob(
          id: 'history-task-${++i}',
          operation: operation,
          key: 'source',
          created: DateTime.now().millisecondsSinceEpoch + i,
          provider: 'device',
          phase: 'completed',
          text: 'Private generated writing',
        );
        await store.save(job, 0);
        await store.release(job, 0);
      }
      final router = await pumpApp(
        tester,
        initialLocation: '/settings/brain/history',
        database: db,
        tasks: tasks,
      );
      try {
        for (final label in [
          'Flow question',
          'Flow reflection',
          'Ask your past',
          'Photo questions',
          'Diary conversation',
          'Note summary',
        ]) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('$label · Completed'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('$label · Completed'), findsOneWidget);
        }
        await tester.scrollUntilVisible(
          find.text('Flow question · Completed'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tap(tester, find.text('Flow question · Completed'));
        expect(
          router.state.uri.path,
          startsWith('/settings/brain/history/history-task-'),
        );
        expect(
          find.textContaining('preview is no longer retained'),
          findsOneWidget,
        );
        expect(find.text('Private generated writing'), findsNothing);
        expect(find.text('Retry task'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'expired current preview is redacted and history never restarts it',
    (tester) async {
      final job = AiJob(
        id: 'expired-question',
        operation: AiOperation.thoughtQuestion,
        key: 'thought-search',
        created: DateTime.now()
            .subtract(const Duration(hours: 25))
            .millisecondsSinceEpoch,
        provider: 'device',
        prompt: 'Private prompt',
        source: 'Private excerpts',
        phase: 'completed',
        text: 'Private result',
      );
      tasks.value = jsonEncode(job.json());
      await pumpApp(
        tester,
        initialLocation: '/settings/brain/history/expired-question',
        database: db,
        tasks: tasks,
      );
      try {
        expect(find.text('This task’s preview has expired.'), findsOneWidget);
        expect(find.text('Private result'), findsNothing);
        expect(find.text('Retry task'), findsNothing);
        final protected = jsonDecode(tasks.value!) as Map;
        expect(protected['prompt'], '');
        expect(protected['source'], '');
        expect(protected['text'], isNull);
        await tap(tester, find.text('Clear task'));
        expect(tasks.value, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'Grand Maestar and the Notes toolbox open the shared history route',
    (tester) async {
      final notes = DriftNotesRepository(db, clock: DateTime.now);
      await notes.saveNote(
        id: 'a' * 32,
        text: const PlainTextDocument(body: 'A saved note'),
        expectedRevision: 0,
        details: const NoteDetails(),
      );
      final router = await pumpApp(
        tester,
        initialLocation: '/settings/brain',
        database: db,
        notes: notes,
        tasks: tasks,
      );
      try {
        await tap(tester, find.text('AI task history'));
        expect(router.state.uri.path, '/settings/brain/history');
        router.go('/notes/${'a' * 32}');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('AI tools'));
        await tester.pumpAndSettle();
        await tap(tester, find.text('AI task history'));
        expect(router.state.uri.path, '/settings/brain/history');
        expect(
          find.byKey(const ValueKey('note-assistant-actions')),
          findsNothing,
        );
        expect(find.text('No AI tasks yet.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }
    },
  );
}
