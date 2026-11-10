import 'package:redkeep/features/appearance/application/appearance_typography.dart';

import '../../support/fake_appearance_fonts.dart';

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
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/sync/data/drift_sync_collection.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/fake_required_assets.dart';
import 'drift_sync_test.dart' show Harness;
import 'sync_coordinator_test.dart' show QuietNetwork;
import 'sync_ui_test.dart' show MemoryResetStorage;
import '../../../packages/sync_wise/test/support/memory_backend.dart'
    show MemoryDrive;

void main() {
  testWidgets(
    'production root coordination opens More offline without native accounts or provider errors',
    (tester) async {
      final h = Harness(AppDatabase(NativeDatabase.memory()), MemoryDrive());
      h.backend.auth.user = null;
      final appearance = FakeAppearanceRepository();
      await h.storage.initialize();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appearanceFontLoaderProvider.overrideWithValue(
              fakeAppearanceFontLoader,
            ),
            appDatabaseProvider.overrideWithValue(h.db),
            appearanceRepositoryProvider.overrideWithValue(appearance),
            onboardingRepositoryProvider.overrideWithValue(
              FakeOnboardingRepository(),
            ),
            requiredAssetsProvider.overrideWith(
              (ref) async => FakeRequiredAssets(),
            ),
            releaseSplashProvider.overrideWithValue(() {}),
            startupArtworkProvider.overrideWith((_) async {}),
            syncBackendProvider.overrideWithValue(h.backend),
            networkServiceProvider.overrideWithValue(QuietNetwork()),
            accountResetStorageProvider.overrideWithValue(MemoryResetStorage()),
            syncConfigurationProvider.overrideWith(
              (ref) async => SyncEngineConfig(
                backend: h.backend,
                deviceId: h.device,
                deviceName: h.device,
                network: h.network,
                storage: h.storage,
                collections: [
                  for (final type in ['note', 'diary', 'thought'])
                    DriftSyncCollection(h.db, type),
                ],
                canSync: () async => true,
              ),
            ),
            initialNavigationLocationProvider.overrideWithValue('/more'),
          ],
          child: const RedkeepApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connect Account'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final container = tester.container();
      expect(container.read(accountResetProvider).blocksDataAccess, false);
      expect(container.read(appDatabaseProvider).writingBlocked, false);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await h.close();
      await appearance.close();
    },
  );
}
