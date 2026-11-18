import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../../../core/notifications/app_notifications.dart';
import '../application/sync_providers.dart';
import '../../../core/presentation/rendering_policy.dart';
import 'backup_status.dart';
import 'tome_material.dart';
import '../../onboarding/application/onboarding_controller.dart';

/// The journal as a heavy leather tome, which folds down to a pinned strip
/// of its cover. Tapping the backup line opens it ([onOpen]).
class SyncAccountCard extends ConsumerWidget {
  const SyncAccountCard({
    super.key,
    required this.collapseProgress,
    required this.onExpand,
    this.onOpen,
  });

  final double collapseProgress;
  final VoidCallback onExpand;

  /// Opens the backup page; the backup line is inert without it.
  final VoidCallback? onOpen;

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    try {
      final account = await ref.read(syncAuthProvider).signIn();
      if (account == null || !context.mounted) return;
      unawaited(requestNotificationPermission());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connected as ${account.email}.')));
      // Restoring belongs to onboarding; here the journal is just backed up.
      await ref.read(backupActionsProvider).backUpIfWriting();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  static const _expandedAvatarSize = 84.0;
  static const _avatarNameGap = 16.0;

  /// Content keeps clear of the spine, and of the clasp and page edges.
  static const _start = TomeBinding.spine + 16;
  static const _end = TomeBinding.thickness + 34;

  static String initialsOf(String title) => title
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part.characters.first)
      .join()
      .toUpperCase();

  static double _identityHeight(BuildContext context, {bool compact = false}) {
    final scaler = MediaQuery.textScalerOf(context);
    final textHeight =
        (scaler.scale(compact ? 16 : 22) * 1.2).ceilToDouble() +
        4 +
        (scaler.scale(compact ? 11 : 12) * 1.4).ceilToDouble() +
        2;
    return compact
        ? math.max(34, textHeight)
        : _expandedAvatarSize + _avatarNameGap + textHeight;
  }

  static double compactHeight(BuildContext context) =>
      28 + _identityHeight(context, compact: true) + TomeBinding.thickness;

  static const _identityTop = 24.0;

  static double expandedHeight(
    BuildContext context, {
    required bool isSignedIn,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    return _identityTop +
        _identityHeight(context) +
        16 +
        25 +
        scaler.scale(13) * 1.35 +
        scaler.scale(12) * 1.45 +
        (isSignedIn ? 0 : 14 + math.max(48, 24 + scaler.scale(13) * 1.35)) +
        20 +
        TomeBinding.thickness;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(onboardingControllerProvider).name?.trim();
    final title = name == null || name.isEmpty ? 'Your journal' : name;
    final syncAccount = ref.watch(syncAccountProvider);
    final backupState = ref.watch(backupStateProvider);
    final isSignedIn = syncAccount != null;
    final status = describeBackup(
      backupState,
      signedIn: isSignedIn,
      cloudName: ref.watch(syncBackendProvider).displayName,
    );
    final tome = TomePalette.of(context);
    final simpler = RenderingPolicyScope.of(context).simplerEffects;
    final t = collapseProgress.clamp(0.0, 1.0);
    final compact = t >= .6;
    final fade = (1 - t * 3).clamp(0.0, 1.0);
    final statusColor = status.error ? tome.warning : tome.gilt;
    final identityHeight = _identityHeight(context);
    final compactIdentityHeight = _identityHeight(context, compact: true);
    // Move the name beside the avatar before lifting it into the compact row.
    final horizontal = Curves.easeInOut.transform((t / .35).clamp(0.0, 1.0));
    final vertical = ((t - .35) / .65).clamp(0.0, 1.0);
    final avatarSize = lerpDouble(_expandedAvatarSize, 32, t)!;
    final textAlignment = AlignmentDirectional.lerp(
      AlignmentDirectional.center,
      AlignmentDirectional.centerStart,
      horizontal,
    )!;
    final initials = initialsOf(title);

    return TomeBinding(
      key: const ValueKey('sync-account-card'),
      shadow: !simpler,
      child: Padding(
        padding: const EdgeInsets.only(
          right: TomeBinding.thickness,
          bottom: TomeBinding.thickness,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned(
                top: lerpDouble(_identityTop, 14, t),
                left: _start,
                right: _end - TomeBinding.thickness,
                child: Semantics(
                  button: compact,
                  onTap: compact ? onExpand : null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: compact ? onExpand : null,
                    child: SizedBox(
                      height: lerpDouble(
                        identityHeight,
                        compactIdentityHeight,
                        vertical,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          children: [
                            PositionedDirectional(
                              top: lerpDouble(
                                0,
                                (compactIdentityHeight - 32) / 2,
                                vertical,
                              ),
                              start: lerpDouble(
                                (constraints.maxWidth - avatarSize) / 2,
                                0,
                                horizontal,
                              ),
                              child: TomeMedallion(
                                key: const ValueKey('sync-avatar'),
                                size: avatarSize,
                                initials: initials,
                              ),
                            ),
                            PositionedDirectional(
                              top: lerpDouble(
                                _expandedAvatarSize + _avatarNameGap,
                                0,
                                vertical,
                              ),
                              bottom: 0,
                              start: lerpDouble(0, avatarSize + 14, horizontal),
                              end: lerpDouble(0, 28, horizontal),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Align(
                                    alignment: textAlignment,
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tome.stamped(
                                        fontSize: lerpDouble(22, 16, t)!,
                                        letterSpacing: lerpDouble(1.2, .4, t)!,
                                        color: Color.lerp(
                                          tome.onLeather,
                                          tome.gilt,
                                          .45,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isSignedIn || compact) ...[
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: textAlignment,
                                      child: Text(
                                        compact
                                            ? status.label
                                            : syncAccount!.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: compact
                                              ? statusColor
                                              : tome.onLeatherMuted,
                                          fontSize: lerpDouble(12, 11, t),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (compact)
                              PositionedDirectional(
                                top: 0,
                                bottom: 0,
                                end: 0,
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  color: tome.gilt,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: _identityTop + identityHeight + 16,
                left: _start,
                right: _end - TomeBinding.thickness,
                child: IgnorePointer(
                  ignoring: t > .15,
                  child: ExcludeSemantics(
                    excluding: t > .15,
                    child: Opacity(
                      opacity: fade,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            key: const ValueKey('sync-card-status'),
                            onTap: isSignedIn ? onOpen : null,
                            splashColor: tome.gilt.withValues(alpha: .14),
                            highlightColor: tome.gilt.withValues(alpha: .08),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  // A line pressed into the hide.
                                  top: BorderSide(
                                    color: Colors.black.withValues(alpha: .5),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (status.active)
                                    SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: statusColor,
                                        value:
                                            status.fraction ??
                                            (MediaQuery.disableAnimationsOf(
                                                  context,
                                                )
                                                ? .7
                                                : null),
                                      ),
                                    )
                                  else
                                    Icon(
                                      status.icon,
                                      color: statusColor,
                                      size: 20,
                                    ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Semantics(
                                          liveRegion: true,
                                          child: Text(
                                            status.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 13,
                                              height: 1.35,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Tooltip(
                                          message: status.detail,
                                          child: Text(
                                            status.detail,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: tome.onLeatherMuted,
                                              fontSize: 12,
                                              height: 1.45,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSignedIn) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: tome.gilt,
                                      size: 17,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (!isSignedIn) ...[
                            const SizedBox(height: 14),
                            FilledButton(
                              key: const ValueKey('sync-card-action'),
                              onPressed: backupState.busy
                                  ? null
                                  : () => _connect(context, ref),
                              style: FilledButton.styleFrom(
                                backgroundColor: tome.gilt,
                                foregroundColor: tome.board,
                                minimumSize: const Size.fromHeight(48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Text(
                                    'G',
                                    textScaler: TextScaler.noScaling,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Connect Account',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 17),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
