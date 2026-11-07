import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_cloud.dart';
import 'voice_capture.dart';

/// The microphone lease: one voice page records at a time.
final voiceActiveProvider = NotifierProvider<VoiceActive, bool>(
  VoiceActive.new,
);

class VoiceActive extends Notifier<bool> {
  Object? _owner;
  bool owns(Object? owner) =>
      _owner != null && identical(owner, _owner) && _draining == null;
  Future<void>? _draining;
  Future<void> Function()? _stop;
  @override
  bool build() => false;
  void acquire(Object owner, Future<void> Function() stop) {
    if (_draining != null || _owner != null && !identical(owner, _owner)) {
      throw StateError('Another voice session is open.');
    }
    _owner = owner;
    _stop = stop;
    state = true;
  }

  void release(Object owner) {
    if (identical(owner, _owner)) {
      _owner = null;
      _stop = null;
      state = false;
    }
  }

  /// Backgrounding stops recording; returning never restarts it.
  Future<void> suspend() =>
      _draining ??= _suspend().whenComplete(() => _draining = null);
  Future<void> _suspend() async {
    await _stop?.call();
  }

  Future<void> stopAll() async {
    final pending = _draining;
    if (pending != null) await pending;
    await (_draining ??= _drain().whenComplete(() => _draining = null));
  }

  Future<void> _drain() async {
    try {
      await _stop?.call();
    } finally {
      _owner = null;
      _stop = null;
      state = false;
    }
  }
}

/// Plain speech-to-text with the configured provider, for every target.
final voiceCaptureFactoryProvider = Provider<VoiceCapture Function(String)>(
  (ref) =>
      (target) => VoiceCapture(
        target: target,
        transcribe: (wav, seconds, abort) => ref
            .read(aiCloudProvider)
            .transcribe(wav, seconds: seconds, abort: abort),
      ),
);
