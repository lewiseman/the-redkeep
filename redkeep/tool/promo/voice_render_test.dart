// Renders the dictation page for the promo video, frame by frame, with a
// fake microphone and transcriber (the emulator has no working microphone).
//
// Offline. Run from `redkeep/`:
//   flutter test tool/promo/voice_render_test.dart
// Writes docs/play-store/promo-video/work/gfx/voice.mp4 (1080x2424, 60 fps).
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/voice/application/mic_permission.dart';
import 'package:redkeep/features/voice/application/voice_capture.dart';
import 'package:redkeep/features/voice/application/voice_coordination.dart';
import 'package:redkeep/features/voice/data/pcm_recorder.dart';
import 'package:redkeep/features/voice/presentation/voice_capture_page.dart';

const _work = 'docs/play-store/promo-video/work';
const _out = '$_work/gfx/voice.mp4';
const _fps = 60;
const _words =
    'Pick up oat milk on the way home, and call Mum about Sunday lunch.';

/// Speech-like PCM bursts while "recording".
class _Recorder extends PcmRecorder {
  Timer? _timer;
  @override
  Future<void> start({
    required String path,
    required void Function(Uint8List) onData,
    required void Function() onStopped,
    required void Function(Object) onError,
  }) async {
    File(path).writeAsBytesSync(Uint8List(32000));
    var tick = 0;
    final random = math.Random(7);
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      tick++;
      // Syllables: a quick rise and fall every few ticks, quieter pauses.
      final syllable = math.sin(tick * 0.9).abs();
      final pause = (tick ~/ 14).isOdd && tick % 14 > 10 ? 0.15 : 1.0;
      final amp =
          (0.04 + 0.11 * syllable * pause * (0.7 + 0.3 * random.nextDouble()));
      final data = ByteData(1600);
      for (var i = 0; i < 800; i++) {
        final v = (math.sin(i * 0.31) * amp * 32767).round();
        data.setInt16(i * 2, v, Endian.little);
      }
      onData(data.buffer.asUint8List());
    });
  }

  @override
  Future<void> stop() async => _timer?.cancel();
}

Future<void> _loadFonts() async {
  // The SDK's icon font, which widget tests otherwise draw as boxes.
  final sdk = Platform.environment['FLUTTER_ROOT']!;
  for (final (family, path) in [
    ('Poppins', '$_work/fonts/Poppins-Regular.ttf'),
    ('Caveat', '$_work/fonts/Caveat-Medium.ttf'),
    ('Lora', '$_work/fonts/Lora.ttf'),
    (
      'MaterialIcons',
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ),
  ]) {
    final loader = FontLoader(family)
      ..addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
    await loader.load();
  }
}

void main() {
  testWidgets('render dictation', (tester) async {
    await tester.runAsync(_loadFonts);
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('promo-voice-'),
    );
    const mic = MethodChannel('promo/mic');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(mic, (call) async => 'granted');
    messenger.setMockMethodCallHandler(
      VoiceCapture.methods,
      (call) async => call.method == 'permission' ? true : null,
    );

    tester.view.physicalSize = const Size(1080, 2424);
    tester.view.devicePixelRatio = 2.625;
    final key = GlobalKey();
    final base = RedkeepTheme.forAppearance(Brightness.light, AppAccent.olive);
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Poppins'),
    );

    final container = ProviderContainer(
      overrides: [
        voiceCaptureFactoryProvider.overrideWithValue(
          (target) => VoiceCapture(
            target: target,
            recorder: _Recorder(),
            directory: () async => root!,
            supported: true,
            transcribe: (wav, seconds, abort) async {
              await Future<void>.delayed(const Duration(milliseconds: 1300));
              return _words;
            },
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            builder: (context, child) => RenderingPolicyHost(
              preferences: const AppearancePreferences(),
              child: child!,
            ),
            home: _StatusBar(
              child: VoiceCapturePage(
                title: 'Dictate a note',
                permission: MicPermission(methods: mic, supported: true),
              ),
            ),
          ),
        ),
      ),
    );

    Directory('$_work/gfx').createSync(recursive: true);
    final ffmpeg = (await tester.runAsync(
      () => Process.start('ffmpeg', [
        '-y',
        '-v',
        'error',
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgba',
        '-s',
        '1080x2424',
        '-r',
        '$_fps',
        '-i',
        '-',
        '-c:v',
        'libx264',
        '-preset',
        'medium',
        '-crf',
        '14',
        '-pix_fmt',
        'yuv420p',
        _out,
      ]),
    ))!;
    Future<void> capture() async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.625);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        ffmpeg.stdin.add(bytes!.buffer.asUint8List());
        await ffmpeg.stdin.flush();
        // Let real file work in the capture finish between frames.
        await Future<void>.delayed(const Duration(milliseconds: 2));
      });
    }

    Future<void> run(double seconds) async {
      for (var i = 0; i < (seconds * _fps).round(); i++) {
        await tester.pump(const Duration(microseconds: 1000000 ~/ _fps));
        await capture();
      }
    }

    await run(3.6);
    final stop = find.text('Stop · review');
    if (stop.evaluate().isNotEmpty) await tester.tap(stop);
    await run(4.4);
    await tester.runAsync(() async {
      await ffmpeg.stdin.close();
      await ffmpeg.exitCode;
    });
    // Close the page while its providers still exist, then drop them.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    messenger.setMockMethodCallHandler(mic, null);
    messenger.setMockMethodCallHandler(VoiceCapture.methods, null);
  }, timeout: Timeout.none);
}

/// The phone's status bar, as the screen recordings show it.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(padding: const EdgeInsets.only(top: 44, bottom: 24)),
    child: Stack(
      children: [
        Positioned.fill(child: child),
        const Positioned(
          left: 26,
          top: 12,
          child: Text(
            '9:41',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: Colors.black,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Positioned(
          right: 22,
          top: 15,
          child: Container(
            width: 24,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    ),
  );
}
