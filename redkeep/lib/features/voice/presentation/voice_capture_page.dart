import 'voice_ui.dart';
import '../application/voice_coordination.dart';

import 'package:redkeep/features/voice/application/mic_permission.dart';
import 'package:redkeep/features/voice/application/voice_capture.dart';
import 'package:redkeep/features/voice/presentation/widgets/voice_ambient_background.dart';
import 'package:redkeep/features/voice/presentation/widgets/voice_bottom_card.dart';
import 'package:redkeep/features/voice/presentation/widgets/voice_session_chrome.dart';
import 'package:redkeep/features/voice/presentation/widgets/voice_transcript.dart';

class VoiceCapturePage extends ConsumerStatefulWidget {
  const VoiceCapturePage({
    super.key,
    required this.title,
    this.target = 'note',
    this.permission,
  });
  final String title, target;

  /// Injected in tests; the caller then owns and disposes it.
  final MicPermission? permission;
  @override
  ConsumerState<VoiceCapturePage> createState() => _VoiceCapturePageState();
}

class _VoiceCapturePageState extends ConsumerState<VoiceCapturePage>
    with WidgetsBindingObserver {
  late final VoiceCapture _capture;
  late final MicPermission _mic;
  final _review = TextEditingController();
  String _lastTranscript = '';
  final _owner = Object();
  late VoiceActive _lease;
  bool _saving = false, _autoStarted = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lease = ref.read(voiceActiveProvider.notifier);
    _capture = ref.read(voiceCaptureFactoryProvider)(widget.target);
    _capture.addListener(_changed);
    _mic = widget.permission ?? MicPermission();
    _mic.addListener(_permissionChanged);
    unawaited(_mic.check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  /// Opening the page starts listening straight away, unless the microphone
  /// is not allowed yet.
  void _maybeStart() {
    if (!mounted || _autoStarted || !_mic.granted) return;
    if (_capture.id != null || _capture.phase != CapturePhase.idle) return;
    _autoStarted = true;
    try {
      _lease.acquire(_owner, _capture.stop);
    } catch (_) {
      _capture.fail('Another voice session is finishing. Retry shortly.');
      return;
    }
    unawaited(_capture.start());
  }

  Future<void> _withLease(Future<void> Function() action) async {
    try {
      _lease.acquire(_owner, _capture.stop);
      await action();
    } catch (_) {
      _capture.fail('Another voice session is finishing. Retry shortly.');
    }
  }

  void _permissionChanged() {
    if (!mounted) return;
    _maybeStart();
    setState(() {});
  }

  void _changed() {
    if (!mounted) return;
    if (_capture.text != _lastTranscript) {
      _lastTranscript = _capture.text;
      _review.text = _capture.text;
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Back from Settings, or a one-time permission that has now expired.
      unawaited(_mic.check());
    } else if (_capture.recording) {
      _capture.interruption =
          'Recording paused when the app left the foreground.';
      unawaited(_capture.stop());
    }
  }

  Future<void> _use() async {
    if (_saving ||
        _review.text.trim().isEmpty ||
        _capture.recording ||
        ref.read(appDatabaseProvider).writingBlocked) {
      return;
    }
    setState(() => _saving = true);
    try {
      final text = _review.text.trim();
      // Flow's normal repository owns permissions/outbox; a stable UUID also
      // prevents duplicate creations if the app closes immediately after save.
      if (widget.target == 'flow') {
        final repo = ref.read(flowRepositoryProvider);
        final id = _capture.thoughtId!;
        final existing = await repo.openDocument(id);
        if (!existing.available) {
          await repo.save(id: id, body: text, expectedRevision: 0);
        } else if (existing.thought!.body != text) {
          throw StateError(
            'This recording was already saved with other words.',
          );
        }
      }
      if (widget.target == 'flow') {
        await _capture.discard();
      } else {
        _capture.text = text;
      }
      if (mounted) Navigator.of(context).pop(text);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not finish. Your transcript is still available for review.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_capture.stop().whenComplete(() => _lease.release(_owner)));
    WidgetsBinding.instance.removeObserver(this);
    _capture.removeListener(_changed);
    _capture.dispose();
    _mic.removeListener(_permissionChanged);
    if (widget.permission == null) _mic.dispose();
    _review.dispose();
    super.dispose();
  }

  (String, IconData) _status(bool waiting) {
    if (!_mic.granted &&
        _capture.id == null &&
        _mic.status != MicStatus.unknown) {
      return ('Waiting for your microphone', Icons.mic_off_rounded);
    }
    return switch (_capture.phase) {
      CapturePhase.idle => ('Ready when you are', Icons.mic_none_rounded),
      CapturePhase.connecting => ('Getting ready…', Icons.more_horiz_rounded),
      CapturePhase.recording => ('Listening', Icons.graphic_eq_rounded),
      CapturePhase.stopping || CapturePhase.processing => (
        'Working on your words…',
        Icons.more_horiz_rounded,
      ),
      CapturePhase.review => ('Review your words', Icons.edit_note_rounded),
      CapturePhase.error => ('Paused', Icons.pause_rounded),
    };
  }

  Widget? _card(Color ink, {required bool waiting, required bool reviewable}) {
    if (_capture.id == null || !_mic.granted) {
      final mic = VoiceBottomCard.microphone(permission: _mic, ink: ink);
      if (mic != null) return mic;
    }
    final message = _capture.message;
    if (waiting || _capture.recording || message == null) return null;
    if (_capture.phase != CapturePhase.error &&
        _capture.phase != CapturePhase.review) {
      return null;
    }
    final (action, onAction) = !reviewable && _capture.id != null
        ? (
            _capture.canTranscribeAgain ? 'Retry' : 'Try again',
            () => _withLease(
              _capture.canTranscribeAgain ? _capture.retry : _capture.start,
            ),
          )
        : _capture.canTranscribeAgain
        ? ('Transcribe again', () => _withLease(_capture.transcribeAgain))
        : (null, null);
    return VoiceBottomCard(
      key: const ValueKey('voice-note-card'),
      ink: ink,
      icon: Icons.info_outline_rounded,
      title: message,
      action: action,
      onAction: onAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _capture.recording;
    final waiting = [
      CapturePhase.connecting,
      CapturePhase.stopping,
      CapturePhase.processing,
    ].contains(_capture.phase);
    final reviewable = !active && !waiting && _capture.text.isNotEmpty;
    final ink = VoiceColors.of(context).ink;
    final reduced = mediaMotionDisabled(context);
    final (label, icon) = _status(waiting);
    final (actionLabel, actionIcon, onAction) = reviewable
        ? (
            'Continue recording',
            Icons.mic_rounded,
            _mic.granted
                ? () =>
                      _withLease(() => _capture.continueRecording(_review.text))
                : null,
          )
        : _capture.id == null && !active
        ? (
            'Record',
            Icons.mic_rounded,
            _mic.granted && !waiting ? () => _withLease(_capture.start) : null,
          )
        : (null, null, null);
    final (primary, onPrimary) = active
        ? ('Stop · review', _capture.stop)
        : reviewable
        ? (
            widget.target == 'flow' ? 'Save thought' : 'Use transcript',
            _saving ? null : _use,
          )
        : waiting
        ? ('Cancel', () => Navigator.of(context).pop())
        : ('Close', () => Navigator.of(context).pop());
    return PopScope(
      canPop: !active && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && active) unawaited(_capture.stop());
      },
      child: VoiceSessionScaffold(
        background: VoiceAmbientBackground(
          mode: VoiceSessionMode.transcription,
          phase: active
              ? VoiceSessionPhase.listening
              : waiting
              ? VoiceSessionPhase.thinking
              : VoiceSessionPhase.paused,
          activity: VoiceAudioActivity(level: _capture.level, pitch: .5),
          reducedMotion: reduced,
        ),
        header: VoiceSessionHeader(
          title: widget.title,
          onClose: () => Navigator.of(context).maybePop(),
          trailing: IconButton(
            tooltip: 'Discard recording',
            onPressed: _saving
                ? null
                : () async {
                    await _capture.discard();
                    if (mounted) _review.clear();
                  },
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
          ),
        ),
        status: VoiceSessionStatus(label: label, icon: icon),
        transcript: reviewable
            ? Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 18),
                child: TextField(
                  key: const ValueKey('voice-review-field'),
                  controller: _review,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.bottom,
                  style: TextStyle(
                    color: ink.withValues(alpha: .94),
                    fontSize: 23,
                    height: 1.45,
                    letterSpacing: -.45,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Your words',
                    hintStyle: TextStyle(color: ink.withValues(alpha: .4)),
                  ),
                  onChanged: (value) {
                    _capture.text = value;
                    _lastTranscript = value;
                  },
                ),
              )
            : VoiceTranscript(
                turns: [
                  if (_capture.text.isNotEmpty)
                    VoiceTranscriptTurn(
                      speaker: VoiceSpeaker.user,
                      text: _capture.text,
                      isFinal: !active,
                    ),
                ],
                mode: VoiceSessionMode.transcription,
                ink: ink,
                reducedMotion: reduced,
              ),
        card: _card(ink, waiting: waiting, reviewable: reviewable),
        controls: VoiceSessionControls(
          actionLabel: actionLabel,
          actionIcon: actionIcon,
          onAction: onAction,
          primaryLabel: primary,
          onPrimary: onPrimary,
        ),
      ),
    );
  }
}
