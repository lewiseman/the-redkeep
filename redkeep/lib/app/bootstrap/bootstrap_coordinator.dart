import 'dart:async';

import '../../features/assets/domain/asset_catalog.dart';

/// Coalesces slow local checks so timeout/retry cannot start overlapping work.
/// Settings/database and onboarding checks share this same aggregate deadline.
class BootstrapCoordinator {
  BootstrapCoordinator({required this.localChecks, required this.loadAssets});
  final Future<void> Function() localChecks;
  final Future<RequiredAssets> Function() loadAssets;
  Future<List<String>>? _pending;

  Future<List<String>> check({bool verifyAll = false}) =>
      _pending ??= _check(verifyAll).whenComplete(() => _pending = null);

  Future<List<String>> _check(bool verifyAll) async {
    await localChecks();
    return (await loadAssets()).inspect(verifyAll: verifyAll);
  }

  Future<void> download(void Function(AssetProgress) onProgress) async =>
      (await loadAssets()).download(onProgress);
}
