import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/app/writing_shell.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/flow/application/flow_editor_controller.dart';
import 'package:redkeep/features/flow/application/flow_providers.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';
import 'package:redkeep/features/flow/presentation/flow_composer.dart';
import 'package:redkeep/features/flow/presentation/flow_opening.dart';
import 'package:redkeep/features/flow/presentation/flow_page.dart';
import 'package:redkeep/features/flow/presentation/flow_thought_card.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';

import '../../support/controlled_flow_repository.dart';
import '../../support/fake_required_assets.dart';

const _captureKey = ValueKey('flow-scene-capture');
final _history = find.byKey(const PageStorageKey('flow-history'));
final _field = find.byKey(const ValueKey('flow-body'));
ScrollController _scroll(WidgetTester tester) =>
    tester.widget<CustomScrollView>(_history).controller!;
FlowSceneLayout _layout(WidgetTester tester) =>
    (tester
                .widget<SliverPersistentHeader>(
                  find.byType(SliverPersistentHeader),
                )
                .delegate
            as FlowOpening)
        .layout;

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('FLOW_CAPTURES')) return;
  final previous = debugDisableShadows;
  try {
    debugDisableShadows = false;
    for (final object in tester.allRenderObjects) {
      object.markNeedsPaint();
    }
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 2);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/redkeep-flow-$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  } finally {
    debugDisableShadows = previous;
    for (final object in tester.allRenderObjects) {
      object.markNeedsPaint();
    }
    await tester.pump();
  }
}

void main() {
  late AppDatabase db;
  late ControlledFlowRepository repo;
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final font = File.fromUri(
      File(Platform.resolvedExecutable).uri
          .resolve('../../material_fonts/Roboto-Regular.ttf'),
    );
    if (font.existsSync()) {
      await (FontLoader('FlowTest')..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          ))
          .load();
    }
  });
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ControlledFlowRepository(
      DriftFlowRepository(db, clock: () => DateTime(2026, 11, 3, 12)),
    );
  });
  tearDown(() => db.close());
  void sceneTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });

  Future<void> mount(
    WidgetTester tester, {
    int count = 12,
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    bool reduced = false,
    bool simple = false,
  }) async {
    const examples = [
      'A quiet morning, a warm cup, and a little time to think.',
      'Remember to make room for the things that matter.',
      'An idea for tomorrow: take the longer walk home.',
      'Some days a small beginning is enough.',
      'The conversation stayed with me long after we said goodbye.',
      'There is still so much to notice.',
    ];
    for (var i = 0; i < count; i++) {
      await repo.save(
        id: i.toRadixString(16).padLeft(32, '0'),
        body: examples[i % examples.length],
        expectedRevision: 0,
      );
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final base = dark ? RedkeepTheme.dark : RedkeepTheme.light;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncEnabledProvider.overrideWithValue(false),
          flowRepositoryProvider.overrideWithValue(repo),
          flowIdProvider.overrideWithValue(() => 'f' * 32),
          requiredAssetsProvider.overrideWith(
            (ref) async => FakeRequiredAssets(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: base.copyWith(
            textTheme: base.textTheme.apply(fontFamily: 'FlowTest'),
          ),
          home: RenderingPolicyHost(
            preferences: AppearancePreferences(
              reduceMotion: reduced,
              simplerEffects: simple,
            ),
            child: const RepaintBoundary(
              key: _captureKey,
              child: WritingShell(location: '/flow', child: FlowPage()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // File reads and engine decoding run outside the widget test's fake clock.
    // Pump between IO turns so the resolver and then the Image can publish.
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      final pictures = find.byType(RawImage);
      if (pictures.evaluate().length == 5 &&
          pictures.evaluate().every(
            (element) => (element.renderObject! as RenderImage).image != null,
          )) {
        break;
      }
    }
    expect(find.byType(RawImage), findsNWidgets(5));
    for (final element in find.byType(RawImage).evaluate()) {
      expect((element.renderObject! as RenderImage).image, isNotNull);
    }
    await tester.pumpAndSettle();
  }

  sceneTest(
    'opening settles without duplicate cards; input yields to history',
    (tester) async {
      await mount(tester);
      final mascot = tester.widget<Image>(
        find.byKey(const ValueKey('flow-mascot')),
      );
      final source = (mascot.image as ResizeImage).imageProvider as AssetImage;
      expect(source.assetName, 'assets/branding/grand_maestar.png');
      expect(_layout(tester).previewCount, 6);
      final original = tester.getRect(find.byType(FlowComposer));
      expect(original.left, 20);
      expect(original.right, 370);
      expect(find.byType(FloatingActionButton), findsNothing);
      await _capture(tester, 'opening');
      await tester.enterText(_field, 'A small idea worth keeping.');
      await tester.pumpAndSettle();
      await _capture(tester, 'typing');
      await tester.enterText(_field, '');
      tester.widget<TextField>(_field).focusNode!.unfocus();
      await tester.pumpAndSettle();
      _scroll(tester).jumpTo(30);
      await tester.pump();
      expect(tester.getRect(find.byType(FlowComposer)), original);
      _scroll(tester).jumpTo(_layout(tester).collapseExtent * .5);
      await tester.pump();
      await _capture(tester, 'transition');
      _scroll(tester).jumpTo(_layout(tester).collapseExtent);
      await tester.pump();
      final cards = tester.widgetList<FlowThoughtCard>(
        find.byType(FlowThoughtCard),
      );
      final ids = cards.map((card) => card.thought.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      final first = find.byKey(ValueKey('flow-thought-${ids[0]}'));
      final third = find.byKey(ValueKey('flow-thought-${ids[2]}'));
      expect(tester.getTopLeft(first).dx, tester.getTopLeft(third).dx);
      await _capture(tester, 'collection');
      _scroll(tester).jumpTo(_scroll(tester).position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(_field.hitTestable(), findsNothing);
      expect(
        tester.widget<TextField>(_field).focusNode!.canRequestFocus,
        isFalse,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      _scroll(tester).jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FlowComposer)), original);
      expect(_field.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  sceneTest('send appears only for text; failed Retry commits once', (
    tester,
  ) async {
    await mount(tester, count: 0);
    expect(find.byTooltip('Add thought'), findsNothing);
    await tester.enterText(_field, ' \n ');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add thought'), findsNothing);
    await tester.enterText(_field, 'Keep this thought 👩🏽‍💻');
    await tester.pumpAndSettle();
    final pill = tester.getRect(find.byType(FlowComposer));
    expect(
      pill.contains(tester.getCenter(find.byTooltip('Add thought'))),
      isTrue,
    );
    await _capture(tester, 'empty-typing');
    repo.failCommit = true;
    await tester.tap(find.byTooltip('Add thought'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_field).controller!.text,
      'Keep this thought 👩🏽‍💻',
    );
    expect(await repo.watchThoughts().first, isEmpty);
    repo.failCommit = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(await repo.watchThoughts().first, hasLength(1));
    expect(repo.commits, 2);
    expect(tester.widget<TextField>(_field).controller!.text, isEmpty);
    expect(_scroll(tester).offset, 0);
    expect(tester.takeException(), isNull);
  });

  sceneTest(
    'keyboard submit preserves draft until commit and blocks double send',
    (tester) async {
      await mount(tester);
      await tester.enterText(
        _field,
        'One thought\nAnother line\nMore to remember',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      _scroll(tester).jumpTo(_scroll(tester).position.maxScrollExtent);
      await tester.pumpAndSettle();
      final send = find.byTooltip('Add thought');
      expect(send.hitTestable(), findsOneWidget);
      expect(tester.getRect(send).bottom, lessThan(844 - 300));
      await _capture(tester, 'keyboard');
      repo.commitGate = Completer<void>();
      final before = repo.commits;
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(tester.widget<TextField>(_field).enabled, isFalse);
      expect(tester.widget<TextField>(_field).controller!.text, isNotEmpty);
      expect(
        await tester.container().read(flowEditorProvider(null).notifier).save(),
        isFalse,
      );
      repo.commitGate!.complete();
      await tester.pumpAndSettle();
      expect(repo.commits, before + 1);
      expect(tester.widget<TextField>(_field).controller!.text, isEmpty);
      expect(_scroll(tester).offset, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final config in [
    (
      name: 'narrow',
      size: Size(320, 480),
      scale: 3.0,
      dark: false,
      reduced: true,
      simple: false,
    ),
    (
      name: 'dark',
      size: Size(390, 844),
      scale: 1.0,
      dark: true,
      reduced: false,
      simple: false,
    ),
    (
      name: 'simple',
      size: Size(390, 844),
      scale: 1.0,
      dark: false,
      reduced: false,
      simple: true,
    ),
    (
      name: 'tablet',
      size: Size(1024, 1366),
      scale: 1.0,
      dark: false,
      reduced: false,
      simple: false,
    ),
  ]) {
    sceneTest(
      '${config.name}: readable, scrollable and focused input stays usable',
      (tester) async {
        await mount(
          tester,
          size: config.size,
          scale: config.scale,
          dark: config.dark,
          reduced: config.reduced,
          simple: config.simple,
        );
        expect(_layout(tester).width, lessThanOrEqualTo(760));
        expect(_layout(tester).columns, config.scale > 1.4 ? 1 : 2);
        await _capture(tester, config.name);
        _scroll(tester).jumpTo(_layout(tester).collapseExtent);
        await tester.pumpAndSettle();
        // The text stays within the cloud's body when it grows for large text.
        for (final element in find.byType(FlowThoughtCard).evaluate()) {
          final card = find.byWidget(element.widget);
          final bounds = tester.getRect(card);
          final material = tester.widget<Material>(
            find.descendant(of: card, matching: find.byType(Material)),
          );
          if (config.simple) expect(material.elevation, 0);
          final outline = material.shape!.getOuterPath(
            Offset.zero & bounds.size,
          );
          for (final text
              in find
                  .descendant(of: card, matching: find.byType(Text))
                  .evaluate()) {
            final rect = tester
                .getRect(find.byWidget(text.widget))
                .shift(-bounds.topLeft);
            for (final corner in [
              rect.topLeft,
              rect.topRight,
              rect.bottomLeft,
              rect.bottomRight,
            ]) {
              expect(outline.contains(corner), isTrue);
            }
          }
        }
        _scroll(tester).jumpTo(0);
        await tester.pumpAndSettle();
        await tester.enterText(
          _field,
          'Large thought\nSecond line\nThird line\nLast line',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Add thought').hitTestable(), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
        await tester.tap(find.byTooltip('Add thought'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(_field).controller!.text, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
