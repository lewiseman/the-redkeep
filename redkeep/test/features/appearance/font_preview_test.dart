import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redkeep/core/presentation/diary_typography.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/application/appearance_typography.dart';
import 'package:redkeep/features/appearance/data/font_preview_loader.dart';
import 'package:redkeep/features/appearance/domain/appearance_fonts.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/appearance/presentation/font_picker.dart';

import '../../support/fake_appearance_fonts.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';

const _subsetUrl = 'https://fonts.gstatic.com/l/font?kit=abc';
const _css = "@font-face { src: url($_subsetUrl) format('truetype'); }";

void main() {
  group('FontPreviewLoader', () {
    late Directory cache;
    late List<Uri> requests;
    late List<String> registered;

    setUp(() {
      cache = Directory.systemTemp.createTempSync('font_preview_test');
      requests = [];
      registered = [];
    });
    tearDown(() => cache.deleteSync(recursive: true));

    FontPreviewLoader loader({
      Future<http.Response> Function(http.Request)? respond,
      int maxConcurrent = 4,
    }) => FontPreviewLoader(
      client: MockClient((request) async {
        requests.add(request.url);
        if (respond != null) return respond(request);
        return request.url.host == 'fonts.googleapis.com'
            ? http.Response(_css, 200)
            : http.Response.bytes([1, 2, 3], 200);
      }),
      cacheDirectory: () async => cache,
      registerFont: (family, _) async => registered.add(family),
      maxConcurrent: maxConcurrent,
    );

    test('requests only a subset of the sample, then reuses it', () async {
      final first = loader();
      final family = await first.load('Literata');
      expect(family, isNotNull);
      expect(first.readyFamily('Literata'), family);
      expect(family, isNot('Literata'));
      expect(requests, hasLength(2));
      expect(requests.first.queryParameters['text'], fontPreviewSample);
      expect(requests.last.toString(), _subsetUrl);

      await first.load('Literata');
      expect(requests, hasLength(2));

      // A later session reads the disk cache without the network.
      final second = loader();
      expect(await second.load('Literata'), family);
      expect(requests, hasLength(2));
      expect(registered, hasLength(2));
    });

    test('a family the API rejects is not requested again', () async {
      final subject = loader(
        respond: (_) async => http.Response('Bad request', 400),
      );
      expect(await subject.load('Literata'), isNull);
      expect(await subject.load('Literata'), isNull);
      expect(requests, hasLength(1));
    });

    test('a network failure can be retried and leaves no cache', () async {
      var online = false;
      final subject = loader(
        respond: (request) async {
          if (!online) throw http.ClientException('offline');
          return request.url.host == 'fonts.googleapis.com'
              ? http.Response(_css, 200)
              : http.Response.bytes([1], 200);
        },
      );
      expect(await subject.load('Literata'), isNull);
      online = true;
      expect(await subject.load('Literata'), isNotNull);
    });

    test('a damaged cache entry is replaced by a fresh download', () async {
      await loader().load('Literata');
      requests.clear();
      var failOnce = true;
      final subject = FontPreviewLoader(
        client: MockClient((request) async {
          requests.add(request.url);
          return request.url.host == 'fonts.googleapis.com'
              ? http.Response(_css, 200)
              : http.Response.bytes([9], 200);
        }),
        cacheDirectory: () async => cache,
        registerFont: (_, _) async {
          if (failOnce) {
            failOnce = false;
            throw StateError('invalid font');
          }
        },
      );
      expect(await subject.load('Literata'), isNotNull);
      expect(requests, hasLength(2));
    });

    test(
      'caps concurrency, loads newest first, and drops cancelled requests',
      () async {
        final gates = <String, Completer<http.Response>>{};
        final subject = loader(
          maxConcurrent: 1,
          respond: (request) {
            final family = request.url.queryParameters['family']!;
            return (gates[family] = Completer()).future;
          },
        );
        final familyA = fontPreviewApiFamily('Lora');
        final familyC = fontPreviewApiFamily('Literata');
        final a = subject.load('Lora');
        final b = subject.load('Poppins');
        final c = subject.load('Literata');
        await pumpEventQueue();
        expect(gates.keys, [familyA]);

        subject.cancel('Poppins');
        expect(await b, isNull);
        gates[familyA]!.complete(http.Response('', 404));
        expect(await a, isNull);
        await pumpEventQueue();
        expect(gates.keys, [familyA, familyC]);
        gates[familyC]!.complete(http.Response('', 404));
        expect(await c, isNull);
      },
    );

    test(
      'a queued request survives while another row still wants it',
      () async {
        final gate = Completer<http.Response>();
        final subject = loader(maxConcurrent: 1, respond: (_) => gate.future);
        final running = subject.load('Abel');
        final first = subject.load('Lora');
        final second = subject.load('Lora');
        subject.cancel('Lora');
        gate.complete(http.Response('', 404));
        await running;
        await first;
        await second;
        expect(requests, hasLength(2));
      },
    );

    test('names a real style for families without an upright regular', () {
      expect(fontPreviewApiFamily('Literata'), 'Literata:wght@400');
      expect(fontPreviewApiFamily('Buda'), 'Buda:wght@300');
      expect(fontPreviewApiFamily('UnifrakturCook'), 'UnifrakturCook:wght@700');
      expect(fontPreviewApiFamily('Molle'), 'Molle:ital,wght@1,400');
    });
  });

  group('font picker', () {
    Future<FakeFontPreviewLoader> open(
      WidgetTester tester, {
      FontRole role = FontRole.diaryBody,
      String selectedFont = 'Literata',
      Future<void> Function(String)? onSelected,
      Map<String, String> ready = const {},
    }) async {
      final previews = FakeFontPreviewLoader()..ready.addAll(ready);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [fontPreviewLoaderProvider.overrideWithValue(previews)],
          child: MaterialApp(
            builder: (context, child) => RenderingPolicyScope(
              policy: RenderingPolicy(
                osReducedMotion: false,
                preferences: const AppearancePreferences(),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFontPicker(
                  context,
                  title: 'Diary body font',
                  role: role,
                  selectedFont: selectedFont,
                  onSelected: onSelected ?? (_) async {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return previews;
    }

    testWidgets('suggestions lead with the font in use, then all fonts', (
      tester,
    ) async {
      await open(tester, selectedFont: 'Abel');
      expect(find.text('Using Abel'), findsOneWidget);
      expect(find.text('Suggested'), findsOneWidget);
      final rows = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((row) => (row.title! as Text).data!)
          .toList();
      expect(rows.take(3), ['Abel', 'Literata', 'Lora']);
    });

    test('every suggestion is a font the catalog can load', () {
      for (final role in FontRole.values) {
        expect(fontSuggestions[role], isNotEmpty);
        for (final font in fontSuggestions[role]!) {
          expect(AppearanceFonts.supports(font), isTrue, reason: font);
        }
      }
    });

    testWidgets('search ranks name starts first and ignores spaces', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'lora');
      await tester.pump();
      expect(find.text('Suggested'), findsNothing);
      final first = tester.widget<ListTile>(find.byType(ListTile).first);
      expect((first.title! as Text).data, 'Lora');

      await tester.enterText(find.byType(TextField), 'sourceserif4');
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'Source Serif 4'), findsOneWidget);
      expect(find.text('1 font'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'no-such-font');
      await tester.pump();
      expect(find.text('No fonts found'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Clear search'));
      await tester.pump();
      expect(find.text('Suggested'), findsOneWidget);
    });

    testWidgets('a failed font says so on its row, which can be retried', (
      tester,
    ) async {
      var fail = true;
      final picked = <String>[];
      await open(
        tester,
        onSelected: (font) async {
          if (fail) throw StateError('offline');
          picked.add(font);
        },
      );
      final lora = find.widgetWithText(ListTile, 'Lora').first;
      await tester.tap(lora);
      await tester.pump();
      expect(
        find.descendant(
          of: lora,
          matching: find.textContaining('couldn’t be loaded'),
        ),
        findsOneWidget,
      );
      expect(find.text('Using Literata'), findsOneWidget);
      fail = false;
      await tester.tap(lora);
      await tester.pump();
      expect(picked, ['Lora']);
      expect(find.text('Using Lora'), findsOneWidget);
      expect(find.textContaining('couldn’t be loaded'), findsNothing);
    });

    testWidgets('loads previews only for the rows on screen', (tester) async {
      final previews = await open(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(previews.requested, isNotEmpty);
      expect(previews.requested.length, lessThan(40));
      expect(AppearanceFonts.families.length, greaterThan(1000));
    });

    testWidgets('rows that leave before settling request nothing', (
      tester,
    ) async {
      final previews = await open(tester);
      await tester.pump(const Duration(milliseconds: 200));
      previews.requested.clear();
      await tester.enterText(find.byType(TextField), 'Z');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'Literata');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(previews.requested, ['Literata']);
    });

    testWidgets('a row renders in its preview family, or says it has none', (
      tester,
    ) async {
      await open(tester, ready: const {'Literata': 'preview-literata'});
      await tester.enterText(find.byType(TextField), 'Literata');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final sample = tester.widget<Text>(find.text(fontPreviewSample));
      expect(sample.style!.fontFamily, 'preview-literata');

      await tester.enterText(find.byType(TextField), 'Lora');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Preview unavailable'), findsWidgets);
    });

    testWidgets('previews stay out of the accessibility tree', (tester) async {
      final handle = tester.ensureSemantics();
      final previews = await open(tester);
      previews.ready['Literata'] = 'preview-literata';
      await tester.enterText(find.byType(TextField), 'Literata');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(fontPreviewSample)), findsNothing);
      handle.dispose();
    });
  });

  testWidgets('appearance page no longer shows a typography preview', (
    tester,
  ) async {
    final repository = FakeAppearanceRepository();
    addTearDown(repository.close);
    await pumpApp(tester, initialLocation: '/settings', repository: repository);
    expect(find.text('Diary body font'), findsOneWidget);
    expect(find.text('A little room to breathe.'), findsNothing);
    expect(find.textContaining('Coffee by the window'), findsNothing);
  });

  test('the diary body default is a supported Google Font', () {
    const family = AppearancePreferences.defaultDiaryBodyFontFamily;
    expect(family, 'Literata');
    expect(AppearanceFonts.supports(family), isTrue);
    expect(const DiaryTypography().body.fontFamily, family);
  });
}
