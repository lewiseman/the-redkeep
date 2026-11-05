import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redkeep/features/ai/data/http_ai_provider_client.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/ai/domain/ai_provider_catalog.dart';

const _token = 'secret-token';
const _openAi = AiProviderConnection(
  id: 'provider-a',
  presetId: 'openai',
  name: 'OpenAI',
  format: AiProviderFormat.openAiCompatible,
  baseUrl: 'https://ai.example/v1/',
  token: _token,
  tokenLimitParameter: 'max_completion_tokens',
);
const _anthropic = AiProviderConnection(
  id: 'provider-b',
  presetId: 'anthropic',
  name: 'Anthropic',
  format: AiProviderFormat.anthropic,
  baseUrl: 'https://ai.example/v1',
  token: _token,
);
const _request = AiCompletionRequest(
  model: 'test-model',
  system: 'Be brief.',
  user: 'Private words',
  outputTokens: 99,
  temperature: .4,
);
String _openAiReply(String text, [String reason = 'stop']) => jsonEncode({
  'choices': [
    {
      'finish_reason': reason,
      'message': {'content': text},
    },
  ],
});

Matcher _fails(AiProviderFailureKind kind) =>
    throwsA(isA<AiProviderFailure>().having((f) => f.kind, 'kind', kind));

/// Never answers, and honours the abort trigger as the real client does.
class _StallingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await (request as http.Abortable).abortTrigger;
    throw http.RequestAbortedException(request.url);
  }
}

void main() {
  test('OpenAI-compatible request shape and answer', () async {
    late http.Request sent;
    final client = HttpAiProviderClient(
      MockClient((request) async {
        sent = request;
        return http.Response(_openAiReply('Hello'), 200);
      }),
    );
    expect(await client.complete(_openAi, _request), 'Hello');
    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'https://ai.example/v1/chat/completions');
    expect(sent.headers['authorization'], 'Bearer $_token');
    expect(sent.followRedirects, isFalse);
    final body = jsonDecode(sent.body) as Map;
    expect(body['model'], 'test-model');
    expect(body['max_completion_tokens'], 99);
    expect(body['temperature'], .4);
    expect(body['messages'], [
      {'role': 'system', 'content': 'Be brief.'},
      {'role': 'user', 'content': 'Private words'},
    ]);
  });

  test('Anthropic request shape and answer', () async {
    late http.Request sent;
    final client = HttpAiProviderClient(
      MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'stop_reason': 'end_turn',
            'content': [
              {'type': 'thinking', 'thinking': 'ignored'},
              {'type': 'text', 'text': 'Hello'},
            ],
          }),
          200,
        );
      }),
    );
    expect(await client.complete(_anthropic, _request), 'Hello');
    expect(sent.url.toString(), 'https://ai.example/v1/messages');
    expect(sent.headers['x-api-key'], _token);
    expect(sent.headers['anthropic-version'], isNotEmpty);
    expect(sent.headers.containsKey('authorization'), isFalse);
    final body = jsonDecode(sent.body) as Map;
    expect(body['system'], 'Be brief.');
    expect(body['max_tokens'], 99);
    expect(body['messages'], [
      {'role': 'user', 'content': 'Private words'},
    ]);
  });

  test('an empty token sends no auth header', () async {
    late http.Request sent;
    final client = HttpAiProviderClient(
      MockClient((request) async {
        sent = request;
        return http.Response(_openAiReply('Hello'), 200);
      }),
    );
    await client.complete(_openAi.copyWith(token: ''), _request);
    expect(sent.headers.containsKey('authorization'), isFalse);
  });

  for (final scenario in [
    (status: 401, kind: AiProviderFailureKind.badToken),
    (status: 403, kind: AiProviderFailureKind.badToken),
    (status: 404, kind: AiProviderFailureKind.notFound),
    (status: 429, kind: AiProviderFailureKind.rateLimited),
    (status: 400, kind: AiProviderFailureKind.rejected),
    (status: 503, kind: AiProviderFailureKind.unavailable),
    (status: 302, kind: AiProviderFailureKind.badUrl),
  ]) {
    test(
      'HTTP ${scenario.status} is ${scenario.kind.name}, without its body',
      () async {
        final client = HttpAiProviderClient(
          MockClient(
            (_) async =>
                http.Response('leak $_token Private words', scenario.status),
          ),
        );
        try {
          await client.complete(_openAi, _request);
          fail('Expected a failure');
        } on AiProviderFailure catch (failure) {
          expect(failure.kind, scenario.kind);
          expect(failure.message, isNot(contains(_token)));
          expect(failure.message, isNot(contains('Private')));
          expect(failure.toString(), isNot(contains(_token)));
        }
      },
    );
  }

  test('a rejected temperature is retried once without it', () async {
    final bodies = <Map>[];
    final client = HttpAiProviderClient(
      MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map);
        return bodies.length == 1
            ? http.Response('Unsupported value: temperature', 400)
            : http.Response(_openAiReply('Hello'), 200);
      }),
    );
    expect(await client.complete(_openAi, _request), 'Hello');
    expect(bodies, hasLength(2));
    expect(bodies.last.containsKey('temperature'), isFalse);
  });

  test('a second temperature rejection stops retrying', () async {
    var calls = 0;
    final client = HttpAiProviderClient(
      MockClient((_) async {
        calls++;
        return http.Response('temperature', 400);
      }),
    );
    await expectLater(
      client.complete(_openAi, _request),
      _fails(AiProviderFailureKind.rejected),
    );
    expect(calls, 2);
  });

  test('truncated answers fail in both formats', () async {
    final openAi = HttpAiProviderClient(
      MockClient(
        (_) async => http.Response(_openAiReply('Half', 'length'), 200),
      ),
    );
    await expectLater(
      openAi.complete(_openAi, _request),
      _fails(AiProviderFailureKind.truncated),
    );
    final anthropic = HttpAiProviderClient(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'stop_reason': 'max_tokens',
            'content': [
              {'type': 'text', 'text': 'Half'},
            ],
          }),
          200,
        ),
      ),
    );
    await expectLater(
      anthropic.complete(_anthropic, _request),
      _fails(AiProviderFailureKind.truncated),
    );
  });

  test('unreadable and empty answers are invalid', () async {
    for (final body in [
      'not json',
      '[]',
      '{"choices":[]}',
      _openAiReply('  '),
    ]) {
      final client = HttpAiProviderClient(
        MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        client.complete(_openAi, _request),
        _fails(AiProviderFailureKind.invalidResponse),
        reason: body,
      );
    }
  });

  test('an oversized response is refused', () async {
    final client = HttpAiProviderClient(
      MockClient((_) async => http.Response('x' * (4 * 1024 * 1024 + 1), 200)),
    );
    await expectLater(
      client.complete(_openAi, _request),
      _fails(AiProviderFailureKind.invalidResponse),
    );
  });

  test('network errors read as offline', () async {
    final client = HttpAiProviderClient(
      MockClient((_) async => throw http.ClientException('private detail')),
    );
    await expectLater(
      client.complete(_openAi, _request),
      _fails(AiProviderFailureKind.offline),
    );
  });

  test('abort stops the request', () async {
    final abort = Completer<void>();
    final client = HttpAiProviderClient(_StallingClient());
    final running = client.complete(_openAi, _request, abort: abort.future);
    abort.complete();
    await expectLater(running, _fails(AiProviderFailureKind.cancelled));
  });

  test('the deadline stops a stalled request', () async {
    final client = HttpAiProviderClient(
      _StallingClient(),
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      client.complete(_openAi, _request),
      _fails(AiProviderFailureKind.timeout),
    );
  });

  test('only plain https addresses receive a token', () async {
    var calls = 0;
    final client = HttpAiProviderClient(
      MockClient((_) async {
        calls++;
        return http.Response(_openAiReply('Hello'), 200);
      }),
    );
    for (final url in [
      'http://ai.example/v1',
      'ftp://ai.example',
      'https://user:pass@ai.example/v1',
      'https://ai.example/v1?key=x',
      'https://ai.example/v1#x',
      'ai.example/v1',
      '',
    ]) {
      await expectLater(
        client.complete(_openAi.copyWith(baseUrl: url), _request),
        _fails(AiProviderFailureKind.badUrl),
        reason: url,
      );
    }
    expect(calls, 0);
  });

  test('models are listed sorted, with Gemini prefixes removed', () async {
    late http.Request sent;
    final client = HttpAiProviderClient(
      MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'zeta'},
              {'id': 'models/alpha'},
              {'nope': true},
            ],
          }),
          200,
        );
      }),
    );
    expect(await client.listModels(_openAi), ['alpha', 'zeta']);
    expect(sent.method, 'GET');
    expect(sent.url.toString(), 'https://ai.example/v1/models');
  });

  test('every catalog URL is valid and every preset ID is routable', () {
    for (final preset in aiProviderCatalog) {
      expect(RegExp(r'^[a-z]{2,20}$').hasMatch(preset.id), isTrue);
      if (preset != customAiProviderPreset) {
        parseAiProviderBaseUrl(preset.baseUrl);
      }
    }
  });

  group('stripSurroundingCodeFence', () {
    test('removes one surrounding fence', () {
      expect(stripSurroundingCodeFence('```json\n{"a":1}\n```'), '{"a":1}');
      expect(stripSurroundingCodeFence('```\nplain\n```\n'), 'plain');
    });
    test('leaves everything else exactly as written', () {
      for (final text in [
        '{"a":1}',
        'Before\n```\ncode\n```\nafter',
        '```\none\n```\nmiddle\n```\ntwo\n```',
      ]) {
        expect(stripSurroundingCodeFence(text), text);
      }
    });
  });
}
