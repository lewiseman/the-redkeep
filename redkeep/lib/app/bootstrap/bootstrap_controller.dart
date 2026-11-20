import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/appearance/application/appearance_controller.dart';
import 'bootstrap_providers.dart';
import 'startup_artwork.dart';

enum BootstrapStage { checking, localError, ready }

class BootstrapState {
  const BootstrapState(this.stage);
  final BootstrapStage stage;
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

  Future<void> check() async {
    if (_working || !ref.mounted) return;
    _working = true;
    state = const BootstrapState(BootstrapStage.checking);
    try {
      await ref
          .read(bootstrapCoordinatorProvider)
          .check()
          .timeout(ref.read(localCheckLimitProvider));
      if (ref.mounted) {
        if (ref.read(appearanceControllerProvider).loadError) {
          ref.read(appearanceControllerProvider.notifier).retryLoading();
        }
        await _open();
      }
    } catch (_) {
      if (ref.mounted) {
        state = const BootstrapState(BootstrapStage.localError);
      }
    } finally {
      _working = false;
      // Never wait for a first frame: preserve() deferred that frame.
      if (ref.mounted) _release();
    }
  }

  Future<void> _open() async {
    // Decoding the first screen's artwork is best effort; it is bundled.
    await ref
        .read(startupArtworkProvider.future)
        .timeout(ref.read(startupArtworkLimitProvider), onTimeout: () {})
        .catchError((_) {});
    if (ref.mounted) state = const BootstrapState(BootstrapStage.ready);
  }
}
