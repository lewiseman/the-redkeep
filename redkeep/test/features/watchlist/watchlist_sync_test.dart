import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/sync/data/drift_account_reset_data.dart';
import 'package:redkeep/features/sync/data/drift_sync_collection.dart';
import 'package:redkeep/features/sync/data/drift_sync_store.dart';
import 'package:redkeep/features/watchlist/data/drift_watchlist_repository.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../packages/sync_wise/test/support/memory_backend.dart';
import 'watchlist_repository_test.dart' show matrix, thrones;

final now = DateTime.utc(2026, 11, 13, 20);
const types = ['watch', 'watchlist', 'watchtaste'];

class Device {
  Device(this.drive, this.name) {
    storage = DriftSyncStateStore(db, deviceId: name, now: () => now);
    backend = MemoryBackend(drive);
    var ids = 0;
    watchlist = DriftWatchlistRepository(
      db,
      clock: () => now,
      newId: () => '$name${++ids}'.codeUnits
          .map((c) => (c % 16).toRadixString(16))
          .join()
          .padLeft(32, '0'),
    );
    provider = NotifierProvider<SyncEngine, SyncEngineState>(
      () => SyncEngine(
        (ref) => SyncEngineConfig(
          backend: backend,
          deviceId: name,
          deviceName: name,
          network: TestNetwork(),
          storage: storage,
          collections: [
            for (final type in types) DriftSyncCollection(db, type),
          ],
        ),
      ),
    );
  }

  final MemoryDrive drive;
  final String name;
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer();
  late final DriftSyncStateStore storage;
  late final MemoryBackend backend;
  late final DriftWatchlistRepository watchlist;
  late final NotifierProvider<SyncEngine, SyncEngineState> provider;

  Future<void> sync() => container.read(provider.notifier).syncNow(manual: true);

  /// A new phone takes over: it becomes primary and downloads everything.
  Future<void> takeOver() async {
    await sync();
    await container.read(provider.notifier).reclaimPrimary();
    await sync();
  }

  Future<void> close() async {
    container.dispose();
    backend.dispose();
    await db.close();
  }
}

void main() {
  late MemoryDrive drive;
  late Device phone;
  setUp(() {
    drive = MemoryDrive();
    phone = Device(drive, 'phone');
  });
  tearDown(() => phone.close());

  test('a title and a list reach a device that takes over, whole', () async {
    await phone.sync();
    await phone.watchlist.setStatus(thrones, WatchStatus.watching);
    await phone.watchlist.setRating(thrones, 8);
    await phone.watchlist.setNote(thrones, 'Skip season 8');
    await phone.watchlist.setEpisodes(thrones, watched: {'s1e1', 's1e2'});
    final list = await phone.watchlist.createList('Weekends', first: thrones);
    await phone.sync();

    final remote = drive.documents['watch/${thrones.key.id}']!.payload;
    expect(remote['schema'], 1);
    expect(remote['media_key'], 'tv:1399');
    expect(remote['status'], 'watching');
    expect(remote.containsKey('revision'), isFalse);
    expect(jsonDecode(remote['episodes'] as String), ['s1e1', 's1e2']);
    expect(drive.documents['watchlist/$list']!.payload['name'], 'Weekends');

    final tablet = Device(drive, 'tablet');
    addTearDown(tablet.close);
    await tablet.takeOver();
    final arrived = await tablet.watchlist.watchTitle(thrones.key.id).first;
    expect(arrived!.status, WatchStatus.watching);
    expect(arrived.rating, 8);
    expect(arrived.note, 'Skip season 8');
    expect(arrived.episodes, {'s1e1', 's1e2'});
    expect((await tablet.watchlist.watchLists().first).single.items, [
      thrones.key.id,
    ]);
  });

  test('removal travels as a cleared title, and the add-only device can still add', () async {
    await phone.sync();
    await phone.watchlist.setStatus(matrix, WatchStatus.completed);
    await phone.sync();
    final tablet = Device(drive, 'tablet');
    addTearDown(tablet.close);
    await tablet.sync();

    await tablet.watchlist.setStatus(thrones, WatchStatus.planned);
    await expectLater(
      tablet.watchlist.setRating(thrones, 5),
      throwsStateError,
      reason: 'the second device adds but does not edit',
    );
    await tablet.sync();
    await phone.sync();
    expect(
      (await phone.watchlist.watchTitle(thrones.key.id).first)!.status,
      WatchStatus.planned,
    );

    await phone.watchlist.removeTitle(matrix.key.id);
    await phone.sync();
    final remote = drive.documents['watch/${matrix.key.id}']!.payload;
    expect(remote['deleted_at'], isNotNull);
    expect(remote['status'], isNull);
    final laptop = Device(drive, 'laptop');
    addTearDown(laptop.close);
    await laptop.takeOver();
    expect(await laptop.watchlist.watchTitle(matrix.key.id).first, isNull);
    expect(await laptop.watchlist.watchTitle(thrones.key.id).first, isNotNull);
  });

  test('taste and dealbreakers travel as one document', () async {
    await phone.sync();
    await phone.watchlist.saveProfile({
      'version': 1,
      'swipes': 12,
      'dealbreakers': {'excluded_genres': ['Horror']},
    });
    await phone.sync();
    final remote = drive.documents.values.where((d) => d.type == 'watchtaste');
    expect(remote, hasLength(1));
    final tablet = Device(drive, 'tablet');
    addTearDown(tablet.close);
    await tablet.takeOver();
    final profile = await tablet.watchlist.readProfile();
    expect(profile!['swipes'], 12);
    expect(
      () => DriftSyncCollection(phone.db, 'watchtaste').decode({
        'schema': 1,
        'id': 'a' * 32,
        'state': '{}',
        'created_at': 1,
        'updated_at': 1,
      }),
      throwsFormatException,
      reason: 'there is only one taste document',
    );
  });

  test('malformed documents are refused', () {
    final collection = DriftSyncCollection(phone.db, 'watch');
    final valid = {
      'schema': 1,
      'id': matrix.key.id,
      'media_key': 'movie:603',
      'title': 'The Matrix',
      'note': '',
      'episodes': '[]',
      'created_at': 1,
      'updated_at': 1,
    };
    expect(collection.decode(valid).id, matrix.key.id);
    for (final change in <Map<String, Object?>>[
      {'id': thrones.key.id},
      {'media_key': 'person:1'},
      {'status': 'binged'},
      {'rating': 11},
      {'episodes': '["e1"]'},
      {'episodes': 'nope'},
      {'note': 4},
    ]) {
      expect(
        () => collection.decode({...valid, ...change}),
        throwsFormatException,
        reason: '$change',
      );
    }
    expect(
      () => DriftSyncCollection(phone.db, 'watchlist').decode({
        'schema': 1,
        'id': 'a' * 32,
        'name': 'Later',
        'items': '["not-an-id"]',
        'created_at': 1,
        'updated_at': 1,
      }),
      throwsFormatException,
    );
  });

  test('chats with a title stay on this device and never sync', () async {
    await phone.sync();
    await phone.watchlist.setStatus(matrix, WatchStatus.planned);
    await phone.sync();
    final before = Map.of(drive.documents);
    await phone.db
        .into(phone.db.watchChatTurns)
        .insert(
          WatchChatTurnsCompanion.insert(
            id: 'c' * 32,
            titleId: matrix.key.id,
            at: 1,
            fromReader: true,
            body: 'Are you worth the hype?',
          ),
        );
    expect(
      await (phone.db.select(phone.db.syncRecords)
            ..where((r) => r.state.equals('pending')))
          .get(),
      isEmpty,
      reason: 'a message queues nothing',
    );
    await phone.sync();
    expect(drive.documents.keys, before.keys);
    expect(
      drive.documents.values.map((d) => jsonEncode(d.payload)).join(),
      isNot(contains('worth the hype')),
    );
  });

  test('account reset clears every watchlist table', () async {
    await phone.watchlist.setStatus(matrix, WatchStatus.planned);
    await phone.watchlist.createList('Later');
    await phone.watchlist.cacheTitles([matrix]);
    await DriftAccountResetData(phone.db).clear();
    expect(await phone.db.select(phone.db.watchTitles).get(), isEmpty);
    expect(await phone.db.select(phone.db.watchLists).get(), isEmpty);
    expect(await phone.db.select(phone.db.watchCatalog).get(), isEmpty);
  });
}
