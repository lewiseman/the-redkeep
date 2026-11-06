import 'package:redkeep/app/more_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/onboarding/application/onboarding_controller.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/sync/presentation/sync_card.dart';
import 'package:redkeep/features/sync/presentation/sync_account_sheet.dart';
import 'package:redkeep/features/sync/presentation/reset_account_page.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../packages/sync_wise/test/support/memory_backend.dart';
import '../../support/fake_required_assets.dart';

class FixedEngine extends SyncEngine {
  FixedEngine(this.snapshot) : super((_) => throw UnimplementedError());
  final SyncEngineState snapshot;
  @override
  SyncEngineState build() => snapshot;
  @override
  Future<void> suspendForReset({bool requireIdle = false}) async {}
}

class NamedOnboarding extends OnboardingController {
  @override
  OnboardingState build() =>
      const OnboardingState(name: 'Lewis', complete: true);
}

class MemoryResetStorage extends AccountResetStorage {
  @override
  Future<bool> canSync() async => true;
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Brightness brightness,
    required String screen,
    double width = 390,
    double scale = 1,
    bool connected = true,
    SyncEngineState state = const SyncEngineState(
      role: SyncDeviceRole.secondary,
      primary: PrimaryDevice(
        deviceId: 'other',
        deviceName: 'Other phone',
        fileId: 'registry',
      ),
    ),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = MemoryBackend(MemoryDrive());
    if (!connected) backend.auth.user = null;
    addTearDown(backend.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredAssetsProvider.overrideWith(
            (ref) async => FakeRequiredAssets(),
          ),
          syncBackendProvider.overrideWithValue(backend),
          syncConfigurationProvider.overrideWith(
            (ref) async => SyncEngineConfig(
              backend: backend,
              deviceId: 'device',
              deviceName: 'Phone',
              network: TestNetwork(),
              collections: [],
              storage: SyncStateStore(
                storage: MemorySyncKeyValueStore(),
                deviceId: 'device',
              ),
            ),
          ),
          syncEngineProvider.overrideWith(() => FixedEngine(state)),
          onboardingControllerProvider.overrideWith(NamedOnboarding.new),
          accountResetStorageProvider.overrideWithValue(MemoryResetStorage()),
        ],
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? RedkeepTheme.dark
              : RedkeepTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: RenderingPolicyHost(
              preferences: const AppearancePreferences(reduceMotion: true),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: SafeArea(
              child: Builder(
                builder: (context) {
                  if (screen == 'more') return const MorePage();
                  if (screen == 'nested') {
                    return Navigator(
                      key: const ValueKey('nested-navigator'),
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (context) => Material(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              height: SyncAccountCard.expandedHeight(
                                context,
                                isSignedIn: true,
                              ),
                              child: SyncAccountCard(
                                collapseProgress: 0,
                                onExpand: () {},
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  if (screen == 'sheet') return const SyncAccountSheet();
                  if (screen == 'reset') {
                    return const ResetAccountPage(
                      account: SyncAccount(
                        id: 'owner',
                        email: 'owner@example.test',
                      ),
                    );
                  }
                  final collapsed = screen == 'collapsed';
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: SizedBox(
                        height: collapsed
                            ? SyncAccountCard.compactHeight(context)
                            : SyncAccountCard.expandedHeight(
                                context,
                                isSignedIn: connected,
                              ),
                        child: SyncAccountCard(
                          collapseProgress: collapsed ? 1 : 0,
                          onExpand: () {},
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  // Unmount inside the test so Drift's stream-close timers can run.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'scrolling collapses the sync card; tapping expands it ${brightness.name}',
      (tester) async {
        await pump(tester, brightness: brightness, screen: 'more');
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('Grand Maestar'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey('sync-avatar'))).width,
          84,
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const ValueKey('sync-avatar'))).width,
          32,
        );
        await tester.tap(find.byKey(const ValueKey('sync-avatar')));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const ValueKey('sync-avatar'))).width,
          84,
        );
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
    );
    testWidgets(
      'account sheet opens above nested navigators ${brightness.name}',
      (tester) async {
        await pump(tester, brightness: brightness, screen: 'nested');
        await tester.tap(find.byKey(const ValueKey('sync-card-status')));
        await tester.pumpAndSettle();
        expect(find.byType(SyncAccountSheet), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byType(SyncAccountSheet),
            matching: find.byKey(const ValueKey('nested-navigator')),
          ),
          findsNothing,
        );
        expect(find.text('Other phone'), findsOneWidget);
        expect(find.text('Add-only'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('reclaim-primary-role')),
          findsOneWidget,
        );

        // Scrolling the content keeps the sheet open…
        final sheet = find.byType(SyncAccountSheet);
        await tester.drag(sheet, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(sheet, findsOneWidget);
        // …and pulling down past the top carries the sheet down and closes it.
        await tester.fling(sheet, const Offset(0, 800), 2000);
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
    );
    testWidgets('syncing shows one progress animation ${brightness.name}', (
      tester,
    ) async {
      await pump(
        tester,
        brightness: brightness,
        screen: 'sheet',
        state: const SyncEngineState(
          status: EngineSyncState.syncing,
          activity: 'Uploading entries…',
          role: SyncDeviceRole.primary,
        ),
      );
      Finder inSheet(Finder finder) =>
          find.descendant(of: find.byType(SyncAccountSheet), matching: finder);
      expect(find.text('Uploading entries…'), findsOneWidget);
      expect(inSheet(find.byType(LinearProgressIndicator)), findsNothing);
      expect(inSheet(find.byType(CircularProgressIndicator)), findsNothing);
      expect(inSheet(find.byType(RotationTransition)), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('account-sync-now')),
            )
            .onPressed,
        isNull,
      );
      await unmount(tester);
    });
    for (final screen in ['more', 'expanded', 'collapsed', 'sheet', 'reset']) {
      testWidgets('sync UI 320px 3x ${brightness.name} $screen', (
        tester,
      ) async {
        await pump(
          tester,
          brightness: brightness,
          screen: screen,
          width: 320,
          scale: 3,
          connected: screen != 'expanded',
        );
        if (screen == 'reset') {
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('confirm-reset-account')),
                )
                .onPressed,
            isNull,
          );
          await tester.enterText(
            find.byKey(const ValueKey('reset-confirmation-input')),
            'DELX',
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('confirm-reset-account')),
                )
                .onPressed,
            isNull,
          );
          expect(find.text('ERASED'), findsNothing);
          expect(find.textContaining('doesn’t match'), findsOneWidget);
          await tester.enterText(
            find.byKey(const ValueKey('reset-confirmation-input')),
            'delete',
          );
          await tester.pumpAndSettle();
          expect(find.text('DELETE'), findsOneWidget);
          expect(find.text('ERASED'), findsOneWidget);
          expect(find.text('Ready. This cannot be undone.'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('confirm-reset-account')),
                )
                .onPressed,
            isNotNull,
          );
        }
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  }
}
