import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../domain/ai_provider.dart';
import 'maestar_study.dart';
import 'settings_parts.dart';

/// One skill hung on the chain: its metal link on a rail running down the
/// left, the model in serif, and its state in a quiet line beneath.
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

  /// A short line under the model: forged, or why the link is off.
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

/// Whether a model's name suggests it can do this skill. Providers list
/// everything they serve; most of it cannot write, or cannot listen.
bool modelFitsSkill(AiCapability capability, String model) {
  final name = model.toLowerCase();
  bool has(List<String> words) => words.any(name.contains);
  return switch (capability) {
    AiCapability.transcription => has(const ['transcribe', 'whisper']),
    _ => !has(const [
      'embedding',
      'tts',
      'whisper',
      'transcribe',
      'dall-e',
      'image',
      'moderation',
      'audio',
      'realtime',
      'search',
      'davinci',
      'babbage',
      'sora',
    ]),
  };
}

/// Choosing one link's model, on a sheet of paper. It asks the provider
/// for its models as it opens; a search line narrows them or names one the
/// list lacks. Choosing saves at once and closes.
class ModelSheet extends StatefulWidget {
  const ModelSheet({
    super.key,
    required this.capability,
    required this.current,
    required this.providerName,
    required this.load,
    required this.onChoose,
  });

  final AiCapability capability;
  final String? current;
  final String providerName;

  /// The provider's models; throws [AiProviderFailure] when it cannot say.
  final Future<List<String>> Function() load;

  /// Saves the choice, or none; returns a message when it could not.
  final Future<String?> Function(String? model) onChoose;

  @override
  State<ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<ModelSheet> {
  /// Asked once the sheet is up: asking updates the page behind it, which
  /// cannot happen while the sheet is still being built.
  late final Future<List<String>> _models = Future(widget.load);
  final _search = TextEditingController();
  String? _saving;
  String? _error;
  bool _all = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(String? model) async {
    HapticFeedback.selectionClick();
    setState(() {
      _saving = model ?? '';
      _error = null;
    });
    final error = await widget.onChoose(model);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = null;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final metal = maestarMetal(widget.capability);
    final engraved = Color.lerp(metal, palette.ink, .4)!;
    final optional = widget.capability != AiCapability.chat;
    final query = _search.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 56,
                child: CustomPaint(
                  painter: MaestarLinkPainter(
                    metal: metal,
                    forged: widget.current == null ? 0 : 1,
                    faint: palette.ink,
                    angle: math.pi / 2,
                  ),
                  child: Center(
                    child: Icon(
                      maestarIcon(widget.capability),
                      size: 15,
                      color: engraved,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        widget.capability.label,
                        style: settingsHand(context, size: 32),
                      ),
                    ),
                    Text(
                      'The ${maestarMetalName(widget.capability)} link',
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: InkedField(
            fieldKey: const ValueKey('ai-model-search'),
            label: 'Search or name a model',
            controller: _search,
            hint: widget.current ?? 'gpt-…',
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) _choose(value.trim());
            },
          ),
        ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              error,
              style: TextStyle(color: colors.error, fontSize: 13),
            ),
          ),
        Flexible(
          child: FutureBuilder<List<String>>(
            future: _models,
            builder: (context, snapshot) {
              final all = snapshot.data ?? const <String>[];
              final current = widget.current;
              final fitting = [
                for (final m in all)
                  if (modelFitsSkill(widget.capability, m)) m,
              ];
              // Searching looks through everything; otherwise the fitting
              // ones, unless the reader asks for the rest.
              final pool = query.isNotEmpty || _all ? all : fitting;
              final shown = [
                if (current != null && query.isEmpty) current,
                for (final m in pool)
                  if (m != current &&
                      (query.isEmpty ||
                          m.toLowerCase().contains(query.toLowerCase())))
                    m,
              ];
              final hidden = all.length - fitting.length;
              final named = query.isNotEmpty && !all.contains(query);
              final rows = <Widget>[
                if (optional && query.isEmpty)
                  _ModelLine(
                    label: 'Leave it off',
                    note: 'This skill stays quiet',
                    chosen: widget.current == null,
                    saving: _saving == '',
                    onTap: _saving == null ? () => _choose(null) : null,
                  ),
                if (named)
                  _ModelLine(
                    label: 'Use “$query”',
                    note: 'Named by you',
                    chosen: false,
                    saving: _saving == query,
                    onTap: _saving == null ? () => _choose(query) : null,
                  ),
                for (final m in shown)
                  _ModelLine(
                    key: ValueKey('ai-model-option-$m'),
                    label: m,
                    note: m == current ? 'In use' : null,
                    chosen: m == current,
                    saving: _saving == m,
                    onTap: _saving == null ? () => _choose(m) : null,
                  ),
                if (query.isEmpty && !_all && hidden > 0)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _all = true),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.muted,
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text(
                        hidden == 1
                            ? 'Show 1 more model'
                            : 'Show $hidden more models',
                      ),
                    ),
                  ),
              ];
              final waiting = snapshot.connectionState != ConnectionState.done;
              final failure = snapshot.error;
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  if (waiting)
                    _Aside(
                      'Asking ${widget.providerName} for its models…',
                      busy: true,
                    )
                  else if (failure != null)
                    _Aside(
                      failure is AiProviderFailure
                          ? '${failure.message} You can still name a model above.'
                          : 'Could not list models. You can still name one above.',
                    )
                  else if (all.isEmpty)
                    const _Aside('No models listed. Name one above.'),
                  ...rows,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Aside extends StatelessWidget {
  const _Aside(this.text, {this.busy = false});
  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          if (busy) ...[
            SizedBox.square(
              dimension: 14,
              child: RenderingPolicyScope.of(context).animate
                  ? CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: palette.accent,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: palette.muted, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// One model to choose: a glass pip that fills when it is the one.
class _ModelLine extends StatelessWidget {
  const _ModelLine({
    super.key,
    required this.label,
    required this.chosen,
    required this.saving,
    required this.onTap,
    this.note,
  });

  final String label;
  final String? note;
  final bool chosen, saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final cushion = CushionColors.of(context);
    final note = this.note;
    return Semantics(
      button: true,
      selected: chosen,
      label: [label, ?note].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Springy(
          depth: .02,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: chosen ? palette.accent.withValues(alpha: .08) : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CustomPaint(
                  size: const Size.square(20),
                  painter: _RadioPainter(cushion, chosen || saving),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 15.5,
                          fontWeight: chosen
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      if (note != null)
                        Text(
                          note,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
                if (saving)
                  SizedBox.square(
                    dimension: 16,
                    child: RenderingPolicyScope.of(context).animate
                        ? CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: palette.accent,
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioPainter extends CustomPainter {
  const _RadioPainter(this.colors, this.on);
  final CushionColors colors;
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final drop = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width / 2),
    );
    if (!on) {
      paintDimple(canvas, drop, colors);
      return;
    }
    paintGlass(
      canvas,
      drop,
      colors: colors,
      tint: colors.tint,
      fill: .9,
      lift: .6,
    );
  }

  @override
  bool shouldRepaint(_RadioPainter old) => old.colors != colors || old.on != on;
}
