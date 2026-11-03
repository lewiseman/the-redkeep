import 'dart:math' as math;

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/confirm_discard_changes.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../application/flow_editor_controller.dart';
import '../application/flow_providers.dart';
import '../domain/thought.dart';
import 'flow_composer.dart';
import 'flow_opening.dart';
import 'flow_thought_card.dart';

class FlowPage extends ConsumerStatefulWidget {
  const FlowPage({super.key});

  @override
  ConsumerState<FlowPage> createState() => _FlowPageState();
}

class _FlowPageState extends ConsumerState<FlowPage> {
  final _scroll = ScrollController();
  final _draft = TextEditingController();
  final _focus = FocusNode();
  final _composerKey = GlobalKey();
  double _composerHeight = 56;
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    _measureComposer();
  }

  void _focusChanged() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) _focus.unfocus();
  }

  void _measureComposer() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      final box = _composerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null &&
          box.hasSize &&
          (box.size.height - _composerHeight).abs() > .5) {
        setState(() => _composerHeight = box.size.height);
      }
    });
  }

  Future<void> _send() async {
    final editor = ref.read(flowEditorProvider(null)).value;
    if (editor == null || editor.saving || editor.body.trim().isEmpty) return;
    final saved = await ref.read(flowEditorProvider(null).notifier).save();
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Couldn’t save your thought. Your draft is still here.',
          ),
          action: SnackBarAction(label: 'Retry', onPressed: _send),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _focus.unfocus();
    if (_scroll.hasClients) {
      if (!RenderingPolicyScope.of(context).animate) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _openThought(ThoughtListing thought) {
    _focus.unfocus();
    context.go(thoughtLocation(thought.id));
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thoughts = ref.watch(thoughtsProvider);
    final editor = ref.watch(flowEditorProvider(null));
    final body = editor.value?.body;
    if (body != null && body != _draft.text) {
      _draft.value = TextEditingValue(
        text: body,
        selection: TextSelection.collapsed(offset: body.length),
      );
    }
    final saved = thoughts.asData?.value ?? const <ThoughtListing>[];
    final policy = RenderingPolicyScope.of(context);
    final reduced = policy.reducedMotion;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final tabActive = TickerMode.valuesOf(context).enabled && policy.active;
    final colors = Theme.of(context).colorScheme;
    final paper = colors.brightness == Brightness.dark
        ? const Color(0xff33312c)
        : const Color(0xfff4f0e8);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          gradient: policy.simplerEffects
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(colors.surface, paper, .55)!,
                    colors.surface,
                  ],
                ),
        ),
        child: SafeArea(
          bottom: true,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = FlowSceneLayout(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    textScale: MediaQuery.textScalerOf(context).scale(16) / 16,
                    composerHeight: _composerHeight,
                    thoughtCount: saved.length,
                  );
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      _history(layout, reduced, saved, thoughts),
                      AnimatedBuilder(
                        animation: _scroll,
                        builder: (context, _) => _floatingScene(
                          layout,
                          reduced: reduced,
                          keyboard: keyboard,
                          tabActive: tabActive,
                          editor: editor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _history(
    FlowSceneLayout layout,
    bool reduced,
    List<ThoughtListing> thoughts,
    AsyncValue<List<ThoughtListing>> state,
  ) => CustomScrollView(
    key: const PageStorageKey('flow-history'),
    controller: _scroll,
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    slivers: [
      SliverPersistentHeader(
        delegate: FlowOpening(
          layout: layout,
          thoughts: thoughts.take(layout.previewCount).toList(),
          onOpen: _openThought,
          reduced: reduced,
          status: state.when(
            data: (_) => const Text(
              'A little space for what’s on your mind.\nWrite your first thought below.',
              textAlign: TextAlign.center,
            ),
            loading: () => const Text(
              'Loading your thoughts…',
              textAlign: TextAlign.center,
            ),
            error: (_, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Couldn’t load your thoughts.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => ref.invalidate(thoughtsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: FlowSceneLayout.gutter),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: layout.columns,
          mainAxisSpacing: FlowSceneLayout.gap,
          crossAxisSpacing: FlowSceneLayout.gap,
          childCount: thoughts.length - layout.previewCount,
          itemBuilder: (context, index) {
            final thought = thoughts[index + layout.previewCount];
            return SizedBox(
              height:
                  [184.0, 150.0, 172.0, 206.0][index % 4] * layout.cardScale,
              child: FlowThoughtCard(
                key: ValueKey('flow-thought-${thought.id}'),
                thought: thought,
                onTap: () => _openThought(thought),
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Text(
            'Every little thought has a place.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _floatingScene(
    FlowSceneLayout layout, {
    required bool reduced,
    required bool keyboard,
    required bool tabActive,
    required AsyncValue<FlowEditorState> editor,
  }) {
    final offset = _scroll.hasClients ? math.max(0.0, _scroll.offset) : 0.0;
    final progress = layout.progress(offset, reduced: reduced);
    final overlap = layout.composerOverlap(offset, progress);
    final visibility = _focus.hasFocus
        ? 1.0
        : (1 - overlap / math.max(80, _composerHeight * .7)).clamp(0.0, 1.0);
    final mascotVisibility = keyboard
        ? 0.0
        : (1 - progress * 2).clamp(0.0, 1.0);
    final mascotSpace = math.max(
      0.0,
      layout.composerTop - layout.previewBottom - 22,
    );
    final lift = _focus.hasFocus ? 0.0 : math.min(overlap * .45, 64.0);
    return Stack(
      children: [
        Positioned(
          top: layout.previewBottom + 8 - offset * .12,
          height: mascotSpace,
          left: 24,
          right: 24,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: mascotVisibility,
                child: _FlowMascot(
                  showCaption: mascotSpace > 175 && layout.textScale < 1.5,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: FlowSceneLayout.bottom,
          child: Transform.translate(
            offset: Offset(0, -lift),
            child: IgnorePointer(
              ignoring: visibility < .05 || !tabActive,
              child: ExcludeSemantics(
                excluding: visibility < .05 || !tabActive,
                child: ExcludeFocus(
                  excluding: visibility < .05 || !tabActive,
                  child: Opacity(
                    opacity: visibility,
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 600,
                          maxHeight: math.max(
                            0,
                            layout.height - FlowSceneLayout.bottom - 12,
                          ),
                        ),
                        child:
                            NotificationListener<SizeChangedLayoutNotification>(
                              onNotification: (_) {
                                _measureComposer();
                                return true;
                              },
                              child: SizeChangedLayoutNotifier(
                                child: SingleChildScrollView(
                                  key: _composerKey,
                                  primary: false,
                                  reverse: true,
                                  child: _composer(editor),
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _composer(AsyncValue<FlowEditorState> editor) {
    return editor.when(
      loading: () => const Text('Opening writing…'),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(flowEditorProvider(null)),
        child: const Text('Composer could not be opened. Retry.'),
      ),
      data: (state) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowComposer(
            controller: _draft,
            focusNode: _focus,
            onSend: _send,
            onChanged: ref.read(flowEditorProvider(null).notifier).edit,
            enabled: !state.saving,
            saving: state.saving,
          ),
          if (state.sourceUnavailable) ...[
            Semantics(
              liveRegion: true,
              child: Text(state.message ?? 'Save a copy to keep this writing.'),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: state.saving
                      ? null
                      : () async {
                          final id = await ref
                              .read(flowEditorProvider(null).notifier)
                              .saveCopy();
                          if (mounted && id != null) {
                            context.go(thoughtLocation(id));
                          }
                        },
                  child: const Text('Save a copy'),
                ),
                TextButton(
                  onPressed: state.saving
                      ? null
                      : () async {
                          if (await confirmDiscardChanges(context) && mounted) {
                            await ref
                                .read(flowEditorProvider(null).notifier)
                                .discard();
                          }
                        },
                  child: const Text('Discard changes'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FlowMascot extends StatelessWidget {
  const _FlowMascot({required this.showCaption});

  final bool showCaption;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 186),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 170,
                  maxHeight: 156,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RenderingPolicyScope.of(context).simplerEffects
                        ? null
                        : RadialGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary
                                  .withValues(alpha: .065),
                              Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0),
                            ],
                          ),
                  ),
                  child: Image.asset(
                    'assets/branding/grand_maestar.png',
                    key: const ValueKey('flow-mascot'),
                    width: 170,
                    height: 170,
                    fit: BoxFit.contain,
                    cacheWidth: (170 * MediaQuery.devicePixelRatioOf(context))
                        .ceil(),
                  ),
                ),
              ),
            ),
          ),
          if (showCaption) ...[
            const SizedBox(height: 4),
            Text(
              'A passing thought counts, too.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
}
