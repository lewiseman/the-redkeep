import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync_wise/google_drive.dart';
import 'package:sync_wise/sync_wise.dart';

http.Response jsonResponse(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);
Map<String, dynamic> file(String id, {bool owned = true}) => {
  'id': id,
  'createdTime': '2026-11-03T00:00:00Z',
  'appProperties': {
    'type': 'note',
    'docId': id,
    'syncSchema': '2',
    if (owned) 'redkeepNamespace': DriveSyncClient.namespace,
  },
};
void main() {
  test('every listing is namespaced; foreign files returned by server are ignored before content reads', () async {
    final read = <String>[];
    final client = MockClient((r) async {
      if (r.url.path == '/drive/v3/files') {
        expect(r.url.queryParameters['q'], contains("key='redkeepNamespace'"));
        return jsonResponse({
          'files': [file('mine'), file('journal', owned: false)],
        });
      }
      final id = r.url.pathSegments.last;
      read.add(id);
      if (r.url.path.startsWith('/drive/v3/')) return jsonResponse(file(id));
      if (r.url.queryParameters['alt'] == 'media') {
        return jsonResponse({'id': id});
      }
      return jsonResponse({'etag': '"1"'});
    });
    addTearDown(client.close);
    expect(
      (await DriveSyncClient(
        client,
        documentIdFields: {'note': 'id'},
      ).listDocuments(type: 'note')).single.documentId,
      'mine',
    );
    expect(read, everyElement('mine'));
  });
  test('foreign direct baseline cannot authorize an update', () async {
    final requests = <String>[];
    final client = MockClient((r) async {
      requests.add(r.method);
      return jsonResponse(file('journal', owned: false));
    });
    addTearDown(client.close);
    await expectLater(
      DriveSyncClient(client).writeDocument(
        type: 'note',
        documentId: 'n',
        payload: {'id': 'n'},
        baseline: const RemoteDocument(
          fileId: 'journal',
          type: 'note',
          documentId: 'n',
          revision: '"1"',
          payload: {},
        ),
      ),
      throwsFormatException,
    );
    expect(requests, ['GET']);
  });
  test(
    'ownership is checked before any listed document content is read',
    () async {
      var payloadReads = 0;
      final client = MockClient((r) async {
        if (r.url.path == '/drive/v3/files') {
          return jsonResponse({
            'files': [file('changed')],
          });
        }
        if (r.url.queryParameters['alt'] == 'media') payloadReads++;
        return jsonResponse(file('changed', owned: false));
      });
      addTearDown(client.close);
      await expectLater(
        DriveSyncClient(client).listDocuments(type: 'note'),
        throwsFormatException,
      );
      expect(payloadReads, 0);
    },
  );
  test('reset deletes only owned files, tolerates 404 and verifies the remaining namespace', () async {
    final remaining = {'mine', 'missing', 'journal'};
    final deleted = <String>[];
    final client = MockClient((r) async {
      if (r.url.path == '/drive/v3/files') {
        return jsonResponse({
          'files': [
            for (final id in remaining) file(id, owned: id != 'journal'),
          ],
        });
      }
      final id = r.url.pathSegments.last;
      if (r.method == 'GET') {
        return jsonResponse(file(id, owned: id != 'journal'));
      }
      deleted.add(id);
      remaining.remove(id);
      return http.Response('', id == 'missing' ? 404 : 204);
    });
    addTearDown(client.close);
    await DriveSyncClient(client).permanentlyDeleteAllData();
    expect(deleted, ['mine', 'missing']);
    expect(remaining, {'journal'});
  });
  test('reset refuses a file whose ownership changed after listing', () async {
    var deleted = false;
    final client = MockClient((r) async {
      if (r.url.path == '/drive/v3/files') {
        return jsonResponse({
          'files': [file('changed')],
        });
      }
      if (r.method == 'DELETE') deleted = true;
      return jsonResponse(file('changed', owned: false));
    });
    addTearDown(client.close);
    await expectLater(
      DriveSyncClient(client).permanentlyDeleteAllData(),
      throwsFormatException,
    );
    expect(deleted, false);
  });
  test('legacy import never enumerates Journal documents', () async {
    final client = MockClient(
      (_) async => throw StateError('Unexpected HTTP request'),
    );
    addTearDown(client.close);
    expect(
      await DriveSyncClient(client).listLegacyDocuments(type: 'note'),
      isEmpty,
    );
  });
}
