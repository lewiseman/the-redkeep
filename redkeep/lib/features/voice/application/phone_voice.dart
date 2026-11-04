import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../ai/application/ai_preferences.dart';

abstract interface class GuideVoice {
  Future<void> speak(String text);
  Future<void> stop();
}

final guideVoiceProvider = Provider<GuideVoice>((ref) {
  final voice = PhoneGuideVoice(
    () async => (await ref.read(aiPreferencesRepositoryProvider).read()).voice,
  );
  ref.onDispose(voice.stop);
  return voice;
});

class PhoneGuideVoice implements GuideVoice {
  PhoneGuideVoice(this.preference);
  final Future<Map<String, String>?> Function() preference;
  FlutterTts? _tts;
  int _epoch = 0;
  @override
  Future<void> speak(String text) async {
    final epoch = ++_epoch;
    final tts = _tts ??= FlutterTts();
    await tts.stop();
    final chosen = await preference();
    final engines = (await tts.getEngines as List? ?? []).cast<String>();
    final savedEngine = chosen?['engine'];
    final defaultEngine = await tts.getDefaultEngine as String?;
    final engine = engines.contains(savedEngine) ? savedEngine : defaultEngine;
    if (engine != null) await tts.setEngine(engine);
    final voices = [
      for (final voice in (await tts.getVoices as List? ?? []))
        Map<String, String>.from(voice as Map),
    ];
    final offline = voices
        .where(
          (v) =>
              v['network_required'] != '1' &&
              v['locale']?.startsWith('en') == true,
        )
        .toList();
    final voice =
        offline
            .where(
              (v) =>
                  v['name'] == chosen?['name'] &&
                  v['locale'] == chosen?['locale'],
            )
            .firstOrNull ??
        offline.firstOrNull;
    if (voice == null) {
      throw StateError('Download an offline English voice in phone settings.');
    }
    await tts.setVoice({'name': voice['name']!, 'locale': voice['locale']!});
    await tts.setSpeechRate(.42);
    if (epoch == _epoch) await tts.speak(text);
  }

  @override
  Future<void> stop() async {
    _epoch++;
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
