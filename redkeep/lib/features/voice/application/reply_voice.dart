import 'package:flutter_tts/flutter_tts.dart';

class ReplyVoice {
  ReplyVoice({this.preference});
  final Future<Map<String, String>?> Function()? preference;
  final _tts = FlutterTts();
  bool enabled = true;
  int _epoch = 0;
  Future<void>? _ready;
  Future<void> _setup() async {
    await _tts.awaitSpeakCompletion(true);
    final saved = await preference?.call();
    final engines = (await _tts.getEngines as List? ?? []).cast<String>();
    final defaultEngine = await _tts.getDefaultEngine as String?;
    final engine = engines.contains(saved?['engine'])
        ? saved!['engine']
        : defaultEngine;
    if (engine != null) await _tts.setEngine(engine);
    final voices = [
      for (final v in await _tts.getVoices as List? ?? [])
        Map<String, String>.from(v as Map),
    ];
    final offline = voices.where(
      (v) =>
          v['network_required'] != '1' && v['locale']?.startsWith('en') == true,
    );
    final chosen =
        offline
            .where(
              (v) =>
                  v['name'] == saved?['name'] &&
                  v['locale'] == saved?['locale'],
            )
            .firstOrNull ??
        offline.firstOrNull;
    if (chosen == null) {
      throw StateError('An offline reply voice is not available.');
    }
    await _tts.setVoice({'name': chosen['name']!, 'locale': chosen['locale']!});
  }

  Future<void> say(String text) async {
    final epoch = ++_epoch;
    if (!enabled) return;
    try {
      _ready ??= _setup();
      await _ready;
      await _tts.stop();
      if (enabled && epoch == _epoch) await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    ++_epoch;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
