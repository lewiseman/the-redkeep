import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/sync_providers.dart';
import 'reset_account_progress.dart';

/// Lives above every route. Removing the Navigator disposes editors and helper
/// dialogs before reset cleanup; the router epoch also prevents route reuse.
class SyncHost extends ConsumerWidget {
  const SyncHost({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(syncEnabledProvider)) return child;
    final configuration = ref.watch(syncConfigurationProvider);
    ref.watch(syncCoordinatorProvider);
    if (configuration.hasError) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not check account recovery.'),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(syncConfigurationProvider);
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
    if (!configuration.hasValue) {
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
    return child;
  }
}
