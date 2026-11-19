import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../sync/presentation/sync_material.dart';

const _brass = Color(0xFFD4A84B);

/// The provider key as one quiet row: a brass key, the key itself masked, the
/// address it opens, and whether the provider has accepted it.
class KeyRow extends StatelessWidget {
  const KeyRow({
    super.key,
    required this.providerName,
    required this.token,
    required this.address,
    required this.status,
    required this.checking,
    required this.accepted,
    required this.rejected,
    required this.onEdit,
    required this.onTest,
    this.onGetKey,
  });

  final String providerName, token, address, status;
  final bool checking, accepted, rejected;
  final VoidCallback? onEdit, onTest, onGetKey;

  static String mask(String token) {
    if (token.isEmpty) return '';
    if (token.length <= 8) return '•' * token.length;
    return '${token.substring(0, 3)}••••${token.substring(token.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final serif = DiaryTypography.of(context).body.fontFamily;
    final hasKey = token.isNotEmpty;
    final statusColor = rejected
        ? colors.error
        : accepted
        ? palette.accent
        : palette.muted;
    final engraved = Color.lerp(_brass, palette.ink, .4)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label:
              '$providerName key. ${hasKey ? 'Key added' : 'No key'}. $address. $status',
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('ai-provider-key-row'),
              borderRadius: BorderRadius.circular(16),
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CustomPaint(
                        painter: _BrassKeyPainter(
                          present: hasKey,
                          accepted: accepted,
                          faint: palette.ink,
                          glow: palette.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${providerName.toUpperCase()} KEY',
                            style: TextStyle(
                              color: engraved,
                              fontSize: 10.5,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasKey ? mask(token) : 'Add your key',
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
                          const SizedBox(height: 3),
                          Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Semantics(
                            liveRegion: true,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: checking
                                      ? SizedBox.square(
                                          dimension: 10,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.6,
                                            color: palette.muted,
                                          ),
                                        )
                                      : Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: statusColor,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: palette.muted.withValues(alpha: .7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 58),
          child: Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                key: const ValueKey('ai-provider-test'),
                onPressed: onTest,
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('Test key'),
              ),
              if (onGetKey != null)
                TextButton.icon(
                  onPressed: onGetKey,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text('Get a $providerName key'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An old brass key, lying at an angle. Accepted keys catch the light.
class _BrassKeyPainter extends CustomPainter {
  const _BrassKeyPainter({
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
  bool shouldRepaint(_BrassKeyPainter old) =>
      old.present != present ||
      old.accepted != accepted ||
      old.faint != faint ||
      old.glow != glow;
}

/// Editing the address and key, away from the page.
class KeyEditorSheet extends StatefulWidget {
  const KeyEditorSheet({
    super.key,
    required this.providerName,
    required this.baseUrl,
    required this.token,
    required this.tokenRequired,
    this.onGetKey,
  });

  final String providerName;
  final TextEditingController baseUrl, token;
  final bool tokenRequired;
  final VoidCallback? onGetKey;

  @override
  State<KeyEditorSheet> createState() => _KeyEditorSheetState();
}

class _KeyEditorSheetState extends State<KeyEditorSheet> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final serif = DiaryTypography.of(context).body.fontFamily;
    InputDecoration field(String label, {Widget? suffix}) => InputDecoration(
      labelText: label,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.providerName} key',
                style: TextStyle(
                  fontFamily: serif,
                  fontSize: 22,
                  color: palette.ink,
                ),
              ),
              Text(
                'Kept on this phone. Sent only to your provider.',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('ai-provider-token'),
                controller: widget.token,
                obscureText: _hide,
                autocorrect: false,
                enableSuggestions: false,
                decoration: field(
                  widget.tokenRequired ? 'API key' : 'API key (optional)',
                  suffix: IconButton(
                    tooltip: _hide ? 'Show key' : 'Hide key',
                    onPressed: () => setState(() => _hide = !_hide),
                    icon: Icon(
                      _hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('ai-provider-url'),
                controller: widget.baseUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: field('API address (https://)'),
              ),
              if (widget.onGetKey != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: widget.onGetKey,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text('Get a ${widget.providerName} key'),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
