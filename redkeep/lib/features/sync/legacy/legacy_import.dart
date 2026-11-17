// Remove with the legacy sync helper.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sync_wise/google_drive.dart' show DriveNamespace;

import '../../../core/storage/app_database.dart';
import 'legacy_documents.dart';

/// How the old per-document sync marked its Drive files.
const legacySyncNamespace = DriveNamespace('redkeepNamespace', 'redkeep-v1');

/// One stored document of the old sync.
class LegacyDocument {
  final String type;
  final Map<String, dynamic> payload;
  const LegacyDocument(this.type, this.payload);
}

/// Reads the old one-file-per-document sync from Drive's app folder.
class LegacyDriveReader {
  LegacyDriveReader(this._http, {this.concurrency = 4});
  final http.Client _http;
  final int concurrency;

  static const _files = 'https://www.googleapis.com/drive/v3/files';

  Future<List<Map<String, dynamic>>> _list() async {
    final key = legacySyncNamespace.key, value = legacySyncNamespace.value;
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    String? token;
    do {
      final uri = Uri.parse(_files).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'q':
              "'appDataFolder' in parents and trashed = false and appProperties has { key='$key' and value='$value' }",
          'pageSize': '1000',
          'fields': 'nextPageToken,incompleteSearch,files(id,createdTime,appProperties)',
          'pageToken': ?token,
        },
      );
      final response = await _get(uri);
      final page = jsonDecode(response) as Map<String, dynamic>;
      if (page['incompleteSearch'] == true) {
        throw const HttpException('Google Drive returned an incomplete list.');
      }
      for (final file in (page['files'] as List? ?? const [])) {
        final map = file as Map<String, dynamic>;
        if ((map['appProperties'] as Map?)?[key] == value) result.add(map);
      }
      token = page['nextPageToken'] as String?;
      if (token != null && !seen.add(token)) {
        throw const FormatException('Google Drive repeated a page.');
      }
    } while (token != null);
    return result;
  }

  Future<String> _get(Uri uri) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _http.get(uri);
        if (response.statusCode == 200) return response.body;
        final transient =
            response.statusCode >= 500 || response.statusCode == 429;
        if (!transient || attempt >= 3) {
          throw HttpException(
            'Google Drive request failed (${response.statusCode}).',
          );
        }
      } on SocketException {
        if (attempt >= 3) rethrow;
      } on TimeoutException {
        if (attempt >= 3) rethrow;
      }
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
    }
  }

  /// Whether any old sync data exists, without downloading it.
  Future<bool> hasData() async =>
      (await _list()).any((f) => (f['appProperties'] as Map)['type'] != 'sync_primary');

  /// One copy of every stored document. Where an interrupted upload left
  /// duplicates, the copy the registry points at wins, else the oldest.
  Future<List<LegacyDocument>> readAll() async {
    final files = await _list();
    final registry = files
        .where((f) => (f['appProperties'] as Map)['type'] == 'sync_primary')
        .toList()
      ..sort(_oldestFirst);
    var canonical = <String, String>{};
    if (registry.isNotEmpty) {
      final body = jsonDecode(await _media(registry.first['id'] as String));
      if (body is Map && body['documents'] is Map) {
        canonical = (body['documents'] as Map).map(
          (key, value) => MapEntry('$key', '$value'),
        );
      }
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final file in files) {
      final props = file['appProperties'] as Map;
      final type = props['type'];
      final id = props['docId'];
      if (type is! String ||
          id is! String ||
          !legacyDocumentTypes.contains(type)) {
        continue;
      }
      groups.putIfAbsent('$type/$id', () => []).add(file);
    }
    final chosen = <(String, String)>[];
    for (final MapEntry(key: key, value: copies) in groups.entries) {
      copies.sort(_oldestFirst);
      final preferred = canonical[key];
      final file = copies.firstWhere(
        (f) => f['id'] == preferred,
        orElse: () => copies.first,
      );
      chosen.add((key.split('/').first, file['id'] as String));
    }
    final documents = <LegacyDocument>[];
    var next = 0;
    Future<void> worker() async {
      while (next < chosen.length) {
        final (type, id) = chosen[next++];
        final body = jsonDecode(await _media(id));
        if (body is Map<String, dynamic>) {
          documents.add(LegacyDocument(type, body));
        }
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    return documents;
  }

  Future<String> _media(String id) => _get(
    Uri.parse(
      '$_files/${Uri.encodeComponent(id)}',
    ).replace(queryParameters: {'alt': 'media'}),
  );

  static int _oldestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
    final time = '${a['createdTime']}'.compareTo('${b['createdTime']}');
    return time != 0 ? time : '${a['id']}'.compareTo('${b['id']}');
  }
}

/// Imports old sync data once per account, before the first backup.
class LegacyImport {
  LegacyImport({required this.db, required this.marker});
  final AppDatabase db;

  /// `<app support>/legacy_sync_import.json`.
  final File marker;

  static Future<File> markerFile(Directory support) async =>
      File(p.join(support.path, 'legacy_sync_import.json'));

  Future<bool> isDone(String accountId) => isDoneAt(marker, accountId);

  /// Readable without a database, e.g. from the background backup.
  static Future<bool> isDoneAt(File marker, String accountId) async {
    try {
      final value = jsonDecode(await marker.readAsString());
      return value is Map && value['account'] == accountId && value['done'] == true;
    } on Object {
      return false;
    }
  }

  /// Adds documents this device is missing. Throws when Drive cannot be read
  /// completely, so the backup waits and the import is retried.
  Future<int> run({required String accountId, required http.Client client}) async {
    if (await isDone(accountId)) return 0;
    final documents = await LegacyDriveReader(client).readAll();
    final store = LegacyDocuments(db);
    var added = 0, skipped = 0;
    for (final document in documents) {
      try {
        added += await store.insertMissing(document.type, document.payload);
      } on FormatException {
        // Unreadable documents cannot become readable by retrying.
        skipped++;
      }
    }
    final pending = File('${marker.path}-pending');
    await pending.writeAsString(
      jsonEncode({
        'account': accountId,
        'done': true,
        'added': added,
        'skipped': skipped,
        'at': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await pending.rename(marker.path);
    return added;
  }
}
