import 'dart:async';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../ai/domain/ai_provider.dart';
import '../data/pcm_recorder.dart';

enum CapturePhase {
  idle,
  connecting,
  recording,
  stopping,
  processing,
  review,
  error,
}

/// Sends a WAV recording to speech-to-text. Completing the abort future
/// cancels the request.
typedef VoiceTranscriber = Future<String> Function(
  Uint8List wav,
  double seconds,
  Future<void> abort,
);

/// The recorder's format: 16 kHz, mono, 16-bit little-endian PCM.
const voiceSampleRate = 16000;
const _bytesPerSecond = voiceSampleRate * 2;

/// Ten minutes of audio stays under common 25 MB upload limits.
const voiceMaxDuration = Duration(minutes: 10);

Uint8List wavFromPcm(Uint8List pcm) {
  final header = ByteData(44);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, voiceSampleRate, Endian.little);
  header.setUint32(28, _bytesPerSecond, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm))
      .takeBytes();
}

/// Records speech, then turns it into text with one request. Nothing is
/// summarized or rewritten, and nothing is kept after the page closes.
class VoiceCapture extends ChangeNotifier {
  VoiceCapture({
    required this.target,
    required this.transcribe,
    PcmRecorder? recorder,
    Future<Directory> Function()? directory,
    bool? supported,
  }) : _mic = recorder ?? PcmRecorder(),
       _directory = directory ?? getTemporaryDirectory,
       _supported = supported ?? Platform.isAndroid;
  final String target;
  final VoiceTranscriber transcribe;
  final PcmRecorder _mic;
  final Future<Directory> Function() _directory;
  final bool _supported;
  static const methods = MethodChannel('redkeep/pcm');

  CapturePhase phase = CapturePhase.idle;
  String? message, id, interruption;
  String? _thoughtId;
  bool canTranscribeAgain = false, disposed = false;
  double level = 0;
  String text = '', prefix = '';
  int bytes = 0;
  File? audio;
  Timer? _limit;
  Completer<void>? _abort;
  int _generation = 0;

  /// A Flow thought keeps one identity across retries and continuations.
  String? get thoughtId => _thoughtId ?? id;
  bool get recording => phase == CapturePhase.recording;
  void update() {
    if (!disposed) notifyListeners();
  }

  void fail(String value) {
    phase = CapturePhase.error;
    message = value;
    level = 0;
    update();
  }

  Future<void> start() async {
    if (disposed || recording || phase == CapturePhase.connecting) return;
    if (!_supported) {
      fail('Microphone capture currently requires Android.');
      return;
    }
    final generation = ++_generation;
    phase = CapturePhase.connecting;
    message = 'Checking microphone permission…';
    interruption = null;
    update();
    try {
      if (await methods.invokeMethod<bool>('permission') != true) {
        throw PlatformException(
          code: 'PERMISSION_DENIED',
          message: 'Microphone permission was denied. Allow it in Android app settings, then retry.',
        );
      }
      if (disposed || generation != _generation) return;
      await _deleteAudio();
      id = const Uuid().v4().replaceAll('-', '');
      _thoughtId ??= id;
      final directory = Directory('${(await _directory()).path}/voice');
      await directory.create(recursive: true);
      audio = File('${directory.path}/$id.pcm');
      bytes = 0;
      canTranscribeAgain = false;
      if (disposed || generation != _generation) return;
      phase = CapturePhase.recording;
      message = 'Listening · your words appear when you stop';
      update();
      await _mic.start(
        path: audio!.path,
        onData: (event) {
          if (!recording) return;
          bytes += event.length;
          final samples = ByteData.sublistView(event);
          double energy = 0;
          for (var i = 0; i + 1 < event.length; i += 2) {
            final v = samples.getInt16(i, Endian.little) / 32768;
            energy += v * v;
          }
          level = (math.sqrt(energy / math.max(1, event.length / 2)) * 8).clamp(
            0,
            1,
          );
          update();
        },
        onStopped: () {
          if (recording) unawaited(stop());
        },
        onError: (Object error) {
          if (recording) {
            interruption = error is PlatformException
                ? error.message
                : 'Recording was interrupted.';
            unawaited(stop());
          }
        },
      );
      if (disposed || generation != _generation) {
        await _mic.stop();
        return;
      }
      _limit = Timer(voiceMaxDuration, () => unawaited(stop()));
    } catch (e) {
      await _mic.stop().catchError((_) {});
      if (disposed || generation != _generation) return;
      fail(
        e is PlatformException
            ? e.message ?? 'Microphone unavailable.'
            : 'Could not start the microphone.',
      );
    }
  }

  /// Stops recording and transcribes it.
  Future<void> stop() async {
    if (!recording) return;
    _limit?.cancel();
    phase = CapturePhase.stopping;
    level = 0;
    update();
    try {
      await _mic.stop();
    } catch (_) {
      /* The file still holds what was recorded. */
    }
    if (disposed) return;
    await _transcribe();
  }

  Future<void> _transcribe() async {
    final generation = ++_generation;
    final file = audio;
    if (file == null || !await file.exists() || await file.length() < 3200) {
      phase = text.isEmpty ? CapturePhase.error : CapturePhase.review;
      message = interruption ?? 'Nothing was recorded. Try again.';
      update();
      return;
    }
    phase = CapturePhase.processing;
    message = 'Turning your words into text…';
    update();
    final abort = _abort = Completer<void>();
    try {
      final pcm = await file.readAsBytes();
      final spoken = await transcribe(
        wavFromPcm(pcm),
        pcm.length / _bytesPerSecond,
        abort.future,
      );
      if (disposed || generation != _generation) return;
      text = [
        if (prefix.trim().isNotEmpty) prefix.trim(),
        if (spoken.trim().isNotEmpty) spoken.trim(),
      ].join('\n\n');
      canTranscribeAgain = true;
      phase = text.isEmpty ? CapturePhase.error : CapturePhase.review;
      message = text.isEmpty ? 'No words were heard. Try again.' : interruption;
      update();
    } catch (error) {
      if (disposed || generation != _generation) return;
      canTranscribeAgain = true;
      phase = CapturePhase.error;
      message = error is AiProviderFailure
          ? error.message
          : 'Could not turn the recording into text. Try again.';
      update();
    } finally {
      if (identical(_abort, abort)) _abort = null;
    }
  }

  /// Sends the same recording again.
  Future<void> retry() => transcribeAgain();

  Future<void> transcribeAgain() async {
    if (recording || phase == CapturePhase.processing) return;
    await _transcribe();
  }

  /// Keeps the reviewed words and adds a new recording after them.
  Future<void> continueRecording(String reviewed) async {
    prefix = reviewed;
    text = reviewed;
    await start();
  }

  Future<void> discard() async {
    _generation++;
    _stopRequest();
    _limit?.cancel();
    await _mic.stop().catchError((_) {});
    await _deleteAudio();
    id = null;
    _thoughtId = null;
    text = '';
    prefix = '';
    bytes = 0;
    canTranscribeAgain = false;
    interruption = null;
    message = null;
    level = 0;
    phase = CapturePhase.idle;
    update();
  }

  void _stopRequest() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _abort = null;
  }

  Future<void> _deleteAudio() async {
    final file = audio;
    audio = null;
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {
      /* The temporary directory is cleared by the system. */
    }
  }

  /// Leaving the page cancels any request and deletes the recording.
  @override
  void dispose() {
    disposed = true;
    _generation++;
    _stopRequest();
    _limit?.cancel();
    unawaited(_mic.stop().catchError((_) {}).then((_) => _deleteAudio()));
    super.dispose();
  }
}
