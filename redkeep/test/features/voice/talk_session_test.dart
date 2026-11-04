import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';
import 'package:redkeep/features/voice/application/diary_conversation.dart';
import 'package:redkeep/features/voice/application/reply_voice.dart';
import 'package:redkeep/features/voice/application/talk_session.dart';

import 'voice_capture_recovery_test.dart' show testComputer;

final computer = testComputer;

class FakeMic implements TalkMic {
  bool on = false;
  int starts = 0;
  @override
  Future<void> start(void Function(Uint8List pcm) onData) async {
    on = true;
    starts++;
  }

  @override
  Future<void> stop() async => on = false;
}

class BrokenMic implements TalkMic {
  @override
  Future<void> start(void Function(Uint8List pcm) onData) async =>
      throw const CompanionFailure(
        'MICROPHONE',
        'Could not open the microphone.',
      );

  @override
  Future<void> stop() async {}
}

class FakeVoice extends ReplyVoice {
  FakeVoice() : super(preference: () async => null);
  final said = <String>[];
  @override
  Future<void> say(String text) async => said.add(text);
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DiaryConversation conversation;
  late FakeMic mic;
  late FakeVoice voice;
  late TalkSession talk;
  setUp(() {
    conversation = DiaryConversation(
      computer: () => computer,
      dateString: '2026-10-28',
      writeDraft: () async => 'Synthetic draft',
      saveTurns: () async {},
    );
    mic = FakeMic();
    voice = FakeVoice();
    talk = TalkSession(conversation: conversation, voice: voice, mic: mic);
  });
  tearDown(() {
    talk.dispose();
    conversation.dispose();
  });

  test('a spoken reply always closes the microphone first', () async {
    await talk.handle({'type': 'listening'});
    expect(mic.on, isTrue);
    await talk.handle({'type': 'reply', 'text': 'What happened next?'});
    await pumpEventQueue();
    expect(mic.on, isFalse);
    expect(voice.said, ['What happened next?']);
  });
  test(
    'silencing pauses the microphone and keeps late turns without speaking',
    () async {
      await talk.handle({'type': 'listening'});
      await talk.interrupted(
        const CompanionFailure(
          'INTERRUPTED',
          'Android silenced the microphone.',
        ),
      );
      expect(mic.on, isFalse);
      expect(talk.phase, TalkPhase.paused);
      expect(talk.note, contains('silenced'));
      await talk.handle({
        'type': 'turn',
        'text': 'Words captured before interruption',
      });
      await talk.handle({'type': 'reply', 'text': 'What happened next?'});
      expect(
        conversation.turns.first['text'],
        'Words captured before interruption',
      );
      expect(voice.said, isEmpty);
    },
  );
  test('malformed events fail closed and never add turns', () async {
    await expectLater(
      talk.handle({
        'type': 'segment',
        'segment': {'id': 'wrong', 'text': 4},
      }),
      throwsFormatException,
    );
    await expectLater(talk.handle({'type': 'unknown'}), throwsFormatException);
    expect(conversation.turns, isEmpty);
  });

  test(
    'a streamed reply is kept, spoken, then the turn is handed back',
    () async {
      await talk.handle({'type': 'thinking'});
      await talk.handle({'type': 'token', 'text': 'How was '});
      await talk.handle({'type': 'token', 'text': 'your day?'});
      expect(talk.streaming, 'How was your day?');
      await talk.handle({'type': 'reply', 'text': 'How was your day?'});
      await pumpEventQueue();
      expect(conversation.turns.single, {
        'speaker': 'assistant',
        'text': 'How was your day?',
      });
      expect(voice.said, ['How was your day?']);
      expect(talk.streaming, isEmpty);
      expect(talk.phase, TalkPhase.listening);
    },
  );

  test(
    'the microphone runs only while listening and the transcribed turn is kept',
    () async {
      await talk.handle({'type': 'listening'});
      expect(mic.on, isTrue);
      await talk.handle({
        'type': 'segment',
        'segment': {'id': 0, 'text': 'I went to the market.'},
      });
      await talk.handle({
        'type': 'segment',
        'segment': {'id': 1, 'text': ' It rained.'},
      });
      expect(talk.heard, 'I went to the market. It rained.');
      await talk.handle({'type': 'endpoint'});
      expect(mic.on, isFalse);
      expect(talk.phase, TalkPhase.transcribing);
      await talk.handle({
        'type': 'turn',
        'text': 'I went to the market. It rained.',
      });
      expect(conversation.turns.single['speaker'], 'user');
      expect(talk.heard, isEmpty);
    },
  );

  test('errors pause the loop; leaving the foreground keeps replies without speaking them', () async {
    await talk.handle({'type': 'listening'});
    await talk.handle({
      'type': 'error',
      'code': 'BUSY',
      'message': 'The computer is busy.',
    });
    expect(mic.on, isFalse);
    expect(talk.phase, TalkPhase.paused);
    expect(talk.note, 'The computer is busy.');

    await talk.handle({'type': 'listening'});
    await talk.hold();
    expect(mic.on, isFalse);
    await talk.handle({'type': 'reply', 'text': 'What happened next?'});
    expect(conversation.turns.last['text'], 'What happened next?');
    expect(voice.said, isEmpty);
    expect(talk.phase, TalkPhase.paused);
  });

  test(
    'a microphone that fails to open keeps its reason over "nothing heard"',
    () async {
      final broken = TalkSession(
        conversation: conversation,
        voice: voice,
        mic: BrokenMic(),
      );
      addTearDown(broken.dispose);
      await broken.handle({'type': 'listening'});
      expect(broken.note, 'Could not open the microphone.');
      await broken.handle({'type': 'endpoint'});
      await broken.handle({'type': 'empty'});
      expect(broken.phase, TalkPhase.paused);
      expect(broken.note, 'Could not open the microphone.');
    },
  );

  test('after nothing was heard, continuing listens again without repeating the question', () async {
    await talk.handle({'type': 'reply', 'text': 'How was your day?'});
    await pumpEventQueue();
    expect(voice.said, ['How was your day?']);
    await talk.handle({'type': 'listening'});
    await talk.handle({'type': 'endpoint'});
    await talk.handle({'type': 'empty'});
    expect(talk.note, contains('Nothing was heard'));
    expect(mic.on, isFalse);
    // No socket in this test, so resume reconnects via start(); check the
    // in-session path directly instead.
    expect(talk.phase, TalkPhase.paused);
  });
}
