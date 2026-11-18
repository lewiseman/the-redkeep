import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../app/storage_providers.dart';
import '../../sync/application/sync_providers.dart';

enum OnboardingRestorePhase {
  /// Touring, or the backup step was skipped.
  idle,
  signingIn,
  checking,

  /// A backup exists: restore it or skip.
  found,

  /// Signed in, but there is no backup yet.
  none,
  restoring,

  /// The journal was restored; onboarding finishes with the restored name.
  restored,
  failed,
}

class OnboardingRestoreState {
  const OnboardingRestoreState({
    this.phase = OnboardingRestorePhase.idle,
    this.backup,
    this.name,
    this.error,
  });
  final OnboardingRestorePhase phase;
  final RemoteBackup? backup;

  /// The name inside the restored journal.
  final String? name;
  final String? error;

  bool get busy => switch (phase) {
    OnboardingRestorePhase.signingIn ||
    OnboardingRestorePhase.checking ||
    OnboardingRestorePhase.restoring => true,
    _ => false,
  };

  /// While a restore runs or has finished, onboarding stays on screen even
  /// though the database underneath it is replaced and checked again.
  bool get holdsOnboarding =>
      phase == OnboardingRestorePhase.restoring ||
      phase == OnboardingRestorePhase.restored;
}

/// The WhatsApp-style first-run step: sign in, find the newest backup, and
/// restore it before any local name or writing exists. It deliberately does
/// not depend on the database, so swapping the database does not reset it.
final onboardingRestoreProvider =
    NotifierProvider<OnboardingRestore, OnboardingRestoreState>(
      OnboardingRestore.new,
    );

class OnboardingRestore extends Notifier<OnboardingRestoreState> {
  @override
  OnboardingRestoreState build() => const OnboardingRestoreState();

  void _set(OnboardingRestoreState next) {
    if (ref.mounted) state = next;
  }

  /// Signs in (if needed) and looks for a backup.
  Future<void> connect() async {
    if (state.busy) return;
    _set(const OnboardingRestoreState(phase: OnboardingRestorePhase.signingIn));
    try {
      final auth = ref.read(syncAuthProvider);
      final account = auth.currentUser ?? await auth.signIn();
      if (account == null) {
        // The sign-in was dismissed: back to the backup page.
        _set(const OnboardingRestoreState());
        return;
      }
      _set(
        const OnboardingRestoreState(phase: OnboardingRestorePhase.checking),
      );
      final engine = await ref.read(backupEngineProvider.future);
      final backup = await engine.latestBackup();
      _set(
        backup == null
            ? const OnboardingRestoreState(phase: OnboardingRestorePhase.none)
            : OnboardingRestoreState(
                phase: OnboardingRestorePhase.found,
                backup: backup,
              ),
      );
    } on Object catch (error) {
      _set(
        OnboardingRestoreState(
          phase: OnboardingRestorePhase.failed,
          error: _message(error),
        ),
      );
    }
  }

  /// Restores the backup that was found.
  Future<void> restore() async {
    final backup = state.backup;
    if (backup == null || state.busy) return;
    _set(
      OnboardingRestoreState(
        phase: OnboardingRestorePhase.restoring,
        backup: backup,
      ),
    );
    try {
      await ref.read(backupActionsProvider).restore(backup);
      final name = await ref.read(onboardingRepositoryProvider).readName();
      _set(
        OnboardingRestoreState(
          phase: OnboardingRestorePhase.restored,
          backup: backup,
          name: name,
        ),
      );
    } on Object catch (error) {
      _set(
        OnboardingRestoreState(
          phase: OnboardingRestorePhase.failed,
          backup: backup,
          error: _message(error),
        ),
      );
    }
  }

  /// Tries the step that failed again.
  Future<void> retry() => state.backup == null ? connect() : restore();

  /// Skip, continue without a backup, or finish: back to plain onboarding.
  void dismiss() => _set(const OnboardingRestoreState());

  static String _message(Object error) => error is BackupException
      ? error.message
      : 'Something went wrong. Check your connection and try again.';
}
