import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/ai_provider.dart';

/// Rejects anything but a plain https:// address, before a token can be sent.
Uri parseAiProviderBaseUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const AiProviderFailure(AiProviderFailureKind.badUrl);
  }
  return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
}

typedef AiDelay = Future<void> Function(Duration duration);
typedef AiOnline = Future<bool> Function();

class AiHttpResponse {
  const AiHttpResponse(this.status, this.text, this.headers);
  final int status;
  final String text;
  final Map<String, String> headers;
}

/// Sends one call with the shared cloud rules: an offline check first, then
/// up to [attempts] tries with exponential backoff for rate limits, server
/// errors and dropped connections. Bad keys and bad requests never retry.
class AiTransport {
  AiTransport(
    this._client, {
    AiOnline? online,
    AiDelay? delay,
    Random? random,
    this.timeout = const Duration(seconds: 90),
    this.attempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 20),
  }) : _online = online ?? _alwaysOnline,
       _delay = delay ?? Future<void>.delayed,
       _random = random ?? Random();
  final http.Client _client;
  final AiOnline _online;
  final AiDelay _delay;
  final Random _random;
  final Duration timeout, baseDelay, maxDelay;
  final int attempts;
  static const _maxResponseBytes = 24 * 1024 * 1024;
  static Future<bool> _alwaysOnline() async => true;

  void close() => _client.close();

  Future<Map<String, dynamic>> json(
    AiCloudSettings settings,
    String method,
    String path, {
    Map<String, Object?>? body,
    Future<void>? abort,
    bool Function(AiHttpResponse response)? retryWithout,
    Map<String, Object?>? Function()? fallbackBody,

    /// Overrides [timeout] for one long call.
    Duration? timeout,
  }) async {
    var response = await _withRetries(
      () => _jsonRequest(settings, method, path, body),
      abort,
      timeout: timeout,
    );
    if (retryWithout != null &&
        fallbackBody != null &&
        retryWithout(response)) {
      response = await _withRetries(
        () => _jsonRequest(settings, method, path, fallbackBody()),
        abort,
        timeout: timeout,
      );
    }
    return _success(response);
  }

  Future<Map<String, dynamic>> multipart(
    AiCloudSettings settings,
    String path, {
    required Map<String, String> fields,
    required Uint8List file,
    required String filename,
    required String mime,
    Future<void>? abort,
  }) async => _success(
    await _withRetries(
      () => (Future<void> trigger) {
        final request = http.AbortableMultipartRequest(
          'POST',
          _uri(settings, path),
          abortTrigger: trigger,
        );
        request.fields.addAll(fields);
        // Providers read the audio format from the file name.
        request.files.add(
          http.MultipartFile.fromBytes('file', file, filename: filename),
        );
        _authorize(settings, request);
        return request;
      },
      abort,
    ),
  );

  Uri _uri(AiCloudSettings settings, String path) {
    final base = parseAiProviderBaseUrl(settings.baseUrl);
    return base.replace(path: '${base.path}$path');
  }

  void _authorize(AiCloudSettings settings, http.BaseRequest request) {
    // A redirect must not carry the token to another address.
    request
      ..followRedirects = false
      ..headers['accept'] = 'application/json';
    if (settings.format == AiProviderFormat.anthropic) {
      request.headers['anthropic-version'] = '2023-06-01';
      if (settings.token.isNotEmpty) {
        request.headers['x-api-key'] = settings.token;
      }
    } else if (settings.token.isNotEmpty) {
      request.headers['authorization'] = 'Bearer ${settings.token}';
    }
  }

  http.BaseRequest Function(Future<void>) _jsonRequest(
    AiCloudSettings settings,
    String method,
    String path,
    Map<String, Object?>? body,
  ) => (trigger) {
    final request = http.AbortableRequest(
      method,
      _uri(settings, path),
      abortTrigger: trigger,
    );
    _authorize(settings, request);
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return request;
  };

  Future<AiHttpResponse> _withRetries(
    http.BaseRequest Function(Future<void> trigger) Function() build,
    Future<void>? abort, {
    Duration? timeout,
  }) async {
    var cancelled = false;
    unawaited(abort?.then((_) => cancelled = true));
    for (var attempt = 1; ; attempt++) {
      if (cancelled) {
        throw const AiProviderFailure(AiProviderFailureKind.cancelled);
      }
      if (!await _online()) {
        throw const AiProviderFailure(AiProviderFailureKind.offline);
      }
      Duration? wait;
      try {
        final response = await _sendOnce(
          build(),
          abort,
          timeout ?? this.timeout,
        );
        final retryable =
            response.status == 429 ||
            const {500, 502, 503, 504}.contains(response.status);
        if (!retryable || attempt >= attempts) return response;
        wait = _retryAfter(response.headers['retry-after']);
      } on AiProviderFailure catch (failure) {
        if (failure.kind != AiProviderFailureKind.offline ||
            attempt >= attempts) {
          rethrow;
        }
      }
      wait ??= baseDelay * pow(2, attempt - 1).toInt();
      if (wait > maxDelay) wait = maxDelay;
      wait += Duration(milliseconds: _random.nextInt(250));
      await Future.any([_delay(wait), ?abort]);
    }
  }

  /// Seconds or an HTTP date. Anything unreadable falls back to backoff.
  Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = double.tryParse(value.trim());
    if (seconds != null) {
      return Duration(milliseconds: (seconds * 1000).round().clamp(0, 1 << 31));
    }
    try {
      final at = HttpDate.parse(value);
      final wait = at.difference(DateTime.now());
      return wait.isNegative ? Duration.zero : wait;
    } on FormatException {
      return null;
    }
  }

  Future<AiHttpResponse> _sendOnce(
    http.BaseRequest Function(Future<void> trigger) build,
    Future<void>? abort,
    Duration timeout,
  ) async {
    final trigger = Completer<void>();
    var timedOut = false, cancelled = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      if (!trigger.isCompleted) trigger.complete();
    });
    unawaited(
      abort?.then((_) {
        cancelled = true;
        if (!trigger.isCompleted) trigger.complete();
      }),
    );
    try {
      final response = await _client.send(build(trigger.future));
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (bytes.length > _maxResponseBytes) {
          throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
        }
      }
      return AiHttpResponse(
        response.statusCode,
        utf8.decode(bytes, allowMalformed: true),
        response.headers,
      );
    } on http.RequestAbortedException {
      throw AiProviderFailure(
        cancelled || !timedOut
            ? AiProviderFailureKind.cancelled
            : AiProviderFailureKind.timeout,
      );
    } on http.ClientException {
      if (cancelled) {
        throw const AiProviderFailure(AiProviderFailureKind.cancelled);
      }
      throw const AiProviderFailure(AiProviderFailureKind.offline);
    } on SocketException {
      throw const AiProviderFailure(AiProviderFailureKind.offline);
    } on TlsException {
      throw const AiProviderFailure(AiProviderFailureKind.offline);
    } finally {
      timer.cancel();
    }
  }

  Map<String, dynamic> _success(AiHttpResponse response) {
    final status = response.status;
    if (status < 200 || status >= 300) {
      throw AiProviderFailure(switch (status) {
        401 || 403 => AiProviderFailureKind.badToken,
        404 => AiProviderFailureKind.notFound,
        429 => AiProviderFailureKind.rateLimited,
        >= 500 => AiProviderFailureKind.unavailable,
        >= 300 && < 400 => AiProviderFailureKind.badUrl,
        _ => AiProviderFailureKind.rejected,
      });
    }
    try {
      final json = jsonDecode(response.text);
      if (json is Map<String, dynamic>) return json;
    } on FormatException {
      /* Reported below without echoing the body. */
    }
    throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
  }
}

int _int(Object? value) => value is num ? value.toInt() : 0;

/// OpenAI API conventions: chat completions, embeddings, audio
/// transcriptions, image generations and the model list.
class OpenAiCloudClient implements AiCloudClient {
  OpenAiCloudClient(this.transport);
  final AiTransport transport;

  @override
  Future<AiResult<String>> chat(
    AiCloudSettings settings,
    AiChatRequest request, {
    Future<void>? abort,
  }) async {
    Map<String, Object?> body({required bool temperature}) => {
      'model': request.model,
      settings.preset.tokenLimitParameter: request.outputTokens,
      'messages': [
        {'role': 'system', 'content': request.system},
        {
          'role': 'user',
          'content': request.images.isEmpty
              ? request.user
              : [
                  {'type': 'text', 'text': request.user},
                  for (final image in request.images)
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url':
                            'data:${image.mime};base64,${base64Encode(image.bytes)}',
                      },
                    },
                ],
        },
      ],
      if (temperature) 'temperature': request.temperature,
      if (temperature && request.topP != 1) 'top_p': request.topP,
    };
    final json = await transport.json(
      settings,
      'POST',
      '/chat/completions',
      body: body(temperature: true),
      abort: abort,
      timeout: request.timeout,
      // Some models only accept their default temperature.
      retryWithout: (r) =>
          r.status == 400 && r.text.toLowerCase().contains('temperature'),
      fallbackBody: () => body(temperature: false),
    );
    final choices = json['choices'];
    final choice = choices is List && choices.isNotEmpty ? choices.first : null;
    if (choice is! Map) {
      throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
    }
    if (choice['finish_reason'] == 'length') {
      throw const AiProviderFailure(AiProviderFailureKind.truncated);
    }
    final message = choice['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
    }
    final usage = json['usage'];
    return AiResult(
      content,
      AiUsage(
        inputTokens: usage is Map ? _int(usage['prompt_tokens']) : 0,
        outputTokens: usage is Map ? _int(usage['completion_tokens']) : 0,
      ),
    );
  }

  @override
  Future<AiResult<List<List<double>>>> embed(
    AiCloudSettings settings,
    String model,
    List<String> inputs, {
    Future<void>? abort,
  }) async {
    final json = await transport.json(
      settings,
      'POST',
      '/embeddings',
      body: {'model': model, 'input': inputs, 'encoding_format': 'float'},
      abort: abort,
    );
    final data = json['data'];
    if (data is! List || data.length != inputs.length) {
      throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
    }
    final vectors = List<List<double>?>.filled(inputs.length, null);
    for (final (i, item) in data.indexed) {
      final index = item is Map && item['index'] is int
          ? item['index'] as int
          : i;
      final embedding = item is Map ? item['embedding'] : null;
      if (index < 0 ||
          index >= inputs.length ||
          embedding is! List ||
          embedding.isEmpty ||
          embedding.any((v) => v is! num)) {
        throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
      }
      vectors[index] = [for (final v in embedding) (v as num).toDouble()];
    }
    if (vectors.any((v) => v == null)) {
      throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
    }
    final usage = json['usage'];
    return AiResult(
      [for (final v in vectors) v!],
      AiUsage(
        inputTokens: usage is Map
            ? _int(usage['prompt_tokens'] ?? usage['total_tokens'])
            : 0,
      ),
    );
  }

  @override
  Future<AiResult<String>> transcribe(
    AiCloudSettings settings,
    String model,
    Uint8List audio, {
    String filename = 'speech.wav',
    String mime = 'audio/wav',
    double seconds = 0,
    Future<void>? abort,
  }) async {
    final json = await transport.multipart(
      settings,
      '/audio/transcriptions',
      fields: {'model': model, 'response_format': 'json'},
      file: audio,
      filename: filename,
      mime: mime,
      abort: abort,
    );
    final text = json['text'];
    if (text is! String) {
      throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
    }
    return AiResult(text.trim(), AiUsage(seconds: seconds));
  }

  @override
  Future<AiResult<Uint8List>> generateImage(
    AiCloudSettings settings,
    String model,
    String prompt, {
    String size = '1024x1536',
    Future<void>? abort,
  }) async {
    final json = await transport.json(
      settings,
      'POST',
      '/images/generations',
      body: {
        'model': model,
        'prompt': prompt,
        'n': 1,
        'size': size,
        // GPT image models always answer in base64; older ones need asking.
        if (model.startsWith('dall-e')) 'response_format': 'b64_json',
      },
      abort: abort,
    );
    final data = json['data'];
    final first = data is List && data.isNotEmpty ? data.first : null;
    final encoded = first is Map ? first['b64_json'] : null;
    if (encoded is! String) {
      throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
    }
    try {
      return AiResult(base64Decode(encoded), const AiUsage(images: 1));
    } on FormatException {
      throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
    }
  }

  @override
  Future<List<String>> listModels(
    AiCloudSettings settings, {
    Future<void>? abort,
  }) async {
    final json = await transport.json(settings, 'GET', '/models', abort: abort);
    final data = json['data'];
    if (data is! List) {
      throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
    }
    return [
      for (final item in data)
        if (item is Map && item['id'] is String)
          // Gemini lists "models/x" but expects "x" in requests.
          (item['id'] as String).replaceFirst(RegExp(r'^models/'), ''),
    ]..sort();
  }
}

/// Anthropic's Messages API. It has no embeddings, speech or image APIs.
class AnthropicCloudAdapter extends OpenAiCloudClient {
  AnthropicCloudAdapter(super.transport);

  static const _unsupported = AiProviderFailure(
    AiProviderFailureKind.unsupported,
  );

  @override
  Future<AiResult<String>> chat(
    AiCloudSettings settings,
    AiChatRequest request, {
    Future<void>? abort,
  }) async {
    Map<String, Object?> body({required bool temperature}) => {
      'model': request.model,
      'max_tokens': request.outputTokens,
      'system': request.system,
      'messages': [
        {
          'role': 'user',
          'content': request.images.isEmpty
              ? request.user
              : [
                  for (final image in request.images)
                    {
                      'type': 'image',
                      'source': {
                        'type': 'base64',
                        'media_type': image.mime,
                        'data': base64Encode(image.bytes),
                      },
                    },
                  {'type': 'text', 'text': request.user},
                ],
        },
      ],
      if (temperature) 'temperature': request.temperature,
    };
    final json = await transport.json(
      settings,
      'POST',
      '/messages',
      body: body(temperature: true),
      abort: abort,
      timeout: request.timeout,
      retryWithout: (r) =>
          r.status == 400 && r.text.toLowerCase().contains('temperature'),
      fallbackBody: () => body(temperature: false),
    );
    if (json['stop_reason'] == 'max_tokens') {
      throw const AiProviderFailure(AiProviderFailureKind.truncated);
    }
    final blocks = json['content'];
    final text = blocks is List
        ? [
            for (final block in blocks)
              if (block is Map &&
                  block['type'] == 'text' &&
                  block['text'] is String)
                block['text'] as String,
          ].join()
        : '';
    if (text.trim().isEmpty) {
      throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
    }
    final usage = json['usage'];
    return AiResult(
      text,
      AiUsage(
        inputTokens: usage is Map ? _int(usage['input_tokens']) : 0,
        outputTokens: usage is Map ? _int(usage['output_tokens']) : 0,
      ),
    );
  }

  @override
  Future<AiResult<List<List<double>>>> embed(
    AiCloudSettings settings,
    String model,
    List<String> inputs, {
    Future<void>? abort,
  }) async => throw _unsupported;

  @override
  Future<AiResult<String>> transcribe(
    AiCloudSettings settings,
    String model,
    Uint8List audio, {
    String filename = 'speech.wav',
    String mime = 'audio/wav',
    double seconds = 0,
    Future<void>? abort,
  }) async => throw _unsupported;

  @override
  Future<AiResult<Uint8List>> generateImage(
    AiCloudSettings settings,
    String model,
    String prompt, {
    String size = '1024x1536',
    Future<void>? abort,
  }) async => throw _unsupported;
}

/// Picks the adapter for the configured format.
class CloudAiClient implements AiCloudClient {
  CloudAiClient(AiTransport transport)
    : _openAi = OpenAiCloudClient(transport),
      _anthropic = AnthropicCloudAdapter(transport);
  final OpenAiCloudClient _openAi;
  final AnthropicCloudAdapter _anthropic;
  AiCloudClient _for(AiCloudSettings s) =>
      s.format == AiProviderFormat.anthropic ? _anthropic : _openAi;

  @override
  Future<AiResult<String>> chat(
    AiCloudSettings settings,
    AiChatRequest request, {
    Future<void>? abort,
  }) => _for(settings).chat(settings, request, abort: abort);

  @override
  Future<AiResult<List<List<double>>>> embed(
    AiCloudSettings settings,
    String model,
    List<String> inputs, {
    Future<void>? abort,
  }) => _for(settings).embed(settings, model, inputs, abort: abort);

  @override
  Future<AiResult<String>> transcribe(
    AiCloudSettings settings,
    String model,
    Uint8List audio, {
    String filename = 'speech.wav',
    String mime = 'audio/wav',
    double seconds = 0,
    Future<void>? abort,
  }) => _for(settings).transcribe(
    settings,
    model,
    audio,
    filename: filename,
    mime: mime,
    seconds: seconds,
    abort: abort,
  );

  @override
  Future<AiResult<Uint8List>> generateImage(
    AiCloudSettings settings,
    String model,
    String prompt, {
    String size = '1024x1536',
    Future<void>? abort,
  }) =>
      _for(settings)
          .generateImage(settings, model, prompt, size: size, abort: abort);

  @override
  Future<List<String>> listModels(
    AiCloudSettings settings, {
    Future<void>? abort,
  }) => _for(settings).listModels(settings, abort: abort);
}
