import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/notes/application/note_ai_controller.dart';
import 'package:redkeep/features/notes/application/note_ai_sources.dart';
import 'package:redkeep/features/notes/application/note_editor_controller.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/domain/note_help_contract.dart';
import 'package:redkeep/features/notes/domain/note_scan_contract.dart';
import 'package:redkeep/features/notes/domain/note_tag.dart';
import 'package:redkeep/features/notes/domain/website/website_render.dart';
import 'package:redkeep/features/sync/data/drift_sync_store.dart';

import '../../support/fake_ai.dart';
import '../../support/notes_ai_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NotesAiHarness h;
  setUp(() async {
    h = await NotesAiHarness.create();
    await h.save(
      details: const NoteDetails(
        tags: ['travel'],
        background: {'type': 'sage'},
      ),
    );
  });
  tearDown(() => h.close());
  NoteAiController actions() => h.scope.read(noteAiControllerProvider);
  AiJob job() => h.scope.read(aiJobsProvider).job!;

  for (final operation in AiOperation.values.where(
    (o) => o.isNote && o != AiOperation.noteBackground,
  )) {
    test(
      '${operation.wireName} rejects a malformed result without changing writing',
      () async {
        h.remote.output = '<script>untrusted output</script>';
        if (operation == AiOperation.noteIdeas) {
          await actions().ideas('', []);
        } else if (operation == AiOperation.noteQuestion) {
          await actions().search('tomatoes');
        } else if (operation == AiOperation.noteTemplate) {
          final id = 'c' * 32;
          h.scope.read(noteNewIdsProvider.notifier).add(id);
          final sub = h.scope.listen(noteEditorProvider(id), (_, _) {});
          addTearDown(sub.close);
          await h.scope.read(noteEditorProvider(id).future);
          await actions().start(operation, id, topic: 'Trip plan');
        } else if (operation.imageInput) {
          final path = await h.media.write(h.remote.generated);
          final attachment = NoteAttachment(path: path, type: 'image/png');
          await h.save(details: NoteDetails(attachments: [attachment]));
          await actions().start(operation, notesTestId, image: attachment);
        } else {
          await actions().start(
            operation,
            notesTestId,
            description: 'A garden plan',
          );
        }
        expect(job().phase, isNot('completed'));
        expect(
          (await h.repository.openDocument(notesTestId)).note!.text.body,
          notesTestBody,
        );
        expect(await h.repository.priorContent(notesTestId), isEmpty);
      },
    );
  }

  test(
    'summary only sends this note and leaves the full document untouched',
    () async {
      await h.save(id: 'b' * 32, body: 'Private unrelated note');
      await actions().start(AiOperation.noteSummary, notesTestId);
      expect(job().phase, 'completed');
      expect(h.remote.submissions.single['prompt'], contains(notesTestBody));
      expect(
        h.remote.submissions.single.toString(),
        isNot(contains('Private unrelated')),
      );
      expect(h.remote.submissions.single.containsKey('source'), isFalse);
      expect((await h.repository.openDocument(notesTestId)).note!.revision, 1);
      expect(
        (await h.repository.openDocument(notesTestId))
            .note!
            .details
            .background['type'],
        'sage',
      );
    },
  );

  for (final operation in [
    AiOperation.noteRewrite,
    AiOperation.noteExpand,
    AiOperation.noteTone,
    AiOperation.noteClarify,
    AiOperation.noteMarkdown,
  ]) {
    test(
      '${operation.wireName} reviews a selected passage and restores prior content',
      () async {
        h.remote.output = 'Grow tomatoes';
        await actions().start(
          operation,
          notesTestId,
          selectionStart: 0,
          selectionEnd: 14,
          intent: operation == AiOperation.noteTone
              ? 'Use a friendly tone.'
              : '',
        );
        expect(
          (jsonDecode(h.remote.submissions.single['prompt'] as String)
              as Map)['text'],
          'Plant tomatoes',
        );
        expect(
          (await h.repository.openDocument(notesTestId)).note!.text.body,
          notesTestBody,
        );
        final saved = (await actions().apply(job()))!;
        expect(saved.text.body, startsWith('Grow tomatoes in the raised bed.'));
        expect(saved.tags, ['travel']);
        expect(saved.details.background['type'], 'sage');
        final prior = (await h.repository.priorContent(notesTestId)).single;
        await h.repository.restorePriorContent(
          notesTestId,
          prior.id,
          saved.revision,
        );
        expect(
          (await h.repository.openDocument(notesTestId)).note!.text.body,
          notesTestBody,
        );
      },
    );
  }

  test(
    'accepting a reviewed result never clears a newer unrelated task',
    () async {
      await actions().start(AiOperation.noteRewrite, notesTestId);
      final reviewed = job();
      await h.scope.read(aiJobsProvider.notifier).clear();
      h.remote.output = '{"ideas":["A garden plan"]}';
      await actions().ideas('', []);
      final newer = job();
      await actions().apply(reviewed);
      expect(job().id, newer.id);
      expect(job().operation, AiOperation.noteIdeas);
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        reviewed.text,
      );
    },
  );

  test('metadata applies only selected fields, preserves manual tags, and supports undo', () async {
    h.remote.output = noteMetadataOutput;
    await actions().start(AiOperation.noteMetadata, notesTestId);
    final saved = (await actions().apply(
      job(),
      title: 'Raised bed plan',
      tags: ['🌱#Gardening'],
    ))!;
    expect(saved.text.title, 'Raised bed plan');
    expect(saved.text.body, notesTestBody);
    expect(saved.tags, containsAll(['travel', '🌱#Gardening']));
    final prior = (await h.repository.priorContent(notesTestId)).single;
    await h.repository.restorePriorContent(
      notesTestId,
      prior.id,
      saved.revision,
    );
    final undone = (await h.repository.openDocument(notesTestId)).note!;
    expect(undone.text.title, 'Garden');
    expect(undone.tags, ['travel']);
  });

  test('ideas disclose selected excerpts only and generate no writing automatically', () async {
    final n = (await h.repository.openDocument(notesTestId)).note!;
    h.remote.output = '{"ideas":["A plan for the raised bed"]}';
    await actions().ideas('Gardening', []);
    final generic =
        jsonDecode(h.remote.submissions.single['prompt'] as String) as Map;
    expect(generic['notes'], isEmpty);
    await h.scope.read(aiJobsProvider.notifier).clear();
    await actions().ideas('Gardening', [n]);
    expect(h.remote.submissions.last['prompt'], contains('Plant tomatoes'));
    expect((await h.repository.watchNotes().first).length, 1);
  });

  test('template result enters the new draft and survives recovery without committing', () async {
    final id = 'c' * 32;
    h.scope.read(noteNewIdsProvider.notifier).add(id);
    final sub = h.scope.listen(noteEditorProvider(id), (_, _) {});
    addTearDown(sub.close);
    await h.scope.read(noteEditorProvider(id).future);
    h.remote.output =
        '{"title":"Trip plan","body":"Destination:\\n- [ ] Pack"}';
    await actions().start(AiOperation.noteTemplate, id, topic: 'Trip plan');
    await actions().apply(job());
    final opened = await h.repository.openDocument(id);
    expect(opened.note, isNull);
    expect(opened.draft!.text.title, 'Trip plan');
    expect(opened.draft!.text.body, contains('- [ ] Pack'));
  });

  test(
    'AI note search uses bounded matched excerpts and validated source links',
    () async {
      h.remote.output = '{"status":"answered","answer":"Water the tomatoes every morning.","citations":["s0"]}';
      await actions().search('What did I plan for tomatoes?');
      expect(job().operation, AiOperation.noteQuestion);
      expect(h.remote.submissions.single['prompt'], contains('tomatoes'));
      expect((await h.repository.openDocument(notesTestId)).note!.revision, 1);
    },
  );

  test('website is saved beside unchanged note text and can change theme without AI', () async {
    h.remote.output = noteWebsiteOutput;
    await actions().start(
      AiOperation.noteWebsite,
      notesTestId,
      description: 'A calm garden plan',
      theme: 'garden',
    );
    final saved = (await actions().apply(job()))!;
    expect(saved.text.body, notesTestBody);
    expect(saved.details.website, contains('Plant tomatoes'));
    final spec = websiteSpecOf(saved.details.website)!;
    expect(spec.theme, 'garden');
    await h.repository.applyProposal(
      saved.id,
      saved.revision,
      text: saved.text,
      details: saved.details.copy(
        website: renderWebsite(
          spec.withStyle(theme: 'night'),
          title: saved.text.title,
        ),
      ),
      taskId: 'manual-theme',
      operation: 'website-look',
      retainPrior: false,
    );
    expect(h.remote.submissions.length, 1);
    expect(
      websiteSpecOf(
        (await h.repository.openDocument(saved.id)).note!.details.website,
      )!.theme,
      'night',
    );
  });

  test('background bytes are persisted and verified before ack, then accepted locally', () async {
    h.remote.beforeAck = () async {
      final text = h.remote.task!['text'] as String;
      expect(
        await h.media.resolve(
          backgroundPreviewPath(h.remote.task!['id'] as String, text),
        ),
        isNotNull,
      );
    };
    await actions().start(
      AiOperation.noteBackground,
      notesTestId,
      description: 'Soft leaves',
    );
    expect(job().phase, 'completed');
    final saved = (await actions().apply(job()))!;
    expect(saved.details.background['image'], startsWith('note_media/'));
    expect(saved.text.body, notesTestBody);
    expect(
      h.remote.events.indexWhere((e) => e.endsWith('/result')),
      lessThan(h.remote.events.indexWhere((e) => e.endsWith('/ack'))),
    );
  });

  test(
    'corrupted generated image is neither accepted nor acknowledged',
    () async {
      h.remote.corruptImage = true;
      await actions().start(
        AiOperation.noteBackground,
        notesTestId,
        description: 'Soft leaves',
      );
      expect(job().phase, isNot('completed'));
      expect(h.remote.events.any((e) => e.endsWith('/ack')), isFalse);
      expect(
        (await h.repository.openDocument(notesTestId)).note!.details.background,
        {'type': 'sage'},
      );
    },
  );

  test(
    'scan uploads the selected image only and appends reviewed corrections',
    () async {
      final path = await h.media.write(h.remote.generated);
      h.remote.output = '{"text":"Meet Sam at 3pm [?]","readable":true,"check":[{"text":"Meet Sam at 3pm","confidence":0.9}]}';
      final attachment = NoteAttachment(path: path, type: 'image/png');
      await actions().start(
        AiOperation.noteScan,
        notesTestId,
        image: attachment,
      );
      expect(h.remote.submissions.single['prompt'], noteScanPrompt);
      expect(h.remote.events, contains('POST /v1/image-jobs'));
      final saved = (await actions().apply(
        job(),
        reviewedText: 'Meet Sam at 3pm Friday',
      ))!;
      expect(saved.text.body, endsWith('Meet Sam at 3pm Friday'));
      expect(saved.details.attachments.single.path, path);
      expect(await h.media.scanOriginal(path), 'Meet Sam at 3pm [?]');
    },
  );

  test(
    'image answers preserve separate evidence and insert only after review',
    () async {
      final path = await h.media.write(h.remote.generated);
      final attachment = NoteAttachment(path: path, type: 'image/png');
      await h.save(
        details: NoteDetails(attachments: [attachment], tags: ['travel']),
      );
      h.remote.output = '{"observations":"A garden bed.","text":"Tomatoes","inference":"It may be a planting plan.","answer":""}';
      await actions().start(
        AiOperation.noteImage,
        notesTestId,
        image: attachment,
      );
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        notesTestBody,
      );
      final saved = (await actions().apply(job()))!;
      expect(saved.text.body, contains('A garden bed.'));
      expect(saved.details.attachments.single.path, path);
    },
  );

  test(
    'manual edit or recovery draft during inference prevents stale acceptance',
    () async {
      await actions().start(AiOperation.noteRewrite, notesTestId);
      final old = job();
      await h.save(body: 'New manual writing');
      await expectLater(actions().apply(old), throwsFormatException);
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        'New manual writing',
      );
    },
  );

  test(
    'changed draft is never overwritten by an older template result',
    () async {
      final id = 'c' * 32;
      h.scope.read(noteNewIdsProvider.notifier).add(id);
      final sub = h.scope.listen(noteEditorProvider(id), (_, _) {});
      addTearDown(sub.close);
      await h.scope.read(noteEditorProvider(id).future);
      h.remote.output = '{"title":"Plan","body":"A starting point"}';
      await actions().start(AiOperation.noteTemplate, id, topic: 'A plan');
      final old = job();
      h.scope
          .read(noteEditorProvider(id).notifier)
          .edit(const PlainTextDocument(body: 'My own new writing'));
      await expectLater(actions().apply(old), throwsFormatException);
      expect(
        h.scope.read(noteEditorProvider(id)).requireValue.text.body,
        'My own new writing',
      );
    },
  );

  test('role change rejects acceptance at the repository boundary', () async {
    await actions().start(AiOperation.noteRewrite, notesTestId);
    final old = job();
    final values = DriftSyncKeyValueStore(h.db);
    await values.write('deviceId', 'this-device');
    await values.write('role', '{"device_id":"other-device"}');
    await expectLater(actions().apply(old), throwsStateError);
    expect(
      (await h.repository.openDocument(notesTestId)).note!.text.body,
      notesTestBody,
    );
  });

  test('unavailable model and oversized input send no requests', () async {
    (h.scope.read(companionControllerProvider.notifier) as TestConnection).set(
      notesReadyComputer(status: 'missing'),
    );
    await actions().start(AiOperation.noteSummary, notesTestId);
    expect(h.remote.submissions, isEmpty);
    expect(h.scope.read(aiJobsProvider).message, isNotNull);
    (h.scope.read(companionControllerProvider.notifier) as TestConnection).set(
      notesReadyComputer(),
    );
    await h.save(body: 'word ' * 1000);
    await actions().start(AiOperation.noteSummary, notesTestId);
    expect(h.remote.submissions, isEmpty);
  });

  test(
    'retained queued task restores with the same identity and no resubmission',
    () async {
      h.remote.queued = true;
      final work = actions().start(AiOperation.noteSummary, notesTestId);
      for (
        var i = 0;
        i < 100 && h.scope.read(aiJobsProvider).job?.accepted != true;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final id = job().id;
      h.scope.dispose();
      h.remote.task!['state'] = 'completed';
      h.remote.task!['text'] = 'A short garden summary.';
      h.scope = h.createScope();
      await h.scope.read(aiJobsProvider.notifier).restore();
      await work;
      expect(job().id, id);
      expect(job().phase, 'completed');
      expect(h.remote.submissions.length, 1);
    },
  );

  test(
    'expired preview cannot be applied even when its note did not change',
    () async {
      await actions().start(AiOperation.noteRewrite, notesTestId);
      final current = job();
      final expired = AiJob(
        id: current.id,
        operation: current.operation,
        key: current.key,
        created: current.created - const Duration(days: 2).inMilliseconds,
        provider: current.provider,
        phase: 'completed',
        source: current.source,
        text: current.text,
      );
      await expectLater(actions().apply(expired), throwsFormatException);
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        notesTestBody,
      );
    },
  );

  test('cancel and reject never change notes', () async {
    h.remote.queued = true;
    final work = actions().start(AiOperation.noteRewrite, notesTestId);
    for (
      var i = 0;
      i < 100 && h.scope.read(aiJobsProvider).job?.accepted != true;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await h.scope.read(aiJobsProvider.notifier).cancel();
    await work;
    await h.scope.read(aiJobsProvider.notifier).clear();
    expect((await h.repository.openDocument(notesTestId)).note!.revision, 1);
    expect(h.remote.events.any((e) => e.endsWith('/cancel')), isTrue);
  });

  test('compatible text tools use the assigned phone model with the migrated prompt', () async {
    h.scope.dispose();
    h.scope = h.createScope(connected: false);
    h.assignments.values[BrainCapability.rewrite] = qualifiedBrainModel.id;
    await actions().start(AiOperation.noteRewrite, notesTestId);
    expect(job().provider, 'device');
    expect(job().phase, 'completed');
    expect(h.remote.submissions, isEmpty);
    expect(
      h.models.single.settings.systemInstruction,
      contains('Preserve facts'),
    );
    expect(h.models.single.closed, isTrue);
  });

  test(
    'metadata filters sensitive tags and reuses existing plain-tag spelling',
    () {
      final source = NoteMetadataSource(
        noteId: notesTestId,
        title: 'Garden',
        content: notesTestBody,
        tags: [],
        version: '1',
      );
      final suggestions = NoteMetadataSuggestions.parse(
        '{"titles":["Garden","A plan"],"tags":[{"name":"Depression","emoji":"🏷️"},{"name":"travel","emoji":"🌍"}]}',
        source,
        library: [NoteTag.tryParse('travel')!],
      );
      expect(suggestions.titles, ['A plan']);
      expect(suggestions.tags.single.name, 'travel');
    },
  );
}
