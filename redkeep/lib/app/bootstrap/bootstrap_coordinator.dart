import 'dart:async';

/// Coalesces slow local checks so timeout/retry cannot start overlapping work.
/// Settings/database and onboarding checks share this same aggregate deadline.
class BootstrapCoordinator {
  BootstrapCoordinator({required this.localChecks});
  final Future<void> Function() localChecks;
  Future<void>? _pending;

  Future<void> check() =>
      _pending ??= localChecks().whenComplete(() => _pending = null);
}
