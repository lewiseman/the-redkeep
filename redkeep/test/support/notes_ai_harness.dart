import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/application/ai_cloud.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
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
const noteMetadataOutput = '{"titles":["Raised bed plan"]}';

/// The request scope the notes tests act as.
const notesJobScope = 'note-ai:test:';
const noteWebsiteOutput =
    '<!doctype html><html><head><style>:root[data-theme="dark"]{--ink:#eee}</style></head>'
    '<body><h1>Garden plan</h1><p>Plant tomatoes in the raised bed.</p>'
    '<script>document.querySelector("h1").dataset.ready = "1";</script></body></html>';

/// The cloud provider as the notes tests see it.
class NotesRemote {
  NotesRemote(this.ai) {
    ai.reply = output;
    ai.image = generated;
  }
  final FakeAiProviderClient ai;
  final Uint8List generated = image.encodePng(
    image.Image(width: 64, height: 64),
  );
  String get output => ai.reply;
  set output(String value) => ai.reply = value;

  /// Holds requests open until released.
  set queued(bool value) => ai.gate = value ? Completer<void>() : null;
  set corruptImage(bool value) =>
      ai.image = value ? Uint8List.fromList([1, 2, 3]) : generated;

  /// What was sent, as the user message and how many images it carried.
  List<Map<String, dynamic>> get submissions => [
    for (final request in ai.requests)
      {
        'prompt': request.user,
        'system': request.system,
        'images': request.images.length,
      },
  ];
}

class NotesAiHarness {
  NotesAiHarness._(this.db, this.directory) {
    repository = DriftNotesRepository(
      db,
      clock: () => DateTime.utc(2026, 11, 4),
    );
    media = NoteMediaStore(db, support: () async => directory);
    remote = NotesRemote(aiProvider);
    scope = createScope();
  }

  /// Stands in for the open notes AI page, which owns the request.
  ProviderSubscription<AiJobState> holdPage() =>
      scope.listen(aiJobsProvider(notesJobScope), (_, _) {});
  static Future<NotesAiHarness> create() async => NotesAiHarness._(
    AppDatabase(NativeDatabase.memory()),
    await Directory.systemTemp.createTemp('redkeep-notes-test-'),
  );
  final AppDatabase db;
  final Directory directory;
  final aiProvider = FakeAiProviderClient(
    'Plant tomatoes in the raised bed and water them each morning.',
  );
  late final NotesRemote remote;
  late final DriftNotesRepository repository;
  late final NoteMediaStore media;
  late ProviderContainer scope;
  ProviderContainer createScope({
    AiCloudSettings? settings = testAiSettings,
    bool canEdit = true,
  }) => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      notesRepositoryProvider.overrideWithValue(repository),
      noteMediaStoreProvider.overrideWithValue(media),
      syncEnabledProvider.overrideWithValue(false),
      syncCanEditProvider.overrideWithValue(canEdit),
      protectedAiProvidersProvider.overrideWithValue(
        MemoryAiProviders(saved: settings),
      ),
      aiCloudClientProvider.overrideWithValue(aiProvider),
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
    return repository.saveNote(
      id: id,
      text: PlainTextDocument(title: title, body: body),
      expectedRevision: opened.note?.revision ?? 0,
      details: details ?? opened.note?.details ?? const NoteDetails(),
    );
  }

  Future<void> close() async {
    scope.dispose();
    await db.close();
    await directory.delete(recursive: true);
  }
}
