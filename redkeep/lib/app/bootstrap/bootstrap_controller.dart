import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assets/domain/asset_catalog.dart';
import '../../features/assets/presentation/local_artwork.dart';
import '../../features/appearance/application/appearance_controller.dart';
import '../../features/diary/presentation/diary_artwork.dart';
import 'bootstrap_providers.dart';
import 'startup_artwork.dart';

enum BootstrapStage {
  checking,
  localError,
  download,
  downloading,
  preparing,
  ready,
}

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
        if (missing.isEmpty) {
          await _open(refreshArtwork: verifyAll);
        } else {
          state = const BootstrapState(BootstrapStage.download);
        }
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
    // The artwork is required and small, so there is nothing to ask first.
    if (ref.mounted && state.stage == BootstrapStage.download) {
      await download();
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
      if (ref.mounted) {
        final total = state.progress?.totalBytes;
        state = BootstrapState(
          BootstrapStage.preparing,
          progress: total == null ? null : AssetProgress(total, total),
        );
        await _open(refreshArtwork: true);
      }
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

  Future<void> _open({required bool refreshArtwork}) async {
    if (refreshArtwork) {
      // Repair or download may have replaced an image at the same path.
      ref.invalidate(startupArtworkProvider);
      ref.invalidate(localArtworkFileProvider);
      ref.invalidate(diaryImageProvider);
    }
    try {
      await ref
          .read(startupArtworkProvider.future)
          .timeout(ref.read(startupArtworkLimitProvider), onTimeout: () {});
      if (ref.mounted) {
        state = BootstrapState(BootstrapStage.ready, progress: state.progress);
      }
    } catch (_) {
      if (ref.mounted) _showArtworkError();
    }
  }

  /// Recheck suspicious files (including image decoder failures) before entry.
  Future<void> repair() => check(verifyAll: true);

  void artworkFailed() {
    if (!ref.mounted || state.stage != BootstrapStage.ready) return;
    _showArtworkError();
  }

  void _showArtworkError() {
    state = const BootstrapState(
      BootstrapStage.localError,
      failure: AssetFailure.integrity,
    );
  }
}
