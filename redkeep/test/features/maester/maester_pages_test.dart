import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';

import '../../support/fake_brain.dart';
import '../../support/pump_app.dart';

const id = '11111111111111111111111111111111';
const missingId = '22222222222222222222222222222222';
const writing = 'Existing writing stays on this device.';

void main() {
  testWidgets('writing pages have no floating AI controls and never load AI', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 11, 3);
    final date = DiaryPeriod(2026, 11, 3);
    final notes = DriftNotesRepository(db, clock: () => now);
    final diary = DriftDiaryRepository(db, clock: () => now);
    final flow = DriftFlowRepository(db, clock: () => now);
    final draft = await notes.putDraft(
      id: id,
      text: const PlainTextDocument(title: 'Existing note', body: writing),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    await notes.commitDraft(id, draft.draftRevision);
    await diary.save(
      id: id,
      date: date,
      text: const DiaryText(body: writing),
      expectedRevision: 0,
    );
    await flow.save(id: id, body: writing, expectedRevision: 0);
    final files = FakeBrainFiles();
    final assignments = FakeBrainAssignments();
    for (final capability in BrainCapability.values) {
      assignments.values[capability] = qualifiedBrainModel.id;
    }
    var modelLoads = 0;
    try {
      final router = await pumpApp(
        tester,
        initialLocation: '/flow',
        notes: notes,
        diary: diary,
        flow: flow,
        brainAssignments: assignments,
        brainFiles: files,
        brainLoader: (_, _) async {
          modelLoads++;
          throw StateError('Writing pages must not load AI.');
        },
      );
      for (final location in [
        '/flow',
        thoughtLocation(id),
        thoughtLocation(id, edit: true),
        '/notes',
        noteLocation(id),
        noteLocation(id, edit: true),
        '/diary',
        diaryEntryLocation(date, id),
        diaryEntryLocation(date, id, edit: true),
        '/more',
        thoughtLocation(missingId),
        noteLocation(missingId),
        diaryEntryLocation(date, missingId),
      ]) {
        final checksBefore = files.checks;
        router.go(location);
        await tester.pumpAndSettle();
        if (location == '/more') {
          expect(files.checks, greaterThan(checksBefore));
        } else {
          // Writing does not inspect models; only More reads local readiness.
          expect(files.checks, checksBefore);
        }
        expect(router.routeInformationProvider.value.uri.path, location);
        expect(
          find.byType(FloatingActionButton, skipOffstage: false),
          findsNothing,
          reason: location,
        );
        expect(
          find.byTooltip('Grand Maester', skipOffstage: false),
          findsNothing,
          reason: location,
        );
        expect(tester.takeException(), isNull, reason: location);
      }
      expect(files.installs, 0);
      expect(modelLoads, 0);
      expect((await notes.openDocument(id)).note!.text.body, writing);
      expect((await diary.openDocument(id)).entry!.text.body, writing);
      expect((await flow.openDocument(id)).thought!.body, writing);
      expect((await notes.openDocument(id)).note!.revision, 1);
      expect((await diary.openDocument(id)).entry!.revision, 1);
      expect((await flow.openDocument(id)).thought!.revision, 1);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
