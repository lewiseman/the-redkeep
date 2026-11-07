import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../recall/application/recall_coverage.dart';
import '../../sync/presentation/sync_material.dart';
import '../domain/ai_provider_catalog.dart';
import 'maestar_study.dart';

/// A titled leaf of the Maestar's book: an ornament, an eyebrow, a title.
class MaestarSection extends StatelessWidget {
  const MaestarSection({
    super.key,
    required this.numeral,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String numeral, eyebrow, title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final serif = DiaryTypography.of(context).body.fontFamily;
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                Text(
                  numeral,
                  style: TextStyle(
                    fontFamily: serif,
                    color: palette.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    eyebrow.toUpperCase(),
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1, color: palette.rule)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontFamily: serif,
              color: palette.ink,
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                color: palette.muted,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// A warm paper card used across Grand Maestar and the Library.
class MaestarCard extends StatelessWidget {
  const MaestarCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlight = 0,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// A brief glow, from 0 to 1, when the card is pointed to from elsewhere.
  final double highlight;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final glow = tint ?? palette.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(palette.paper, glow, .08 * highlight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color.lerp(palette.rule, glow, highlight)!,
          width: 1 + highlight,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.ink.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          if (highlight > 0)
            BoxShadow(
              color: glow.withValues(alpha: .28 * highlight),
              blurRadius: 22,
            ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class MaestarNotice extends StatelessWidget {
  const MaestarNotice({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// Providers as wax seals. Each seal shows, as small metal pips, which links
/// of the chain that provider can forge.
class ProviderSeals extends StatelessWidget {
  const ProviderSeals({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 112).floor().clamp(2, 5);
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          key: const ValueKey('ai-provider-preset'),
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final preset in aiProviderCatalog)
              SizedBox(
                width: width,
                child: _Seal(
                  preset: preset,
                  selected: preset.id == selected,
                  onTap: onSelect == null ? null : () => onSelect!(preset.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Seal extends StatelessWidget {
  const _Seal({required this.preset, required this.selected, this.onTap});
  final AiProviderPreset preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final policy = RenderingPolicyScope.of(context);
    final initial = preset.id == 'custom'
        ? '✶'
        : preset.name.characters.first.toUpperCase();
    return Semantics(
      button: true,
      selected: selected,
      label: preset.name,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('ai-provider-${preset.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: policy.duration,
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? Color.lerp(palette.paper, palette.accent, .10)
                  : palette.paper,
              border: Border.all(
                color: selected ? palette.accent : palette.rule,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                AnimatedScale(
                  duration: policy.animate
                      ? const Duration(milliseconds: 260)
                      : Duration.zero,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1.08 : 1,
                  child: SizedBox.square(
                    dimension: 46,
                    child: CustomPaint(
                      painter: _WaxSealPainter(
                        color: selected
                            ? palette.accent
                            : Color.lerp(palette.muted, palette.paper, .25)!,
                        pressed: selected,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontFamily: DiaryTypography.of(context)
                                .body
                                .fontFamily,
                            color: Colors.white.withValues(alpha: .92),
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(
                                color: Color(0x55000000),
                                offset: Offset(0, 1),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  preset.id == 'custom' ? 'Custom' : preset.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? palette.ink : palette.muted,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final capability in maestarLinks)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: preset.capabilities.contains(capability)
                              ? maestarMetal(capability)
                              : palette.rule,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A blob of wax with a stamped ring. Pressed seals sit a little deeper.
class _WaxSealPainter extends CustomPainter {
  const _WaxSealPainter({required this.color, required this.pressed});
  final Color color;
  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final blob = Path();
    const lobes = 11;
    for (var i = 0; i <= 60; i++) {
      final a = i / 60 * math.pi * 2;
      final rr = r * (.92 + .07 * math.sin(a * lobes) + .02 * math.cos(a * 3));
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? blob.moveTo(p.dx, p.dy) : blob.lineTo(p.dx, p.dy);
    }
    blob.close();
    canvas.drawShadow(blob, Colors.black, pressed ? 3 : 1.5, false);
    final hsl = HSLColor.fromColor(color);
    canvas.drawPath(
      blob,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.4),
          colors: [
            hsl.withLightness((hsl.lightness + .14).clamp(0, 1)).toColor(),
            color,
            hsl.withLightness((hsl.lightness - .16).clamp(0, 1)).toColor(),
          ],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * .66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.black.withValues(alpha: .18),
    );
    canvas.drawCircle(
      c.translate(0, .8),
      r * .66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .18),
    );
  }

  @override
  bool shouldRepaint(_WaxSealPainter old) =>
      old.color != color || old.pressed != pressed;
}

/// This month's spending as a coin purse gauge: a gilt arc filling toward the
/// limit, turning to red as it nears it.
class PurseGauge extends StatelessWidget {
  const PurseGauge({super.key, required this.spent, required this.limit});
  final double spent, limit;

  static String money(double value) =>
      '\$${value.toStringAsFixed(value < 1 && value > 0 ? 4 : 2)}';

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final share = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final serif = DiaryTypography.of(context).body.fontFamily;
    final animate = RenderingPolicyScope.of(context).animate;
    return Semantics(
      label: limit <= 0
          ? 'About ${money(spent)} used this month. No monthly limit.'
          : 'About ${money(spent)} used of ${money(limit)} this month.',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: share),
        duration: animate ? const Duration(milliseconds: 1100) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => AspectRatio(
          aspectRatio: 2.1,
          child: CustomPaint(
            painter: _PursePainter(
              share: value,
              track: palette.rule,
              fill: Color.lerp(
                const Color(0xFFD4A84B),
                colors.error,
                ((value - .7) / .3).clamp(0.0, 1.0),
              )!,
              limited: limit > 0,
            ),
            child: Align(
              alignment: const Alignment(0, .7),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      money(spent),
                      style: TextStyle(
                        fontFamily: serif,
                        fontSize: 30,
                        color: palette.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      limit <= 0
                          ? 'this month · no limit'
                          : 'of ${money(limit)} this month',
                      style: TextStyle(color: palette.muted, fontSize: 12.5),
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

class _PursePainter extends CustomPainter {
  const _PursePainter({
    required this.share,
    required this.track,
    required this.fill,
    required this.limited,
  });
  final double share;
  final Color track, fill;
  final bool limited;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 12.0;
    final r = math.min(size.width / 2, size.height) - stroke;
    final c = Offset(size.width / 2, size.height - stroke / 2);
    final arc = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      arc,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = track,
    );
    // Ticks like coins along the rim.
    final tick = Paint()
      ..color = track
      ..strokeWidth = 1.2;
    for (var i = 0; i <= 10; i++) {
      final a = math.pi + i / 10 * math.pi;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + d * (r - stroke - 2),
        c + d * (r - stroke - (i % 5 == 0 ? 10 : 5)),
        tick,
      );
    }
    if (!limited || share <= 0) return;
    final hsl = HSLColor.fromColor(fill);
    canvas.drawArc(
      arc,
      math.pi,
      math.pi * share,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: math.pi,
          endAngle: math.pi * 2,
          colors: [
            hsl.withLightness((hsl.lightness - .1).clamp(0, 1)).toColor(),
            fill,
            hsl.withLightness((hsl.lightness + .15).clamp(0, 1)).toColor(),
          ],
        ).createShader(arc),
    );
    final end = math.pi + math.pi * share;
    final coin = c + Offset(math.cos(end), math.sin(end)) * r;
    canvas.drawCircle(coin, stroke * .8, Paint()..color = fill);
    canvas.drawCircle(
      coin,
      stroke * .5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: .6),
    );
  }

  @override
  bool shouldRepaint(_PursePainter old) =>
      old.share != share ||
      old.fill != fill ||
      old.track != track ||
      old.limited != limited;
}

/// The way into the Library, where search by meaning is kept.
class LibraryDoorCard extends ConsumerWidget {
  const LibraryDoorCard({super.key, required this.onOpen, required this.ready});
  final VoidCallback onOpen;

  /// Whether the provider has an embedding model.
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final coverage = ref.watch(recallCoverageProvider).value ?? const {};
    final saved = coverage.values.fold(0, (a, c) => a + c.saved);
    final indexed = coverage.values.fold(0, (a, c) => a + c.indexed);
    final serif = DiaryTypography.of(context).body.fontFamily;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('maestar-library-door'),
          borderRadius: BorderRadius.circular(22),
          onTap: onOpen,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF141A3C), Color(0xFF2B2858)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF141A3C).withValues(alpha: .25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: CustomPaint(
                        painter: _DoorStarsPainter(
                          lit: saved == 0 ? (ready ? 1 : 0) : indexed / saved,
                          accent: palette.accent,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THE LIBRARY',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .6),
                                fontSize: 11,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Search by meaning',
                              style: TextStyle(
                                fontFamily: serif,
                                color: Colors.white,
                                fontSize: 21,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              !ready
                                  ? 'Needs an embedding model. Keyword search still works.'
                                  : saved == 0
                                  ? 'Nothing written yet. The index fills as you write.'
                                  : '$indexed of $saved pieces of writing indexed',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .75),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white.withValues(alpha: .85),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoorStarsPainter extends CustomPainter {
  const _DoorStarsPainter({required this.lit, required this.accent});
  final double lit;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(31);
    const count = 38;
    final points = <Offset>[];
    for (var i = 0; i < count; i++) {
      final p = Offset(
        size.width * (.45 + rng.nextDouble() * .55),
        size.height * rng.nextDouble(),
      );
      points.add(p);
      final on = i < (count * lit).round();
      canvas.drawCircle(
        p,
        on ? 1.4 + rng.nextDouble() : .9,
        Paint()
          ..color = (on ? Color.lerp(Colors.white, accent, .25)! : Colors.white)
              .withValues(alpha: on ? .9 : .18),
      );
    }
    final thread = Paint()
      ..strokeWidth = .7
      ..color = Colors.white.withValues(alpha: .14);
    final shown = (count * lit).round();
    for (var i = 1; i < math.min(shown, 12); i++) {
      canvas.drawLine(points[i - 1], points[i], thread);
    }
  }

  @override
  bool shouldRepaint(_DoorStarsPainter old) =>
      old.lit != lit || old.accent != accent;
}

class ModelPicker extends StatefulWidget {
  const ModelPicker({super.key, required this.models, required this.title});
  final List<String> models;
  final String title;
  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<ModelPicker> {
  String _filter = '';
  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final model in widget.models)
        if (model.toLowerCase().contains(_filter.toLowerCase())) model,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Find a model',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _filter = value.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '${shown.length} of ${widget.models.length} models',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(shown[i]),
                onTap: () => Navigator.pop(context, shown[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
