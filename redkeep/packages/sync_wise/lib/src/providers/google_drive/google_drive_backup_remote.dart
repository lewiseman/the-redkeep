import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../backup/backup_config.dart';
import '../../backup/backup_models.dart';
import '../../backup/backup_remote.dart';

/// An appProperties key and value that mark this app's objects.
class _Namespace {
  final String key;
  final String value;
  const _Namespace(this.key, this.value);
}

class DriveRequestFailed implements Exception {
  final int status;
  final String? reason;
  const DriveRequestFailed(this.status, [this.reason]);
  @override
  String toString() =>
      'Google Drive request failed ($status${reason == null ? '' : ', $reason'}).';
}

/// Google Drive storage in the hidden, app-private `appDataFolder`.
///
/// Uses Drive v3 resumable uploads: the session URI is kept by the caller, and
/// after any interruption the server is asked how many bytes it has.
class GoogleDriveBackupRemote implements BackupRemote {
  static const _files = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _fields = 'id,name,size,md5Checksum,createdTime,appProperties';
  static const ownerKey = 'swApp';

  final http.Client _http;
  final String appId;
  final int chunkSize;
  final BackupRetry retry;

  GoogleDriveBackupRemote(
    this._http, {
    required this.appId,
    this.chunkSize = 2 * 1024 * 1024,
    BackupRetry? retry,
  }) : retry = retry ?? BackupRetry();

  _Namespace get _own => _Namespace(ownerKey, appId);

  // ---- HTTP helpers --------------------------------------------------------

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? bytes,
    String? json,
  }) async {
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll(headers);
    if (json != null) {
      request.headers['Content-Type'] = 'application/json; charset=UTF-8';
      request.body = json;
    } else if (bytes != null) {
      request.bodyBytes = bytes;
    }
    return http.Response.fromStream(await _http.send(request));
  }

  static String? _reason(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      final error = body is Map ? body['error'] : null;
      final errors = error is Map ? error['errors'] : null;
      if (errors is List && errors.isNotEmpty && errors.first is Map) {
        return (errors.first as Map)['reason'] as String?;
      }
    } on Object {
      // Non-JSON error bodies carry no reason.
    }
    return null;
  }

  static void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw DriveRequestFailed(response.statusCode, _reason(response));
  }

  static Map<String, dynamic> _json(http.Response response) {
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Unexpected Google Drive response.');
    }
    return value;
  }

  /// Transient failures: network errors, 5xx, 429 and Drive rate limits.
  static bool isTransient(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is HttpException ||
      error is DriveRequestFailed &&
          (error.status >= 500 ||
              error.status == 429 ||
              error.status == 408 ||
              error.status == 403 &&
                  (error.reason == 'rateLimitExceeded' ||
                      error.reason == 'userRateLimitExceeded'));

  Future<T> _retrying<T>(Future<T> Function() operation) async {
    for (var failure = 0; ; failure++) {
      try {
        return await operation();
      } on Object catch (error) {
        if (!isTransient(error) || failure + 1 >= retry.attempts) rethrow;
        await retry.sleep(retry.delay(failure));
      }
    }
  }

  RemoteObject _object(Map<String, dynamic> json) => RemoteObject(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    size: int.tryParse('${json['size']}') ?? 0,
    md5: json['md5Checksum'] as String?,
    createdTime: DateTime.tryParse('${json['createdTime']}'),
    properties: {
      for (final entry in ((json['appProperties'] as Map?) ?? const {}).entries)
        '${entry.key}': '${entry.value}',
    },
  );

  static String _escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  String _has(String key, String value) =>
      " and appProperties has { key='${_escape(key)}' and value='${_escape(value)}' }";

  bool _owns(RemoteObject object, _Namespace namespace) =>
      object.properties[namespace.key] == namespace.value;

  // ---- Listing -------------------------------------------------------------

  Future<List<RemoteObject>> _list(_Namespace namespace, {String? kind}) async {
    var query =
        "'appDataFolder' in parents and trashed = false${_has(namespace.key, namespace.value)}";
    if (kind != null) query += _has(BackupProperties.kind, kind);
    final result = <RemoteObject>[];
    final seenTokens = <String>{};
    String? token;
    do {
      final uri = Uri.parse(_files).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': query,
          'pageSize': '1000',
          'fields': 'nextPageToken,incompleteSearch,files($_fields)',
          'pageToken': ?token,
        },
      );
      final response = await _retrying(() => _send('GET', uri));
      _check(response);
      final page = _json(response);
      if (page['incompleteSearch'] == true) {
        throw const DriveRequestFailed(503, 'incompleteSearch');
      }
      for (final file in (page['files'] as List? ?? const [])) {
        final object = _object(file as Map<String, dynamic>);
        // Drive's query is a filter, not a guarantee; check ownership again.
        if (_owns(object, namespace) &&
            (kind == null ||
                object.properties[BackupProperties.kind] == kind)) {
          result.add(object);
        }
      }
      token = page['nextPageToken'] as String?;
      if (token != null && !seenTokens.add(token)) {
        throw const FormatException('Google Drive repeated a page.');
      }
    } while (token != null);
    return result;
  }

  @override
  Future<List<RemoteObject>> list({String? kind}) => _list(_own, kind: kind);

  Future<RemoteObject?> _get(String id, _Namespace namespace) async {
    final uri = Uri.parse('$_files/${Uri.encodeComponent(id)}')
        .replace(queryParameters: {'fields': _fields});
    final response = await _retrying(() => _send('GET', uri));
    if (response.statusCode == 404) return null;
    _check(response);
    final object = _object(_json(response));
    return _owns(object, namespace) ? object : null;
  }

  @override
  Future<RemoteObject?> get(String id) => _get(id, _own);

  // ---- Upload --------------------------------------------------------------

  @override
  Future<String> createUploadSession({
    required String name,
    required int length,
    required Map<String, String> properties,
    String mimeType = 'application/octet-stream',
  }) async {
    final uri = Uri.parse(
      _upload,
    ).replace(queryParameters: {'uploadType': 'resumable', 'fields': _fields});
    final body = jsonEncode({
      'name': name,
      'parents': ['appDataFolder'],
      'mimeType': mimeType,
      'appProperties': {...properties, ownerKey: appId},
    });
    final response = await _retrying(
      () => _send(
        'POST',
        uri,
        headers: {
          'X-Upload-Content-Type': mimeType,
          'X-Upload-Content-Length': '$length',
        },
        json: body,
      ),
    );
    _check(response);
    final location = response.headers['location'];
    if (location == null || !location.startsWith('https://')) {
      throw const DriveRequestFailed(502, 'missingUploadLocation');
    }
    return location;
  }

  /// The number of bytes the server has, or the finished object.
  Future<(int, RemoteObject?)> _status(String session, int length) async {
    final response = await _send(
      'PUT',
      Uri.parse(session),
      headers: {'Content-Range': 'bytes */$length'},
      bytes: const [],
    );
    return _uploadResponse(response, length);
  }

  (int, RemoteObject?) _uploadResponse(http.Response response, int length) {
    final code = response.statusCode;
    if (code == 200 || code == 201) {
      final object = _object(_json(response));
      if (!_owns(object, _own)) {
        throw const FormatException('Uploaded file is not owned by this app.');
      }
      return (length, object);
    }
    if (code == 308) {
      final range = response.headers['range'];
      final match = range == null
          ? null
          : RegExp(r'bytes=0-(\d+)').firstMatch(range);
      return (match == null ? 0 : int.parse(match.group(1)!) + 1, null);
    }
    if (code == 404 || code == 410) throw const UploadSessionExpired();
    _check(response);
    throw DriveRequestFailed(code);
  }

  @override
  Future<RemoteObject> upload({
    required String session,
    required File file,
    required int length,
    void Function(int sent)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final input = await file.open();
    try {
      var failures = 0;
      var (offset, done) = await _retrying(() => _status(session, length));
      while (done == null) {
        onProgress?.call(offset);
        if (isCancelled?.call() == true) {
          throw const BackupException(
            BackupErrorKind.cancelled,
            'Backup paused. It will continue from here.',
          );
        }
        try {
          final end = (offset + chunkSize).clamp(0, length);
          await input.setPosition(offset);
          final bytes = await input.read(end - offset);
          if (bytes.length != end - offset) {
            throw const FileSystemException('The staged backup changed.');
          }
          final response = await _send(
            'PUT',
            Uri.parse(session),
            headers: {
              'Content-Range': length == 0
                  ? 'bytes */0'
                  : 'bytes $offset-${end - 1}/$length',
            },
            bytes: bytes,
          );
          final previous = offset;
          (offset, done) = _uploadResponse(response, length);
          if (offset > previous || done != null) failures = 0;
        } on UploadSessionExpired {
          rethrow;
        } on Object catch (error) {
          if (!isTransient(error) || ++failures >= retry.attempts) rethrow;
          await retry.sleep(retry.delay(failures - 1));
          // The server may have stored part of the chunk; ask before resending.
          (offset, done) = await _retrying(() => _status(session, length));
        }
      }
      onProgress?.call(length);
      return done;
    } finally {
      await input.close();
    }
  }

  @override
  Future<void> updateProperties(
    String id,
    Map<String, String> properties,
  ) async {
    if (await get(id) == null) {
      throw const FormatException(
        'Refusing to change a file this app does not own.',
      );
    }
    final uri = Uri.parse('$_files/${Uri.encodeComponent(id)}')
        .replace(queryParameters: {'fields': 'id'});
    final response = await _retrying(
      () =>
          _send('PATCH', uri, json: jsonEncode({'appProperties': properties})),
    );
    _check(response);
  }

  // ---- Download ------------------------------------------------------------

  @override
  Future<void> download(
    String id,
    File target, {
    int? expectedLength,
    void Function(int received)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (await get(id) == null) {
      throw const FormatException(
        'Refusing to read a file this app does not own.',
      );
    }
    await target.parent.create(recursive: true);
    var failures = 0;
    while (true) {
      var offset = await target.exists() ? await target.length() : 0;
      if (expectedLength != null && offset > expectedLength) {
        await target.delete();
        offset = 0;
      }
      if (expectedLength != null && offset == expectedLength) {
        onProgress?.call(offset);
        return;
      }
      try {
        final request =
            http.Request(
                'GET',
                Uri.parse('$_files/${Uri.encodeComponent(id)}')
                    .replace(queryParameters: {'alt': 'media'}),
              )
              ..followRedirects = false
              ..headers['Accept-Encoding'] = 'identity';
        if (offset > 0) request.headers['Range'] = 'bytes=$offset-';
        final response = await _http.send(request);
        if (response.statusCode == 416 && expectedLength == null) {
          await response.stream.drain<void>();
          return;
        }
        if (response.statusCode != 200 && response.statusCode != 206) {
          final body = await http.Response.fromStream(response);
          _check(body);
          throw DriveRequestFailed(response.statusCode);
        }
        final append = response.statusCode == 206 && offset > 0;
        var received = append ? offset : 0;
        final sink = target.openWrite(
          mode: append ? FileMode.append : FileMode.write,
        );
        try {
          await for (final chunk in response.stream) {
            if (isCancelled?.call() == true) {
              throw const BackupException(
                BackupErrorKind.cancelled,
                'Restore paused. It will continue from here.',
              );
            }
            sink.add(chunk);
            received += chunk.length;
            if (expectedLength != null && received > expectedLength) {
              throw const FormatException('Download is larger than expected.');
            }
            onProgress?.call(received);
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (expectedLength == null || received == expectedLength) return;
        throw const HttpException('Download ended early.');
      } on Object catch (error) {
        if (!isTransient(error) || ++failures >= retry.attempts) rethrow;
        await retry.sleep(retry.delay(failures - 1));
      }
    }
  }

  // ---- Delete --------------------------------------------------------------

  Future<void> _delete(String id, _Namespace namespace) async {
    final owned = await _get(id, namespace);
    if (owned == null) return;
    final response = await _retrying(
      () => _send('DELETE', Uri.parse('$_files/${Uri.encodeComponent(id)}')),
    );
    if (response.statusCode == 404) return;
    _check(response);
  }

  @override
  Future<void> delete(String id) => _delete(id, _own);

  @override
  Future<void> deleteAll({
    void Function(int done, int total)? onProgress,
  }) async {
    final targets = await _list(_own);
    var done = 0;
    onProgress?.call(done, targets.length);
    for (final object in targets) {
      await _delete(object.id, _own);
      onProgress?.call(++done, targets.length);
    }
    if ((await _list(_own)).isNotEmpty) {
      throw StateError(
        'Google Drive still contains backup data. Close the app on other devices and retry.',
      );
    }
  }
}
