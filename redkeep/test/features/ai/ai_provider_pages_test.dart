import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/data/ai_preferences_repository.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/ai/domain/ai_route.dart';

import '../../support/fake_ai_provider.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;
  late AiPreferencesRepository prefs;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    prefs = AiPreferencesRepository(db);
  });
  tearDown(() => db.close());

  Future<void> finish(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void useSize(WidgetTester tester, {double width = 390, double scale = 1}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  testWidgets(
    'Grand Maestar links to providers and tasks with no phone setup',
    (tester) async {
      useSize(tester);
      final router = await pumpApp(
        tester,
        initialLocation: '/settings/brain',
        database: db,
      );
      expect(find.text('Manage phone models'), findsNothing);
      expect(find.text('AI on this phone'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('ai-providers-link')));
      expect(router.state.uri.path, '/settings/brain/providers');
      await tap(tester, find.byKey(const ValueKey('ai-preset-anthropic')));
      expect(router.state.uri.path, '/settings/brain/providers/add/anthropic');
      await finish(tester);
    },
  );

  testWidgets('a saved token is never shown again and stays when left blank', (
    tester,
  ) async {
    useSize(tester);
    final aiProvider = FakeAiProviderClient();
    await pumpApp(
      tester,
      initialLocation: '/settings/brain/providers/${testAiProvider.id}',
      database: db,
      aiProvider: aiProvider,
    );
    await tester.pumpAndSettle();
    final token = find.byKey(const ValueKey('ai-provider-token'));
    expect(tester.widget<TextField>(token).controller!.text, isEmpty);
    expect(tester.widget<TextField>(token).obscureText, isTrue);
    expect(find.textContaining(testAiProvider.token), findsNothing);
    await tap(tester, find.byKey(const ValueKey('ai-provider-test')));
    expect(find.text('Connected. 1 model available.'), findsOneWidget);
    aiProvider.failure = const AiProviderFailure(
      AiProviderFailureKind.badToken,
    );
    await tap(tester, find.byKey(const ValueKey('ai-provider-test')));
    expect(find.textContaining('rejected this token'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a preset needs its token, and only https is accepted', (
    tester,
  ) async {
    useSize(tester);
    await pumpApp(
      tester,
      initialLocation: '/settings/brain/providers/add/openai',
      database: db,
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('ai-provider-advanced')));
    final url = tester.widget<TextField>(
      find.byKey(const ValueKey('ai-provider-url')),
    );
    expect(url.controller!.text, 'https://api.openai.com/v1');
    await tap(tester, find.byKey(const ValueKey('ai-provider-connect')));
    expect(find.textContaining('Enter the key'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('ai-provider-token')),
      'typed-token',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai-provider-url')),
      'http://insecure.example',
    );
    await tap(tester, find.byKey(const ValueKey('ai-provider-connect')));
    expect(find.textContaining('https://'), findsWidgets);
    expect(find.textContaining('plain https'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a task picks provider then model; daily question asks first', (
    tester,
  ) async {
    useSize(tester);
    await pumpApp(
      tester,
      initialLocation: '/settings/brain/tasks',
      database: db,
    );
    await tester.pumpAndSettle();

    await tap(tester, find.byKey(const ValueKey('ai-task-noteRewrite')));
    await tap(
      tester,
      find.byKey(ValueKey('ai-route-provider-${testAiProvider.id}')),
    );
    await tap(tester, find.text('test-model'));
    expect(
      (await tester.runAsync(prefs.read))!.routeFor(AiOperation.noteRewrite),
      AiRoute.provider(testAiProvider.id, 'test-model'),
    );
    expect(find.byKey(const ValueKey('daily-opt-in-allow')), findsNothing);

    await tap(tester, find.byKey(const ValueKey('ai-task-dailyQuestion')));
    await tap(
      tester,
      find.byKey(ValueKey('ai-route-provider-${testAiProvider.id}')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai-route-model')),
      'typed-model',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('ai-route-model-use')));
    expect(find.textContaining('Let Test AI ask'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('daily-opt-in-decline')));
    var stored = (await tester.runAsync(prefs.read))!;
    expect(stored.routeFor(AiOperation.dailyQuestion).model, 'typed-model');
    expect(stored.dailyQuestionMayRunAutomatically, isFalse);

    final toggle = find.byKey(const ValueKey('daily-auto-toggle'));
    await tap(tester, toggle);
    await tap(tester, find.byKey(const ValueKey('daily-opt-in-allow')));
    stored = (await tester.runAsync(prefs.read))!;
    expect(stored.dailyQuestionMayRunAutomatically, isTrue);
    await finish(tester);
  });

  testWidgets('connecting checks first, then offers what to do next', (
    tester,
  ) async {
    useSize(tester);
    final aiProvider = FakeAiProviderClient()
      ..failure = const AiProviderFailure(AiProviderFailureKind.badToken);
    await pumpApp(
      tester,
      initialLocation: '/settings/brain/providers/add/groq',
      database: db,
      aiProvider: aiProvider,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai-provider-token')),
      'typed-key',
    );
    await tap(tester, find.byKey(const ValueKey('ai-provider-connect')));
    expect(find.textContaining('rejected this token'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-provider-connected')), findsNothing);
    expect(find.byKey(const ValueKey('ai-provider-save')), findsOneWidget);

    aiProvider.failure = null;
    await tap(tester, find.byKey(const ValueKey('ai-provider-connect')));
    expect(find.byKey(const ValueKey('ai-provider-connected')), findsOneWidget);
    expect(find.text('Groq is connected'), findsOneWidget);
    expect(find.textContaining('typed-key'), findsNothing);

    await tap(tester, find.byKey(const ValueKey('ai-connected-all')));
    await tap(tester, find.text('test-model'));
    expect(find.textContaining('Let Groq ask'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('daily-opt-in-decline')));
    final stored = (await tester.runAsync(prefs.read))!;
    expect(stored.defaultRoute.model, 'test-model');
    expect(stored.dailyQuestionMayRunAutomatically, isFalse);
    await finish(tester);
  });

  testWidgets('route all moves a whole group and the model list is searchable', (
    tester,
  ) async {
    useSize(tester);
    final aiProvider = FakeAiProviderClient()
      ..models = const ['alpha-large', 'beta-small', 'gamma-large'];
    await pumpApp(
      tester,
      initialLocation: '/settings/brain/tasks',
      database: db,
      aiProvider: aiProvider,
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('ai-group-notes')));
    await tap(
      tester,
      find.byKey(ValueKey('ai-route-provider-${testAiProvider.id}')),
    );
    expect(find.text('beta-small'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('ai-route-model')),
      'LARGE',
    );
    await tester.pumpAndSettle();
    expect(find.text('alpha-large'), findsOneWidget);
    expect(find.text('gamma-large'), findsOneWidget);
    expect(find.text('beta-small'), findsNothing);
    await tap(tester, find.text('gamma-large'));
    await tap(tester, find.byKey(const ValueKey('ai-task-noteTone')));
    await tap(
      tester,
      find.byKey(ValueKey('ai-route-provider-${testAiProvider.id}')),
    );
    expect(
      tester.getTopLeft(find.text('gamma-large')).dy,
      lessThan(tester.getTopLeft(find.text('alpha-large')).dy),
      reason: 'The model in use is pinned first.',
    );
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    final stored = (await tester.runAsync(prefs.read))!;
    for (final operation in AiOperation.values.where((o) => o.isNote)) {
      expect(
        stored.routeFor(operation).model,
        operation.supportsProvider ? 'gamma-large' : isNull,
        reason: operation.name,
      );
    }
    expect(stored.routeFor(AiOperation.diaryDetails).isCompanion, isTrue);
    expect(find.text('On your network · 4 tasks'), findsOneWidget);
    expect(find.text('Over the internet · 10 tasks'), findsOneWidget);
    await finish(tester);
  });

  for (final layout in [
    (width: 280.0, scale: 1.0),
    (width: 320.0, scale: 3.0),
  ]) {
    testWidgets('provider pages fit $layout', (tester) async {
      useSize(tester, width: layout.width, scale: layout.scale);
      final router = await pumpApp(
        tester,
        initialLocation: '/settings/brain/tasks',
        database: db,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final location in [
        '/settings/brain/providers',
        '/settings/brain/providers/add/custom',
        '/settings/brain/providers/${testAiProvider.id}',
      ]) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
      }
      await finish(tester);
    });
  }
}
