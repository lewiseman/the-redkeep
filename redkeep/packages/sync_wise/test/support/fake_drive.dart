import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:sync_wise/google_drive.dart';
import 'package:sync_wise/sync_wise.dart';

class FakeFile {
  final String id;
  final String name;
  final DateTime createdTime;
  final Map<String, String> properties;
  final BytesBuilder data = BytesBuilder(copy: false);
  Uint8List? content;
  FakeFile(this.id, this.name, this.createdTime, this.properties);
  Uint8List get bytes => content ?? Uint8List(0);
}

class FakeSession {
  final String id;
  final String name;
  final int length;
  final Map<String, String> properties;
  final BytesBuilder received = BytesBuilder();
  FakeFile? done;
  FakeSession(this.id, this.name, this.length, this.properties);
}

/// An in-memory subset of the Drive v3 REST API used by the backup remote.
class FakeDrive {
  final files = <String, FakeFile>{};
  final sessions = <String, FakeSession>{};
  final requests = <String>[];
  var _ids = 0;
  DateTime now = DateTime.utc(2026, 11, 17, 2);

  /// Called before each upload PUT with bytes; may throw to simulate drops.
  /// Return a number to store only that many bytes of this chunk, then fail.
  int? Function(FakeSession session, int offset, int length)? onChunk;

  /// Corrupts the md5 reported for finished uploads.
  bool reportWrongMd5 = false;

  /// Drops the response stream of media downloads after this many bytes once.
  int? dropDownloadAfter;
  var chunkPuts = 0;
  var sessionsCreated = 0;

  late final http.Client client = _Client(this);

  FakeFile add(
    Map<String, String> properties, {
    List<int> bytes = const [],
    DateTime? created,
    String name = 'file',
  }) {
    final file = FakeFile(
      'f${++_ids}',
      name,
      created ?? now,
      Map.of(properties),
    )..content = Uint8List.fromList(bytes);
    files[file.id] = file;
    return file;
  }

  Map<String, Object?> _resource(FakeFile file) => {
    'id': file.id,
    'name': file.name,
    'size': '${file.bytes.length}',
    'md5Checksum': reportWrongMd5 ? '0' * 32 : '${md5.convert(file.bytes)}',
    'createdTime': file.createdTime.toIso8601String(),
    'appProperties': file.properties,
  };

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<http.StreamedResponse> handle(http.BaseRequest request) async {
    final uri = request.url;
    final body = request is http.Request ? request.bodyBytes : Uint8List(0);
    requests.add('${request.method} ${uri.path}');
    http.Response response;
    if (uri.host == 'upload.test') {
      response = _chunk(uri.pathSegments.last, request.headers, body);
    } else if (uri.path == '/upload/drive/v3/files' &&
        request.method == 'POST') {
      final meta = jsonDecode(utf8.decode(body)) as Map;
      sessionsCreated++;
      final id = 's${++_ids}';
      sessions[id] = FakeSession(
        id,
        meta['name'] as String,
        int.parse(request.headers['X-Upload-Content-Length']!),
        (meta['appProperties'] as Map).cast<String, String>(),
      );
      response = http.Response(
        '',
        200,
        headers: {'location': 'https://upload.test/session/$id'},
      );
    } else if (uri.path == '/drive/v3/files' && request.method == 'GET') {
      response = _list(uri.queryParameters['q'] ?? '');
    } else if (uri.path.startsWith('/drive/v3/files/')) {
      final id = uri.pathSegments.last;
      final file = files[id];
      if (file == null) {
        response = _json({
          'error': {'code': 404},
        }, 404);
      } else if (request.method == 'GET' &&
          uri.queryParameters['alt'] == 'media') {
        return _media(file, request.headers['Range']);
      } else if (request.method == 'GET') {
        response = _json(_resource(file));
      } else if (request.method == 'PATCH') {
        final patch = jsonDecode(utf8.decode(body)) as Map;
        file.properties.addAll(
          (patch['appProperties'] as Map).cast<String, String>(),
        );
        response = _json({'id': id});
      } else if (request.method == 'DELETE') {
        files.remove(id);
        response = http.Response('', 204);
      } else {
        response = http.Response('', 405);
      }
    } else {
      response = http.Response('', 404);
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  http.Response _list(String query) {
    final pairs = RegExp(r"key='([^']*)' and value='([^']*)'")
        .allMatches(query)
        .map((m) => (m.group(1)!, m.group(2)!));
    final matches = files.values.where(
      (file) => pairs.every((pair) => file.properties[pair.$1] == pair.$2),
    );
    return _json({'files': matches.map(_resource).toList()});
  }

  http.Response _chunk(String id, Map<String, String> headers, List<int> body) {
    final session = sessions[id];
    if (session == null) return http.Response('', 404);
    final range = headers['Content-Range']!;
    if (session.done != null) return _json(_resource(session.done!), 200);
    if (range.startsWith('bytes */')) return _incomplete(session);
    final match = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(range)!;
    final start = int.parse(match.group(1)!);
    if (start != session.received.length) return http.Response('', 400);
    chunkPuts++;
    final keep = onChunk?.call(session, start, body.length);
    if (keep != null) {
      session.received.add(body.sublist(0, keep));
      throw const SocketException('Connection reset');
    }
    session.received.add(body);
    if (session.received.length < session.length) return _incomplete(session);
    final file = add(
      session.properties,
      bytes: session.received.toBytes(),
      name: session.name,
    );
    session.done = file;
    return _json(_resource(file), 200);
  }

  http.Response _incomplete(FakeSession session) => http.Response(
    '',
    308,
    headers: {
      if (session.received.length > 0)
        'range': 'bytes=0-${session.received.length - 1}',
    },
  );

  http.StreamedResponse _media(FakeFile file, String? range) {
    var start = 0;
    if (range != null) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
    }
    final bytes = file.bytes.sublist(start);
    final drop = dropDownloadAfter;
    Stream<List<int>> stream;
    if (drop != null && drop < bytes.length) {
      dropDownloadAfter = null;
      stream = (() async* {
        yield bytes.sublist(0, drop);
        throw const SocketException('Connection reset');
      })();
    } else {
      stream = Stream.value(bytes);
    }
    return http.StreamedResponse(stream, range == null ? 200 : 206);
  }
}

class _Client extends http.BaseClient {
  final FakeDrive drive;
  _Client(this.drive);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      drive.handle(request);
}

class FakeAuth implements SyncAuth {
  SyncAccount? user = const SyncAccount(id: 'owner', email: 'o@example.test');
  @override
  SyncAccount? get currentUser => user;
  @override
  bool get isSignedIn => user != null;
  @override
  Stream<SyncAccount?> get onAuthStateChanged => const Stream.empty();
  @override
  Future<SyncAccount?> signIn() async => user;
  @override
  Future<void> signOut() async => user = null;
  @override
  Future<SyncAccount?> trySilentSignIn() async => user;
}

class FakeDriveBackend implements BackupBackend {
  final FakeDrive drive;
  final String appId;
  final List<DriveNamespace> legacy;
  final int chunkSize;
  @override
  final FakeAuth auth = FakeAuth();
  var opened = 0;
  FakeDriveBackend(
    this.drive, {
    this.appId = 'app',
    this.legacy = const [],
    this.chunkSize = 256 * 1024,
  });
  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake Drive';
  @override
  Future<BackupSession?> open() async {
    if (auth.user == null) return null;
    opened++;
    return _Session(
      GoogleDriveBackupRemote(
        drive.client,
        appId: appId,
        chunkSize: chunkSize,
        legacyNamespaces: legacy,
        retry: BackupRetry(attempts: 3, sleep: (_) async {}),
      ),
    );
  }

  @override
  void dispose() {}
}

class _Session implements BackupSession {
  @override
  final BackupRemote remote;
  _Session(this.remote);
  @override
  void close() {}
}

class FakeNetwork implements SyncNetwork {
  bool online = true;
  bool unmetered = true;
  @override
  Future<bool> isOnline() async => online;
  @override
  Future<bool> isUnmeteredConnection() async => online && unmetered;
}

class RecordingNotifier implements BackupNotifier {
  final events = <String>[];
  @override
  Future<void> clear() async => events.add('clear');
  @override
  Future<void> failed({required String title, required String body}) async =>
      events.add('failed');
  @override
  Future<void> progress({required String title, double? fraction}) async =>
      events.add('progress');
}
