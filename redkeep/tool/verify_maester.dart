// Opt-in synthetic native integration. Never imported by main.dart. All writing
// is in an isolated in-memory database; only report/model files use disk.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/brain/application/brain_providers.dart';
import 'package:redkeep/features/brain/data/file_brain_models.dart';
import 'package:redkeep/features/brain/data/model_download.dart';
import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/maester/application/maester_controller.dart';
import 'package:redkeep/features/maester/domain/maester_source.dart';
import 'package:redkeep/features/notes/application/note_editor_controller.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';

const _id = '11111111111111111111111111111111';
const _text =
    'Mira planted a tree. She watered it each morning. New leaves appeared.';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = ValueNotifier('Running synthetic M11 verification…');
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ValueListenableBuilder(
              valueListenable: status,
              builder: (_, value, _) => SelectableText(value),
            ),
          ),
        ),
      ),
    ),
  );
  final root = Directory(
    '${(await getApplicationSupportDirectory()).path}/m11-verification',
  );
  await root.create(recursive: true);
  final files = FileBrainModels(root: root, download: HttpModelDownload());
  final database = AppDatabase(NativeDatabase.memory());
  final notes = DriftNotesRepository(
    database,
    clock: () => DateTime.utc(2026, 11, 3),
  );
  final assignments = _SyntheticAssignments();
  final scope = ProviderContainer(
    overrides: [
      notesRepositoryProvider.overrideWithValue(notes),
      brainAssignmentsProvider.overrideWithValue(assignments),
      brainModelFilesProvider.overrideWith((_) async => files),
    ],
  );
  final cases = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'phase': 'M11',
    'platform': Platform.operatingSystem,
    'os': Platform.operatingSystemVersion,
    'mode': kReleaseMode ? 'release' : 'debug',
    'writing': 'synthetic, in-memory SQLite only',
    'core': '2.5.5',
    'engine': '1.19.1',
    'backend': 'cpu; fallback disabled',
    'model': qualifiedBrainModel.id,
    'bytes': qualifiedBrainModel.bytes,
    'sha256': qualifiedBrainModel.sha256,
    'cases': cases,
    'limits': 'Controller and native runtime integration; not physical accessibility, OS lifecycle, sustained performance or response quality qualification.',
  };
  Future<void> persist() =>
      File('${root.path}/report.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  Future<void> record(
    String name,
    Future<Map<String, Object?>> Function() body,
  ) async {
    status.value = 'M11: $name';
    report['inProgress'] = name;
    await persist();
    final timer = Stopwatch()..start();
    try {
      cases.add({
        'name': name,
        ...await body(),
        'passed': true,
        'elapsedMs': timer.elapsedMilliseconds,
      });
    } catch (error) {
      cases.add({
        'name': name,
        'passed': false,
        'error': error.toString(),
        'elapsedMs': timer.elapsedMilliseconds,
      });
      rethrow;
    } finally {
      report.remove('inProgress');
      await persist();
    }
  }

  void require(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  try {
    final draft = await notes.putDraft(
      id: _id,
      text: const PlainTextDocument(title: 'Synthetic M11', body: _text),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    await notes.commitDraft(_id, draft.draftRevision);
    scope.listen(noteEditorProvider(_id), (_, _) {});
    await scope.read(noteEditorProvider(_id).future);
    final editor = scope.read(noteEditorProvider(_id).notifier);
    var kind = MaesterKind.note;
    var selectionVersion = 0;
    NoteEditorState current() =>
        scope.read(noteEditorProvider(_id)).requireValue;
    MaesterSource source() => MaesterSource(
      kind: kind,
      id: _id,
      revision: current().baseRevision,
      version: (current().editVersion, selectionVersion),
      body: current().text.body,
      end: current().text.body.length,
      editing: true,
    );
    final context = MaesterContext(
      current: source,
      validate: (captured) async {
        if (!await editor.flushRecovery()) return false;
        final opened = await notes.openDocument(_id);
        return captured.matches(source()) &&
            opened.available &&
            opened.note!.revision == captured.revision &&
            opened.draft?.draftRevision == current().draftRevision;
      },
      accept: (proposal, valid) => editor.acceptReplacement(
        expected: current(),
        start: proposal.source.start,
        end: proposal.source.end,
        replacement: proposal.output,
        stillCurrent: valid,
      ),
    );
    final provider = maesterControllerProvider(context);
    scope.listen(provider, (_, _) {});
    final controller = scope.read(provider.notifier);
    MaesterState state() => scope.read(provider);
    await record('no_model_setup', () async {
      await controller.refresh();
      require(state().ready.isEmpty, 'Unassigned helper became ready');
      return {'ready': false, 'writingUnchanged': current().text.body == _text};
    });
    await record('verified_readiness', () async {
      assignments.assigned = true;
      await controller.refresh();
      require(
        state().ready.length == 3,
        'Stage the exact pinned model in m11-verification',
      );
      return {'capabilities': state().ready.keys.map((e) => e.name).toList()};
    });
    await record('rewrite_review_reject', () async {
      await controller.run(BrainCapability.rewrite);
      require(
        state().proposal != null,
        'Rewrite did not complete: ${state().failure}',
      );
      final output = state().output;
      require(current().text.body == _text, 'Generation silently edited text');
      await controller.cancel();
      require(
        (await notes.openDocument(_id)).draft == null,
        'Rejection created a draft',
      );
      return {'output': output, 'writingUnchanged': true};
    });
    await record('rewrite_accept_then_manual_save', () async {
      await controller.run(BrainCapability.rewrite);
      require(state().proposal != null, 'Rewrite failed: ${state().failure}');
      final output = state().output;
      require(await controller.accept(), 'Acceptance failed');
      await editor.flushRecovery();
      final before = await notes.openDocument(_id);
      require(
        before.note!.text.body == _text && before.draft!.text.body == output,
        'Acceptance bypassed recovery/commit boundary',
      );
      require(await editor.save(), 'Explicit save failed');
      require(
        (await notes.openDocument(_id)).note!.text.body == output,
        'Save did not commit',
      );
      return {
        'output': output,
        'committedRevision': current().baseRevision,
        'explicitSave': true,
      };
    });
    for (final operation in [
      BrainCapability.summarize,
      BrainCapability.reflect,
    ]) {
      await record('view_only_${operation.name}', () async {
        kind = operation == BrainCapability.reflect
            ? MaesterKind.flow
            : MaesterKind.diary;
        final before = current().text.body;
        await controller.run(operation);
        require(
          state().proposal != null,
          'Response failed: ${state().failure}',
        );
        require(
          !await controller.accept() && current().text.body == before,
          'View-only response edited writing',
        );
        return {
          'output': state().output,
          'writingUnchanged': true,
          'context':
              '${kind.name} capability over synthetic text; UI adapters covered separately',
        };
      });
    }
    kind = MaesterKind.note;
    for (final interruption in [
      'cancel',
      'source_edit',
      'selection_change',
      'background_controller',
    ]) {
      await record(interruption, () async {
        var interrupted = false;
        final before = current().text.body;
        final subscription = scope.listen(provider, (_, next) {
          if (!interrupted && next.busy && next.output.isNotEmpty) {
            interrupted = true;
            scheduleMicrotask(() {
              switch (interruption) {
                case 'cancel':
                  unawaited(controller.cancel());
                case 'source_edit':
                  editor.edit(
                    const PlainTextDocument(
                      title: 'Synthetic M11',
                      body: 'Newer synthetic writing.',
                    ),
                  );
                  controller.sourceChanged();
                case 'selection_change':
                  selectionVersion++;
                  controller.sourceChanged();
                case 'background_controller':
                  controller.setForeground(false);
              }
            });
          }
        });
        try {
          await controller.run(BrainCapability.rewrite);
        } finally {
          subscription.close();
        }
        controller.setForeground(true);
        require(
          interrupted && state().proposal == null && !state().busy,
          'Interruption failed',
        );
        require(
          !await controller.accept(),
          'Interrupted response was accepted',
        );
        require(
          current().text.body ==
              (interruption == 'source_edit'
                  ? 'Newer synthetic writing.'
                  : before),
          'Late output changed writing',
        );
        return {
          'cancelledAfterDelta': true,
          'failure': state().failure?.name,
          'expired': state().expired,
          'noProposal': true,
        };
      });
    }
    report['passed'] = true;
    status.value =
        'M11 verification passed (${cases.length} checks).\n${root.path}/report.json';
  } catch (error) {
    report['passed'] = false;
    report['error'] = error.toString();
    status.value = 'M11 verification failed: $error';
  } finally {
    scope.dispose();
    await database.close();
    await persist();
  }
}

class _SyntheticAssignments implements BrainAssignments {
  bool assigned = false;
  @override
  Future<List<BrainAssignment>> read() async => [
    if (assigned)
      for (final capability in BrainCapability.values)
        BrainAssignment(
          capability: capability,
          modelId: qualifiedBrainModel.id,
        ),
  ];
  @override
  Future<void> assign(BrainCapability capability, String? modelId) =>
      throw UnsupportedError('Verification assignments are isolated.');
}
