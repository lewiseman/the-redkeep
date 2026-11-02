import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assets/domain/asset_catalog.dart';
import '../../features/appearance/application/appearance_controller.dart';
import 'bootstrap_providers.dart';

enum BootstrapStage { checking, localError, download, downloading, ready }

class BootstrapState {
  const BootstrapState(this.stage, {this.failure, this.progress});
  final BootstrapStage stage;
  final AssetFailure? failure;
  final AssetProgress? progress;
}

final bootstrapControllerProvider =
    NotifierProvider<BootstrapController, BootstrapState>(
      BootstrapController.new,
    );

class BootstrapController extends Notifier<BootstrapState> {
  bool _working = false;
  bool _released = false;
  late void Function() _releaseSplash;

  @override
  BootstrapState build() {
    // Read dependencies before scheduling async work; no network is started here.
    ref.watch(bootstrapCoordinatorProvider);
    _releaseSplash = ref.read(releaseSplashProvider);
    ref.onDispose(_release);
    Future.microtask(check);
    return const BootstrapState(BootstrapStage.checking);
  }

  void _release() {
    if (_released) return;
    _released = true;
    _releaseSplash();
  }

  Future<void> check({bool verifyAll = false}) async {
    if (_working || !ref.mounted) return;
    _working = true;
    state = const BootstrapState(BootstrapStage.checking);
    try {
      final missing = await ref
          .read(bootstrapCoordinatorProvider)
          .check(verifyAll: verifyAll)
          .timeout(ref.read(localCheckLimitProvider));
      if (ref.mounted) {
        if (ref.read(appearanceControllerProvider).loadError) {
          ref.read(appearanceControllerProvider.notifier).retryLoading();
        }
        state = BootstrapState(
          missing.isEmpty ? BootstrapStage.ready : BootstrapStage.download,
        );
      }
    } catch (error) {
      if (ref.mounted) {
        state = BootstrapState(
          BootstrapStage.localError,
          failure: error is AssetException ? error.failure : null,
        );
      }
    } finally {
      _working = false;
      // Never wait for a first frame: preserve() deferred that frame.
      if (ref.mounted) _release();
    }
  }

  Future<void> download() async {
    if (_working || !_released || state.stage != BootstrapStage.download) {
      return;
    }
    _working = true;
    state = const BootstrapState(BootstrapStage.downloading);
    try {
      await ref.read(bootstrapCoordinatorProvider).download((progress) {
        if (ref.mounted) {
          state = BootstrapState(
            BootstrapStage.downloading,
            progress: progress,
          );
        }
      });
      if (ref.mounted) state = const BootstrapState(BootstrapStage.ready);
    } catch (error) {
      if (ref.mounted) {
        state = BootstrapState(
          BootstrapStage.download,
          failure: error is AssetException
              ? error.failure
              : AssetFailure.network,
        );
      }
    } finally {
      _working = false;
    }
  }

  /// Recheck suspicious files (including image decoder failures) before entry.
  Future<void> repair() => check(verifyAll: true);

  void artworkFailed() {
    if (!ref.mounted || state.stage != BootstrapStage.ready) return;
    state = const BootstrapState(
      BootstrapStage.localError,
      failure: AssetFailure.integrity,
    );
  }
}
