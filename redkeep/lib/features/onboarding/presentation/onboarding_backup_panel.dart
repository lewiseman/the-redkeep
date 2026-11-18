import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sync_wise/google_drive.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../sync/application/sync_providers.dart';
import '../../sync/presentation/backup_status.dart';
import '../application/onboarding_restore.dart';
import 'onboarding_controls.dart';

const _ink = Color(0xFF30274E);
const _body = Color(0xFF514354);
const _error = Color(0xFF9B3E4C);
const _track = Color(0x55A99A91);
const _fill = Color(0xFF715B83);

/// The sign-in button names the provider; the book's art never does.
String onboardingSignInLabel(BackupBackend backend) =>
    backend is GoogleDriveBackend
    ? 'Continue with Google'
    : 'Continue with ${backend.displayName}';

/// The backup step under the shrunken book: signing in, the backup found,
/// restore progress, or what went wrong.
class OnboardingBackupPanel extends ConsumerWidget {
  const OnboardingBackupPanel({super.key, required this.onSkip});

  /// Leaves the backup step for the name cover.
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restore = ref.watch(onboardingRestoreProvider);
    final actions = ref.read(onboardingRestoreProvider.notifier);
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final reduced = RenderingPolicyScope.of(context).reducedMotion;
    Widget primary(String label, VoidCallback onPressed, Key key) =>
        OnboardingPrimaryButton(
          key: key,
          label: label,
          onPressed: onPressed,
          simple: simple,
        );
    Widget secondary(String label, VoidCallback onPressed, Key key) =>
        TextButton(
          key: key,
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: _fill,
            minimumSize: const Size(0, 48),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        );
    final (
      String title,
      String? detail,
      List<Widget> buttons,
      bool progress,
    ) = switch (restore.phase) {
      OnboardingRestorePhase.signingIn => (
        'Signing in…',
        null,
        const <Widget>[],
        true,
      ),
      OnboardingRestorePhase.checking => (
        'Looking for your backup…',
        null,
        const <Widget>[],
        true,
      ),
      OnboardingRestorePhase.found => (
        'Backup found',
        _describe(restore.backup!),
        [
          primary(
            'Restore',
            actions.restore,
            const ValueKey('onboarding-restore'),
          ),
          secondary('Skip', onSkip, const ValueKey('onboarding-skip-restore')),
        ],
        false,
      ),
      OnboardingRestorePhase.none => (
        'No backup yet',
        'You’ll start fresh. Your journal backs up by itself once you '
            'start writing.',
        [
          primary(
            'Continue',
            onSkip,
            const ValueKey('onboarding-no-backup-continue'),
          ),
        ],
        false,
      ),
      OnboardingRestorePhase.restoring => (
        'Restoring your journal',
        'Keep Redkeep open. If it closes, the download continues from '
            'where it stopped.',
        const <Widget>[],
        true,
      ),
      OnboardingRestorePhase.restored => (
        'Your journal is back',
        null,
        const <Widget>[],
        false,
      ),
      OnboardingRestorePhase.failed => (
        'That didn’t finish',
        restore.error,
        [
          primary(
            'Try again',
            actions.retry,
            const ValueKey('onboarding-restore-retry'),
          ),
          secondary('Skip', onSkip, const ValueKey('onboarding-skip-restore')),
        ],
        false,
      ),
      OnboardingRestorePhase.idle => ('', null, const <Widget>[], false),
    };
    final status = restore.phase == OnboardingRestorePhase.restoring
        ? describeBackup(ref.watch(backupStateProvider), signedIn: true)
        : null;
    final fraction = status?.fraction;
    return ConstrainedBox(
      key: const ValueKey('onboarding-backup-panel'),
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: restore.phase == OnboardingRestorePhase.failed
                    ? _error
                    : _body,
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ],
          if (progress) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                key: const ValueKey('onboarding-backup-progress'),
                minHeight: 6,
                // Reduced motion: a still bar instead of a sweep.
                value: fraction ?? (reduced ? .5 : null),
                color: _fill,
                backgroundColor: _track,
              ),
            ),
            if (status != null && status.active) ...[
              const SizedBox(height: 8),
              Text(
                status.label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _body, fontSize: 14),
              ),
            ],
          ],
          if (buttons.isNotEmpty) ...[const SizedBox(height: 20), ...buttons],
        ],
      ),
    );
  }

  static String _describe(RemoteBackup backup) => [
    DateFormat.yMMMd().add_jm().format(backup.createdAt),
    backupSize(backup.size),
    if (backup.deviceName != null) backup.deviceName!,
  ].join(' · ');
}
