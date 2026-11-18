import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../domain/watch_title.dart';
import '../../assets/presentation/local_artwork.dart';
import 'watch_host.dart';
import 'watch_wall.dart';
import 'watch_widgets.dart';

/// Titles worth spinning for: anything not yet watched or given up on.
List<WatchTitle> spinPool(List<WatchTitle> titles) {
  final open = [
    for (final t in titles)
      if (t.status != WatchStatus.completed && t.status != WatchStatus.dropped)
        t,
  ];
  return open.length > 1 ? open : titles;
}

/// The lights go down and the posters whirl past until one is left in the
/// spotlight. For a night when nothing on the wall will choose itself.
Future<void> showWatchSpin(
  BuildContext context,
  List<WatchTitle> pool, {
  math.Random? random,
}) {
  HapticFeedback.mediumImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: .93),
    transitionDuration: RenderingPolicyScope.of(context).duration * 2,
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (context, _, _) =>
        WatchSpinStage(pool: pool, random: random ?? math.Random()),
  );
}

class WatchSpinStage extends StatefulWidget {
  const WatchSpinStage({super.key, required this.pool, required this.random});

  final List<WatchTitle> pool;
  final math.Random random;

  @override
  State<WatchSpinStage> createState() => _WatchSpinStageState();
}

class _WatchSpinStageState extends State<WatchSpinStage>
    with SingleTickerProviderStateMixin {
  late final _reel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..addListener(_tick);

  int _start = 0;
  int _steps = 0;
  int _shown = 0;
  bool _landed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_steps == 0) _spin();
  }

  @override
  void dispose() {
    _reel.dispose();
    super.dispose();
  }

  void _spin() {
    final pool = widget.pool;
    // Never the one already showing, so a second spin always moves.
    var target = widget.random.nextInt(pool.length);
    if (pool.length > 1 && target == _shown) {
      target = (target + 1) % pool.length;
    }
    _start = _shown;
    final laps = pool.length < 4 ? 6 : 3;
    _steps = laps * pool.length + (target - _start) % pool.length;
    if (_steps == 0) _steps = pool.length;
    setState(() => _landed = false);
    if (!RenderingPolicyScope.of(context).animate) {
      _reel.value = 1;
      _land();
      return;
    }
    _reel.forward(from: 0).then((_) {
      if (mounted) _land();
    });
  }

  void _tick() {
    final step = (Curves.easeOutQuart.transform(_reel.value) * _steps).floor();
    final shown = (_start + step) % widget.pool.length;
    if (shown != _shown) {
      HapticFeedback.selectionClick();
      setState(() => _shown = shown);
    }
  }

  void _land() {
    final shown = (_start + _steps) % widget.pool.length;
    HapticFeedback.heavyImpact();
    setState(() {
      _shown = shown;
      _landed = true;
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      'How about ${widget.pool[shown].title}?',
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    final title = widget.pool[_shown];
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final posterWidth = math.min(size.width * .56, size.height * .3);
    final kind = title.media == WatchMedia.tv ? 'Series' : 'Film';
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          children: [
            // The spotlight.
            if (!policy.simplerEffects)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _landed ? 1 : .55,
                    duration: policy.duration * 3,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0, -.25),
                          radius: .75,
                          colors: [Color(0x40fff1c9), Color(0x00fff1c9)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    color: Colors.white70,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const ExcludeSemantics(
                              child: LocalArtwork(
                                assetKey: watchlistArtworkKey,
                                dimension: 88,
                                highResolution: true,
                              ),
                            ),
                            Expanded(
                              // Level with his mouth, the tail reaching it.
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 88 * .26,
                                ),
                                child: Transform.translate(
                                  offset: const Offset(-24, 0),
                                  child: SpeechBubble(
                                    speaker: SpeakerSide.left,
                                    text: _landed
                                        ? 'How about…'
                                        : 'Let me think…',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        AnimatedScale(
                          scale: _landed ? 1 : .92,
                          duration: policy.duration * 3,
                          curve: Curves.elasticOut,
                          child: Transform.rotate(
                            angle: _landed ? -.03 : 0,
                            child: _Frame(width: posterWidth, title: title),
                          ),
                        ),
                        const SizedBox(height: 22),
                        AnimatedOpacity(
                          opacity: _landed ? 1 : .35,
                          duration: policy.duration * 2,
                          child: Column(
                            children: [
                              Text(
                                title.title,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: wallHand(
                                  context,
                                  size: 34,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                title.year == null
                                    ? kind
                                    : '${title.year} · $kind',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _landed ? _spin : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white38,
                            side: const BorderSide(color: Colors.white38),
                            minimumSize: Size.fromHeight(56 * scale),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.casino_outlined),
                          label: const Text('Spin again'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _landed
                              ? () {
                                  final router = GoRouter.of(context);
                                  Navigator.pop(context);
                                  router.push(watchTitleLocation(title.key));
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xfffff1c9),
                            foregroundColor: const Color(0xff1d1b16),
                            disabledBackgroundColor: Colors.white12,
                            minimumSize: Size.fromHeight(56 * scale),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.local_movies_outlined),
                          label: const Text('Open it'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.width, required this.title});
  final double width;
  final WatchTitle title;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.fromLTRB(9, 9, 9, 26),
    decoration: BoxDecoration(
      color: const Color(0xfffbf8ef),
      borderRadius: BorderRadius.circular(3),
      boxShadow: const [
        BoxShadow(color: Color(0x66fff1c9), blurRadius: 40),
        BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 10)),
      ],
    ),
    child: AspectRatio(
      aspectRatio: 2 / 3,
      child: WatchPoster(
        // The wall's own size, so posters come straight from the cache.
        key: ValueKey(title.id),
        path: title.posterPath,
        media: title.media,
        size: 'w342',
        radius: 2,
      ),
    ),
  );
}
