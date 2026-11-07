import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../ai/application/ai_cloud.dart';
import '../../ai/application/ai_preferences.dart';
import '../../ai/domain/ai_provider.dart';
import '../../ai/presentation/maestar_parts.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/recall_controller.dart';
import '../application/recall_coverage.dart';
import 'recall_sky.dart';

/// The Library: search by meaning, which kinds of writing it covers, and the
/// index kept on this phone.
class RecallLibraryPage extends ConsumerStatefulWidget {
  const RecallLibraryPage({super.key});

  @override
  ConsumerState<RecallLibraryPage> createState() => _RecallLibraryPageState();
}

class _RecallLibraryPageState extends ConsumerState<RecallLibraryPage>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final _shelfKeys = {for (final kind in recallKinds) kind: GlobalKey()};
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  String? _pointed;

  @override
  void dispose() {
    _scroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _change(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this preference. Retry.'),
          ),
        );
      }
    }
  }

  void _showShelf(String kind) {
    final policy = RenderingPolicyScope.of(context);
    setState(() => _pointed = kind);
    final shelf = _shelfKeys[kind]!.currentContext;
    if (shelf != null) {
      unawaited(
        Scrollable.ensureVisible(
          shelf,
          alignment: .4,
          duration: policy.animate
              ? const Duration(milliseconds: 650)
              : Duration.zero,
          curve: Curves.easeInOutCubic,
        ),
      );
    }
    if (policy.animate) _pulse.forward(from: 0);
  }

  Future<void> _rebuild() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rebuild the search index?'),
        content: const Text(
          'The index on this phone is cleared and all your writing is sent to your provider again to be indexed. This uses some of your monthly spending.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rebuild'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _change(ref.read(recallControllerProvider.notifier).rebuild);
    }
  }

  void _toMaestar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/brain');
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(aiPreferencesProvider).value;
    final index = ref.watch(recallControllerProvider);
    final controller = ref.read(recallControllerProvider.notifier);
    final coverage = ref.watch(recallCoverageProvider).value ?? const {};
    final embeddings = ref
        .watch(aiCapabilitiesProvider)
        .contains(AiCapability.embeddings);
    final enabled = prefs?.collections ?? recallKinds.toSet();
    final paused = prefs?.paused == true;
    final palette = MorePalette.of(context);
    final policy = RenderingPolicyScope.of(context);
    final media = MediaQuery.of(context);
    final typography = DiaryTypography.of(context);
    final skyHeight =
        (media.size.height < 700 ? 280.0 : 340.0) + media.padding.top;

    var saved = 0, indexed = 0, waiting = 0;
    for (final kind in enabled) {
      final c = coverage[kind] ?? const RecallCoverage();
      saved += c.saved;
      indexed += c.indexed;
      waiting += c.waiting;
    }

    final (stateIcon, stateText) = !embeddings
        ? (Icons.nights_stay_outlined, 'Keyword search only')
        : paused
        ? (Icons.pause_circle_outline_rounded, 'Indexing is paused')
        : index.running
        ? (
            Icons.auto_awesome_rounded,
            index.total == 0
                ? 'Indexing…'
                : 'Indexing ${index.done} of ${index.total}…',
          )
        : enabled.isEmpty
        ? (Icons.do_not_disturb_on_outlined, 'No writing is included')
        : waiting > 0
        ? (
            Icons.hourglass_bottom_rounded,
            '$waiting waiting for a quiet moment',
          )
        : (Icons.check_circle_outline_rounded, 'Up to date');

    final content = <Widget>[
      Text(
        'The Library',
        textAlign: TextAlign.center,
        style: typography.title.copyWith(color: palette.ink, fontSize: 40),
      ),
      const SizedBox(height: 4),
      Text(
        'Find writing by what it means, not only the words it uses.',
        textAlign: TextAlign.center,
        style: TextStyle(color: palette.muted, fontSize: 14, height: 1.5),
      ),
      const SizedBox(height: 20),
      if (!embeddings)
        MaestarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.nights_stay_outlined, color: palette.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your provider has no embedding model, so search uses keywords only. Add a search index model in Grand Maestar to light the sky.',
                      style: TextStyle(color: palette.ink, height: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _toMaestar,
                  child: const Text('Open Grand Maestar'),
                ),
              ),
            ],
          ),
        )
      else
        MaestarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: 84,
                    child: _CoverageRing(
                      share: saved == 0 ? 1 : indexed / saved,
                      animate: policy.animate,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          saved == 0 ? 'Nothing yet' : '$indexed of $saved',
                          style: TextStyle(
                            fontFamily: typography.body.fontFamily,
                            color: palette.ink,
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          saved == 0
                              ? 'The index fills as you write.'
                              : 'pieces of writing indexed',
                          style: TextStyle(color: palette.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Icon(stateIcon, size: 18, color: palette.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stateText,
                        style: TextStyle(
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (index.running) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: index.total == 0 ? null : index.done / index.total,
                  ),
                ),
              ],
              if (index.message != null) ...[
                const SizedBox(height: 10),
                Text(
                  index.message!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),

      MaestarSection(
        numeral: 'I',
        eyebrow: 'The shelves',
        title: 'What the index covers',
        subtitle: 'Touch a constellation above to find its shelf.',
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final glow = policy.animate
                ? Curves.easeOut.transform(1 - (2 * _pulse.value - 1).abs())
                : .6;
            return Column(
              children: [
                for (final kind in recallKinds)
                  Padding(
                    key: _shelfKeys[kind],
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Shelf(
                      kind: kind,
                      coverage: coverage[kind] ?? const RecallCoverage(),
                      on: enabled.contains(kind),
                      highlight: _pointed == kind ? glow : 0,
                      onChanged: prefs == null
                          ? null
                          : (v) =>
                                _change(() => controller.setEnabled(kind, v)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),

      MaestarSection(
        numeral: 'II',
        eyebrow: 'The lamp',
        title: 'Tend the index',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: index.running || !embeddings
                  ? null
                  : () => _change(controller.run),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Index now'),
            ),
            OutlinedButton.icon(
              onPressed: prefs == null
                  ? null
                  : () => _change(() => controller.pause(!paused)),
              icon: Icon(
                paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 18,
              ),
              label: Text(paused ? 'Resume indexing' : 'Pause indexing'),
            ),
            TextButton.icon(
              onPressed: index.running || !embeddings ? null : _rebuild,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Rebuild search index'),
            ),
          ],
        ),
      ),

      const MaestarSection(
        numeral: 'III',
        eyebrow: 'The craft',
        title: 'How it works',
        child: _Path(),
      ),
    ];

    return Scaffold(
      backgroundColor: palette.ground,
      body: CustomScrollView(
        key: const ValueKey('recall-library'),
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: skyHeight,
            backgroundColor: const Color(0xFF0A0F2C),
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final min = media.padding.top + kToolbarHeight;
                final collapse =
                    (1 - (constraints.maxHeight - min) / (skyHeight - min))
                        .clamp(0.0, 1.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Semantics(
                      label: saved == 0
                          ? 'Night sky. No writing yet.'
                          : 'Night sky of your writing. $indexed of $saved pieces indexed.',
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: RecallSky(
                          coverage: coverage,
                          enabled: enabled,
                          running: index.running,
                          dormant: !embeddings,
                          onConstellation: _showShelf,
                          collapse: collapse,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 56,
                      right: 56,
                      top: media.padding.top,
                      height: kToolbarHeight,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: ((collapse - .6) / .4).clamp(0.0, 1.0),
                          child: Center(
                            child: Text(
                              'Search by meaning',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: MoreSurface.contentWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.kind,
    required this.coverage,
    required this.on,
    required this.highlight,
    required this.onChanged,
  });

  final String kind;
  final RecallCoverage coverage;
  final bool on;
  final double highlight;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final star = recallStarColor(kind);
    final ink = Color.lerp(star, palette.ink, .45)!;
    final animate = RenderingPolicyScope.of(context).animate;
    return MaestarCard(
      tint: star,
      highlight: highlight,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: star.withValues(alpha: on ? .28 : .1),
            ),
            child: Icon(
              recallKindIcon(kind),
              size: 20,
              color: on ? ink : palette.muted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recallKindLabel(kind),
                  style: TextStyle(
                    color: on ? palette.ink : palette.muted,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  !on
                      ? 'Not in the index'
                      : coverage.saved == 0
                      ? 'Nothing saved yet'
                      : '${coverage.indexed} of ${coverage.saved} saved sources indexed',
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: on ? coverage.fraction : 0),
                  duration: animate
                      ? const Duration(milliseconds: 900)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: value,
                      color: Color.lerp(star, palette.ink, .25),
                      backgroundColor: palette.rule,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Switch(
            key: ValueKey('recall-$kind'),
            value: on,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CoverageRing extends StatelessWidget {
  const _CoverageRing({required this.share, required this.animate});
  final double share;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: share),
      duration: animate ? const Duration(milliseconds: 1200) : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        painter: _RingPainter(
          share: value,
          track: palette.rule,
          colors: [for (final kind in recallKinds) recallStarColor(kind)],
          ink: palette.accent,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.share,
    required this.track,
    required this.colors,
    required this.ink,
  });
  final double share;
  final Color track, ink;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 1);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (share <= 0) return;
    final shaded = [for (final c in colors) Color.lerp(c, ink, .35)!];
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * share,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          transform: const GradientRotation(-math.pi / 2),
          colors: [...shaded, shaded.first],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.share != share || old.track != track || old.ink != ink;
}

/// The life of one piece of writing on its way into the index.
class _Path extends StatelessWidget {
  const _Path();

  static const _steps = [
    (
      Icons.edit_outlined,
      'You write',
      'Notes, diary entries and Flow thoughts you choose above.',
    ),
    (
      Icons.hourglass_bottom_rounded,
      'A quiet moment',
      'About 45 seconds after you stop writing, or soon after you leave an editor, saved text is sent to your provider in batches.',
    ),
    (
      Icons.auto_awesome_rounded,
      'Meaning comes back',
      'Your provider returns vectors that capture what the writing is about. They stay on this phone.',
    ),
    (
      Icons.search_rounded,
      'You search',
      'Searches by meaning run when you press search, alongside keywords.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Column(
      children: [
        for (final (i, (icon, title, body)) in _steps.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.paper,
                          border: Border.all(color: palette.accent, width: 1.4),
                        ),
                        child: Icon(icon, size: 17, color: palette.accent),
                      ),
                      if (i < _steps.length - 1)
                        Expanded(
                          child: CustomPaint(
                            size: const Size(2, double.infinity),
                            painter: _DottedLine(palette.accent),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 6,
                      bottom: i < _steps.length - 1 ? 22 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: palette.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DottedLine extends CustomPainter {
  const _DottedLine(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = color.withValues(alpha: .45);
    for (var y = 6.0; y < size.height - 2; y += 7) {
      canvas.drawCircle(Offset(size.width / 2, y), 1.2, dot);
    }
  }

  @override
  bool shouldRepaint(_DottedLine old) => old.color != color;
}
