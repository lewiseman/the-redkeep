import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/ai/application/ai_providers.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/data/note_media_store.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/recall/application/recall_controller.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';

import 'fake_ai.dart';
import 'fake_ai_provider.dart';

const notesTestId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const notesTestBody =
    'Plant tomatoes in the raised bed. Water them every morning.';
const noteMetadataOutput =
    '{"titles":["Raised bed plan"],"tags":[{"name":"Gardening","emoji":"🌱"}]}';
const noteWebsiteOutput =
    '{"theme":"garden","accent":"forest","hero":{"heading":"Garden plan","tagline":""},"sections":[{"kind":"text","heading":"","body":"Plant tomatoes in the raised bed.","items":[],"photo":-1}]}';

CompanionState notesReadyComputer({String status = 'ready'}) => CompanionState(
  phase: CompanionPhase.connected,
  computers: [syntheticComputer()],
  selectedId: 'computer-1',
  status: {
    'recovery': 1,
    'capabilities': [
      for (final kind in ['text', 'vision', 'image'])
        {
          'id': kind,
          'implemented': true,
          'status': status,
          'noteHelpContract': 1,
          'noteQuestionContract': 1,
          'websiteDesignContract': 1,
          'visionContract': 1,
          'scanContract': 1,
          'backgroundContract': 1,
          'operations': [
            for (final o in AiOperation.values)
              if (o.isNote && o.capabilityId == kind) o.wireName,
          ],
        },
    ],
  },
);

class NotesTransport implements CompanionTransport {
  final submissions = <Map<String, dynamic>>[];
  final events = <String>[];
  Map<String, dynamic>? task;
  String output =
      'Plant tomatoes in the raised bed and water them each morning.';
  bool queued = false, corruptImage = false;
  final Uint8List generated = image.encodePng(
    image.Image(width: 64, height: 64),
  );
  Future<void> Function()? beforeAck;
  @override
  Future<Map<String, dynamic>> request(
    Uri endpoint,
    String pin,
    String method,
    String route, {
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (route == '/v1/challenge') return {'nonce': 'a' * 43};
    events.add('$method $route');
    if (method == 'POST' &&
        (route == '/v1/jobs' || route == '/v1/image-jobs')) {
      submissions.add(Map.of(body!));
      task = {
        'id': body['id'],
        'operation': body['operation'],
        'device': 'b' * 32,
        'state': queued ? 'queued' : 'completed',
        if (!queued)
          'text': body['operation'] == 'generate-note-background'
              ? jsonEncode({
                  'width': 64,
                  'height': 64,
                  'bytes': generated.length,
                  'seed': 42,
                  'sha256': sha256.convert(generated).toString(),
                })
              : output,
      };
      return Map.of(task!);
    }
    if (route.endsWith('/result')) {
      return {
        'id': task!['id'],
        'image': base64Encode(
          corruptImage ? Uint8List.fromList([1, 2, 3]) : generated,
        ),
      };
    }
    if (route.endsWith('/ack')) {
      await beforeAck?.call();
      return {'ok': true};
    }
    if (route.endsWith('/cancel')) {
      task?['state'] = 'cancelled';
      return {'ok': true};
    }
    if (method == 'GET' && route.startsWith('/v1/jobs/')) return Map.of(task!);
    throw StateError('Unexpected offline test route: $route');
  }

  @override
  void close() {}
}

class NotesAiHarness {
  NotesAiHarness._(this.db, this.directory) {
    repository = DriftNotesRepository(
      db,
      clock: () => DateTime.utc(2026, 11, 4),
    );
    media = NoteMediaStore(db, support: () async => directory);
    scope = createScope();
  }
  static Future<NotesAiHarness> create() async => NotesAiHarness._(
    AppDatabase(NativeDatabase.memory()),
    await Directory.systemTemp.createTemp('redkeep-notes-test-'),
  );
  final AppDatabase db;
  final Directory directory;
  final protected = MemoryAiTasks();
  final remote = NotesTransport();
  final aiProvider = FakeAiProviderClient();
  late final DriftNotesRepository repository;
  late final NoteMediaStore media;
  late ProviderContainer scope;
  ProviderContainer createScope({bool connected = true, bool canEdit = true}) =>
      ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          noteMediaStoreProvider.overrideWithValue(media),
          protectedAiTasksProvider.overrideWithValue(protected),
          companionTransportProvider.overrideWithValue(remote),
          companionControllerProvider.overrideWith(
            () => TestConnection(
              connected
                  ? notesReadyComputer()
                  : const CompanionState(phase: CompanionPhase.idle),
            ),
          ),
          syncEnabledProvider.overrideWithValue(false),
          syncCanEditProvider.overrideWithValue(canEdit),
          protectedAiProvidersProvider.overrideWithValue(
            MemoryAiProviders(saved: const [testAiProvider]),
          ),
          aiProviderClientProvider.overrideWithValue(aiProvider),
          recallVectorsProvider.overrideWith((ref) async => MemoryVectors()),
          recallEmbedderProvider.overrideWithValue(FakeEmbedder()),
        ],
      );
  Future<NoteDocument> save({
    String id = notesTestId,
    String body = notesTestBody,
    String title = 'Garden',
    NoteDetails? details,
  }) async {
    final opened = await repository.openDocument(id);
    final draft = await repository.putDraft(
      id: id,
      text: PlainTextDocument(title: title, body: body),
      baseRevision: opened.note?.revision ?? 0,
      expectedDraftRevision: opened.draft?.draftRevision,
      details: details,
    );
    return repository.commitDraft(id, draft.draftRevision);
  }

  Future<void> close() async {
    await scope.read(aiJobsProvider.notifier).stopForReset();
    scope.dispose();
    await db.close();
    await directory.delete(recursive: true);
  }
}

