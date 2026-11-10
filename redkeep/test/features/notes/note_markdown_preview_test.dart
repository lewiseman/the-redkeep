import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/domain/note_link_launcher.dart';
import 'package:redkeep/features/notes/presentation/note_markdown_preview.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';

class _Launcher implements NoteLinkLauncher {
  final opened = <Uri>[];
  bool succeeds = true;
  bool fails = false;
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    if (fails) throw StateError('synthetic platform failure');
    return succeeds;
  }
}

void main() {
  test('only absolute, credential-free web links reach the platform', () {
    for (final value in <String?>[
      null,
      '',
      '/notes',
      '//example.org',
      'javascript:alert(1)',
      'data:text/html,hello',
      'file:///tmp/writing',
      'mailto:a@b.com',
      'https:example.org',
      'https://user:pass@example.org',
      'https://a b.com',
      'https://example.org\\path',
      'https://example.org\n',
    ]) {
      expect(safeNoteLink(value), isNull, reason: '$value');
    }
    for (final value in [
      'https://example.org/a?q=words#part',
      'http://example.org',
      'https://example.org/中文',
    ]) {
      expect(safeNoteLink(value), isNotNull);
    }
  });

  Future<void> preview(
    WidgetTester tester,
    String text,
    _Launcher launcher, {
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteLinkLauncherProvider.overrideWithValue(launcher)],
        child: MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: NoteMarkdownPreview(text: text),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'links validate, launch externally through injection and expose failures',
    (tester) async {
      final launcher = _Launcher();
      await preview(tester, '[Visit](https://example.org)', launcher);
      await tester.tap(find.text('Visit', findRichText: true));
      await tester.pumpAndSettle();
      expect(launcher.opened.single, Uri.parse('https://example.org'));
      void link(String href) => tester
          .widget<MarkdownBody>(find.byType(MarkdownBody))
          .onTapLink!('link', href, '');
      link('javascript:alert(1)');
      await tester.pumpAndSettle();
      expect(launcher.opened.length, 1);
      expect(find.textContaining('Only complete http'), findsOneWidget);
      launcher.succeeds = false;
      link('https://example.org');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This link could not be opened'),
        findsOneWidget,
      );
      launcher.fails = true;
      link('https://example.org');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('read-only notes expose the checked state without a tap action', (
    tester,
  ) async {
    const id = '11111111111111111111111111111111';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteDocumentProvider(id)
              .overrideWith((_) => Stream.value(const OpenNote())),
          syncCanEditProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NoteMarkdownPreview(
              text: '- [x] Finished',
              readingNoteId: id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final checkbox = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.checked == true,
    );
    expect(tester.widget<Semantics>(checkbox).properties.enabled, isFalse);
    expect(
      find.descendant(of: checkbox, matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  for (final simple in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'malformed Markdown, HTML, omitted images and narrow large text dark=$dark simple=$simple',
        (tester) async {
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = FakeViewPadding(top: 24, bottom: 16);
          tester.view.viewInsets = FakeViewPadding(bottom: 100);
          tester.platformDispatcher.textScaleFactorTestValue = 3;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(
                disableAnimations: simple,
                reduceMotion: simple,
              );
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await preview(
            tester,
            '# Heading\n\n**Unclosed [broken](\n\n<script>alert("no")</script>\n\n![remote](https://example.org/private.png)\n\n![local](file:///tmp/private.png)\n\n| A | B |\n|---|---|\n| Long words | é 中文 |\n\n- one\n- two\n\n```dart\n${'x' * 400}\n```\n\n[web](https://example.org)',
            _Launcher(),
            dark: dark,
          );
          expect(find.byType(Image), findsNothing);
          expect(find.text('Image omitted: remote'), findsOneWidget);
          expect(find.text('Image omitted: local'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('long content is still shown formatted, never as plain text', (
    tester,
  ) async {
    await preview(tester, List.filled(1200, 'Some **writing**.').join('\n'), _Launcher());
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('plain text'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
