import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/notes/application/note_ai_controller.dart';
import 'package:redkeep/features/notes/application/note_ai_sources.dart';
import 'package:redkeep/features/notes/application/note_editor_controller.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/domain/note_help_contract.dart';
import 'package:redkeep/features/notes/domain/note_tag.dart';
import 'package:redkeep/features/sync/data/drift_sync_store.dart';

import '../../support/fake_ai_provider.dart';
import '../../support/notes_ai_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NotesAiHarness h;
  setUp(() async {
    h = await NotesAiHarness.create();
    h.holdPage();
    await h.save(
      details: const NoteDetails(
        tags: ['travel'],
        background: {'type': 'sage'},
      ),
    );
  });
  tearDown(() => h.close());
  NoteAiController actions() => h.scope.read(noteAiControllerProvider);
  AiJob job() => h.scope.read(aiJobsProvider(notesJobScope)).job!;

  for (final operation in AiOperation.values.where(
    (o) => o.isNote && o.available && o != AiOperation.noteBackground,
  )) {
    test(
      '${operation.wireName} rejects a malformed result without changing writing',
      () async {
        h.remote.output = '<script>untrusted output</script>';
        if (operation == AiOperation.noteQuestion) {
          await actions().search('tomatoes', scope: notesJobScope);
        } else if (operation == AiOperation.noteTemplate) {
          final id = 'c' * 32;
          h.scope.read(noteNewIdsProvider.notifier).add(id);
          final sub = h.scope.listen(noteEditorProvider(id), (_, _) {});
          addTearDown(sub.close);
          await h.scope.read(noteEditorProvider(id).future);
          await actions().start(
            operation,
            id,
            scope: notesJobScope,
            topic: 'Trip plan',
          );
        } else if (operation.imageInput) {
          final path = await h.media.write(h.remote.generated);
          final attachment = NoteAttachment(path: path, type: 'image/png');
          await h.save(details: NoteDetails(attachments: [attachment]));
          await actions().start(
            operation,
            notesTestId,
            scope: notesJobScope,
            image: attachment,
          );
        } else {
          await actions().start(
            operation,
            notesTestId,
            scope: notesJobScope,
            description: 'A garden plan',
          );
        }
        expect(job().phase, isNot('completed'));
        expect(
          (await h.repository.openDocument(notesTestId)).note!.text.body,
          notesTestBody,
        );
      },
    );
  }

  test(
    'summary only sends this note and leaves the full document untouched',
    () async {
      await h.save(id: 'b' * 32, body: 'Private unrelated note');
      await actions().start(
        AiOperation.noteSummary,
        notesTestId,
        scope: notesJobScope,
      );
      expect(job().phase, 'completed');
      expect(h.remote.submissions.single['prompt'], contains(notesTestBody));
      expect(
        h.remote.submissions.single.toString(),
        isNot(contains('Private unrelated')),
      );
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
      '${operation.wireName} reviews and applies only a selected passage',
      () async {
        h.remote.output = 'Grow tomatoes';
        await actions().start(
          operation,
          notesTestId,
          scope: notesJobScope,
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
        final saved = (await actions().apply(job(), scope: notesJobScope))!;
        expect(saved.text.body, startsWith('Grow tomatoes in the raised bed.'));
        expect(saved.tags, ['travel']);
        expect(saved.details.background['type'], 'sage');
      },
    );
  }

  test(
    'accepting a reviewed result never clears a newer unrelated task',
    () async {
      await actions().start(
        AiOperation.noteRewrite,
        notesTestId,
        scope: notesJobScope,
      );
      final reviewed = job();
      await h.scope.read(aiJobsProvider(notesJobScope).notifier).clear();
      h.remote.output = '{"status":"answered","answer":"Water the tomatoes.","citations":["s0"]}';
      await actions().search(
        'What did I plan for tomatoes?',
        scope: notesJobScope,
      );
      final newer = job();
      await actions().apply(reviewed, scope: notesJobScope);
      expect(job().id, newer.id);
      expect(job().operation, AiOperation.noteQuestion);
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        reviewed.text,
      );
    },
  );

  test(
    'metadata applies only selected fields and preserves manual tags',
    () async {
      h.remote.output = noteMetadataOutput;
      await actions().start(
        AiOperation.noteMetadata,
        notesTestId,
        scope: notesJobScope,
      );
      final saved = (await actions().apply(
        job(),
        scope: notesJobScope,
        title: 'Raised bed plan',
        tags: ['🌱#Gardening'],
      ))!;
      expect(saved.text.title, 'Raised bed plan');
      expect(saved.text.body, notesTestBody);
      expect(saved.tags, containsAll(['travel', '🌱#Gardening']));
    },
  );

  test('template result fills a new note and saves it', () async {
    final id = 'c' * 32;
    h.scope.read(noteNewIdsProvider.notifier).add(id);
    final sub = h.scope.listen(noteEditorProvider(id), (_, _) {});
    addTearDown(sub.close);
    await h.scope.read(noteEditorProvider(id).future);
    h.remote.output =
        '{"title":"Trip plan","body":"Destination:\\n- [ ] Pack"}';
    await actions().start(
      AiOperation.noteTemplate,
      id,
      scope: notesJobScope,
      topic: 'Trip plan',
    );
    await actions().apply(job(), scope: notesJobScope);
    final buffer = h.scope.read(noteEditorProvider(id)).requireValue;
    expect(buffer.text.title, 'Trip plan');
    final opened = await h.repository.openDocument(id);
    expect(opened.note!.text.title, 'Trip plan');
    expect(opened.note!.text.body, contains('- [ ] Pack'));
  });

  test(
    'AI note search uses bounded matched excerpts and validated source links',
    () async {
      h.remote.output = '{"status":"answered","answer":"Water the tomatoes every morning.","citations":["s0"]}';
      await actions().search(
        'What did I plan for tomatoes?',
        scope: notesJobScope,
      );
      expect(job().operation, AiOperation.noteQuestion);
      expect(h.remote.submissions.single['prompt'], contains('tomatoes'));
      expect((await h.repository.openDocument(notesTestId)).note!.revision, 1);
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
        scope: notesJobScope,
        image: attachment,
      );
      expect(h.remote.submissions.single['images'], 1);
      final saved = (await actions().apply(
        job(),
        scope: notesJobScope,
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
        scope: notesJobScope,
        image: attachment,
      );
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        notesTestBody,
      );
      final saved = (await actions().apply(job(), scope: notesJobScope))!;
      expect(saved.text.body, contains('A garden bed.'));
      expect(saved.details.attachments.single.path, path);
    },
  );

  test(
    'manual edit or recovery draft during inference prevents stale acceptance',
    () async {
      await actions().start(
        AiOperation.noteRewrite,
        notesTestId,
        scope: notesJobScope,
      );
      final old = job();
      await h.save(body: 'New manual writing');
      await expectLater(
        actions().apply(old, scope: notesJobScope),
        throwsFormatException,
      );
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
      await actions().start(
        AiOperation.noteTemplate,
        id,
        scope: notesJobScope,
        topic: 'A plan',
      );
      final old = job();
      h.scope
          .read(noteEditorProvider(id).notifier)
          .edit(const PlainTextDocument(body: 'My own new writing'));
      await expectLater(
        actions().apply(old, scope: notesJobScope),
        throwsFormatException,
      );
      expect(
        h.scope.read(noteEditorProvider(id)).requireValue.text.body,
        'My own new writing',
      );
    },
  );

  test('role change rejects acceptance at the repository boundary', () async {
    await actions().start(
      AiOperation.noteRewrite,
      notesTestId,
      scope: notesJobScope,
    );
    final old = job();
    final values = DriftSyncKeyValueStore(h.db);
    await values.write('deviceId', 'this-device');
    await values.write('role', '{"device_id":"other-device"}');
    await expectLater(
      actions().apply(old, scope: notesJobScope),
      throwsStateError,
    );
    expect(
      (await h.repository.openDocument(notesTestId)).note!.text.body,
      notesTestBody,
    );
  });

  test('background images are generated, verified and kept locally', () async {
    await actions().start(
      AiOperation.noteBackground,
      notesTestId,
      scope: notesJobScope,
      description: 'Soft leaves',
    );
    expect(h.scope.read(aiJobsProvider(notesJobScope)).message, isNull);
    expect(job().phase, 'completed');
    expect(h.aiProvider.images.single, contains('Soft leaves'));
    expect(
      await h.media.resolve(backgroundPreviewPath(job().id, job().text!)),
      isNotNull,
    );
    final saved = (await actions().apply(job(), scope: notesJobScope))!;
    expect(saved.details.background['image'], startsWith('note_media/'));
    expect(saved.text.body, notesTestBody);
  });

  test('a corrupted generated image is never applied', () async {
    h.remote.corruptImage = true;
    await actions().start(
      AiOperation.noteBackground,
      notesTestId,
      scope: notesJobScope,
      description: 'Soft leaves',
    );
    expect(job().phase, 'failed');
    expect(
      (await h.repository.openDocument(notesTestId)).note!.details.background,
      {'type': 'sage'},
    );
  });

  test(
    'a provider without the feature, or oversized input, sends nothing',
    () async {
      h.scope.dispose();
      h.scope = h.createScope(
        settings: testAiSettings.copyWith(models: {AiCapability.chat: 'm'}),
      );
      h.holdPage();
      await actions().start(
        AiOperation.noteBackground,
        notesTestId,
        scope: notesJobScope,
        description: 'Soft leaves',
      );
      expect(h.aiProvider.images, isEmpty);
      expect(
        h.scope.read(aiJobsProvider(notesJobScope)).message,
        contains('does not offer'),
      );
      await h.save(body: 'word ' * 1000);
      await actions().start(
        AiOperation.noteSummary,
        notesTestId,
        scope: notesJobScope,
      );
      expect(h.remote.submissions, isEmpty);
    },
  );

  test('the website tool is paused and never sends', () async {
    await actions().start(
      AiOperation.noteWebsite,
      notesTestId,
      scope: notesJobScope,
      description: 'A garden plan',
    );
    expect(h.remote.submissions, isEmpty);
    expect(job().phase, 'failed');
  });

  test('cancel and reject never change notes', () async {
    h.remote.queued = true;
    final work = actions().start(
      AiOperation.noteRewrite,
      notesTestId,
      scope: notesJobScope,
    );
    await pumpEventQueue();
    await h.scope.read(aiJobsProvider(notesJobScope).notifier).cancel();
    await work;
    expect(h.aiProvider.aborted, isTrue);
    await h.scope.read(aiJobsProvider(notesJobScope).notifier).clear();
    expect((await h.repository.openDocument(notesTestId)).note!.revision, 1);
  });

  test('leaving the page aborts the request and discards its result', () async {
    h.scope.dispose();
    h.scope = h.createScope();
    final page = h.holdPage();
    h.remote.queued = true;
    unawaited(
      actions().start(
        AiOperation.noteRewrite,
        notesTestId,
        scope: notesJobScope,
      ),
    );
    await pumpEventQueue();
    expect(h.scope.read(aiJobsProvider(notesJobScope)).busy, isTrue);
    page.close();
    await pumpEventQueue();
    expect(h.aiProvider.aborted, isTrue);
    final again = h.holdPage();
    addTearDown(again.close);
    expect(h.scope.read(aiJobsProvider(notesJobScope)).job, isNull);
    expect((await h.repository.openDocument(notesTestId)).note!.revision, 1);
  });

  test('text tools send the note prompt to the cloud provider', () async {
    await actions().start(
      AiOperation.noteRewrite,
      notesTestId,
      scope: notesJobScope,
    );
    expect(job().phase, 'completed');
    expect(h.aiProvider.requests.single.system, contains('Preserve facts'));
    expect(h.aiProvider.requests.single.model, 'test-model');
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
