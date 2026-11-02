import 'package:redkeep/features/notes/data/drift_notes_repository.dart';

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/flow/application/flow_editor_controller.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';

import '../../support/controlled_flow_repository.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';

const id = '11111111111111111111111111111111';
void main() {
  late AppDatabase db;
  late ControlledFlowRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ControlledFlowRepository(
      DriftFlowRepository(db, clock: () => DateTime.utc(2026, 11, 2)),
    );
  });
  tearDown(() => db.close());
  void flowTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
  Future<void> tap(WidgetTester tester, String label) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final control = find.text(label);
    if (control.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        control,
        120,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    expect(control.hitTestable(), findsOneWidget);
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  Future<void> seed({
    String body = 'Synthetic thought 👩🏽‍💻',
    String key = id,
  }) async {
    final d = await repo.putDraft(
      id: key,
      body: body,
      capture: false,
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    await repo.commitDraft(key, d.draftRevision);
  }

  Finder field() => find.byKey(const ValueKey('flow-body'));
  String buffer(WidgetTester tester) =>
      tester.widget<TextField>(field()).controller!.text;

  flowTest(
    'empty → capture after commit → ID read/edit → confirm/cancel delete → deleted routes',
    (tester) async {
      var counter = 0;
      final router = await pumpApp(
        tester,
        initialLocation: '/flow',
        flow: repo,
        flowId: () => (++counter).toString().padLeft(32, '1'),
      );
      await tester.scrollUntilVisible(
        find.text('No thoughts yet. Capture a thought whenever you’re ready.'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(field());
      await tester.enterText(field(), 'Quick capture 中文');
      await tester.pumpAndSettle();
      await tap(tester, 'Capture thought');
      expect(buffer(tester), '');
      expect(find.text('Thought captured on this device.'), findsOneWidget);
      final saved = (await repo.watchThoughts().first).single;
      await tap(tester, 'Quick capture 中文');
      expect(
        router.routeInformationProvider.value.uri.path,
        thoughtLocation(saved.id),
      );
      await tap(tester, 'Edit thought');
      await tester.enterText(field(), 'Revised thought');
      await tester.pumpAndSettle();
      await tap(tester, 'Save thought');
      expect(find.text('Saved revision 2 on this device.'), findsOneWidget);
      await tap(tester, 'Read committed thought');
      await tap(tester, 'Delete thought');
      await tap(tester, 'Keep thought');
      expect((await repo.openDocument(saved.id)).available, isTrue);
      await tap(tester, 'Delete thought');
      await tap(tester, 'Delete committed thought');
      expect(router.routeInformationProvider.value.uri.path, '/flow');
      router.go(thoughtLocation(saved.id));
      await tester.pumpAndSettle();
      expect(find.text('Thought unavailable'), findsOneWidget);
      expect(find.text('Revised thought'), findsNothing);
      router.go(thoughtLocation(saved.id, edit: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('Editor unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  flowTest(
    'composer retains failures across navigation and clears only after delayed commit',
    (tester) async {
      final router = await pumpApp(
        tester,
        initialLocation: '/flow',
        flow: repo,
        flowId: () => id,
      );
      repo.failDraft = true;
      await tester.enterText(field(), 'Do not lose this');
      await tester.pumpAndSettle();
      await tap(tester, 'Capture thought');
      expect(buffer(tester), 'Do not lose this');
      router.go('/more');
      await tester.pumpAndSettle();
      router.go('/flow');
      await tester.pumpAndSettle();
      expect(buffer(tester), 'Do not lose this');
      repo.failDraft = false;
      await tap(tester, 'Retry recovery');
      repo.failCommit = true;
      await tap(tester, 'Capture thought');
      expect(buffer(tester), 'Do not lose this');
      expect((await repo.openCapture())!.body, 'Do not lose this');
      repo.failCommit = false;
      repo.commitGate = Completer<void>();
      final pending = tester
          .container()
          .read(flowEditorProvider(null).notifier)
          .save();
      await tester.pump();
      expect(buffer(tester), 'Do not lose this');
      expect(tester.widget<TextField>(field()).enabled, isFalse);
      expect(find.text('Saving…'), findsOneWidget);
      repo.commitGate!.complete();
      await pending;
      await tester.pumpAndSettle();
      expect(buffer(tester), '');
      expect(tester.takeException(), isNull);
    },
  );
  flowTest(
    'restart restores composer; explicit discard keeps committed writing',
    (tester) async {
      await seed();
      await pumpApp(
        tester,
        initialLocation: '/flow',
        flow: repo,
        flowId: () => '2' * 32,
      );
      await tester.enterText(field(), 'Unfinished capture');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, initialLocation: '/flow', flow: repo);
      expect(buffer(tester), 'Unfinished capture');
      await tap(tester, 'Discard draft');
      await tap(tester, 'Keep writing');
      expect(buffer(tester), 'Unfinished capture');
      await tap(tester, 'Discard draft');
      await tap(tester, 'Discard');
      expect(buffer(tester), '');
      expect(await repo.watchThoughts().first, hasLength(1));
    },
  );
  flowTest(
    'load failures have retry; no empty composer can overwrite an unread draft',
    (tester) async {
      repo.failRead = true;
      final router = await pumpApp(
        tester,
        initialLocation: '/flow',
        flow: repo,
      );
      expect(
        find.textContaining('Capture draft could not be loaded.'),
        findsOneWidget,
      );
      expect(field(), findsNothing);
      expect(find.text('Thoughts could not be loaded.'), findsOneWidget);
      repo.failRead = false;
      await tap(tester, 'Retry opening');
      await tester.tap(find.text('Retry loading').first);
      await tester.pumpAndSettle();
      expect(field(), findsOneWidget);
      repo.failRead = true;
      router.go(thoughtLocation(id));
      await tester.pumpAndSettle();
      expect(find.text('Could not load thought. Retry'), findsOneWidget);
      repo.failRead = false;
      await tap(tester, 'Could not load thought. Retry');
      expect(find.text('Thought unavailable'), findsOneWidget);
    },
  );
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final simple in [false, true]) {
      flowTest(
        '320px 3x keyboard/safe areas composer/reader/editor/dialogs $theme simple=$simple',
        (tester) async {
          await seed();
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = FakeViewPadding(top: 24, bottom: 16);
          tester.view.viewInsets = FakeViewPadding(bottom: 180);
          tester.platformDispatcher.textScaleFactorTestValue = 3;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(
                disableAnimations: simple,
                reduceMotion: simple,
              );
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final appearance = FakeAppearanceRepository(
            AppearancePreferences(theme: theme, simplerEffects: simple),
          );
          addTearDown(appearance.close);
          final router = await pumpApp(
            tester,
            initialLocation: '/flow',
            flow: repo,
            repository: appearance,
            flowId: () => '2' * 32,
          );
          await tester.ensureVisible(field());
          await tester.enterText(field(), 'Large capture');
          await tester.pumpAndSettle();
          await tap(tester, 'Capture thought');
          expect(buffer(tester), '');
          router.go(thoughtLocation(id));
          await tester.pumpAndSettle();
          await tap(tester, 'Delete thought');
          await tap(tester, 'Keep thought');
          router.go(thoughtLocation(id, edit: true));
          await tester.pumpAndSettle();
          await tester.enterText(field(), 'Large edit');
          await tester.pumpAndSettle();
          await tap(tester, 'Save thought');
          expect(find.text('Saved revision 2 on this device.'), findsOneWidget);
          await tester.enterText(field(), 'Draft');
          await tester.pumpAndSettle();
          await tap(tester, 'Discard draft');
          await tap(tester, 'Keep writing');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  flowTest(
    'all four shell destinations remain usable with 3x text and no keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: 24, bottom: 16);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final router = await pumpApp(
        tester,
        flow: repo,
        notes: DriftNotesRepository(db, clock: () => DateTime.utc(2026)),
      );
      for (final destination in ['Notes', 'Flow', 'More', 'Diary']) {
        final control = find.widgetWithText(TextButton, destination);
        expect(control.hitTestable(), findsOneWidget);
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/${destination.toLowerCase()}',
        );
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.widgetWithText(TextButton, 'More'));
      await tester.pumpAndSettle();
      await tap(tester, 'Appearance');
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      expect(find.text('Theme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  flowTest('complete long Unicode reader/editor and lazy large collection', (
    tester,
  ) async {
    final body = 'Unicode 👩🏽‍💻 中文 e\u0301\n' * 5000;
    await seed(body: body);
    final router = await pumpApp(
      tester,
      initialLocation: thoughtLocation(id),
      flow: repo,
    );
    expect(find.text(body), findsOneWidget);
    router.go(thoughtLocation(id, edit: true));
    await tester.pumpAndSettle();
    expect(buffer(tester), body);
    await db.batch((batch) {
      batch.insertAll(db.flowThoughts, [
        for (var i = 100; i < 2100; i++)
          FlowThoughtsCompanion.insert(
            id: i.toRadixString(16).padLeft(32, '0'),
            body: 'Synthetic $i',
            revision: 1,
            createdAt: i,
            updatedAt: i,
          ),
      ]);
    });
    router.go('/flow');
    await tester.pumpAndSettle();
    expect(await repo.watchThoughts().first, hasLength(2001));
    expect(find.byType(ListTile).evaluate().length, lessThan(25));
    expect(tester.takeException(), isNull);
  });
}
