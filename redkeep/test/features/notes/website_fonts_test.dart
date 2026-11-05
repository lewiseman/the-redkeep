import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redkeep/features/notes/data/note_media_store.dart';
import 'package:redkeep/features/notes/data/website_font_store.dart';
import 'package:redkeep/features/notes/domain/website/website_themes.dart';
import 'package:redkeep/features/notes/presentation/website/website_assets.dart';

class _NoStore implements NoteMediaStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const page = '<html><head></head><body class="t-THEME"></body></html>';
  final theme = websiteThemes.firstWhere((t) => t.fonts.isNotEmpty);
  final html = page.replaceFirst('THEME', theme.id);

  setUp(clearNoteWebsiteCache);

  test('a theme embeds its Google Font', () async {
    final result = await withWebsiteAssets(
      html,
      const [],
      store: _NoStore(),
      fontBytes: (family, weight) async => Uint8List.fromList([1, 2, 3]),
    );
    expect(result, contains('font-family:"${theme.fonts.first}"'));
    expect(result, contains('base64,AQID'));
  });

  test('an unreachable font falls back and is retried next time', () async {
    var online = false;
    Future<Uint8List> load(String family, int weight) async {
      if (!online) throw http.ClientException('offline');
      return Uint8List.fromList([1, 2, 3]);
    }

    final offline = await withWebsiteAssets(
      html,
      const [],
      store: _NoStore(),
      fontBytes: load,
    );
    expect(offline, isNot(contains('@font-face')));
    online = true;
    final retried = await withWebsiteAssets(
      html,
      const [],
      store: _NoStore(),
      fontBytes: load,
    );
    expect(retried, contains('@font-face'));
  });

  test('every theme font is a Google Font at its stated weight', () async {
    final cache = Directory.systemTemp.createTempSync('website_fonts');
    addTearDown(() => cache.deleteSync(recursive: true));
    for (final MapEntry(key: family, value: weight) in websiteFonts.entries) {
      final requests = <Uri>[];
      // A wrong download is refused rather than embedded or cached.
      await expectLater(
        loadWebsiteFont(
          family,
          weight,
          cacheDirectory: () async => cache,
          client: MockClient((request) async {
            requests.add(request.url);
            return http.Response.bytes([1, 2, 3], 200);
          }),
        ),
        throwsA(isA<http.ClientException>()),
      );
      expect(requests.single.host, 'fonts.gstatic.com');
    }
    expect(cache.listSync(recursive: true).whereType<File>(), isEmpty);
  });
}
