import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/more_page.dart';
import 'package:redkeep/app/writing_shell.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/onboarding/application/onboarding_controller.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/sync/presentation/backup_panel.dart';
import 'package:redkeep/features/sync/presentation/backup_status.dart';
import 'package:redkeep/features/sync/presentation/reset_account_page.dart';
import 'package:redkeep/features/sync/presentation/sync_card.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../support/fake_backup.dart';

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
  late Directory state;
  late List<bool> navbar;
  setUp(() async {
    navbar = [];
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
          syncBackendProvider.overrideWithValue(backend),
          backupEngineProvider.overrideWithValue(AsyncData(engine)),
          backupStateProvider.overrideWith(() => FixedBackupState(backup)),
          backupSettingsProvider.overrideWith(() => settings),
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
                  if (screen == 'more') {
                    return NotificationListener<
                      BottomNavbarVisibilityNotification
                    >(
                      onNotification: (notification) {
                        navbar.add(notification.hidden);
                        return true;
                      },
                      child: const MorePage(),
                    );
                  }
                  if (screen == 'nested') {
                    return Navigator(
                      key: const ValueKey('nested-navigator'),
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (context) => Material(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: const SyncAccountCard(),
                          ),
                        ),
                      ),
                    );
                  }
                  if (screen == 'sheet') return BackupPanel(onClose: () {});
                  if (screen == 'reset') {
                    return const ResetAccountPage(
                      account: FakeBackupAuth.owner,
                    );
                  }
                  return const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: SyncAccountCard(),
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
    final media = describeBackup(
      const BackupState(
        activity: BackupActivity.restoringFiles,
        bytesDone: 40 * 1024 * 1024,
        bytesTotal: 100 * 1024 * 1024,
      ),
      signedIn: true,
    );
    expect(media.label, 'Restoring media · 40%');
    expect(media.detail, '40.0 MB of 100.0 MB');
    expect(media.inbound, isTrue);
    expect(
      describeBackup(
        const BackupState(
          filesPending: true,
          error: BackupException(BackupErrorKind.offline, 'Waiting for Wi-Fi.'),
        ),
        signedIn: true,
      ).label,
      'Media waiting for Wi-Fi',
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
      'More holds still: the book stays open above the shelf ${brightness.name}',
      (tester) async {
        await pump(tester, brightness: brightness, screen: 'more');
        final avatar = find.byKey(const ValueKey('sync-avatar'));
        final plate = find.byKey(const ValueKey('sync-card-status'));
        expect(tester.getSize(avatar).width, SyncAccountCard.medallionSize);
        // The backup bookplate sits inside the book, below the name.
        final card = tester.getRect(
          find.byKey(const ValueKey('sync-account-card')),
        );
        expect(card.contains(tester.getCenter(plate)), isTrue);
        expect(
          tester.getTopLeft(plate).dy,
          greaterThan(tester.getBottomLeft(avatar).dy),
        );
        expect(
          tester.getTopLeft(find.text('Appearance')).dy,
          greaterThan(card.bottom),
        );
        final before = tester.getTopLeft(avatar);
        await tester.drag(find.text('Appearance'), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(avatar), before);
        expect(tester.getSize(avatar).width, SyncAccountCard.medallionSize);
        await unmount(tester);
      },
    );

    testWidgets(
      'the backup line opens the book over the page; back closes it ${brightness.name}',
      (tester) async {
        await pump(tester, brightness: brightness, screen: 'more');
        final panel = find.byType(BackupPanel);
        expect(panel, findsNothing);
        await tester.tap(find.byKey(const ValueKey('sync-card-status')));
        await tester.pumpAndSettle();
        expect(panel, findsOneWidget);
        expect(navbar, [true]);
        // The open book fills the page; the card's page beneath it is inert.
        expect(
          tester.getSize(panel).width,
          greaterThan(tester.getSize(find.byType(MorePage)).width - 40),
        );
        expect(
          find.byKey(const ValueKey('sync-card-status')).hitTestable(),
          findsNothing,
        );
        expect(find.text('Daily'), findsOneWidget);
        expect(find.text('Weekly'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        expect(navbar, [true, false]);
        await tester.tap(find.byKey(const ValueKey('sync-card-status')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('backup-close')));
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        expect(navbar, [true, false, true, false]);
        expect(
          find.byKey(const ValueKey('sync-card-status')).hitTestable(),
          findsOneWidget,
        );
        await unmount(tester);
      },
    );

    testWidgets(
      'backing up shows one progress bar and Pause ${brightness.name}',
      (tester) async {
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
            find.descendant(of: find.byType(BackupPanel), matching: finder);
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
      },
    );

    testWidgets('choosing a schedule saves it ${brightness.name}', (
      tester,
    ) async {
      final settings = await pump(
        tester,
        brightness: brightness,
        screen: 'sheet',
      );
      await tester.tap(find.byKey(const ValueKey('backup-interval-weekly')));
      await tester.pumpAndSettle();
      expect(settings.saved.single.interval, BackupInterval.weekly);
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('backup-interval-weekly')),
        ),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(
        find.text('Backs up to Google Drive once a week, overnight.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('backup-cellular')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('backup-cellular')));
      await tester.pumpAndSettle();
      expect(settings.saved.last.allowCellular, isTrue);
      await unmount(tester);
    });

    for (final screen in ['more', 'open', 'expanded', 'sheet', 'reset']) {
      testWidgets('backup UI 320px 3x ${brightness.name} $screen', (
        tester,
      ) async {
        await pump(
          tester,
          brightness: brightness,
          screen: screen == 'open' ? 'more' : screen,
          width: 320,
          scale: 3,
          connected: screen != 'expanded',
          backup: BackupState(
            lastSuccess: DateTime(2026, 11, 16, 2, 4),
            lastSize: 3 * 1024 * 1024,
          ),
        );
        if (screen == 'open') {
          await tester.tap(find.byKey(const ValueKey('sync-card-status')));
          await tester.pumpAndSettle();
          final reset = find.byKey(const ValueKey('reset-account-data'));
          await tester.scrollUntilVisible(
            reset,
            200,
            scrollable: find.descendant(
              of: find.byType(BackupPanel),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(reset.hitTestable(), findsOneWidget);
        }
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
