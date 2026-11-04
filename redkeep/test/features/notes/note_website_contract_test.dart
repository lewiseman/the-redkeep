import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:redkeep/features/notes/domain/website/website_contract.dart';
import 'package:redkeep/features/notes/domain/website/website_render.dart';
import 'package:redkeep/features/notes/domain/note_scan_contract.dart';

import '../../support/notes_ai_harness.dart';

void main() {
  test('website sanitizer removes active content, external requests and navigation', () async {
    final safe = await sanitizeWebsiteBounded(
      '<html><head><style>body{color:red;background:url(https://evil.test/a)}</style></head><body onload="alert(1)"><h1>Garden</h1><script>fetch("https://evil.test")</script><iframe src="https://evil.test"></iframe><form action="https://evil.test"><input></form><a href="https://evil.test">Read</a><img src="https://evil.test/image"></body></html>',
    );
    final doc = html.parse(safe);
    expect(doc.querySelectorAll('script,iframe,form,input'), isEmpty);
    expect(
      doc.querySelector('body')!.attributes.containsKey('onload'),
      isFalse,
    );
    expect(
      doc.querySelector('a')?.attributes.containsKey('href') ?? false,
      isFalse,
    );
    expect(doc.querySelectorAll('[src]'), isEmpty);
    expect(safe, contains('Content-Security-Policy'));
  });
  test('themed website escapes text and rejects unsupported sections/photo indexes', () async {
    final spec = WebsiteSpec.decode(noteWebsiteOutput, photos: 0);
    final page = await websitePageFromOutput(
      noteWebsiteDesignOperation,
      spec.encode(),
    );
    expect(websiteSpecOf(page)!.theme, 'garden');
    expect(
      () => WebsiteSpec.decode(
        noteWebsiteOutput.replaceFirst('"photo":-1', '"photo":3'),
        photos: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => WebsiteSpec.decode(
        noteWebsiteOutput.replaceFirst('"garden"', '"unknown"'),
      ),
      throwsFormatException,
    );
  });
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
