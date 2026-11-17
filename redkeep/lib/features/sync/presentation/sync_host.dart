import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/sync_providers.dart';
import 'backup_status.dart';
import 'reset_account_progress.dart';

/// Lives above every route. Removing the Navigator disposes editors and helper
/// dialogs before a reset or restore replaces the journal; the router epoch
/// also prevents route reuse.
class SyncHost extends ConsumerWidget {
  const SyncHost({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(syncEnabledProvider)) return child;
    final engine = ref.watch(backupEngineProvider);
    ref.watch(backupCoordinatorProvider);
    if (engine.hasError) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not check your backups.'),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(backupEngineProvider);
                    ref.invalidate(deviceIdentityProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!engine.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    ref.listen(accountResetProvider, (previous, next) {
      final message = next.completed && previous?.completed != true
          ? 'Account data reset. You are signed out.'
          : previous?.running == true && !next.blocksDataAccess
          ? next.error
          : null;
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)
                ?.showSnackBar(SnackBar(content: Text(message)));
          }
        });
      }
    });
    final reset = ref.watch(accountResetProvider);
    if (reset.blocksDataAccess) return const ResetAccountProgressScreen();
    if (ref.watch(restoringProvider)) return const RestoreProgressScreen();
    return child;
  }
}

/// Shown while a backup replaces this phone's journal.
class RestoreProgressScreen extends ConsumerWidget {
  const RestoreProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = describeBackup(
      ref.watch(backupStateProvider),
      signedIn: true,
    );
    final reduced = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('Restoring your journal')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      key: const ValueKey('restore-progress'),
                      value: status.fraction ?? (reduced ? .5 : null),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        status.active ? status.label : 'Restoring…',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Keep Redkeep open. If it closes, the download '
                      'continues from where it stopped.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
