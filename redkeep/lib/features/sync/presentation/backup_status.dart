import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sync_wise/sync_wise.dart';

/// What the card and the backup sheet say about the backup.
class BackupStatusView {
  const BackupStatusView({
    required this.label,
    required this.detail,
    required this.icon,
    this.error = false,
    this.active = false,
    this.inbound = false,
    this.waiting = false,
    this.never = false,
    this.fraction,
    this.stamp,
  });

  /// Short state, e.g. "Backed up today, 2:04 AM" or "Backing up · 45%".
  final String label;
  final String detail;
  final IconData icon;
  final bool error;

  /// A backup or restore is running.
  final bool active;

  /// Data is coming from the cloud (restore) rather than going to it.
  final bool inbound;

  /// Not signed in, offline or waiting for Wi-Fi.
  final bool waiting;

  /// No backup has finished yet.
  final bool never;
  final double? fraction;

  /// When and how big the last backup was, for a small stamp.
  final String? stamp;
}

BackupStatusView describeBackup(
  BackupState state, {
  required bool signedIn,
  String cloudName = 'Google Drive',
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final last = state.lastSuccess;
  final stamp = last == null
      ? null
      : 'Last backup ${backupTime(last, at)}'
            '${state.lastSize == null ? '' : ' · ${backupSize(state.lastSize!)}'}';
  if (!signedIn) {
    return const BackupStatusView(
      label: 'On this device',
      detail: 'Connect Google Drive to back up your journal.',
      icon: Icons.smartphone_rounded,
      waiting: true,
    );
  }
  final percent = state.fraction == null
      ? ''
      : ' · ${(state.fraction! * 100).floor()}%';
  switch (state.activity) {
    case BackupActivity.preparing:
      return BackupStatusView(
        label: 'Preparing backup…',
        detail: 'Copying your journal for $cloudName.',
        icon: Icons.cloud_upload_outlined,
        active: true,
        stamp: stamp,
      );
    case BackupActivity.uploading:
      return BackupStatusView(
        label: 'Backing up$percent',
        detail: _bytes(state, 'Keep writing; the backup continues by itself.'),
        icon: Icons.cloud_upload_outlined,
        active: true,
        fraction: state.fraction,
        stamp: stamp,
      );
    case BackupActivity.finishing:
      return BackupStatusView(
        label: 'Finishing backup…',
        detail: 'Checking the copy in $cloudName.',
        icon: Icons.cloud_upload_outlined,
        active: true,
        fraction: 1,
        stamp: stamp,
      );
    case BackupActivity.downloading:
      return BackupStatusView(
        label: 'Downloading backup$percent',
        detail: _bytes(state, 'Your journal will be back in a moment.'),
        icon: Icons.cloud_download_outlined,
        active: true,
        inbound: true,
        fraction: state.fraction,
      );
    case BackupActivity.restoring:
      return const BackupStatusView(
        label: 'Restoring…',
        detail: 'Checking and opening your journal.',
        icon: Icons.cloud_download_outlined,
        active: true,
        inbound: true,
      );
    case BackupActivity.idle:
      break;
  }
  final error = state.error;
  if (error != null && error.kind != BackupErrorKind.empty) {
    switch (error.kind) {
      case BackupErrorKind.cancelled:
        return BackupStatusView(
          label: 'Backup paused',
          detail: 'Back up now continues from where it stopped.',
          icon: Icons.pause_circle_outline_rounded,
          waiting: true,
          stamp: stamp,
        );
      case BackupErrorKind.offline:
        final wifi = error.message.contains('Wi');
        return BackupStatusView(
          label: wifi ? 'Waiting for Wi-Fi' : 'Waiting for a connection',
          detail: wifi
              ? 'Backs up on Wi-Fi, or allow mobile data below.'
              : 'The backup continues when you are back online.',
          icon: wifi ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
          waiting: true,
          stamp: stamp,
        );
      case BackupErrorKind.busy:
        break;
      default:
        return BackupStatusView(
          label: 'Backup failed',
          detail: error.message,
          icon: Icons.error_outline_rounded,
          error: true,
          stamp: stamp,
        );
    }
  }
  if (last == null) {
    return BackupStatusView(
      label: 'Not backed up yet',
      detail: 'Backs up to $cloudName overnight on Wi-Fi.',
      icon: Icons.cloud_queue_rounded,
      never: true,
    );
  }
  return BackupStatusView(
    label: 'Backed up ${backupTime(last, at)}',
    detail: '$cloudName${state.lastSize == null ? '' : ' · ${backupSize(state.lastSize!)}'}',
    icon: Icons.cloud_done_outlined,
    stamp: stamp,
  );
}

String _bytes(BackupState state, String fallback) => state.bytesTotal <= 0
    ? fallback
    : '${backupSize(state.bytesDone)} of ${backupSize(state.bytesTotal)}';

/// "just now", "12 min ago", "today, 2:04 AM", "yesterday, 2:04 AM",
/// "Monday, 2:04 AM" or "Nov 3, 2026".
String backupTime(DateTime time, DateTime now) {
  final local = time.toLocal();
  final age = now.difference(local);
  if (age.inSeconds < 60 && !age.isNegative) return 'just now';
  if (age.inMinutes < 60 && !age.isNegative) return '${age.inMinutes} min ago';
  final clock = DateFormat.jm().format(local);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'today, $clock';
  if (days == 1) return 'yesterday, $clock';
  if (days > 1 && days < 7) return '${DateFormat.EEEE().format(local)}, $clock';
  return DateFormat.yMMMd().format(local);
}

String backupSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String backupIntervalLabel(BackupInterval interval) => switch (interval) {
  BackupInterval.daily => 'Daily',
  BackupInterval.weekly => 'Weekly',
  BackupInterval.monthly => 'Monthly',
  BackupInterval.manual => 'Only when I tap “Back up now”',
};
