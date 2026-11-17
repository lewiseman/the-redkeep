import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/app/more_page.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/onboarding/application/onboarding_controller.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/sync/presentation/backup_sheet.dart';
import 'package:redkeep/features/sync/presentation/backup_status.dart';
import 'package:redkeep/features/sync/presentation/reset_account_page.dart';
import 'package:redkeep/features/sync/presentation/sync_card.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../support/fake_backup.dart';
import '../../support/fake_required_assets.dart';

class NamedOnboarding extends OnboardingController {
  @override
  OnboardingState build() =>
      const OnboardingState(name: 'Lewis', complete: true);
}

class MemoryResetStorage extends AccountResetStorage {
  @override
  Future<bool> canSync() async => true;
}

class FixedOffer extends RestoreOfferController {
  FixedOffer(this.offer);
  final RestoreOffer? offer;
  @override
  RestoreOffer? build() => offer;
}

final _backup = RemoteBackup(
  id: 'b1',
  createdAt: DateTime(2026, 11, 16, 2, 4),
  size: 3 * 1024 * 1024,
  sha256: 'a' * 64,
  md5: 'b' * 32,
  schemaVersion: 13,
  deviceName: 'Android device',
);

void main() {
  late Directory state;
  setUp(() async {
    state = await Directory.systemTemp.createTemp('redkeep-backup-ui-');
  });
  tearDown(() => state.delete(recursive: true));

  Future<FixedBackupSettings> pump(
    WidgetTester tester, {
    required Brightness brightness,
    required String screen,
    double width = 390,
    double scale = 1,
    bool connected = true,
    RestoreOffer? offer,
    BackupState backup = const BackupState(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = FakeBackupBackend(signedIn: connected);
    final engine = testBackupEngine(state, backend);
    final settings = FixedBackupSettings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredAssetsProvider.overrideWith(
            (ref) async => FakeRequiredAssets(),
          ),
          syncBackendProvider.overrideWithValue(backend),
          backupEngineProvider.overrideWithValue(AsyncData(engine)),
          backupStateProvider.overrideWith(() => FixedBackupState(backup)),
          backupSettingsProvider.overrideWith(() => settings),
          restoreOfferProvider.overrideWith(() => FixedOffer(offer)),
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
                  if (screen == 'sheet') return const BackupSheet();
                  if (screen == 'reset') {
                    return const ResetAccountPage(
                      account: FakeBackupAuth.owner,
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
    return settings;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  test('status describes each backup state', () {
    final now = DateTime(2026, 11, 17, 9);
    expect(
      describeBackup(const BackupState(), signedIn: false).label,
      'On this device',
    );
    expect(
      describeBackup(const BackupState(), signedIn: true).label,
      'Not backed up yet',
    );
    expect(
      describeBackup(
        BackupState(lastSuccess: DateTime(2026, 11, 17, 2, 4), lastSize: 2048),
        signedIn: true,
        now: now,
      ).label,
      startsWith('Backed up today, 2:04'),
    );
    expect(
      describeBackup(
        const BackupState(
          activity: BackupActivity.uploading,
          bytesDone: 45,
          bytesTotal: 100,
        ),
        signedIn: true,
      ).label,
      'Backing up · 45%',
    );
    expect(
      describeBackup(
        const BackupState(
          error: BackupException(BackupErrorKind.offline, 'Waiting for Wi-Fi.'),
        ),
        signedIn: true,
      ).label,
      'Waiting for Wi-Fi',
    );
    // A skipped empty backup is not a failure.
    expect(
      describeBackup(
        const BackupState(
          error: BackupException(BackupErrorKind.empty, 'Nothing'),
        ),
        signedIn: true,
      ).error,
      isFalse,
    );
    expect(backupSize(3 * 1024 * 1024), '3.0 MB');
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'scrolling collapses the backup card; tapping expands it ${brightness.name}',
      (tester) async {
        await pump(tester, brightness: brightness, screen: 'more');
        expect(find.text('Appearance'), findsOneWidget);
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
        await unmount(tester);
      },
    );

    testWidgets('backup sheet opens above nested navigators ${brightness.name}', (
      tester,
    ) async {
      await pump(tester, brightness: brightness, screen: 'nested');
      await tester.tap(find.byKey(const ValueKey('sync-card-status')));
      await tester.pumpAndSettle();
      final sheet = find.byType(BackupSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.ancestor(
          of: sheet,
          matching: find.byKey(const ValueKey('nested-navigator')),
        ),
        findsNothing,
      );
      expect(find.text('Back up to Google Drive'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Add-only'), findsNothing);
      await tester.drag(sheet, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      await tester.fling(sheet, const Offset(0, 800), 2000);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      await unmount(tester);
    });

    testWidgets('backing up shows one progress bar and Pause ${brightness.name}', (
      tester,
    ) async {
      await pump(
        tester,
        brightness: brightness,
        screen: 'sheet',
        backup: const BackupState(
          activity: BackupActivity.uploading,
          bytesDone: 50,
          bytesTotal: 100,
        ),
      );
      Finder inSheet(Finder finder) =>
          find.descendant(of: find.byType(BackupSheet), matching: finder);
      expect(find.text('Backing up · 50%'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('backup-progress')),
      );
      expect(bar.value, .5);
      expect(inSheet(find.byType(LinearProgressIndicator)), findsOneWidget);
      expect(inSheet(find.byType(CircularProgressIndicator)), findsNothing);
      expect(find.byKey(const ValueKey('backup-pause')), findsOneWidget);
      expect(find.byKey(const ValueKey('backup-now')), findsNothing);
      await unmount(tester);
    });

    testWidgets('choosing a schedule saves it ${brightness.name}', (
      tester,
    ) async {
      final settings = await pump(
        tester,
        brightness: brightness,
        screen: 'sheet',
      );
      await tester.tap(find.byKey(const ValueKey('backup-interval')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('backup-interval-weekly')));
      await tester.pumpAndSettle();
      expect(settings.saved.single.interval, BackupInterval.weekly);
      expect(find.text('Weekly'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('backup-cellular')));
      await tester.pumpAndSettle();
      expect(settings.saved.last.allowCellular, isTrue);
      await unmount(tester);
    });

    testWidgets('an empty phone is offered its backup ${brightness.name}', (
      tester,
    ) async {
      await pump(
        tester,
        brightness: brightness,
        screen: 'sheet',
        offer: RestoreOffer.backup(_backup),
      );
      expect(find.byKey(const ValueKey('restore-offer')), findsOneWidget);
      expect(find.textContaining('3.0 MB'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('skip-restore')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('restore-offer')), findsNothing);
      await unmount(tester);
    });

    for (final screen in ['more', 'expanded', 'collapsed', 'sheet', 'reset']) {
      testWidgets('backup UI 320px 3x ${brightness.name} $screen', (
        tester,
      ) async {
        await pump(
          tester,
          brightness: brightness,
          screen: screen,
          width: 320,
          scale: 3,
          connected: screen != 'expanded',
          offer: screen == 'sheet' ? RestoreOffer.backup(_backup) : null,
          backup: BackupState(
            lastSuccess: DateTime(2026, 11, 16, 2, 4),
            lastSize: 3 * 1024 * 1024,
          ),
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
            'delete',
          );
          await tester.pumpAndSettle();
          expect(find.text('ERASED'), findsOneWidget);
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
