import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

class HttpAiProviderClient implements AiProviderClient {
  HttpAiProviderClient(
    this._client, {
    this.timeout = const Duration(seconds: 90),
  });
  final http.Client _client;
  final Duration timeout;
  static const _maxResponseBytes = 4 * 1024 * 1024;

  void close() => _client.close();

  @override
  Future<String> complete(
    AiProviderConnection connection,
    AiCompletionRequest request, {
    Future<void>? abort,
  }) async {
    final anthropic = connection.format == AiProviderFormat.anthropic;
    final path = anthropic ? '/messages' : '/chat/completions';
    Map<String, Object?> body({required bool temperature}) => anthropic
        ? {
            'model': request.model,
            'max_tokens': request.outputTokens,
            'system': request.system,
            'messages': [
              {'role': 'user', 'content': request.user},
            ],
            if (temperature) 'temperature': request.temperature,
          }
        : {
            'model': request.model,
            connection.tokenLimitParameter: request.outputTokens,
            'messages': [
              {'role': 'system', 'content': request.system},
              {'role': 'user', 'content': request.user},
            ],
            if (temperature) 'temperature': request.temperature,
            if (temperature && request.topP != 1) 'top_p': request.topP,
          };

    var response = await _send(
      connection,
      'POST',
      path,
      body: body(temperature: true),
      abort: abort,
    );
    // Some models only accept their default temperature.
    if (response.status == 400 &&
        response.text.toLowerCase().contains('temperature')) {
      response = await _send(
        connection,
        'POST',
        path,
        body: body(temperature: false),
        abort: abort,
      );
    }
    final json = _success(response);
    return anthropic ? _anthropicText(json) : _openAiText(json);
  }

  @override
  Future<List<String>> listModels(
    AiProviderConnection connection, {
    Future<void>? abort,
  }) async {
    final json = _success(
      await _send(connection, 'GET', '/models', abort: abort),
    );
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

  Future<({int status, String text})> _send(
    AiProviderConnection connection,
    String method,
    String path, {
    Map<String, Object?>? body,
    Future<void>? abort,
  }) async {
    final base = parseAiProviderBaseUrl(connection.baseUrl);
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
    final request =
        http.AbortableRequest(
            method,
            base.replace(path: '${base.path}$path'),
            abortTrigger: trigger.future,
          )
          // A redirect must not carry the token to another address.
          ..followRedirects = false
          ..headers['accept'] = 'application/json';
    if (connection.format == AiProviderFormat.anthropic) {
      request.headers['anthropic-version'] = '2023-06-01';
      if (connection.token.isNotEmpty) {
        request.headers['x-api-key'] = connection.token;
      }
    } else if (connection.token.isNotEmpty) {
      request.headers['authorization'] = 'Bearer ${connection.token}';
    }
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client.send(request);
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (bytes.length > _maxResponseBytes) {
          throw const AiProviderFailure(AiProviderFailureKind.invalidResponse);
        }
      }
      return (
        status: response.statusCode,
        text: utf8.decode(bytes, allowMalformed: true),
      );
    } on http.RequestAbortedException {
      throw AiProviderFailure(
        cancelled || !timedOut
            ? AiProviderFailureKind.cancelled
            : AiProviderFailureKind.timeout,
      );
    } on http.ClientException {
      throw const AiProviderFailure(AiProviderFailureKind.offline);
    } on SocketException {
      throw const AiProviderFailure(AiProviderFailureKind.offline);
    } on TlsException {
      throw const AiProviderFailure(AiProviderFailureKind.offline);
    } finally {
      timer.cancel();
    }
  }

  Map<String, dynamic> _success(({int status, String text}) response) {
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

  String _openAiText(Map<String, dynamic> json) {
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
    return content;
  }

  String _anthropicText(Map<String, dynamic> json) {
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
    return text;
  }
}
