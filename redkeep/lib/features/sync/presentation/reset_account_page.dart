import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../application/sync_providers.dart';
import 'sync_material.dart';

const _word = 'DELETE';

class ResetAccountPage extends ConsumerStatefulWidget {
  const ResetAccountPage({super.key, required this.account});

  final SyncAccount account;

  @override
  ConsumerState<ResetAccountPage> createState() => _ResetAccountPageState();
}

class _ResetAccountPageState extends ConsumerState<ResetAccountPage> {
  final _confirmation = TextEditingController();
  final _focus = FocusNode();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmation.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (_submitting ||
        _confirmation.text.trim() != _word ||
        ref.read(syncAccountProvider)?.id != widget.account.id ||
        ref.read(syncEngineProvider).isSyncing ||
        ref.read(accountResetProvider).blocksDataAccess) {
      return;
    }
    _focus.unfocus();
    setState(() => _submitting = true);
    try {
      await ref
          .read(accountResetProvider.notifier)
          .reset(expectedAccountId: widget.account.id);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(syncAccountProvider);
    final backend = ref.watch(syncBackendProvider);
    final reset = ref.watch(accountResetProvider);
    final syncing = ref.watch(
      syncEngineProvider.select((state) => state.isSyncing),
    );
    final policy = RenderingPolicyScope.of(context);
    final animate = policy.animate && !MediaQuery.disableAnimationsOf(context);
    final palette = MorePalette.of(context);

    final sameAccount = account?.id == widget.account.id;
    final busy = _submitting || reset.blocksDataAccess;
    final typed = _confirmation.text.trim();
    final armed = typed == _word;
    final canReset = sameAccount && !busy && !syncing && armed;

    final blocker = !sameAccount
        ? 'Reconnect ${widget.account.email} before resetting its data.'
        : syncing
        ? 'Wait for sync to finish before resetting account data.'
        : null;

    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        backgroundColor: palette.ground,
        surfaceTintColor: Colors.transparent,
        title: const Text('Reset account data'),
      ),
      body: DefaultTextStyle.merge(
        style: TextStyle(color: palette.ink),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: MoreSurface.contentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: _BrokenSeal(
                        split: armed,
                        animate: animate,
                        duration: policy.duration,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      child: Text(
                        'Erase your journal\nand start over?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 26,
                          height: 1.18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Deletes your writing on this device and in ',
                          ),
                          TextSpan(
                            text: widget.account.email,
                            style: TextStyle(
                              color: palette.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text:
                                ' on ${backend.displayName}. '
                                'There is no undo.',
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Ledger(armed: armed, animate: animate),
                    const SizedBox(height: 14),
                    const _OtherDevicesNote(),
                    const SizedBox(height: 28),
                    _Docket(
                      controller: _confirmation,
                      focusNode: _focus,
                      enabled: !busy && sameAccount,
                      typed: typed,
                      armed: armed,
                      busy: busy,
                      canReset: canReset,
                      blocker: blocker,
                      error: reset.error,
                      animate: animate,
                      duration: policy.duration,
                      onChanged: () => setState(() {}),
                      onSubmit: _reset,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('cancel-reset-account'),
                      onPressed: busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.accent,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text(
                        'Keep my journal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// Header

/// The journal's wax seal, cracked. The halves part once DELETE is typed.
class _BrokenSeal extends StatelessWidget {
  const _BrokenSeal({
    required this.split,
    required this.animate,
    required this.duration,
  });
  final bool split;
  final bool animate;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final danger = colors.error;
    // Dark themes use a pale error tone; deepen it so the seal reads as wax.
    final wax = colors.brightness == Brightness.dark
        ? Color.lerp(danger, const Color(0xff5a0b0b), .55)!
        : danger;
    final simpler = RenderingPolicyScope.of(context).simplerEffects;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: split ? 1 : 0),
        duration: animate ? duration * 2 : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          size: const Size(104, 96),
          painter: _SealPainter(
            wax: wax,
            ground: palette.paper,
            shadow: simpler ? null : wax.withValues(alpha: .3),
            t: t,
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({
    required this.wax,
    required this.ground,
    required this.shadow,
    required this.t,
  });
  final Color wax;
  final Color ground;
  final Color? shadow;
  final double t;

  // Crack from top to bottom, as fractions of the seal's diameter.
  static const _crack = [
    Offset(.53, -.05),
    Offset(.47, .22),
    Offset(.58, .40),
    Offset(.45, .58),
    Offset(.55, .78),
    Offset(.49, 1.05),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const d = 80.0;
    final origin = Offset((size.width - d) / 2, (size.height - d) / 2);
    final rect = origin & const Size(d, d);
    final seal = _wobblyDisc(rect);

    Path half(bool left) {
      final p = Path()
        ..moveTo(left ? rect.left - 20 : rect.right + 20, rect.top - 10);
      for (final c in _crack) {
        p.lineTo(rect.left + c.dx * d, rect.top + c.dy * d);
      }
      p
        ..lineTo(left ? rect.left - 20 : rect.right + 20, rect.bottom + 10)
        ..close();
      return Path.combine(PathOperation.intersect, seal, p);
    }

    final gap = 3 + 5 * t;
    final tilt = (4 + 6 * t) * math.pi / 180;
    final center = rect.center;
    for (final left in [true, false]) {
      final path = half(left);
      canvas.save();
      final dir = left ? -1.0 : 1.0;
      canvas.translate(center.dx + dir * gap, center.dy + (left ? 0 : 2 * t));
      canvas.rotate(dir * tilt);
      canvas.translate(-center.dx, -center.dy);
      if (shadow != null) {
        canvas.drawShadow(path, shadow!, 4, false);
      }
      canvas.drawPath(path, Paint()..color = wax);
      // Pressed rim and monogram.
      canvas.save();
      canvas.clipPath(path);
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ground.withValues(alpha: .28);
      canvas.drawCircle(center, d * .34, rim);
      final r = TextPainter(
        text: TextSpan(
          text: 'R',
          style: TextStyle(
            color: ground.withValues(alpha: .55),
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      r.paint(canvas, center - Offset(r.width / 2, r.height / 2));
      canvas.restore();
      canvas.restore();
    }
  }

  Path _wobblyDisc(Rect rect) {
    final p = Path();
    const lobes = 14;
    final c = rect.center;
    final base = rect.width / 2;
    for (var i = 0; i <= 96; i++) {
      final a = i / 96 * 2 * math.pi;
      final r = base * (1 + .035 * math.sin(a * lobes) + .02 * math.cos(a * 3));
      final o = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.t != t || old.wax != wax || old.ground != ground;
}

// ---------------------------------------------------------------------------
// Ledger

class _Entry {
  const _Entry(this.icon, this.label);
  final IconData icon;
  final String label;
}

const _erased = [
  _Entry(Icons.sticky_note_2_outlined, 'Notes'),
  _Entry(Icons.menu_book_outlined, 'Diary entries'),
  _Entry(Icons.bubble_chart_outlined, 'Thoughts'),
  _Entry(Icons.delete_outline_rounded, 'Trash'),
  _Entry(Icons.cloud_off_outlined, 'Redkeep backups'),
  _Entry(Icons.history_edu_outlined, 'Recovery drafts'),
];

/// One ledger page: what is erased above, a perforated stub of what is kept.
class _Ledger extends StatelessWidget {
  const _Ledger({required this.armed, required this.animate});
  final bool armed;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final danger = Theme.of(context).colorScheme.error;
    return Container(
      key: const ValueKey('reset-erased-ledger'),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tall enough to hold the stamp without covering items.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 38),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _Eyebrow('Will be erased', color: danger),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, box) {
                        final scale = MediaQuery.textScalerOf(context).scale(1);
                        final columns = box.maxWidth / scale >= 300 ? 2 : 1;
                        final width =
                            (box.maxWidth - 12 * (columns - 1)) / columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            for (final e in _erased)
                              SizedBox(
                                width: width,
                                child: _EntryRow(entry: e, struck: armed),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Pressed into the header's empty corner, clear of the items.
              Positioned(
                top: 10,
                right: 16,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: _Stamp(visible: armed, animate: animate),
                  ),
                ),
              ),
            ],
          ),
          _Perforation(color: palette.rule, notch: palette.ground),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Eyebrow('Kept', color: palette.accent),
                const SizedBox(height: 6),
                Text(
                  'Your name, appearance settings, artwork and downloaded '
                  'models. You will be signed out.',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.struck});
  final _Entry entry;
  final bool struck;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final danger = Theme.of(context).colorScheme.error;
    return Row(
      children: [
        Icon(entry.icon, size: 18, color: struck ? danger : palette.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            entry.label,
            style: TextStyle(
              color: struck ? palette.muted : palette.ink,
              fontSize: 14,
              height: 1.3,
              decoration: struck ? TextDecoration.lineThrough : null,
              decorationColor: danger,
              decorationThickness: 2,
            ),
          ),
        ),
      ],
    );
  }
}

/// A tear-off line with half-moon notches cut into the card's edges.
class _Perforation extends StatelessWidget {
  const _Perforation({required this.color, required this.notch});
  final Color color;
  final Color notch;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 14,
    child: CustomPaint(painter: _PerforationPainter(color, notch)),
  );
}

class _PerforationPainter extends CustomPainter {
  _PerforationPainter(this.color, this.notch);
  final Color color;
  final Color notch;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final dash = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    for (double x = 14; x < size.width - 14; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
    }
    final fill = Paint()..color = notch;
    final edge = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    // Fill covers the card border; only the inner half-moon is outlined.
    for (final (x, start) in [
      (-1.0, -math.pi / 2),
      (size.width + 1, math.pi / 2),
    ]) {
      final notchRect = Rect.fromCircle(center: Offset(x, y), radius: 7);
      canvas.drawCircle(Offset(x, y), 7.6, fill);
      canvas.drawArc(notchRect, start, math.pi, false, edge);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) =>
      old.color != color || old.notch != notch;
}

/// Rubber stamp pressed onto the ledger once DELETE is typed.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.visible, required this.animate});
  final bool visible;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    final ink = danger.withValues(alpha: .8);
    final stamp = Transform.rotate(
      angle: -6 * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: ink, width: 2),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: ink, width: 1),
          ),
          child: Text(
            'ERASED',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
    if (!animate) return visible ? stamp : const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 1.7, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: visible
          ? KeyedSubtree(key: const ValueKey('stamp'), child: stamp)
          : const SizedBox.shrink(),
    );
  }
}

class _OtherDevicesNote extends StatelessWidget {
  const _OtherDevicesNote();

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.devices_other_rounded,
            size: 20,
            color: palette.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Close Redkeep on your other devices first. ',
                  style: TextStyle(
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(
                  text:
                      'Their copies are not erased and could upload again '
                      'unless you clear them before reconnecting.',
                ),
              ],
            ),
            style: TextStyle(color: palette.muted, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmation

/// The signing slip: the letter boxes are the input, the button its foot.
class _Docket extends StatelessWidget {
  const _Docket({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.typed,
    required this.armed,
    required this.busy,
    required this.canReset,
    required this.blocker,
    required this.error,
    required this.animate,
    required this.duration,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled, armed, busy, canReset, animate;
  final String typed;
  final String? blocker, error;
  final Duration duration;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final danger = colors.error;
    final matched = _matchedLength(typed);
    final wrong = typed.isNotEmpty && matched < typed.length;

    final (String hint, Color hintColor) = blocker != null
        ? (blocker!, palette.muted)
        : error != null
        ? (error!, danger)
        : busy
        ? ('Erasing your journal…', danger)
        : wrong
        ? ('That doesn’t match. Type $_word.', danger)
        : armed
        ? ('Ready. This cannot be undone.', danger)
        : ('Tap the boxes and type $_word.', palette.muted);

    return AnimatedContainer(
      duration: animate ? duration : Duration.zero,
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: armed ? danger.withValues(alpha: .6) : palette.rule,
          width: armed ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Eyebrow('Sign to confirm', color: palette.muted),
                const SizedBox(height: 14),
                _LetterField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  matched: matched,
                  wrong: wrong,
                  typedLength: typed.length,
                  animate: animate,
                  duration: duration,
                  onChanged: onChanged,
                  onSubmit: () {
                    if (canReset) onSubmit();
                  },
                ),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        error != null || wrong
                            ? Icons.error_outline_rounded
                            : armed
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        size: 16,
                        color: hintColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hint,
                          style: TextStyle(
                            color: hintColor,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            key: const ValueKey('confirm-reset-account'),
            onPressed: canReset ? onSubmit : null,
            style: FilledButton.styleFrom(
              backgroundColor: danger,
              foregroundColor: colors.onError,
              disabledBackgroundColor: palette.cloth,
              disabledForegroundColor: palette.muted,
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: const RoundedRectangleBorder(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onError,
                    ),
                  )
                else
                  const Icon(Icons.delete_forever_rounded, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    busy ? 'Erasing…' : 'Delete permanently',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _matchedLength(String typed) {
    var n = 0;
    while (n < typed.length && n < _word.length && typed[n] == _word[n]) {
      n++;
    }
    return n;
  }
}

/// Six boxes that are the text field: ghost letters guide, typed letters ink.
class _LetterField extends StatelessWidget {
  const _LetterField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.matched,
    required this.wrong,
    required this.typedLength,
    required this.animate,
    required this.duration,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled, wrong, animate;
  final int matched, typedLength;
  final Duration duration;
  final VoidCallback onChanged, onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final danger = colors.error;
    final focused = focusNode.hasFocus;
    final cursor = math.min(typedLength, _word.length - 1);
    final text = controller.text.trim();

    Widget box(int i) {
      final filled = i < matched;
      final bad = wrong && i >= matched && i < typedLength;
      final current = focused && i == cursor && !filled;
      final letter = i < text.length ? text[i] : _word[i];
      return AnimatedContainer(
        duration: animate ? duration : Duration.zero,
        curve: Curves.easeOut,
        width: 44,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? danger : palette.ground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: filled || bad
                ? danger
                : current
                ? palette.accent
                : palette.rule,
            width: current || bad ? 2 : 1,
          ),
        ),
        child: Text(
          letter,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: filled
                ? colors.onError
                : bad
                ? danger
                : palette.muted.withValues(alpha: .35),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _word.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  box(i),
                ],
              ],
            ),
          ),
        ),
        // The real input sits invisibly over the boxes, so taps, keyboards,
        // paste and screen readers all work as a normal text field.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              key: const ValueKey('reset-confirmation-input'),
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autocorrect: false,
              enableSuggestions: false,
              showCursor: false,
              enableInteractiveSelection: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_word.length + 2),
                _UpperCaseFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Type $_word to confirm',
                border: InputBorder.none,
              ),
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: color,
      fontSize: 11,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
    ),
  );
}
