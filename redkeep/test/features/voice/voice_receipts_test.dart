import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';
import 'package:redkeep/features/voice/application/voice_receipts.dart';
import 'package:redkeep/features/voice/data/voice_store.dart';

import '../../support/fake_ai.dart';

class AckTransport implements CompanionTransport {
  bool fail = true;
  final endpoints = <Uri>[];
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
    endpoints.add(endpoint);
    if (fail) {
      throw const CompanionFailure('UNAVAILABLE', 'Synthetic offline computer');
    }
    return {'ok': true};
  }

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('consumption deletes temporary audio and retries acknowledgement only with its original pairing', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory()),
        root = await Directory.systemTemp.createTemp('redkeep-voice-ack-');
    final source = VoiceStore(supportDirectory: () => Future.value(root)),
        wire = AckTransport();
    final original = syntheticComputer(),
        other = syntheticComputer(id: 'other');
    final scope = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        companionTransportProvider.overrideWithValue(wire),
        companionControllerProvider.overrideWith(
          () => TestConnection(
            CompanionState(
              phase: CompanionPhase.connected,
              computers: [original, other],
              selectedId: other.id,
            ),
          ),
        ),
      ],
    );
    addTearDown(() async {
      scope.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await source.save('note', {
      'id': 'audio-11111111',
      'computer': original.id,
      'device': original.deviceId,
      'created': DateTime.now().millisecondsSinceEpoch,
      'text': 'Sensitive transcript',
    });
    final file = File('${(await source.directory()).path}/audio-11111111.pcm');
    await file.writeAsBytes([0, 0]);
    final receipts = scope.read(voiceReceiptsProvider);
    await receipts.consume('note', source: source);
    await receipts.drain();
    expect(await file.exists(), isFalse);
    expect(await source.load('note'), isNull);
    final pending = await VoiceStore.storage.read(key: 'redkeep.voice.acks');
    expect(pending, contains(original.id));
    expect(pending, isNot(contains('Sensitive transcript')));
    final connection =
        scope.read(companionControllerProvider.notifier) as TestConnection;
    connection.set(
      CompanionState(
        phase: CompanionPhase.connected,
        computers: [other],
        selectedId: other.id,
      ),
    );
    final calls = wire.endpoints.length;
    await receipts.drain();
    expect(wire.endpoints.length, calls);
    connection.set(
      CompanionState(
        phase: CompanionPhase.connected,
        computers: [original, other],
        selectedId: other.id,
      ),
    );
    wire.fail = false;
    await receipts.drain();
    expect(await VoiceStore.storage.read(key: 'redkeep.voice.acks'), isNull);
  });
}
