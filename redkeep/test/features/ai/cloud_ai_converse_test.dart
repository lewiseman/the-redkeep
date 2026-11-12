import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redkeep/features/ai/data/cloud_ai_client.dart';
import 'package:redkeep/features/ai/domain/ai_conversation.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';

import '../../support/fake_ai_provider.dart';

const _anthropic = AiCloudSettings(
  presetId: 'anthropic',
  baseUrl: 'https://anthropic.example/v1',
  token: 'secret-token',
  models: {AiCapability.chat: 'claude-test'},
);

const _tool = AiToolSpec(
  name: 'update_website',
  description: 'Change the website.',
  parameters: {
    'type': 'object',
    'properties': {
      'instruction': {'type': 'string'},
    },
    'required': ['instruction'],
  },
);

const _request = AiConverseRequest(
  model: 'test-model',
  system: 'Be the Maester.',
  history: [
    AiExchange(
      user: 'Make it darker',
      reply: 'Darkening it.',
      calls: [
        AiToolCall(
          id: 'call.1',
          name: 'update_website',
          arguments: {'instruction': 'Darker'},
        ),
      ],
      results: [AiToolResult('call.1', 'The person kept this change.')],
    ),
  ],
  user: 'Now add a quiz',
  tools: [_tool],
  outputTokens: 100,
);

void main() {
  late http.Request sent;
  CloudAiClient client(Object reply) => CloudAiClient(
    AiTransport(
      MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode(reply),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      online: () async => true,
      delay: (_) async {},
    ),
  );

  test('OpenAI turns send tools and history and read tool calls', () async {
    final ai = client({
      'choices': [
        {
          'finish_reason': 'tool_calls',
          'message': {
            'content': null,
            'tool_calls': [
              {
                'id': 'call_2',
                'type': 'function',
                'function': {
                  'name': 'update_website',
                  'arguments': '{"instruction":"Add a quiz"}',
                },
              },
              // Broken arguments are dropped, not guessed.
              {
                'id': 'call_3',
                'type': 'function',
                'function': {'name': 'update_website', 'arguments': '{'},
              },
            ],
          },
        },
      ],
      'usage': {'prompt_tokens': 40, 'completion_tokens': 9},
    });
    final result = await ai.converse(testAiSettings, _request);
    expect(result.value.text, isEmpty);
    expect(result.value.calls.single.id, 'call_2');
    expect(result.value.calls.single.arguments, {'instruction': 'Add a quiz'});
    expect(result.usage.inputTokens, 40);
    final body = jsonDecode(sent.body) as Map;
    expect(sent.url.path, '/v1/chat/completions');
    expect(body['tools'].single['function']['name'], 'update_website');
    final messages = body['messages'] as List;
    expect(messages.map((m) => m['role']), [
      'system',
      'user',
      'assistant',
      'tool',
      'user',
    ]);
    expect(jsonDecode(messages[2]['tool_calls'][0]['function']['arguments']), {
      'instruction': 'Darker',
    });
    expect(messages[3]['tool_call_id'], 'call.1');
    expect(messages[4]['content'], 'Now add a quiz');
  });

  test('Anthropic turns put tool results before the next message', () async {
    final ai = client({
      'stop_reason': 'tool_use',
      'content': [
        {'type': 'text', 'text': 'Adding a quiz.'},
        {
          'type': 'tool_use',
          'id': 'toolu_2',
          'name': 'update_website',
          'input': {'instruction': 'Add a quiz'},
        },
      ],
      'usage': {'input_tokens': 30, 'output_tokens': 7},
    });
    final result = await ai.converse(_anthropic, _request);
    expect(result.value.text, 'Adding a quiz.');
    expect(result.value.calls.single.name, 'update_website');
    final body = jsonDecode(sent.body) as Map;
    expect(sent.url.path, '/v1/messages');
    expect(body['system'], 'Be the Maester.');
    expect(body['tools'].single['input_schema']['required'], ['instruction']);
    final messages = body['messages'] as List;
    expect(messages.map((m) => m['role']), ['user', 'assistant', 'user']);
    // Ids from another provider are made plain.
    expect(messages[1]['content'][1], {
      'type': 'tool_use',
      'id': 'call_1',
      'name': 'update_website',
      'input': {'instruction': 'Darker'},
    });
    expect(messages[2]['content'], [
      {
        'type': 'tool_result',
        'tool_use_id': 'call_1',
        'content': 'The person kept this change.',
      },
      {'type': 'text', 'text': 'Now add a quiz'},
    ]);
  });

  test(
    'models that take tools only in the Responses API are asked there',
    () async {
      final requests = <http.Request>[];
      final ai = CloudAiClient(
        AiTransport(
          MockClient((request) async {
            requests.add(request);
            return requests.length == 1
                ? http.Response(
                    '{"error":{"message":"Function tools with reasoning_effort are not supported for this model in /v1/chat/completions. To use function tools, use /v1/responses."}}',
                    400,
                  )
                : http.Response(
                    jsonEncode({
                      'status': 'completed',
                      'output': [
                        {'type': 'reasoning', 'summary': []},
                        {
                          'type': 'message',
                          'content': [
                            {'type': 'output_text', 'text': 'Adding a quiz.'},
                          ],
                        },
                        {
                          'type': 'function_call',
                          'call_id': 'call_9',
                          'name': 'update_website',
                          'arguments': '{"instruction":"Add a quiz"}',
                        },
                      ],
                      'usage': {'input_tokens': 50, 'output_tokens': 20},
                    }),
                    200,
                    headers: {'content-type': 'application/json'},
                  );
          }),
          online: () async => true,
          delay: (_) async {},
        ),
      );
      final result = await ai.converse(testAiSettings, _request);
      expect(result.value.text, 'Adding a quiz.');
      expect(result.value.calls.single.arguments, {
        'instruction': 'Add a quiz',
      });
      expect(result.usage.outputTokens, 20);
      expect(requests.last.url.path, '/v1/responses');
      final body = jsonDecode(requests.last.body) as Map;
      expect(body['instructions'], 'Be the Maester.');
      expect(body['tools'].single['name'], 'update_website');
      expect((body['input'] as List).map((i) => i['type'] ?? i['role']), [
        'user',
        'assistant',
        'function_call',
        'function_call_output',
        'user',
      ]);
    },
  );

  test('a turn with neither words nor calls is refused', () async {
    final ai = client({
      'choices': [
        {
          'finish_reason': 'stop',
          'message': {'content': '  '},
        },
      ],
    });
    await expectLater(
      ai.converse(testAiSettings, _request),
      throwsA(
        isA<AiProviderFailure>().having(
          (f) => f.kind,
          'kind',
          AiProviderFailureKind.invalidResponse,
        ),
      ),
    );
  });
}
