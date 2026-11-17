import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/app/bootstrap/startup_artwork.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/app/redkeep_app.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/application/appearance_typography.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';

import '../../support/fake_appearance_fonts.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/fake_backup.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/fake_required_assets.dart';
import 'sync_ui_test.dart' show MemoryResetStorage;

void main() {
  testWidgets(
    'production root coordination opens More offline without native accounts or provider errors',
    (tester) async {
      final state = Directory.systemTemp.createTempSync('redkeep-host-');
      addTearDown(() => state.deleteSync(recursive: true));
      final db = AppDatabase(NativeDatabase.memory());
      final backend = FakeBackupBackend(signedIn: false);
      final schedule = RecordingSchedule();
      final appearance = FakeAppearanceRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appearanceFontLoaderProvider.overrideWithValue(
              fakeAppearanceFontLoader,
            ),
            appDatabaseProvider.overrideWithValue(db),
            appearanceRepositoryProvider.overrideWithValue(appearance),
            onboardingRepositoryProvider.overrideWithValue(
              FakeOnboardingRepository(),
            ),
            requiredAssetsProvider.overrideWith(
              (ref) async => FakeRequiredAssets(),
            ),
            releaseSplashProvider.overrideWithValue(() {}),
            startupArtworkProvider.overrideWith((_) async {}),
            syncBackendProvider.overrideWithValue(backend),
            networkServiceProvider.overrideWithValue(QuietNetwork()),
            accountResetStorageProvider.overrideWithValue(MemoryResetStorage()),
            backupEngineProvider.overrideWithValue(
              AsyncData(testBackupEngine(state, backend)),
            ),
            backupScheduleProvider.overrideWithValue(schedule),
            initialNavigationLocationProvider.overrideWithValue('/more'),
          ],
          child: const RedkeepApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connect Account'), findsOneWidget);
      expect(find.text('On this device'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final container = tester.container();
      expect(container.read(accountResetProvider).blocksDataAccess, false);
      expect(container.read(appDatabaseProvider).writingBlocked, false);
      expect(container.read(restoringProvider), false);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
      await appearance.close();
    },
  );
}
