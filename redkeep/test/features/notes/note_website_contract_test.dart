import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:redkeep/features/notes/domain/website/website_contract.dart';
import 'package:redkeep/features/notes/domain/note_website.dart';
import 'package:redkeep/features/notes/domain/note_scan_contract.dart';

import '../../support/notes_ai_harness.dart';

void main() {
  test(
    'website sanitizer keeps inline code but nothing that reaches out',
    () async {
      final safe = await sanitizeWebsiteBounded(
        '<html><head><meta http-equiv="refresh" content="0;url=https://evil.test">'
        '<link rel="stylesheet" href="https://evil.test/a.css"><base href="https://evil.test/">'
        '<style>body{color:red;background:url(https://evil.test/a)}@import "https://evil.test/b.css";</style></head>'
        '<body onload="start()"><h1>Garden</h1><script>function start(){}</script>'
        '<script src="https://evil.test/x.js"></script><iframe src="https://evil.test"></iframe>'
        '<object data="https://evil.test/o"></object><form action="https://evil.test"><input type="checkbox"></form>'
        '<a href="https://evil.test">Away</a><a href="#plan">Plan</a><a href="data:text/html,x">Data</a>'
        '<img src="https://evil.test/image"><img src="data:image/png;base64,AA=="></body></html>',
      );
      final doc = html.parse(safe);
      expect(doc.querySelectorAll('iframe,object,link,base'), isEmpty);
      expect(doc.querySelectorAll('meta[http-equiv="refresh"]'), isEmpty);
      expect(doc.querySelectorAll('script[src]'), isEmpty);
      // Interactive pages keep their own scripts, handlers and controls.
      expect(doc.querySelector('body')!.attributes['onload'], 'start()');
      expect(safe, contains('function start(){}'));
      expect(doc.querySelectorAll('input[type=checkbox]'), hasLength(1));
      expect(
        doc.querySelector('form')!.attributes.containsKey('action'),
        isFalse,
      );
      final links = doc.querySelectorAll('a');
      expect(links[0].attributes.containsKey('href'), isFalse);
      expect(links[1].attributes['href'], '#plan');
      expect(links[2].attributes.containsKey('href'), isFalse);
      final images = doc.querySelectorAll('img');
      expect(images[0].attributes.containsKey('src'), isFalse);
      expect(images[1].attributes['src'], startsWith('data:image/png'));
      expect(safe, isNot(contains('evil.test')));
    },
  );

  test('the app policy and theme bootstrap come first and are not doubled', () {
    final once = sanitizeWebsite(
      '<html><head><meta http-equiv="Content-Security-Policy" content="default-src *">'
      '<title>T</title></head><body><p>Hi</p></body></html>',
      appearance: const WebsiteAppearance(
        dark: true,
        reduceMotion: true,
        tokens: {'accent': '#aa3344', 'bg': 'red; x: y'},
      ),
    );
    final twice = sanitizeWebsite(once);
    for (final page in [once, twice]) {
      final head = html.parse(page).head!.children;
      expect(head[0].attributes['charset'], 'utf-8');
      expect(head[1].attributes['content'], websitePolicy);
      expect(head.where((e) => e.localName == 'script'), hasLength(1));
      expect(
        html.parse(page).querySelectorAll('meta[http-equiv]'),
        hasLength(1),
      );
      expect(
        head.firstWhere((e) => e.localName == 'script').text,
        contains('redkeep:appearance'),
      );
    }
    final root = html.parse(once).documentElement!;
    expect(root.attributes['data-theme'], 'dark');
    expect(root.attributes['data-motion'], 'reduce');
    expect(root.attributes['data-effects'], 'full');
    expect(root.attributes['style'], contains('--rk-accent: #aa3344'));
    // Only colours reach the page.
    expect(root.attributes['style'], isNot(contains('--rk-bg')));
    expect(
      const WebsiteAppearance(dark: true).script,
      startsWith(
        'window.redkeep&&window.redkeep.setAppearance({"theme":"dark"',
      ),
    );
  });

  test('pages open with their data and cannot fake it', () {
    final page = sanitizeWebsite(
      '<html><head><script type="application/json" id="redkeep-data">{"state":{"won":true}}</script></head>'
      '<body><p>Hi</p></body></html>',
      data: const WebsitePageData(state: '{"note":"</script><b>x"}'),
    );
    final doc = html.parse(page);
    final data = doc.querySelectorAll('#redkeep-data');
    expect(data, hasLength(1));
    expect(data.single.text, isNot(contains('</script>')));
    expect(jsonDecode(data.single.text)['state'], {'note': '</script><b>x'});
    // The bootstrap's code survives serialization untouched.
    expect(page, contains("bridge&&typeof bridge.postMessage==='function'"));
    expect(page, contains('setChecklistItem'));
    expect(websiteSource(page), isNot(contains('redkeep-data')));
    expect(websiteSource(page), isNot(contains('Content-Security-Policy')));
    expect(websiteSource(page), contains('<p>Hi</p>'));
  });

  test('remix edits apply exactly once or not at all', () {
    const page = '<html><body><h1>A</h1><p>B</p><p>B</p></body></html>';
    String edit(String find, String replace) =>
        '<<<<<<< FIND\n$find\n=======\n$replace\n>>>>>>> REPLACE';
    expect(
      applyWebsiteRemix(
        page,
        '${edit('<h1>A</h1>', '<h1>C</h1>')}\n\n${edit('</body>', '<i>D</i></body>')}',
      ),
      '<html><body><h1>C</h1><p>B</p><p>B</p><i>D</i></body></html>',
    );
    expect(
      () => applyWebsiteRemix(page, edit('<p>B</p>', 'x')),
      throwsFormatException,
    );
    expect(
      () => applyWebsiteRemix(page, edit('<p>Z</p>', 'x')),
      throwsFormatException,
    );
    expect(
      () => applyWebsiteRemix(page, 'Sure! Here is the change.'),
      throwsFormatException,
    );
    expect(
      applyWebsiteRemix(page, '<!doctype html><html><body>New</body></html>'),
      '<!doctype html><html><body>New</body></html>',
    );
  });

  test('cut-off, empty and oversized websites are refused', () {
    expect(
      () => sanitizeWebsite('<html><body><h1>Garden</h1><p>Plant'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('cut off'),
        ),
      ),
    );
    expect(
      () => sanitizeWebsite('<html><body><script>x()</script></body></html>'),
      throwsFormatException,
    );
    expect(
      () => sanitizeWebsite(
        '<html><body>${'a' * (websiteOutputBytes + 1)}</body></html>',
      ),
      throwsFormatException,
    );
    expect(
      sanitizeWebsite('```html\n$noteWebsiteOutput\n```'),
      contains('Garden plan'),
    );
  });

  test(
    'website requests send the note, a one-line brief and a photo count',
    () {
      final request = WebsiteRequest(
        title: 'Garden',
        body: notesTestBody,
        brief: '  A  guide\n',
        photos: 2,
      );
      expect(request.cleanBrief, 'A guide');
      expect(request.request(), contains('"photos":2'));
      expect(
        () => const WebsiteRequest(title: '', body: '  ').request(),
        throwsFormatException,
      );
      expect(
        () => WebsiteRequest(title: '', body: 'x', brief: 'b' * 241).request(),
        throwsFormatException,
      );
      expect(
        () =>
            WebsiteRequest(title: '', body: 'x' * websiteInputBytes).request(),
        throwsFormatException,
      );
      final website = NoteWebsite(
        noteId: notesTestId,
        html: '<html></html>',
        sourceHash: websiteContentHash(notesTestBody),
        madeAt: DateTime.utc(2026),
      );
      expect(website.isOutdatedFor(notesTestBody), isFalse);
      expect(website.isOutdatedFor('$notesTestBody!'), isTrue);
    },
  );

  test('scan disagreements flag uncertain names/numbers without changing the reading', () {
    final scan = NoteScanResult.parse(
      '{"text":"Meet Sam at 3:15pm [?]","readable":true,"check":[{"text":"Meet Pam at 315pm","confidence":0.8}]}',
    );
    expect(scan.unreadableMarks, 1);
    expect(scan.disagreements, containsAll(['Sam', '3:15pm']));
    expect(scan.text, 'Meet Sam at 3:15pm [?]');
    expect(() => NoteScanResult.parse('{"text":12}'), throwsFormatException);
  });
}
