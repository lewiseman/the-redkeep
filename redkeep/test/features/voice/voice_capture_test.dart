import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/voice/application/voice_capture.dart';
import 'package:redkeep/features/voice/data/pcm_recorder.dart';

/// Writes one second of silence to the file, as the native recorder would.
class _FakeRecorder extends PcmRecorder {
  String? path;
  @override
  Future<void> start({
    required String path,
    required void Function(Uint8List) onData,
    required void Function() onStopped,
    required void Function(Object) onError,
  }) async {
    this.path = path;
    final pcm = Uint8List(32000);
    await File(path).writeAsBytes(pcm);
    onData(pcm);
  }

  @override
  Future<void> stop() async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late _FakeRecorder recorder;
  late List<(Uint8List, double)> sent;
  late Completer<void>? gate;
  late Future<void>? lastAbort;
  AiProviderFailure? failure;
  String reply = 'Hello diary';

  VoiceCapture capture() => VoiceCapture(
    target: 'diary',
    recorder: recorder,
    directory: () async => root,
    supported: true,
    transcribe: (wav, seconds, abort) async {
      sent.add((wav, seconds));
      lastAbort = abort;
      if (failure != null) throw failure!;
      if (gate != null) {
        await Future.any([gate!.future, abort]);
        if (!gate!.isCompleted) {
          throw const AiProviderFailure(AiProviderFailureKind.cancelled);
        }
      }
      return reply;
    },
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('redkeep-voice-');
    recorder = _FakeRecorder();
    sent = [];
    gate = null;
    lastAbort = null;
    reply = 'Hello diary';
    failure = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      VoiceCapture.methods,
      (call) async => call.method == 'permission' ? true : null,
    );
  });
  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      VoiceCapture.methods,
      null,
    );
    await root.delete(recursive: true);
  });

  test('wav wrapping describes 16 kHz mono 16-bit audio', () {
    final wav = wavFromPcm(Uint8List(8));
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    final header = ByteData.sublistView(wav);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(40, Endian.little), 8);
    expect(wav.length, 52);
  });

  test(
    'stopping sends one recording and shows plain words for review',
    () async {
      final voice = capture();
      addTearDown(voice.dispose);
      await voice.start();
      expect(voice.recording, isTrue);
      await voice.stop();
      expect(voice.phase, CapturePhase.review);
      expect(voice.text, 'Hello diary');
      expect(sent, hasLength(1));
      expect(sent.single.$2, closeTo(1, .001));
      expect(String.fromCharCodes(sent.single.$1.sublist(0, 4)), 'RIFF');

      reply = 'And a little more';
      await voice.continueRecording('Hello diary, reviewed');
      await voice.stop();
      expect(voice.text, 'Hello diary, reviewed\n\nAnd a little more');
    },
  );

  test(
    'a failed request keeps the recording so it can be sent again',
    () async {
      final voice = capture();
      addTearDown(voice.dispose);
      await voice.start();
      failure = const AiProviderFailure(AiProviderFailureKind.offline);
      await voice.stop();
      expect(voice.phase, CapturePhase.error);
      expect(voice.message, contains('offline'));
      expect(voice.canTranscribeAgain, isTrue);
      failure = null;
      await voice.retry();
      expect(voice.phase, CapturePhase.review);
      expect(sent, hasLength(2));
    },
  );

  test(
    'closing the page cancels the request and deletes the recording',
    () async {
      final voice = capture();
      await voice.start();
      final file = File(recorder.path!);
      gate = Completer<void>();
      unawaited(voice.stop());
      await pumpEventQueue();
      expect(voice.phase, CapturePhase.processing);
      voice.dispose();
      await pumpEventQueue();
      await expectLater(lastAbort, completes);
      expect(await file.exists(), isFalse);
    },
  );
}
