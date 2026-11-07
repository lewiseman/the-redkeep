import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../sync/presentation/sync_material.dart';
import '../domain/ai_provider.dart';
import 'maestar_study.dart';

/// One skill hung on the chain: its metal link on a rail running down the
/// left, the model in serif, and its price in a quiet line beneath.
class ModelChainRow extends StatelessWidget {
  const ModelChainRow({
    super.key,
    required this.capability,
    required this.model,
    required this.detail,
    required this.offered,
    required this.first,
    required this.last,
    this.onTap,
    this.highlight = 0,
  });

  final AiCapability capability;

  /// The chosen model, or null when the link is unforged.
  final String? model;

  /// A short line under the model: its price, or why the link is off.
  final String detail;
  final bool offered, first, last;
  final VoidCallback? onTap;
  final double highlight;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final metal = maestarMetal(capability);
    final forged = offered && model != null;
    final serif = DiaryTypography.of(context).body.fontFamily;
    final engraved = Color.lerp(metal, palette.ink, .4)!;
    return Semantics(
      button: onTap != null,
      label:
          '${capability.label}. ${!offered ? detail : model ?? 'No model'}. ${offered ? detail : ''}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 52,
              child: CustomPaint(
                painter: _RailPainter(
                  color: palette.ink,
                  first: first,
                  last: last,
                ),
                child: Align(
                  alignment: const Alignment(0, -1),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: 44,
                      height: 52,
                      child: CustomPaint(
                        painter: MaestarLinkPainter(
                          metal: metal,
                          forged: forged ? 1 : 0,
                          faint: palette.ink,
                          angle: math.pi / 2,
                          selected: highlight > .05,
                        ),
                        child: Center(
                          child: Icon(
                            maestarIcon(capability),
                            size: 14,
                            color: forged ? engraved : palette.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('ai-model-row-${capability.name}'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: onTap,
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            metal.withValues(alpha: .16 * highlight),
                            metal.withValues(alpha: 0),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  capability.label.toUpperCase(),
                                  style: TextStyle(
                                    color: offered ? engraved : palette.muted,
                                    fontSize: 10.5,
                                    letterSpacing: 1.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  !offered
                                      ? 'Not offered'
                                      : model ?? 'Add a model',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: serif,
                                    fontSize: 19,
                                    height: 1.3,
                                    fontStyle: forged
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                    color: forged ? palette.ink : palette.muted,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  detail,
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onTap != null)
                            Icon(
                              Icons.chevron_right_rounded,
                              color: palette.muted.withValues(alpha: .7),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chain between links: small edge-on links strung down the rail.
class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.color,
    required this.first,
    required this.last,
  });
  final Color color;
  final bool first, last;

  /// Where the big link sits in the rail, matching the row's layout: a 44 by
  /// 52 box, 10 from the top, painted upright by [MaestarLinkPainter]. The
  /// rail meets the middle of its metal, so nothing shows through its hollow.
  static const _ringCenter = 10 + 52 / 2;
  static const _ringHalf = 44 * .86 / 2;
  static const ringTop = _ringCenter - _ringHalf;
  static const ringBottom = _ringCenter + _ringHalf;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final link = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: .16);

    // Links run outward from the big ring: first a bar hooked through its
    // metal, then a small ring, alternating, like a chain seen edge-on and flat.
    void run(double from, double to) {
      final direction = to > from ? 1.0 : -1.0;
      var y = from;
      var ring = false;
      while ((to - y) * direction > 2) {
        final next = (to - y).abs() < 9 ? to : y + 9 * direction;
        final top = math.min(y, next), bottom = math.max(y, next);
        if (ring) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(x - 3.5, top, x + 3.5, bottom),
              const Radius.circular(3.5),
            ),
            link,
          );
        } else {
          canvas.drawLine(Offset(x, top + 1), Offset(x, bottom - 1), link);
        }
        ring = !ring;
        y = next;
      }
    }

    if (!first) run(ringTop, 0);
    if (!last) run(ringBottom, size.height);
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.color != color || old.first != first || old.last != last;
}

/// Editing one link: the model, a pick from the provider, and its price.
class ModelEditorSheet extends StatefulWidget {
  const ModelEditorSheet({
    super.key,
    required this.capability,
    required this.controller,
    required this.priceLabel,
    required this.onPick,
    required this.onPrice,
  });

  final AiCapability capability;
  final TextEditingController controller;
  final String? Function() priceLabel;
  final Future<void> Function() onPick;
  final Future<void> Function() onPrice;

  @override
  State<ModelEditorSheet> createState() => _ModelEditorSheetState();
}

class _ModelEditorSheetState extends State<ModelEditorSheet> {
  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final capability = widget.capability;
    final metal = maestarMetal(capability);
    final serif = DiaryTypography.of(context).body.fontFamily;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final model = widget.controller.text.trim();
              final price = widget.priceLabel();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: 48,
                        child: CustomPaint(
                          painter: MaestarLinkPainter(
                            metal: metal,
                            forged: model.isEmpty ? 0 : 1,
                            faint: palette.ink,
                          ),
                          child: Center(
                            child: Icon(
                              maestarIcon(capability),
                              size: 16,
                              color: palette.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              capability.label,
                              style: TextStyle(
                                fontFamily: serif,
                                fontSize: 22,
                                color: palette.ink,
                              ),
                            ),
                            Text(
                              'The ${maestarMetalName(capability)} link',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: ValueKey('ai-model-${capability.name}'),
                    controller: widget.controller,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Model',
                      helperText: capability == AiCapability.chat
                          ? 'Required'
                          : 'Leave empty to turn this off',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: model.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              onPressed: widget.controller.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () async {
                        await widget.onPick();
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.manage_search_rounded, size: 18),
                      label: const Text('Choose from your provider'),
                    ),
                  ),
                  if (price != null) ...[
                    Divider(color: palette.rule, height: 24),
                    Row(
                      children: [
                        Icon(Icons.sell_outlined, size: 18, color: metal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            price,
                            style: TextStyle(color: palette.ink, fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await widget.onPrice();
                            if (mounted) setState(() {});
                          },
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
