import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/appearance_controller.dart';
import '../application/appearance_typography.dart';
import '../domain/appearance_preferences.dart';
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
    final palette = MorePalette.of(context);
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
                Text(
                  'Make this space yours. Changes save automatically.',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
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
    final palette = MorePalette.of(context);
    final selected = state.preferences.theme;
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;
    final options = [
      for (final theme in const [
        AppTheme.system,
        AppTheme.light,
        AppTheme.dark,
      ])
        _ThemeOption(
          theme: theme,
          selected: selected == theme,
          onTap: state.canEdit ? () => controller.setTheme(theme) : null,
        ),
    ];
    final deviceMode = Theme.of(context).brightness == Brightness.dark
        ? 'dark'
        : 'light';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Theme'),
        const SizedBox(height: 14),
        if (stacked)
          for (final (index, option) in options.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            option,
          ]
        else
          Row(
            children: [
              for (final (index, option) in options.indexed) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: option),
              ],
            ],
          ),
        const SizedBox(height: 10),
        Text(switch (selected) {
          AppTheme.system => 'Follows your device, $deviceMode right now.',
          AppTheme.light => 'Bright and clear, all day.',
          AppTheme.dark => 'Low light for late nights.',
        }, style: TextStyle(color: palette.muted, fontSize: 13, height: 1.5)),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final AppTheme theme;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final policy = RenderingPolicyScope.of(context);
    const shape = StadiumBorder();
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: onTap != null,
      label: theme == AppTheme.system ? 'Use device theme' : null,
      excludeSemantics: theme == AppTheme.system,
      child: AnimatedContainer(
        duration: policy.duration,
        decoration: ShapeDecoration(
          color: selected
              ? palette.accent.withValues(alpha: .12)
              : Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? palette.accent : palette.rule,
              width: selected ? 1.6 : 1,
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Center(
                  child: Text(
                    switch (theme) {
                      AppTheme.system => 'Device',
                      AppTheme.light => 'Light',
                      AppTheme.dark => 'Dark',
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? palette.accent : palette.ink,
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentSection extends ConsumerWidget {
  const _AccentSection({required this.state});
  final AppearanceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appearanceControllerProvider.notifier);
    final palette = MorePalette.of(context);
    final policy = RenderingPolicyScope.of(context);
    final selected = state.preferences.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Accent color'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Every banner stays in view: the rack folds rather than scrolls.
            final label = MediaQuery.textScalerOf(context).scale(12) * 5.6;
            final columns = [AppAccent.values.length, 3].firstWhere(
              (c) => constraints.maxWidth / c >= label,
              orElse: () => 2,
            );
            final cell = constraints.maxWidth / columns;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var start = 0;
                  start < AppAccent.values.length;
                  start += columns
                )
                  Padding(
                    padding: EdgeInsets.only(top: start == 0 ? 0 : 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final accent
                            in AppAccent.values.skip(start).take(columns))
                          SizedBox(
                            width: cell,
                            child: _AccentBanner(
                              accent: accent,
                              selected: selected == accent,
                              width: (cell * .5).clamp(34.0, 56.0),
                              onTap: state.canEdit
                                  ? () => controller.setAccent(accent)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: policy.duration,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          child: Text(
            selected.description,
            key: ValueKey(selected),
            style: TextStyle(color: palette.muted, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// Banners hang from one rail; the chosen one is let down further.
class _AccentBanner extends StatelessWidget {
  const _AccentBanner({
    required this.accent,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final policy = RenderingPolicyScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? accent.darkPrimary : accent.seed;
    final mark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1B1B2B);
    return Semantics(
      button: true,
      selected: selected,
      label: '${accent.label}: ${accent.description}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Container(height: 2, color: palette.rule),
            AnimatedContainer(
              duration: policy.animate
                  ? const Duration(milliseconds: 280)
                  : Duration.zero,
              curve: Curves.easeOutBack,
              width: width,
              height: selected ? 92 : 62,
              child: CustomPaint(
                painter: _BannerPainter(
                  color: color,
                  shaded: !policy.simplerEffects,
                ),
                child: selected
                    ? Align(
                        alignment: const Alignment(0, -.45),
                        child: Icon(Icons.check_rounded, color: mark, size: 20),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                accent.label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: selected ? palette.accent : palette.muted,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _BannerPainter extends CustomPainter {
  const _BannerPainter({required this.color, required this.shaded});

  final Color color;
  final bool shaded;

  @override
  void paint(Canvas canvas, Size size) {
    final notch = size.height - 12;
    final path = Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, notch)
      ..lineTo(0, size.height)
      ..close();
    if (shaded) canvas.drawShadow(path, Colors.black, 2.5, false);
    canvas.drawPath(path, Paint()..color = color);
    if (!shaded) return;
    // Soft folds, so the cloth reads as hanging rather than as a flat chip.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: .14),
            Colors.white.withValues(alpha: .10),
            Colors.black.withValues(alpha: .04),
            Colors.white.withValues(alpha: .06),
            Colors.black.withValues(alpha: .16),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_BannerPainter oldDelegate) =>
      color != oldDelegate.color || shaded != oldDelegate.shaded;
}

/// A block of cards rather than rows: the journal font sets the whole app, so
/// it leads, and the two diary fonts sit beside each other as the pair they are.
class _TypographySection extends StatelessWidget {
  const _TypographySection({required this.state});
  final AppearanceState state;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Typography'),
        const SizedBox(height: 6),
        Text(
          'One font for the app, and a pair of its own for your diary.',
          style: TextStyle(color: palette.muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
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

    final background = featured
        ? palette.accent
        : Color.lerp(palette.ground, palette.accent, dark ? .13 : .08)!;
    final onAccent =
        ThemeData.estimateBrightnessForColor(palette.accent) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1B1B2B);
    final ink = featured ? onAccent : palette.ink;
    final soft = featured ? onAccent.withValues(alpha: .82) : palette.muted;
    final highlight = featured ? onAccent : palette.accent;

    // Large text keeps what the card is for and drops the decoration.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final decorated = scale <= 1.3;
    final showSample = scale <= 2;

    final labelText = Text(
      label,
      style: TextStyle(color: soft, fontSize: 12, height: 1.4),
    );
    final arrow = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlight.withValues(alpha: featured ? .18 : .14),
      ),
      child: Icon(Icons.arrow_outward_rounded, size: 15, color: highlight),
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
        child: Padding(padding: const EdgeInsets.all(16), child: body),
      ),
    );

    return Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    );
  }
}

class _MotionSection extends ConsumerWidget {
  const _MotionSection({required this.state});
  final AppearanceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appearanceControllerProvider.notifier);
    final policy = RenderingPolicyScope.of(context);
    final palette = MorePalette.of(context);
    final titleStyle = TextStyle(
      color: palette.ink,
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w500,
    );
    final detailStyle = TextStyle(
      color: palette.muted,
      fontSize: 13,
      height: 1.45,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Motion and effects'),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Reduce motion', style: titleStyle),
          subtitle: Text(
            'Use immediate transitions. Device motion reduction always applies.',
            style: detailStyle,
          ),
          value: state.preferences.reduceMotion,
          onChanged: state.canEdit ? controller.setReduceMotion : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Simpler effects', style: titleStyle),
          subtitle: Text(
            'Use flat colors without shadows or textures. Reduced motion also enables this.',
            style: detailStyle,
          ),
          value: state.preferences.simplerEffects,
          onChanged: state.canEdit ? controller.setSimplerEffects : null,
        ),
        const SizedBox(height: 12),
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
