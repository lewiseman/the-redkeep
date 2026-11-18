import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../../../core/notifications/app_notifications.dart';
import '../application/sync_providers.dart';
import '../../../core/presentation/rendering_policy.dart';
import 'backup_status.dart';
import 'tome_material.dart';
import '../../onboarding/application/onboarding_controller.dart';

/// The journal as a heavy leather tome: a medallion with the writer's
/// initials, their name stamped into the cover, and a gilt-ruled bookplate
/// for the backup that opens the book ([onOpen]).
class SyncAccountCard extends ConsumerWidget {
  const SyncAccountCard({super.key, this.onOpen, this.headroom = 0});

  final VoidCallback? onOpen;

  /// Extra height for the book, given above its contents.
  final double headroom;

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

  /// The initials medallion on the closed cover.
  static const medallionSize = 108.0;

  /// Contents sit inside the tooled panel with an even margin all round,
  /// centred on it rather than on the whole board.
  static const _margin = 12.0;
  static const _start = TomeBinding.spine + TomeBinding.panelInset + _margin;
  static const _end = TomeBinding.thickness + TomeBinding.panelInset + _margin;
  static const _top = TomeBinding.panelInset + _margin;
  static const _bottom =
      TomeBinding.thickness + TomeBinding.panelInset + _margin;

  static String initialsOf(String title) => title
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part.characters.first)
      .join()
      .toUpperCase();

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

    return TomeBinding(
      key: const ValueKey('sync-account-card'),
      shadow: !simpler,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _start,
          _top + headroom * .5,
          _end,
          // The bookplate rests at the foot of the panel, as close to its
          // tooled line as it is to the sides.
          _bottom,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: TomeMedallion(
                  key: const ValueKey('sync-avatar'),
                  size: medallionSize,
                  initials: initialsOf(title),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tome.stamped(
                  fontSize: 22,
                  letterSpacing: 1.2,
                  color: Color.lerp(tome.onLeather, tome.gilt, .45),
                ),
              ),
              if (isSignedIn) ...[
                const SizedBox(height: 4),
                Text(
                  syncAccount.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tome.onLeatherMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _Bookplate(status: status, onTap: isSignedIn ? onOpen : null),
              if (!isSignedIn) ...[
                const SizedBox(height: 12),
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
                      borderRadius: BorderRadius.circular(14),
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
    );
  }
}

/// The backup as a bookplate set into the cover: a panel pressed into the
/// leather, ruled twice in worn gilt, with a bronze stud for its state and
/// a gilt seal leading on into the book.
class _Bookplate extends StatelessWidget {
  const _Bookplate({required this.status, required this.onTap});

  final BackupStatusView status;
  final VoidCallback? onTap;

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final tome = TomePalette.of(context);
    final simpler = RenderingPolicyScope.of(context).simplerEffects;
    final color = status.error ? tome.warning : tome.gilt;
    final stud = SizedBox.square(
      dimension: 32,
      child: CustomPaint(
        painter: _StudPainter(tome, simple: simpler),
        child: Center(
          child: status.active
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: color,
                    value:
                        status.fraction ??
                        (MediaQuery.disableAnimationsOf(context) ? .7 : null),
                  ),
                )
              : Icon(status.icon, color: color, size: 18),
        ),
      ),
    );
    return CustomPaint(
      painter: _BookplatePainter(tome, simple: simpler),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('sync-card-status'),
          onTap: onTap,
          splashColor: tome.gilt.withValues(alpha: .14),
          highlightColor: tome.gilt.withValues(alpha: .08),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  stud,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            status.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Tooltip(
                          message: status.detail,
                          child: Text(
                            status.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tome.onLeatherMuted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tome.gilt.withValues(alpha: .16),
                        border: Border.all(
                          color: tome.gilt.withValues(alpha: .5),
                          width: .8,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: tome.gilt,
                        size: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookplatePainter extends CustomPainter {
  const _BookplatePainter(this.tome, {required this.simple});

  final TomePalette tome;
  final bool simple;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final plate = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(_Bookplate._radius),
    );
    // Pressed into the hide: darker than the cover, shadowed under its
    // top edge and catching light along its bottom lip.
    canvas.drawRRect(
      plate,
      Paint()..color = tome.leatherDeep.withValues(alpha: .72),
    );
    if (!simple) {
      canvas.drawRRect(
        plate.deflate(.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: .55),
              Colors.black.withValues(alpha: 0),
              tome.leatherLight.withValues(alpha: .45),
            ],
            stops: const [0, .5, 1],
          ).createShader(rect),
      );
    }
    // Two gilt rules, the outer one firmer.
    canvas.drawRRect(
      plate.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..color = tome.gilt.withValues(alpha: .5),
    );
    if (!simple) {
      canvas.drawRRect(
        plate.deflate(6.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6
          ..color = tome.gilt.withValues(alpha: .2),
      );
    }
  }

  @override
  bool shouldRepaint(_BookplatePainter old) =>
      simple != old.simple || tome.leatherDeep != old.tome.leatherDeep;
}

/// A domed bronze stud, the backup's state set into it.
class _StudPainter extends CustomPainter {
  const _StudPainter(this.tome, {required this.simple});

  final TomePalette tome;
  final bool simple;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (simple) {
      canvas.drawCircle(centre, r, Paint()..color = tome.board);
      canvas.drawCircle(
        centre,
        r - .5,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = tome.bronze,
      );
      return;
    }
    canvas.drawCircle(
      centre.translate(0, 1.2),
      r,
      Paint()..color = Colors.black.withValues(alpha: .45),
    );
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.45),
          colors: [tome.bronzeLight, tome.bronze, tome.bronzeDark],
          stops: const [0, .5, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );
    // The well the state sits in.
    canvas.drawCircle(
      centre,
      r - 4,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.2, .3),
          colors: [tome.board, Color.lerp(tome.board, Colors.black, .4)!],
        ).createShader(Rect.fromCircle(center: centre, radius: r - 4)),
    );
    canvas.drawCircle(
      centre,
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = tome.bronzeLight.withValues(alpha: .5),
    );
  }

  @override
  bool shouldRepaint(_StudPainter old) => simple != old.simple;
}
