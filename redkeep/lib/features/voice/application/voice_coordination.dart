import '../data/voice_store.dart';
import 'voice_capture.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../companion/application/companion_controller.dart';
import '../../companion/data/companion_protocol.dart';

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

  // Backgrounding closes capture/playback but retains the interactive owner.
  // Returning to the app never restarts recording or automatic computer work.
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

TrustedComputer requireVoiceComputer(Ref ref, {bool conversation = false}) {
  if (ref.read(appDatabaseProvider).writingBlocked) {
    throw const CompanionFailure('RESET', 'Account reset is in progress.');
  }
  final connection = ref.read(companionControllerProvider);
  final computer = connection.selected;
  if (connection.phase != CompanionPhase.connected || computer == null) {
    throw const CompanionFailure(
      'UNAVAILABLE',
      'Connect your computer in More → Grand Maestar.',
    );
  }
  final capabilities = (connection.status?['capabilities'] as List? ?? [])
      .whereType<Map>();
  final speech = capabilities
      .where((c) => c['id'] == 'transcription')
      .firstOrNull;
  if (speech?['implemented'] != true ||
      speech?['live'] != 1 ||
      speech?['sampleRate'] != 16000 ||
      speech?['channels'] != 1 ||
      speech?['format'] != 's16le' ||
      !['ready', 'busy'].contains(speech?['status'])) {
    throw const CompanionFailure(
      'NOT_READY',
      'Load Whisper and Silero VAD in Journal Companion to capture speech.',
    );
  }
  if (conversation) {
    final writing = capabilities.where((c) => c['id'] == 'text').firstOrNull;
    if (!['ready', 'busy'].contains(writing?['status']) ||
        !(writing?['operations'] as List? ?? []).contains(
          'diary.conversation',
        )) {
      throw const CompanionFailure(
        'NOT_READY',
        'Load a writing model on your computer for diary conversation.',
      );
    }
  }
  return computer;
}

final voiceComputerProvider =
    Provider<TrustedComputer Function({bool conversation})>(
      (ref) =>
          ({bool conversation = false}) =>
              requireVoiceComputer(ref, conversation: conversation),
    );

final voiceCaptureFactoryProvider = Provider<VoiceCapture Function(String)>(
  (ref) =>
      (target) => VoiceCapture(
        target: target,
        computer: () => requireVoiceComputer(ref),
      ),
);

final voiceStoreProvider = Provider<VoiceStore>((ref) => VoiceStore());
