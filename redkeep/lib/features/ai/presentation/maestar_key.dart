import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../domain/ai_provider_catalog.dart';
import 'settings_parts.dart';

const _brass = Color(0xFFD4A84B);

/// Where the key stands with the provider.
enum KeyState { idle, checking, accepted, rejected }

/// Shows a key as a few letters each end, never the whole of it.
String maskKey(String token) {
  if (token.isEmpty) return '';
  if (token.length <= 8) return '•' * token.length;
  return '${token.substring(0, 3)}••••${token.substring(token.length - 4)}';
}

/// The address with its scheme dropped, as people say it.
String plainAddress(String address) =>
    address.trim().replaceFirst(RegExp(r'^https?://'), '');

/// The provider key in its cushion: a brass key that shines once the
/// provider accepts it, the key masked, the address it opens, and a line
/// saying where things stand, with a glass pill to check it again.
class KeyCard extends StatelessWidget {
  const KeyCard({
    super.key,
    required this.address,
    required this.token,
    required this.status,
    required this.state,
    required this.onEdit,
    required this.onCheck,
  });

  final String address, token, status;
  final KeyState state;
  final VoidCallback? onEdit, onCheck;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final serif = DiaryTypography.of(context).body.fontFamily;
    final preset = aiProviderPresetForAddress(address);
    final known = preset != customAiProviderPreset;
    final hasKey = token.isNotEmpty;
    final engraved = Color.lerp(_brass, palette.ink, .4)!;
    final tone = switch (state) {
      KeyState.rejected => colors.error,
      KeyState.accepted => palette.accent,
      _ => palette.muted,
    };
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final statusLine = Row(
      children: [
        _Pip(color: tone, busy: state == KeyState.checking),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              status,
              style: TextStyle(color: tone, fontSize: 13, height: 1.35),
            ),
          ),
        ),
      ],
    );
    final check = GlassPill(
      key: const ValueKey('ai-key-check'),
      label: 'Check',
      icon: Icons.vpn_key_outlined,
      filled: false,
      compact: true,
      busy: state == KeyState.checking,
      onPressed: hasKey ? onCheck : null,
    );
    return SettingsCushion(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: onEdit != null,
            label: [
              known ? '${preset.name} key' : 'Your key',
              hasKey ? 'Key added' : 'No key yet',
              plainAddress(address),
              'Edit',
            ].join('. '),
            excludeSemantics: true,
            onTap: onEdit,
            child: GestureDetector(
              key: const ValueKey('ai-provider-key-row'),
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Springy(
                enabled: onEdit != null,
                depth: .03,
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 54,
                      child: CustomPaint(
                        painter: BrassKeyPainter(
                          present: hasKey,
                          accepted: state == KeyState.accepted,
                          faint: palette.ink,
                          glow: palette.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            known
                                ? preset.name.toUpperCase()
                                : 'OPENAI-COMPATIBLE',
                            style: TextStyle(
                              color: engraved,
                              fontSize: 10.5,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            hasKey ? maskKey(token) : 'Add your key',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: serif,
                              fontSize: 19,
                              height: 1.3,
                              letterSpacing: hasKey ? 1 : 0,
                              fontStyle: hasKey
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                              color: hasKey ? palette.ink : palette.muted,
                            ),
                          ),
                          Text(
                            plainAddress(address),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: palette.muted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.rule),
          const SizedBox(height: 10),
          // Side by side, unless large text needs the whole width.
          if (stacked) ...[
            statusLine,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: check),
          ] else
            Row(
              children: [
                Expanded(child: statusLine),
                const SizedBox(width: 8),
                check,
              ],
            ),
        ],
      ),
    );
  }
}

/// A small glass drop in the status colour; it breathes while checking.
class _Pip extends StatelessWidget {
  const _Pip({required this.color, required this.busy});
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final pip = CustomPaint(
      size: const Size.square(12),
      painter: _PipPainter(cushion, color),
    );
    if (!busy || !RenderingPolicyScope.of(context).animate) return pip;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .4, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: pip,
    );
  }
}

class _PipPainter extends CustomPainter {
  const _PipPainter(this.colors, this.tint);
  final CushionColors colors;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) => paintGlass(
    canvas,
    RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width)),
    colors: colors,
    tint: tint,
    fill: .85,
    lift: .5,
  );

  @override
  bool shouldRepaint(_PipPainter old) =>
      old.colors != colors || old.tint != tint;
}

/// An old brass key, lying at an angle. Accepted keys catch the light.
class BrassKeyPainter extends CustomPainter {
  const BrassKeyPainter({
    required this.present,
    required this.accepted,
    required this.faint,
    required this.glow,
  });
  final bool present, accepted;
  final Color faint, glow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    final s = size.shortestSide / 52;
    canvas.scale(s);

    const bowCenter = Offset(-13, 0);
    final solid = Path()
      ..addOval(Rect.fromCircle(center: bowCenter, radius: 9))
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(-5, -2.2, 21, 2.2),
          const Radius.circular(2),
        ),
      )
      // The bit: two teeth.
      ..addRect(const Rect.fromLTRB(13, 2, 16, 8))
      ..addRect(const Rect.fromLTRB(18, 2, 21, 10));
    // The hollow of the bow shows the page through it.
    final shape = Path.combine(
      PathOperation.difference,
      solid,
      Path()..addOval(Rect.fromCircle(center: bowCenter, radius: 4.6)),
    );

    if (!present) {
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = faint.withValues(alpha: .22),
      );
      canvas.restore();
      return;
    }
    if (accepted) {
      canvas.drawCircle(
        Offset.zero,
        22,
        Paint()
          ..color = glow.withValues(alpha: .14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    final hsl = HSLColor.fromColor(_brass);
    final bounds = shape.getBounds();
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hsl.withLightness((hsl.lightness + .25).clamp(0, 1)).toColor(),
            _brass,
            hsl.withLightness((hsl.lightness - .22).clamp(0, 1)).toColor(),
          ],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      bowCenter,
      4.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = hsl
            .withLightness((hsl.lightness - .25).clamp(0, 1))
            .toColor(),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrassKeyPainter old) =>
      old.present != present ||
      old.accepted != accepted ||
      old.faint != faint ||
      old.glow != glow;
}

/// The address and key, on a sheet of paper. Keeping them saves them at
/// once; nothing waits on a Save button. A known address is recognised as
/// it is typed, with a way to its key page. Forgetting the key asks first,
/// on the sheet itself.
class KeySheet extends StatefulWidget {
  const KeySheet({
    super.key,
    required this.address,
    required this.token,
    required this.onKeep,
    this.onForget,
  });

  final String address, token;

  /// Saves; returns a message when it could not.
  final Future<String?> Function(String address, String token) onKeep;

  /// Deletes the key from the phone. Null before there is one.
  final Future<void> Function()? onForget;

  @override
  State<KeySheet> createState() => _KeySheetState();
}

class _KeySheetState extends State<KeySheet> {
  late final _address = TextEditingController(text: widget.address);
  late final _token = TextEditingController(text: widget.token);
  bool _hidden = true;
  bool _busy = false;
  bool _forgetting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _address.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _address.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _keep() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onKeep(_address.text.trim(), _token.text.trim());
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _forget() async {
    setState(() => _busy = true);
    await widget.onForget!();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openKeyPage(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Open $url in your browser.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final preset = aiProviderPresetForAddress(_address.text);
    final known = preset != customAiProviderPreset;
    final keyUrl = preset.keyUrl;
    final error = _error;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Your key',
                        style: settingsHand(context, size: 34),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Any OpenAI-compatible service. Kept only on this phone.',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: 64,
                child: CustomPaint(
                  painter: BrassKeyPainter(
                    present: _token.text.trim().isNotEmpty,
                    accepted: false,
                    faint: palette.ink,
                    glow: palette.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          InkedField(
            fieldKey: const ValueKey('ai-provider-url'),
            label: 'Address',
            controller: _address,
            hint: 'https://api.openai.com/v1',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: RenderingPolicyScope.of(context).duration,
            child: Row(
              key: ValueKey(preset.id),
              children: [
                Icon(
                  known ? Icons.verified_outlined : Icons.hub_outlined,
                  size: 15,
                  color: known ? palette.accent : palette.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    known ? 'Recognised: ${preset.name}' : 'Your own service',
                    style: TextStyle(
                      color: known ? palette.accent : palette.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (keyUrl != null)
                  TextButton.icon(
                    onPressed: () => unawaited(_openKeyPage(keyUrl)),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.accent,
                      minimumSize: const Size(48, 40),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.north_east_rounded, size: 16),
                    label: const Text('Get a key'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          InkedField(
            fieldKey: const ValueKey('ai-provider-token'),
            label: 'Key',
            controller: _token,
            hint: 'sk-…',
            obscure: _hidden,
            monospace: true,
            onChanged: (_) => setState(() {}),
            trailing: IconButton(
              tooltip: _hidden ? 'Show key' : 'Hide key',
              color: palette.muted,
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(
                _hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: TextStyle(color: colors.error, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 26),
          GlassPill(
            key: const ValueKey('ai-key-keep'),
            label: 'Keep it',
            icon: Icons.check_rounded,
            wide: true,
            busy: _busy && !_forgetting,
            onPressed: _busy || _address.text.trim().isEmpty ? null : _keep,
          ),
          if (widget.onForget != null) ...[
            const SizedBox(height: 10),
            AnimatedSize(
              duration: RenderingPolicyScope.of(context).duration,
              child: _forgetting
                  ? Column(
                      children: [
                        Text(
                          'Delete this key from the phone? AI stops until you add one again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GlassPill(
                                label: 'Keep it',
                                filled: false,
                                compact: true,
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _forgetting = false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassPill(
                                key: const ValueKey('ai-key-forget-confirm'),
                                label: 'Forget it',
                                compact: true,
                                tint: colors.error,
                                busy: _busy,
                                onPressed: _busy ? null : _forget,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Center(
                      child: TextButton.icon(
                        key: const ValueKey('ai-key-forget'),
                        onPressed: _busy
                            ? null
                            : () => setState(() => _forgetting = true),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.error,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.link_off_rounded, size: 18),
                        label: const Text('Forget this key'),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
