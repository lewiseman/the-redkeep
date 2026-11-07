import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redkeep/features/ai/data/cloud_ai_client.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';

import '../../support/fake_ai_provider.dart';

const _anthropic = AiCloudSettings(
  presetId: 'anthropic',
  baseUrl: 'https://anthropic.example/v1',
  token: 'secret-token',
  models: {AiCapability.chat: 'claude-test'},
);

void main() {
  late List<http.BaseRequest> sent;
  late List<Duration> waits;
  late bool online;

  CloudAiClient client(
    FutureOr<http.Response> Function(http.Request request, int attempt) reply,
  ) {
    sent = [];
    waits = [];
    online = true;
    var attempt = 0;
    final transport = AiTransport(
      MockClient((request) async {
        sent.add(request);
        return reply(request, ++attempt);
      }),
      online: () async => online,
      delay: (duration) async => waits.add(duration),
      random: Random(1),
    );
    return CloudAiClient(transport);
  }

  http.Response json(Object body, [int status = 200, Map<String, String>? h]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json', ...?h},
      );

  const chat = AiChatRequest(
    model: 'test-model',
    system: 'Be brief.',
    user: 'Hello',
    outputTokens: 50,
  );

  test('chat follows OpenAI conventions and reports usage', () async {
    final ai = client(
      (_, _) => json({
        'choices': [
          {
            'finish_reason': 'stop',
            'message': {'content': 'Hi'},
          },
        ],
        'usage': {'prompt_tokens': 12, 'completion_tokens': 3},
      }),
    );
    final result = await ai.chat(testAiSettings, chat);
    expect(result.value, 'Hi');
    expect(result.usage.inputTokens, 12);
    expect(result.usage.outputTokens, 3);
    final request = sent.single as http.Request;
    expect(request.url.toString(), 'https://ai.example/v1/chat/completions');
    expect(request.headers['authorization'], 'Bearer secret-token');
    final body = jsonDecode(request.body) as Map;
    expect(body['max_completion_tokens'], 50);
    expect(body['messages'][1]['content'], 'Hello');
  });

  test(
    'images go as data URLs to OpenAI and base64 blocks to Anthropic',
    () async {
      final image = AiImageInput(
        Uint8List.fromList([1, 2, 3]),
        mime: 'image/png',
      );
      var ai = client(
        (_, _) => json({
          'choices': [
            {
              'message': {'content': '{}'},
            },
          ],
        }),
      );
      await ai.chat(
        testAiSettings,
        AiChatRequest(
          model: 'm',
          system: 's',
          user: 'Describe',
          outputTokens: 10,
          images: [image],
        ),
      );
      final parts =
          (jsonDecode((sent.single as http.Request).body)
                  as Map)['messages'][1]['content']
              as List;
      expect(parts.last['image_url']['url'], 'data:image/png;base64,AQID');

      ai = client(
        (_, _) => json({
          'content': [
            {'type': 'text', 'text': 'Ok'},
          ],
          'usage': {'input_tokens': 7, 'output_tokens': 2},
        }),
      );
      final result = await ai.chat(
        _anthropic,
        AiChatRequest(
          model: 'claude-test',
          system: 's',
          user: 'Describe',
          outputTokens: 10,
          images: [image],
        ),
      );
      final request = sent.single as http.Request;
      expect(request.url.path, '/v1/messages');
      expect(request.headers['x-api-key'], 'secret-token');
      final content =
          (jsonDecode(request.body) as Map)['messages'][0]['content'] as List;
      expect(content.first['source']['data'], 'AQID');
      expect(result.usage.inputTokens, 7);
    },
  );

  test('embeddings batch every input in one request, in order', () async {
    final ai = client(
      (_, _) => json({
        'data': [
          {
            'index': 1,
            'embedding': [0.0, 1.0],
          },
          {
            'index': 0,
            'embedding': [1.0, 0.0],
          },
        ],
        'usage': {'prompt_tokens': 4},
      }),
    );
    final result = await ai.embed(testAiSettings, 'test-embed', ['a', 'b']);
    expect(result.value, [
      [1.0, 0.0],
      [0.0, 1.0],
    ]);
    expect(sent, hasLength(1));
    expect((jsonDecode((sent.single as http.Request).body) as Map)['input'], [
      'a',
      'b',
    ]);
  });

  test('transcription uploads one file and returns plain text', () async {
    late http.MultipartRequest upload;
    final transport = AiTransport(
      MockClient.streaming((request, body) async {
        upload = request as http.MultipartRequest;
        await body.drain<void>();
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'text': ' Hello there '}))),
          200,
        );
      }),
    );
    final result = await CloudAiClient(
      transport,
    ).transcribe(testAiSettings, 'test-transcribe', Uint8List(10), seconds: 30);
    expect(result.value, 'Hello there');
    expect(result.usage.seconds, 30);
    expect(upload.url.path, '/v1/audio/transcriptions');
    expect(upload.fields['model'], 'test-transcribe');
    expect(upload.files.single.filename, 'speech.wav');
  });

  test('image generation decodes base64 output', () async {
    final ai = client(
      (_, _) => json({
        'data': [
          {
            'b64_json': base64Encode([9, 8, 7]),
          },
        ],
      }),
    );
    final result = await ai.generateImage(testAiSettings, 'test-image', 'sea');
    expect(result.value, [9, 8, 7]);
    expect(result.usage.images, 1);
  });

  test(
    'Anthropic has no embeddings, speech or images, and sends nothing',
    () async {
      final ai = client((_, _) => json({}));
      for (final call in <Future<Object?> Function()>[
        () => ai.embed(_anthropic, 'm', ['a']),
        () => ai.transcribe(_anthropic, 'm', Uint8List(4)),
        () => ai.generateImage(_anthropic, 'm', 'p'),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<AiProviderFailure>().having(
              (f) => f.kind,
              'kind',
              AiProviderFailureKind.unsupported,
            ),
          ),
        );
      }
      expect(sent, isEmpty);
    },
  );

  test('rate limits back off, honouring Retry-After, then succeed', () async {
    final ai = client(
      (_, attempt) => attempt == 1
          ? json({}, 429, {'retry-after': '3'})
          : attempt == 2
          ? json({}, 503)
          : json({
              'choices': [
                {
                  'message': {'content': 'Done'},
                },
              ],
            }),
    );
    expect((await ai.chat(testAiSettings, chat)).value, 'Done');
    expect(sent, hasLength(3));
    expect(waits, hasLength(2));
    expect(waits[0].inSeconds, 3);
    expect(waits[1].inMilliseconds, inInclusiveRange(2000, 2250));
  });

  test('persistent rate limits give up after three attempts', () async {
    final ai = client((_, _) => json({}, 429));
    await expectLater(
      ai.chat(testAiSettings, chat),
      throwsA(
        isA<AiProviderFailure>().having(
          (f) => f.kind,
          'kind',
          AiProviderFailureKind.rateLimited,
        ),
      ),
    );
    expect(sent, hasLength(3));
  });

  test('an invalid key fails at once without retrying', () async {
    final ai = client((_, _) => json({}, 401));
    await expectLater(
      ai.chat(testAiSettings, chat),
      throwsA(
        isA<AiProviderFailure>().having(
          (f) => f.kind,
          'kind',
          AiProviderFailureKind.badToken,
        ),
      ),
    );
    expect(sent, hasLength(1));
    expect(waits, isEmpty);
  });

  test('offline fails before anything is sent', () async {
    final ai = client((_, _) => json({}));
    online = false;
    await expectLater(
      ai.chat(testAiSettings, chat),
      throwsA(
        isA<AiProviderFailure>().having(
          (f) => f.kind,
          'kind',
          AiProviderFailureKind.offline,
        ),
      ),
    );
    expect(sent, isEmpty);
  });

  test('a plain http address is refused before the key is sent', () async {
    final ai = client((_, _) => json({}));
    await expectLater(
      ai.chat(testAiSettings.copyWith(baseUrl: 'http://ai.example/v1'), chat),
      throwsA(isA<AiProviderFailure>()),
    );
    expect(sent, isEmpty);
  });
}
