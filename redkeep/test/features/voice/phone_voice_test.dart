import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/voice/application/phone_voice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'getEngines' => ['installed.engine'],
            'getDefaultEngine' => 'installed.engine',
            'getVoices' => [
              {'name': 'online', 'locale': 'en-US', 'network_required': '1'},
              {'name': 'offline', 'locale': 'en-US', 'network_required': '0'},
            ],
            _ => 1,
          };
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'removed engine and voice fall back to an installed offline voice',
    () async {
      final voice = PhoneGuideVoice(
        () async => {
          'engine': 'removed.engine',
          'name': 'removed',
          'locale': 'en-US',
        },
      );
      await voice.speak('Synthetic setup guidance');
      expect(
        calls.where((c) => c.method == 'setEngine').single.arguments,
        'installed.engine',
      );
      expect(
        (calls.where((c) => c.method == 'setVoice').single.arguments
            as Map)['name'],
        'offline',
      );
      expect(calls.where((c) => c.method == 'speak'), hasLength(1));
      await voice.stop();
      expect(calls.last.method, 'stop');
    },
  );
  test('leaving during voice preparation suppresses late playback', () async {
    final preference = Completer<Map<String, String>?>();
    final voice = PhoneGuideVoice(() => preference.future);
    final speaking = voice.speak('Synthetic guidance');
    await Future<void>.delayed(Duration.zero);
    await voice.stop();
    preference.complete(null);
    await speaking;
    expect(calls.where((c) => c.method == 'speak'), isEmpty);
  });
}
