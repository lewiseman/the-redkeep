import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/assets/presentation/local_artwork.dart';
import 'package:redkeep/features/ai/data/ai_preferences_repository.dart';
import 'package:redkeep/features/ai/domain/ai_route.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_ai_provider.dart';
import '../../support/fake_required_assets.dart';
import '../../support/pump_app.dart';

const _id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _body =
    'I keep putting off calling my sister, even though I want to catch up.';
const _reflection =
    'Wanting to catch up can sit alongside putting the call off.';

class _RecordingAssets extends FakeRequiredAssets {
  final resolved = <String, Uri>{};

  @override
  Future<Uri> resolve(String key) async {
    final uri = await super.resolve(key);
    resolved[key] = uri;
    return uri;
  }
}

void main() {
  late AppDatabase db;
  late DriftFlowRepository flow;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    flow = DriftFlowRepository(db, clock: () => DateTime(2026, 11, 5, 12));
    await flow.save(id: _id, body: _body, expectedRevision: 0);
  });
  tearDown(() => db.close());

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('reader back control restores the search and its query', (
    tester,
  ) async {
    final assets = _RecordingAssets();
    final router = await pumpApp(
      tester,
      initialLocation: '/flow/search',
      flow: flow,
      database: db,
      assets: assets,
    );
    try {
      final field = find.byKey(const ValueKey('flow-search-field'));
      await tester.enterText(field, 'sister');
      await tester.pumpAndSettle();
      await tap(tester, find.text(_body));
      expect(router.state.uri.path, '/flow/$_id');
      expect(find.widgetWithText(SelectableText, _body), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-reflect')), findsNothing);
      expect(assets.resolved, isNot(contains('flow.reflect')));

      await tap(tester, find.byTooltip('Back'));
      expect(router.state.uri.path, '/flow/search');
      expect(tester.widget<TextField>(field).controller!.text, 'sister');
      expect(find.text(_body), findsOneWidget);
      expect((await flow.openDocument(_id)).thought!.revision, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  for (final (theme, scale) in [(AppTheme.light, 1.0), (AppTheme.dark, 3.0)]) {
    testWidgets(
      'downloaded reflection artwork still requests, keeps, dismisses and removes reflections; $theme ${scale}x',
      (tester) async {
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final appearance = FakeAppearanceRepository(
          AppearancePreferences(
            theme: theme,
            reduceMotion: true,
            simplerEffects: scale > 1,
          ),
        );
        addTearDown(appearance.close);
        final assets = _RecordingAssets();
        await tester.runAsync(
          () => AiPreferencesRepository(db).setDefaultRoute(
            AiRoute.provider(testAiProvider.id, 'test-model'),
          ),
        );
        final aiProvider = FakeAiProviderClient(_reflection);
        final router = await pumpApp(
          tester,
          initialLocation: '/flow/$_id',
          flow: flow,
          database: db,
          assets: assets,
          aiEnabled: true,
          repository: appearance,
          aiProvider: aiProvider,
        );
        try {
          final artwork = find.byWidgetPredicate(
            (widget) =>
                widget is LocalArtwork && widget.assetKey == 'flow.reflect',
          );
          expect(assets.resolved['flow.reflect']?.scheme, 'file');
          final image = tester.widget<Image>(
            find.descendant(of: artwork, matching: find.byType(Image)),
          );
          final file = (image.image as ResizeImage).imageProvider as FileImage;
          expect(file.file.uri, assets.resolved['flow.reflect']);
          final raw = find.descendant(
            of: artwork,
            matching: find.byType(RawImage),
          );
          for (var i = 0; i < 50; i++) {
            if ((tester.renderObject<RenderImage>(raw)).image != null) break;
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          expect(tester.renderObject<RenderImage>(raw).image, isNotNull);

          Future<void> reflect() async {
            await tap(tester, find.byKey(const ValueKey('flow-reflect')));
            for (
              var i = 0;
              i < 30 && find.text('Keep reflection').evaluate().isEmpty;
              i++
            ) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            await tester.pumpAndSettle();
            expect(find.text(_reflection), findsWidgets);
          }

          await reflect();
          await tap(tester, find.text('Keep reflection'));
          expect(
            (await tester.runAsync(
              () => db.select(db.flowReflections).getSingle(),
            ))!.status,
            'kept',
          );
          await reflect();
          await tap(tester, find.text('Dismiss reflection'));
          expect(
            (await tester.runAsync(
              () => db.select(db.flowReflections).getSingle(),
            ))!.status,
            'kept',
          );
          await tap(tester, find.text('Remove reflection'));
          expect(await db.select(db.flowReflections).get(), isEmpty);
          expect(aiProvider.requests, hasLength(2));
          final thought = (await flow.openDocument(_id)).thought!;
          expect(thought.body, _body);
          expect(thought.revision, 1);
          await tap(tester, find.text('AI task history'));
          expect(router.state.uri.path, '/settings/brain/history');
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
        }
      },
    );
  }
}
