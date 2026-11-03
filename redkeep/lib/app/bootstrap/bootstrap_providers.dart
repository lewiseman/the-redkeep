import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/assets/data/asset_download_client.dart';
import '../../features/assets/data/file_required_assets.dart';
import '../../features/assets/domain/asset_catalog.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../storage_providers.dart';
import 'bootstrap_coordinator.dart';

final requiredAssetsProvider = FutureProvider<RequiredAssets>((ref) async {
  final catalog = AssetCatalog.parse(
    await rootBundle.loadString('assets/catalog/presentation-v1.json'),
  );
  final support = await getApplicationSupportDirectory();
  return FileRequiredAssets(
    catalog: catalog,
    root: Directory.fromUri(support.uri.resolve('required-artwork/')),
    location: AssetLocation(
      const String.fromEnvironment('ASSET_BASE_URL'),
      sourceUrlsJson: const String.fromEnvironment('ASSET_SOURCE_URLS_JSON'),
      catalog: catalog,
      allowLocalFixture:
          kDebugMode && const bool.fromEnvironment('ASSET_ALLOW_LOCAL_FIXTURE'),
    ),
    client: HttpAssetDownloadClient(),
  );
}, retry: (_, _) => null);

final assetResolverProvider = Provider<Future<AssetResolver>>(
  (ref) => ref.watch(requiredAssetsProvider.future),
);

final bootstrapCoordinatorProvider = Provider<BootstrapCoordinator>((ref) {
  final preferences = ref.watch(appearanceRepositoryProvider);
  return BootstrapCoordinator(
    // Opens/migrates the same background database and checks saved preferences.
    localChecks: () async {
      await preferences.watch().first;
      await ref.read(onboardingControllerProvider.notifier).load();
    },
    loadAssets: () {
      if (ref.read(requiredAssetsProvider).hasError) {
        ref.invalidate(requiredAssetsProvider);
      }
      return ref.read(requiredAssetsProvider.future);
    },
  );
});

final releaseSplashProvider = Provider<void Function()>(
  (ref) => FlutterNativeSplash.remove,
);

final localCheckLimitProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);
