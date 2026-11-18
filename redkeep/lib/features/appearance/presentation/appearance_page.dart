import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/appearance_controller.dart';
import '../application/appearance_typography.dart';
import '../domain/appearance_preferences.dart';
import 'appearance_controls.dart';
import 'appearance_sky.dart';
import 'font_picker.dart';

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  /// Short screens need their height for controls, so the scene is lower.
  static const _roomySceneMinHeight = 640.0;

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appearanceControllerProvider);
    final controller = ref.read(appearanceControllerProvider.notifier);
    final sceneHeight =
        MediaQuery.sizeOf(context).height >= _roomySceneMinHeight
        ? 256.0
        : 176.0;
    final content = SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MoreSurface.contentWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.loadError) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Saved appearance could not be loaded. Your settings have not been replaced.',
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: controller.retryLoading,
                      child: const Text('Retry loading'),
                    ),
                  ),
                ] else if (!state.loaded) ...[
                  const SizedBox(height: 16),
                  const Text('Loading saved appearance…'),
                ],
                if (state.saving || state.saveFailed) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.saveFailed
                          ? 'Your change could not be saved. Previous settings are still in use. Try the control again.'
                          : 'Saving appearance…',
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                _ThemeSection(state: state),
                const SizedBox(height: 40),
                _AccentSection(state: state),
                const SizedBox(height: 40),
                _TypographySection(state: state),
                const SizedBox(height: 40),
                _MotionSection(state: state),
              ],
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          _SkyAppBar(
            scroll: _scroll,
            theme: state.preferences.theme,
            accent: state.preferences.accent,
            sceneHeight: sceneHeight,
          ),
          SliverToBoxAdapter(child: content),
        ],
      ),
    );
  }
}

/// Open, the sky runs behind the status bar and title. Scrolling collapses it
/// into a solid bar in the page's own surface color.
class _SkyAppBar extends StatelessWidget {
  const _SkyAppBar({
    required this.scroll,
    required this.theme,
    required this.accent,
    required this.sceneHeight,
  });

  final ScrollController scroll;
  final AppTheme theme;
  final AppAccent accent;
  final double sceneHeight;

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final target = skyPhaseFor(theme);
    final topInset = MediaQuery.paddingOf(context).top;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: target, end: target),
      duration: policy.animate
          ? const Duration(milliseconds: 900)
          : Duration.zero,
      curve: Curves.easeInOutCubic,
      builder: (context, phase, _) => ListenableBuilder(
        listenable: scroll,
        builder: (context, _) {
          final offset = scroll.hasClients ? scroll.offset : 0.0;
          final collapse = (offset / (sceneHeight - kToolbarHeight)).clamp(
            0.0,
            1.0,
          );
          // The bar turns solid over the last part of the collapse.
          final solid = ((collapse - .6) / .35).clamp(0.0, 1.0);
          final foreground = Color.lerp(
            SkyColors.foreground(phase),
            colors.onSurface,
            solid,
          )!;
          final darkIcons = solid > .5
              ? colors.brightness == Brightness.light
              : phase < .3;
          return SliverAppBar(
            pinned: true,
            expandedHeight: sceneHeight,
            centerTitle: false,
            leadingWidth: 68,
            leading: const Padding(
              padding: EdgeInsetsDirectional.only(start: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: GlassBackButton(),
              ),
            ),
            backgroundColor: colors.surface,
            foregroundColor: foreground,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: darkIcons
                  ? Brightness.dark
                  : Brightness.light,
              statusBarBrightness: darkIcons
                  ? Brightness.light
                  : Brightness.dark,
            ),
            title: Text(
              'Appearance',
              style: TextStyle(
                color: foreground,
                fontSize: 20,
                height: 1.2,
                letterSpacing: -.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            flexibleSpace: AppearanceSky(
              phase: phase,
              accent: accent,
              height: sceneHeight + topInset,
              collapse: collapse,
              solid: solid,
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: TextStyle(
        color: MorePalette.of(context).ink,
        fontSize: 20,
        height: 1.2,
        letterSpacing: -.6,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection({required this.state});
  final AppearanceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appearanceControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Theme'),
        const SizedBox(height: 14),
        GlassSegments<AppTheme>(
          values: const [AppTheme.system, AppTheme.light, AppTheme.dark],
          selected: state.preferences.theme,
          labelOf: (theme) => switch (theme) {
            AppTheme.system => 'Device',
            AppTheme.light => 'Light',
            AppTheme.dark => 'Dark',
          },
          iconOf: (theme) => switch (theme) {
            AppTheme.system => Icons.brightness_auto_rounded,
            AppTheme.light => Icons.wb_sunny_rounded,
            AppTheme.dark => Icons.dark_mode_rounded,
          },
          semanticLabelOf: (theme) =>
              theme == AppTheme.system ? 'Use device theme' : null,
          onSelected: state.canEdit ? controller.setTheme : null,
        ),
      ],
    );
  }
}

class _AccentSection extends ConsumerWidget {
  const _AccentSection({required this.state});
  final AppearanceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appearanceControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Accent color'),
        const SizedBox(height: 14),
        AccentTray(
          selected: state.preferences.accent,
          onSelected: state.canEdit ? controller.setAccent : null,
        ),
      ],
    );
  }
}

/// A block of cards rather than rows: the journal font sets the whole app, so
/// it leads, and the two diary fonts sit beside each other as the pair they are.
class _TypographySection extends StatelessWidget {
  const _TypographySection({required this.state});
  final AppearanceState state;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Typography'),
        const SizedBox(height: 14),
        _FontCard(role: FontRole.journal, state: state),
        const SizedBox(height: _gap),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 300 || scaler.scale(14) > 18;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FontCard(role: FontRole.diaryTitle, state: state),
                  const SizedBox(height: _gap),
                  _FontCard(role: FontRole.diaryBody, state: state),
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _FontCard(
                      role: FontRole.diaryTitle,
                      state: state,
                      fillHeight: true,
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: _FontCard(
                      role: FontRole.diaryBody,
                      state: state,
                      fillHeight: true,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FontCard extends ConsumerWidget {
  const _FontCard({
    required this.role,
    required this.state,
    this.fillHeight = false,
  });

  final FontRole role;
  final AppearanceState state;

  /// Set when a row gives this card its height, to pin its name to the bottom.
  final bool fillHeight;

  static const _radius = 26.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final text = Theme.of(context).textTheme;
    final diary = DiaryTypography.of(context);
    final fontState = ref.watch(appearanceFontProvider(role));
    final featured = role == FontRole.journal;
    final (label, family, sample, font) = switch (role) {
      FontRole.journal => (
        'Journal font',
        state.preferences.fontFamily,
        'Every keep begins with one stone.',
        text.titleLarge ?? const TextStyle(),
      ),
      FontRole.diaryTitle => (
        'Diary title font',
        state.preferences.diaryTitleFontFamily,
        'Tuesday, after the rain',
        diary.title,
      ),
      FontRole.diaryBody => (
        'Diary body font',
        state.preferences.diaryBodyFontFamily,
        'I took the long way home and let the quiet do its work.',
        diary.body,
      ),
    };

    // The journal font sits on a slab of accent glass; the diary pair on
    // cushions washed with it.
    final cushion = CushionColors.of(
      context,
      tint: palette.accent,
      strength: featured ? 1 : 0,
    );
    final onAccent = cushion.onPaper;
    final ink = featured ? onAccent : palette.ink;
    final soft = featured ? onAccent.withValues(alpha: .8) : palette.muted;
    final highlight = featured ? onAccent : palette.accent;

    // Large text keeps what the card is for and drops the decoration.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final decorated = scale <= 1.3;
    final showSample = scale <= 2;

    final labelText = Text(
      label,
      style: TextStyle(color: soft, fontSize: 12, height: 1.4),
    );
    final arrow = SizedBox.square(
      dimension: 32,
      child: CustomPaint(
        painter: _GlassDotPainter(
          colors: cushion,
          tint: featured ? onAccent : palette.accent,
        ),
        child: Icon(Icons.arrow_outward_rounded, size: 15, color: highlight),
      ),
    );
    final sampleText = !showSample
        ? null
        : ExcludeSemantics(
            child: Text(
              sample,
              maxLines: featured ? 2 : 5,
              overflow: TextOverflow.ellipsis,
              style: font.copyWith(
                color: ink,
                fontSize: switch (role) {
                  FontRole.journal => 15,
                  FontRole.diaryTitle => 25,
                  FontRole.diaryBody => 14,
                },
                height: role == FontRole.diaryTitle ? 1.15 : 1.45,
                fontWeight: role == FontRole.journal ? FontWeight.w400 : null,
              ),
            ),
          );

    final body = featured
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: labelText),
                  const SizedBox(width: 8),
                  arrow,
                ],
              ),
              SizedBox(height: decorated ? 22 : 10),
              Text(
                family,
                style: font.copyWith(
                  color: ink,
                  fontSize: 30,
                  height: 1.15,
                  letterSpacing: -.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (sampleText != null) ...[
                const SizedBox(height: 6),
                Padding(
                  // Keeps the sentence clear of the large glyph.
                  padding: EdgeInsets.only(right: decorated ? 104 : 0),
                  child: sampleText,
                ),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelText,
              if (decorated) ...[
                const SizedBox(height: 6),
                ExcludeSemantics(
                  child: Text(
                    'Aa',
                    style: font.copyWith(
                      color: palette.accent,
                      fontSize: 46,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
              if (sampleText != null) ...[
                const SizedBox(height: 8),
                sampleText,
              ],
              const SizedBox(height: 14),
              if (fillHeight) const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      family,
                      style: TextStyle(
                        color: highlight,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  arrow,
                ],
              ),
            ],
          );

    final tappable = Semantics(
      button: true,
      enabled: state.canEdit,
      child: InkWell(
        onTap: state.canEdit
            ? () => showFontPicker(
                context,
                title: label,
                role: role,
                selectedFont: family,
                onSelected: (font) => ref
                    .read(appearanceControllerProvider.notifier)
                    .setFontFamily(font, role),
              )
            : null,
        child: Padding(padding: const EdgeInsets.all(18), child: body),
      ),
    );

    return Springy(
      enabled: state.canEdit,
      depth: .03,
      child: CustomPaint(
        painter: CushionPainter(
          colors: cushion,
          radius: _radius,
          stitched: !featured,
          glow: featured ? null : Alignment.topLeft,
        ),
        child: Material(
          type: MaterialType.transparency,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: Stack(
            children: [
              if (featured && decorated)
                Positioned(
                  right: -4,
                  bottom: -26,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Text(
                        'Aa',
                        style: font.copyWith(
                          color: onAccent.withValues(alpha: .16),
                          fontSize: 96,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (fillHeight) Expanded(child: tappable) else tappable,
                  if (fontState.hasError)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(foregroundColor: highlight),
                        onPressed: () =>
                            ref.invalidate(appearanceFontProvider(role)),
                        child: const Text('Font unavailable. Retry loading'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small bead of glass behind an icon.
class _GlassDotPainter extends CustomPainter {
  const _GlassDotPainter({required this.colors, required this.tint});

  final CushionColors colors;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) => paintGlass(
    canvas,
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide / 2),
    ),
    colors: colors,
    tint: tint,
    fill: .22,
    lift: .6,
  );

  @override
  bool shouldRepaint(_GlassDotPainter old) =>
      colors != old.colors || tint != old.tint;
}

class _MotionSection extends ConsumerWidget {
  const _MotionSection({required this.state});
  final AppearanceState state;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appearanceControllerProvider.notifier);
    final policy = RenderingPolicyScope.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final motion = CushionToggle(
      title: 'Reduce motion',
      icon: Icons.slow_motion_video_rounded,
      switchKey: const ValueKey('appearance-reduce-motion'),
      value: state.preferences.reduceMotion,
      onChanged: state.canEdit ? controller.setReduceMotion : null,
    );
    final effects = CushionToggle(
      title: 'Simpler effects',
      icon: Icons.auto_awesome_rounded,
      switchKey: const ValueKey('appearance-simpler-effects'),
      value: state.preferences.simplerEffects,
      onChanged: state.canEdit ? controller.setSimplerEffects : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Motion and effects'),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth < 300 || scaler.scale(14) > 18
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    motion,
                    const SizedBox(height: _gap),
                    effects,
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: motion),
                      const SizedBox(width: _gap),
                      Expanded(child: effects),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 14),
        _StatusLine(
          policy.osReducedMotion
              ? 'Motion is reduced by your device.'
              : policy.reducedMotion
              ? 'Motion is reduced by your preference.'
              : 'Standard motion is available.',
          active: !policy.reducedMotion,
        ),
        const SizedBox(height: 4),
        _StatusLine(
          policy.simplerEffects
              ? 'Simplified effects are active.'
              : 'Full effects are active.',
          active: !policy.simplerEffects,
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.message, {required this.active});
  final String message;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final color = active ? palette.accent : palette.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: 8),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: palette.muted, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }
}
