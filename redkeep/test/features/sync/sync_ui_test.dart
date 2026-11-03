import 'package:redkeep/app/more_page.dart';
import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/onboarding/application/onboarding_controller.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/sync/presentation/sync_card.dart';
import 'package:redkeep/features/sync/presentation/sync_account_sheet.dart';
import 'package:redkeep/features/sync/presentation/reset_account_page.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../packages/sync_wise/test/support/memory_backend.dart';

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
  setUpAll(() async {
    // Flutter's own pinned offline fonts make these actual visual comparisons,
    // rather than the unreadable Ahem font used by default in widget tests.
    final root =
        Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable)
            .parent
            .parent
            .parent
            .parent
            .parent
            .parent
            .path;
    final directory = '$root/bin/cache/artifacts/material_fonts';
    for (final family in ['Roboto', 'MaterialIcons']) {
      final loader = FontLoader(family);
      for (final file
          in family == 'Roboto'
              ? ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']
              : ['MaterialIcons-Regular.otf']) {
        loader.addFont(
          Future.value(
            ByteData.sublistView(File('$directory/$file').readAsBytesSync()),
          ),
        );
      }
      await loader.load();
    }
  });
  Future<void> pump(
    WidgetTester tester, {
    required Brightness brightness,
    required String screen,
    double width = 390,
    double scale = 1,
    bool connected = true,
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
          syncEngineProvider.overrideWith(
            () => FixedEngine(
              const SyncEngineState(
                role: SyncDeviceRole.secondary,
                primary: PrimaryDevice(
                  deviceId: 'other',
                  deviceName: 'Other phone',
                  fileId: 'registry',
                ),
              ),
            ),
          ),
          onboardingControllerProvider.overrideWith(NamedOnboarding.new),
          accountResetStorageProvider.overrideWithValue(MemoryResetStorage()),
        ],
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? RedkeepTheme.dark.copyWith(
                  textTheme: RedkeepTheme.dark.textTheme.apply(
                    fontFamily: 'Roboto',
                  ),
                )
              : RedkeepTheme.light.copyWith(
                  textTheme: RedkeepTheme.light.textTheme.apply(
                    fontFamily: 'Roboto',
                  ),
                ),
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
              child: RepaintBoundary(
                key: const ValueKey('capture'),
                child: Builder(
                  builder: (context) {
                    if (screen == 'more') return const MorePage();
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
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'More pins the original card and compact tap expands ${brightness.name}',
      (tester) async {
        await pump(tester, brightness: brightness, screen: 'more');
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('Brain'), findsOneWidget);
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
      },
    );
    for (final screen in ['expanded', 'collapsed', 'sheet']) {
      testWidgets('original sync UI parity ${brightness.name} $screen', (
        tester,
      ) async {
        await pump(tester, brightness: brightness, screen: screen);
        await expectLater(
          find.byKey(const ValueKey('capture')),
          matchesGoldenFile('goldens/${brightness.name}-$screen.png'),
        );
        if (const bool.fromEnvironment('RECORD_SYNC_SCREENSHOTS')) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('capture')),
            );
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('../docs/evidence/gs01/${brightness.name}-$screen.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
    for (final screen in ['expanded', 'collapsed', 'sheet', 'reset']) {
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
            'DELETE',
          );
          await tester.pumpAndSettle();
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
      });
    }
  }
}
