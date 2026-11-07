import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/presentation/ai_settings_page.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/recall/application/recall_coverage.dart';
import 'package:redkeep/features/recall/presentation/recall_library_page.dart';

import '../../support/fake_ai_provider.dart';
import '../../support/pump_app.dart';

void main() {
  test(
    'coverage counts saved writing and what still waits in the queue',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(recallCoverageProvider, (_, _) {});
      addTearDown(subscription.close);

      var coverage = await container.read(recallCoverageProvider.future);
      expect(coverage['note']!.saved, 0);
      expect(coverage['note']!.fraction, 1);

      final notes = DriftNotesRepository(
        db,
        clock: () => DateTime.utc(2026, 11, 4),
      );
      for (final id in ['a' * 32, 'b' * 32]) {
        await notes.saveNote(
          id: id,
          text: const PlainTextDocument(title: 'Garden', body: 'Roses'),
          expectedRevision: 0,
          details: const NoteDetails(),
        );
      }
      await pumpEventQueue();
      coverage = container.read(recallCoverageProvider).value!;
      expect((coverage['note']!.saved, coverage['note']!.waiting), (2, 2));
      expect(coverage['note']!.indexed, 0);

      await (db.delete(
        db.recallQueue,
      )..where((q) => q.sourceId.equals('a' * 32))).go();
      await pumpEventQueue();
      coverage = container.read(recallCoverageProvider).value!;
      expect(coverage['note']!.indexed, 1);
      expect(coverage['note']!.fraction, .5);
      expect(coverage['diary']!.saved, 0);
    },
  );

  testWidgets('Grand Maestar opens the Library and comes back', (tester) async {
    final aiProvider = FakeAiProviderClient();
    final router = await pumpApp(
      tester,
      initialLocation: '/settings/brain',
      aiProvider: aiProvider,
    );
    expect(find.byType(AiSettingsPage), findsOneWidget);
    expect(find.text('Everything is saved'), findsOneWidget);
    final door = find.byKey(const ValueKey('maestar-library-door'));
    await tester.ensureVisible(door);
    await tester.pumpAndSettle();
    await tester.tap(door);
    await tester.pumpAndSettle();
    expect(find.byType(RecallLibraryPage), findsOneWidget);
    expect(find.text('Up to date'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(AiSettingsPage), findsOneWidget);
    expect(aiProvider.requests, isEmpty);
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  testWidgets('editing Grand Maestar marks unsaved changes until saved', (
    tester,
  ) async {
    await pumpApp(tester, initialLocation: '/settings/brain');
    final coin = find.byKey(const ValueKey('ai-limit-10'));
    await tester.ensureVisible(coin);
    await tester.pumpAndSettle();
    await tester.tap(coin);
    await tester.pump();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-provider-save')));
    await tester.pumpAndSettle();
    expect(find.text('Saved.'), findsOneWidget);
    expect(find.text('Unsaved changes'), findsNothing);
    await _finish(tester);
  });

  testWidgets(
    'a custom limit closes its dialog cleanly and shows on the coin',
    (tester) async {
      await pumpApp(tester, initialLocation: '/settings/brain');
      final other = find.byKey(const ValueKey('ai-limit-other'));
      await tester.ensureVisible(other);
      await tester.pumpAndSettle();
      await tester.tap(other);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai-monthly-limit')),
        '12',
      );
      await tester.tap(find.text('Use limit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Monthly limit'), findsNothing);
      expect(find.text('\$12'), findsOneWidget);
      expect(find.text('Unsaved changes'), findsOneWidget);
      await _finish(tester);
    },
  );

  testWidgets(
    'the Library turns a kind of writing off and asks before rebuilding',
    (tester) async {
      await pumpApp(tester, initialLocation: '/settings/brain/library');
      final diary = find.byKey(const ValueKey('recall-diary'));
      await tester.ensureVisible(diary);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(diary).value, isTrue);
      await tester.tap(diary);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(diary).value, isFalse);
      expect(find.text('Not in the index'), findsOneWidget);

      final rebuild = find.text('Rebuild search index');
      await tester.ensureVisible(rebuild);
      await tester.pumpAndSettle();
      await tester.tap(rebuild);
      await tester.pumpAndSettle();
      expect(find.text('Rebuild the search index?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Rebuild the search index?'), findsNothing);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    },
  );
}

/// Tear the tree down so drift's stream timers and recall timers flush.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}
