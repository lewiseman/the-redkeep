import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../application/sync_providers.dart';
import 'backup_status.dart';
import 'sync_material.dart';

/// Restores [offer] and reports the outcome. The app shows restore progress
/// above every route meanwhile, so messages go to the root messenger.
Future<void> restoreFromOffer(
  BuildContext context,
  WidgetRef ref,
  RestoreOffer offer,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final actions = ref.read(backupActionsProvider);
  try {
    final backup = offer.backup;
    if (backup == null) {
      final added = await actions.restoreLegacy();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Nothing new was found in the earlier sync.'
                : 'Restored $added ${added == 1 ? 'item' : 'items'} from the earlier sync.',
          ),
        ),
      );
      return;
    }
    final result = await actions.restore(backup);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          result.filesError == null
              ? 'Your journal is restored.'
              : 'Your journal is restored. ${result.filesError!.message}',
        ),
      ),
    );
  } on Object catch (error) {
    messenger?.showSnackBar(SnackBar(content: Text('$error')));
  }
}

/// "Backup found": offered only while this phone has no writing.
class RestoreOfferPanel extends ConsumerWidget {
  const RestoreOfferPanel({
    super.key,
    required this.offer,
    this.onRestore,
    this.onSkip,
  });

  final RestoreOffer offer;
  final VoidCallback? onRestore;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final backup = offer.backup;
    final busy = ref.watch(backupStateProvider).busy;
    final detail = backup == null
        ? 'Your notes, diary and watchlist from the earlier Redkeep sync.'
        : [
            DateFormat.yMMMd().add_jm().format(backup.createdAt),
            backupSize(backup.size),
            if (backup.deviceName != null) backup.deviceName!,
          ].join(' · ');
    return Container(
      key: const ValueKey('restore-offer'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.accent.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_rounded, color: palette.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Backup found',
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Restore it before you start writing. Once this phone '
                      'has writing, its own backups replace this one.',
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const ValueKey('skip-restore'),
                onPressed: busy
                    ? null
                    : onSkip ??
                          () => ref.read(restoreOfferProvider.notifier).decline(),
                child: const Text('Skip'),
              ),
              FilledButton(
                key: const ValueKey('restore-backup'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: busy
                    ? null
                    : onRestore ?? () => restoreFromOffer(context, ref, offer),
                child: const Text('Restore'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown right after connecting an account on an empty phone.
abstract final class RestoreOfferSheet {
  static Future<void> show(BuildContext context, RestoreOffer offer) {
    final palette = MorePalette.of(context);
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: palette.paper,
      sheetAnimationStyle: RenderingPolicyScope.of(context).reducedMotion
          ? AnimationStyle.noAnimation
          : null,
      builder: (sheet) => Consumer(
        builder: (sheet, ref, _) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: RestoreOfferPanel(
              offer: offer,
              onSkip: () {
                ref.read(restoreOfferProvider.notifier).decline();
                Navigator.pop(sheet);
              },
              onRestore: () {
                Navigator.pop(sheet);
                restoreFromOffer(context, ref, offer);
              },
            ),
          ),
        ),
      ),
    );
  }
}
