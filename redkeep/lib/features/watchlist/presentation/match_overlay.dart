import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../ai/application/ai_cloud.dart';
import '../../ai/domain/ai_provider.dart';
import '../application/discover_controller.dart';
import '../domain/catalog_title.dart';
import '../domain/dating_profile.dart';
import '../domain/recommender/taste.dart';
import 'dating_widgets.dart';
import 'watch_widgets.dart';

/// What the reader did on the match screen.
sealed class MatchChoice {
  const MatchChoice();
}

class MatchSendMessage extends MatchChoice {
  const MatchSendMessage(this.text);
  final String text;
}

class MatchPlanNight extends MatchChoice {
  const MatchPlanNight();
}

class MatchKeepSwiping extends MatchChoice {
  const MatchKeepSwiping();
}

/// "It's a Match": the title and the reader's type slide apart like two
/// photos on a table. Still, with reduced motion.
Future<MatchChoice?> showWatchMatch(
  BuildContext context,
  WidgetRef ref, {
  required CatalogTitle title,
  CatalogTitle? yourType,
}) {
  final animate = RenderingPolicyScope.of(context).animate;
  final profile = ref.read(watchProfileProvider).value ?? WatchProfile();
  final chat = ref.read(aiCapabilitiesProvider).contains(AiCapability.chat);
  return showGeneralDialog<MatchChoice>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'It’s a match',
    transitionDuration: animate
        ? const Duration(milliseconds: 300)
        : Duration.zero,
    pageBuilder: (_, _, _) => WatchMatchScreen(
      title: title,
      yourType: yourType,
      icebreaker: DatingProfile.icebreaker(title, profile),
      canChat: chat,
      animate: animate,
    ),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class WatchMatchScreen extends StatefulWidget {
  const WatchMatchScreen({
    super.key,
    required this.title,
    required this.icebreaker,
    required this.canChat,
    required this.animate,
    this.yourType,
  });

  final CatalogTitle title;
  final CatalogTitle? yourType;
  final String icebreaker;
  final bool canChat;
  final bool animate;

  @override
  State<WatchMatchScreen> createState() => _WatchMatchScreenState();
}

class _WatchMatchScreenState extends State<WatchMatchScreen>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: widget.animate ? 0 : 1,
  );
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.animate) _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _text.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    Navigator.pop(context, MatchSendMessage(text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.title;
    final large = MediaQuery.textScalerOf(context).scale(14) > 24;
    final heading = WatchBrand.serif.copyWith(
      color: WatchBrand.rose,
      fontSize: large ? 44 : 60,
      height: .95,
    );
    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    return Material(
      color: WatchBrand.wine,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Keep swiping',
                  onPressed: () =>
                      Navigator.pop(context, const MatchKeepSwiping()),
                  style: IconButton.styleFrom(backgroundColor: Colors.white12),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Expanded(
                flex: large ? 2 : 3,
                child: Semantics(
                  label: 'It’s a match with ${t.title}',
                  child: ExcludeSemantics(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final cardW = math.min(
                          math.min(box.maxWidth * .42, box.maxHeight * .45),
                          170.0,
                        );
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Text(
                                'It’s a',
                                textAlign: TextAlign.center,
                                style: heading,
                              ),
                            ),
                            Center(
                              child: AnimatedBuilder(
                                animation: curve,
                                builder: (_, _) => Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(
                                        -cardW * .42 * curve.value,
                                        -20,
                                      ),
                                      child: Transform.rotate(
                                        angle: -.14 * curve.value,
                                        child: _Polaroid(
                                          width: cardW,
                                          title: widget.yourType,
                                          label: widget.yourType == null
                                              ? 'You'
                                              : 'Your type',
                                        ),
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: Offset(
                                        cardW * .42 * curve.value,
                                        30,
                                      ),
                                      child: Transform.rotate(
                                        angle: .12 * curve.value,
                                        child: _Polaroid(
                                          width: cardW,
                                          title: t,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Text(
                                'Match',
                                textAlign: TextAlign.center,
                                style: heading.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Flexible(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'You matched with ${t.title}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.icebreaker,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      if (widget.canChat) ...[
                        TextField(
                          controller: _text,
                          style: const TextStyle(color: Colors.white),
                          textInputAction: TextInputAction.send,
                          onSubmitted: _send,
                          decoration: InputDecoration(
                            hintText: 'Say something nice',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Send',
                              onPressed: () => _send(_text.text),
                              icon: const Icon(Icons.send, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final e in ['👋', '😉', '❤️', '😍', '🍿'])
                              Semantics(
                                button: true,
                                label: 'Send $e',
                                excludeSemantics: true,
                                child: InkResponse(
                                  onTap: () => _send(e),
                                  child: Container(
                                    width: 52,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () =>
                              Navigator.pop(context, const MatchPlanNight()),
                          icon: const Icon(Icons.event, color: Colors.white),
                          label: const Text(
                            'Plan a night instead',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ] else
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: WatchBrand.rose,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () =>
                              Navigator.pop(context, const MatchPlanNight()),
                          icon: const Icon(Icons.event),
                          label: const Text('Plan a night'),
                        ),
                    ],
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

class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.width, this.title, this.label});
  final double width;
  final CatalogTitle? title;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = title;
    return Container(
      width: width,
      height: width * 1.4,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black45)],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: t == null
                ? const ColoredBox(
                    color: WatchBrand.rose,
                    child: Icon(Icons.person, color: Colors.white, size: 64),
                  )
                : WatchPoster(path: t.posterPath, radius: 0, media: t.media),
          ),
          if (label != null)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label!,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
