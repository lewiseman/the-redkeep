import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/voice/application/voice_capture.dart';
import 'package:redkeep/features/voice/data/voice_store.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';

class DelayedVoiceStore extends VoiceStore {
  final restored = Completer<Map<String, dynamic>?>();
  bool cleared = false;
  @override
  Future<Map<String, dynamic>?> load(String target) => restored.future;
  @override
  Future<void> cleanup() async {}
  @override
  Future<void> clear(String target) async {
    cleared = true;
  }
}

class RetainedVoiceStore extends VoiceStore {
  RetainedVoiceStore(this.root, this.data);
  final Directory root;
  Map<String, dynamic>? data;
  bool cleared = false;
  @override
  Future<Directory> directory() async => root;
  @override
  Future<void> cleanup() async {}
  @override
  Future<Map<String, dynamic>?> load(String target) async => data;
  @override
  Future<void> save(String target, Map<String, dynamic> value) async {
    data = value;
  }

  @override
  Future<void> clear(String target) async {
    data = null;
    cleared = true;
  }
}

class MissingVoiceTransport implements CompanionTransport {
  @override
  Future<Map<String, dynamic>> request(
    Uri endpoint,
    String pin,
    String method,
    String route, {
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (route == '/v1/challenge') return {'nonce': 'A' * 43};
    throw const CompanionFailure('NOT_FOUND', 'No accepted recording');
  }

  @override
  void close() {}
}

class RetryingCapture extends VoiceCapture {
  RetryingCapture(VoiceStore store)
    : super(target: 'flow', computer: () => testComputer, store: store);
  @override
  Future<void> retry() async {}
}

final testComputer = TrustedComputer(
  id: 'desktop',
  name: 'Synthetic desktop',
  pin: 'a' * 64,
  endpoint: Uri.parse('https://127.0.0.1:47921'),
  seed: base64Encode(List.filled(32, 7)),
  publicKey: base64Encode(List.filled(32, 8)),
  deviceId: 'phone-device',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Flow identity survives a new transcription task and restoration',
    () async {
      final root = await Directory.systemTemp.createTemp('voice-flow-retry-');
      addTearDown(() => root.delete(recursive: true));
      final store = RetainedVoiceStore(root, {
        'id': 'speech-task-original',
        'created': DateTime.now().millisecondsSinceEpoch,
        'text': 'A thought',
        'canTranscribeAgain': true,
      });
      await File('${root.path}/speech-task-original.pcm').writeAsBytes([0, 0]);
      final capture = RetryingCapture(store);
      addTearDown(capture.dispose);
      await capture.restore();
      await capture.transcribeAgain();
      expect(capture.id, isNot('speech-task-original'));
      expect(capture.thoughtId, 'speech-task-original');
      expect(store.data!['thoughtId'], 'speech-task-original');
      final recovered = RetryingCapture(store);
      addTearDown(recovered.dispose);
      await recovered.restore();
      expect(recovered.thoughtId, 'speech-task-original');
      expect(recovered.id, capture.id);
      await recovered.discard(notifyComputer: false);
      expect(recovered.thoughtId, isNull);
    },
  );
  test(
    'discard fences a delayed restoration instead of reviving old audio',
    () async {
      final store = DelayedVoiceStore();
      final capture = VoiceCapture(
        target: 'note',
        computer: () =>
            throw StateError('No pairing is needed for local discard'),
        store: store,
      );
      addTearDown(capture.dispose);
      final restoration = capture.restore();
      await capture.discard();
      store.restored.complete({
        'id': 'old-recording',
        'created': DateTime.now().millisecondsSinceEpoch,
        'text': 'Old words',
      });
      await restoration;
      expect(store.cleared, isTrue);
      expect(capture.id, isNull);
      expect(capture.text, isEmpty);
      expect(capture.phase, CapturePhase.idle);
    },
  );
  test('an empty unaccepted attempt returns to Record after desktop confirms NOT_FOUND', () async {
    final root = await Directory.systemTemp.createTemp('voice-empty-');
    addTearDown(() => root.delete(recursive: true));
    final store = RetainedVoiceStore(root, {
      'id': 'empty-attempt',
      'computer': 'desktop',
      'device': 'phone-device',
      'created': DateTime.now().millisecondsSinceEpoch,
      'accepted': false,
      'text': '',
    });
    final capture = VoiceCapture(
      target: 'note',
      computer: () => testComputer,
      store: store,
      transportFactory: MissingVoiceTransport.new,
    );
    addTearDown(capture.dispose);
    await capture.restore();
    await capture.retry();
    expect(store.cleared, isTrue);
    expect(capture.id, isNull);
    expect(capture.phase, CapturePhase.idle);
    expect(capture.message, contains('no audio was captured'));
  });
  test(
    'an accepted receipt is retained even if the local audio is missing',
    () async {
      final root = await Directory.systemTemp.createTemp('voice-accepted-');
      addTearDown(() => root.delete(recursive: true));
      final store = RetainedVoiceStore(root, {
        'id': 'accepted-attempt',
        'computer': 'desktop',
        'device': 'phone-device',
        'created': DateTime.now().millisecondsSinceEpoch,
        'accepted': true,
        'text': '',
      });
      final capture = VoiceCapture(
        target: 'note',
        computer: () => testComputer,
        store: store,
        transportFactory: MissingVoiceTransport.new,
      );
      addTearDown(capture.dispose);
      await capture.restore();
      await capture.retry();
      expect(store.cleared, isFalse);
      expect(capture.id, 'accepted-attempt');
      expect(capture.accepted, isTrue);
    },
  );
}
