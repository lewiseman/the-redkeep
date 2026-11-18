import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/onboarding/application/onboarding_restore.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_page.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../support/fake_backup.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/onboarding_navigation.dart';
import '../../support/pump_app.dart';

final _backup = RemoteBackup(
  id: 'b1',
  createdAt: DateTime(2026, 11, 16, 2, 4),
  size: 3 * 1024 * 1024,
  sha256: 'a' * 64,
  md5: 'b' * 32,
  schemaVersion: 13,
  deviceName: 'Android device',
);

/// Plays the backup step without Google or Drive.
class ScriptedRestore extends OnboardingRestore {
  ScriptedRestore({this.found = true, this.name = 'Lewis'});
  final bool found;
  final String? name;
  Completer<void>? restoring;

  @override
  Future<void> connect() async {
    state = found
        ? OnboardingRestoreState(
            phase: OnboardingRestorePhase.found,
            backup: _backup,
          )
        : const OnboardingRestoreState(phase: OnboardingRestorePhase.none);
  }

  @override
  Future<void> restore() async {
    state = OnboardingRestoreState(
      phase: OnboardingRestorePhase.restoring,
      backup: _backup,
    );
    await restoring?.future;
    state = OnboardingRestoreState(
      phase: OnboardingRestorePhase.restored,
      backup: _backup,
      name: name,
    );
  }
}

class _ResetStorage extends AccountResetStorage {
  @override
  Future<bool> canSync() async => true;
}

Future<FakeOnboardingRepository> _pump(
  WidgetTester tester,
  ScriptedRestore restore,
) async {
  final state = Directory.systemTemp.createTempSync('redkeep-onboarding-');
  addTearDown(() => state.deleteSync(recursive: true));
  final backend = FakeBackupBackend(signedIn: false);
  final repository = FakeOnboardingRepository(completed: false);
  await pumpApp(
    tester,
    onboarding: repository,
    backups: [
      syncBackendProvider.overrideWithValue(backend),
      backupEngineProvider.overrideWithValue(
        AsyncData(testBackupEngine(state, backend)),
      ),
      backupScheduleProvider.overrideWithValue(RecordingSchedule()),
      networkServiceProvider.overrideWithValue(QuietNetwork()),
      accountResetStorageProvider.overrideWithValue(_ResetStorage()),
      onboardingRestoreProvider.overrideWith(() => restore),
    ],
  );
  return repository;
}

Future<void> _toBackupPage(WidgetTester tester) async {
  await navigateChapter(tester, 1);
  await navigateChapter(tester, 1);
  expect(chapterPosition(3), findsOneWidget);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('earlier pages lead on to the backup page', (tester) async {
    await _pump(tester, ScriptedRestore());
    expect(find.text('Next'), findsOneWidget);
    await _tapKey(tester, 'onboarding-primary');
    expect(chapterPosition(2), findsOneWidget);
    await _tapKey(tester, 'onboarding-primary');
    expect(chapterPosition(3), findsOneWidget);
    expect(find.text('Continue with Google Drive'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-skip-backup')),
      findsOneWidget,
    );
  });

  testWidgets('restoring keeps the book, then closes it on the restored name', (
    tester,
  ) async {
    final restore = ScriptedRestore()..restoring = Completer<void>();
    final repository = await _pump(tester, restore);
    await _toBackupPage(tester);
    expect(find.byKey(const ValueKey('onboarding-mascot')), findsOneWidget);
    await _tapKey(tester, 'onboarding-primary');
    // The book and the Grand Maestar stay; the page hints give way.
    expect(find.byKey(const ValueKey('onboarding-mascot')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-page-hints')), findsNothing);
    expect(find.text('Backup found'), findsOneWidget);
    expect(find.textContaining('3.0 MB'), findsOneWidget);

    // The progress bar keeps moving while restoring, so pump, not settle.
    await tester.ensureVisible(
      find.byKey(const ValueKey('onboarding-restore')),
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-restore')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Restoring your journal'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-backup-progress')),
      findsOneWidget,
    );
    // No going anywhere until it finishes.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Restoring your journal'), findsOneWidget);

    restore.restoring!.complete();
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Lewis');
    expect(field.enabled, isFalse);
    expect(find.text('Welcome back.'), findsOneWidget);
    await _tapKey(tester, 'onboarding-primary');
    expect(find.byType(OnboardingPage), findsNothing);
    // The name came from the backup; nothing local was written first.
    expect(repository.saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip on the backup page goes to the name', (tester) async {
    await _pump(tester, ScriptedRestore());
    await _toBackupPage(tester);
    await _tapKey(tester, 'onboarding-skip-backup');
    expect(find.text('Save'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('skipping a found backup goes to the name', (tester) async {
    await _pump(tester, ScriptedRestore());
    await _toBackupPage(tester);
    await _tapKey(tester, 'onboarding-primary');
    await _tapKey(tester, 'onboarding-skip-restore');
    expect(find.text('Save'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-backup-panel')), findsNothing);
  });

  testWidgets('no backup continues to the name', (tester) async {
    await _pump(tester, ScriptedRestore(found: false));
    await _toBackupPage(tester);
    await _tapKey(tester, 'onboarding-primary');
    expect(find.text('No backup yet'), findsOneWidget);
    await _tapKey(tester, 'onboarding-no-backup-continue');
    expect(find.text('Save'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('backup step fits 320px with 3x text (dark: $dark)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _pump(tester, ScriptedRestore());
      await _toBackupPage(tester);
      await _tapKey(tester, 'onboarding-primary');
      expect(find.text('Backup found'), findsOneWidget);
      await _tapKey(tester, 'onboarding-restore');
      expect(find.text('Welcome back.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
