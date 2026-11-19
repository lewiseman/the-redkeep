import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redkeep/features/ai/data/cloud_ai_client.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';

import '../../support/fake_ai_provider.dart';

const _request = AiChatRequest(
  model: 'test-model',
  system: 'Edit the note.',
  user: '{"text":"a","intent":"b"}',
  outputTokens: 100,
);

String _events(List<Object> events) => [
  for (final event in events)
    'data: ${event is String ? event : jsonEncode(event)}\n\n',
].join();

void main() {
  final sent = <Map<String, dynamic>>[];
  CloudAiClient client(List<(int, String)> replies) => CloudAiClient(
    AiTransport(
      MockClient.streaming((request, body) async {
        sent.add(
          jsonDecode(await body.bytesToString()) as Map<String, dynamic>,
        );
        final (status, text) = replies.removeAt(0);
        // Split mid-line, as a network would.
        final bytes = utf8.encode(text);
        return http.StreamedResponse(
          Stream.fromIterable([
            bytes.sublist(0, bytes.length ~/ 2),
            bytes.sublist(bytes.length ~/ 2),
          ]),
          status,
        );
      }),
      delay: (_) async {},
    ),
  );
  setUp(sent.clear);

  test('OpenAI-compatible answers stream in pieces with their usage', () async {
    final pieces = await client([
      (
        200,
        _events([
          {
            'choices': [
              {
                'delta': {'content': 'Hello'},
              },
            ],
          },
          {
            'choices': [
              {
                'delta': {'content': ', world'},
                'finish_reason': 'stop',
              },
            ],
          },
          {
            'choices': [],
            'usage': {'prompt_tokens': 12, 'completion_tokens': 3},
          },
          '[DONE]',
        ]),
      ),
    ]).chatStream(testAiSettings, _request).toList();

    expect(pieces.map((p) => p.text).join(), 'Hello, world');
    expect(pieces.last.usage?.inputTokens, 12);
    expect(pieces.last.usage?.outputTokens, 3);
    expect(sent.single['stream'], isTrue);
    expect(sent.single['stream_options'], {'include_usage': true});
  });

  test('a rejected request is sent once more without the extras', () async {
    final pieces = await client([
      (400, '{"error":{"message":"Unknown parameter: stream_options"}}'),
      (
        200,
        _events([
          {
            'choices': [
              {
                'delta': {'content': 'Fine'},
              },
            ],
          },
          '[DONE]',
        ]),
      ),
    ]).chatStream(testAiSettings, _request).toList();

    expect(pieces.map((p) => p.text).join(), 'Fine');
    expect(sent.last.containsKey('stream_options'), isFalse);
    expect(sent.last.containsKey('temperature'), isFalse);
  });

  test('attached images stream with the text of the request', () async {
    await client([
          (
            200,
            _events([
              {
                'choices': [
                  {
                    'delta': {'content': 'Read'},
                  },
                ],
              },
              '[DONE]',
            ]),
          ),
        ])
        .chatStream(
          testAiSettings,
          AiChatRequest(
            model: 'test-model',
            system: 'Edit the note.',
            user: _request.user,
            outputTokens: 100,
            images: [
              AiImageInput(Uint8List.fromList([1, 2, 3]), mime: 'image/png'),
            ],
          ),
        )
        .toList();

    final parts = (sent.single['messages'] as List).last['content'] as List;
    expect(parts.first, {'type': 'text', 'text': _request.user});
    expect(parts.last['image_url']['url'], 'data:image/png;base64,AQID');
  });

  test('a bad key fails before anything streams', () async {
    await expectLater(
      client([(401, '{}')]).chatStream(testAiSettings, _request).toList(),
      throwsA(
        isA<AiProviderFailure>().having(
          (f) => f.kind,
          'kind',
          AiProviderFailureKind.badToken,
        ),
      ),
    );
  });
}
