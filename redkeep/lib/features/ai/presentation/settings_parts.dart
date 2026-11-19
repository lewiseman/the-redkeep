import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/pen_squiggle.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../onboarding/presentation/onboarding_terms.dart';
import '../../sync/presentation/sync_material.dart';

/// The reader's own diary title face, for headings and asides.
TextStyle settingsHand(
  BuildContext context, {
  double size = 28,
  Color? color,
}) => DiaryTypography.of(context).title.copyWith(
  fontSize: size,
  height: 1.1,
  color: color ?? MorePalette.of(context).ink,
);

/// A stretch of Settings, named in handwriting, with a quiet aside.
class SettingsHeading extends StatelessWidget {
  const SettingsHeading(this.text, {super.key, this.note});

  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final note = this.note;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 34, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(text, style: settingsHand(context, size: 30)),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: TextStyle(color: palette.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// A stitched cushion holding one part of Settings.
class SettingsCushion extends StatelessWidget {
  const SettingsCushion({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 16, 16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: CushionPainter(colors: CushionColors.of(context), radius: 26),
    child: Padding(padding: padding, child: child),
  );
}

/// A pill of liquid glass: filled for the thing to do, clear otherwise.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.busy = false,
    this.tint,
    this.compact = false,
    this.wide = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled, busy, compact;

  /// Spans the width it is given, for the one thing a sheet is for.
  final bool wide;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final tint = this.tint ?? cushion.tint;
    final enabled = onPressed != null && !busy;
    final fill = filled ? (enabled ? .92 : .45) : .1;
    final body = Color.lerp(cushion.paper, tint, fill)!;
    final ink = filled
        ? (ThemeData.estimateBrightnessForColor(body) == Brightness.dark
              ? Colors.white
              : cushion.ink)
        : Color.lerp(tint, cushion.ink, cushion.dark ? 0 : .35)!;
    final height = compact ? 40.0 : 52.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onPressed!();
              }
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 48 : 52),
          child: Center(
            heightFactor: 1,
            widthFactor: wide ? null : 1,
            child: Springy(
              enabled: enabled,
              depth: .08,
              child: CustomPaint(
                painter: _PillPainter(cushion, tint, fill),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: height),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 22,
                    ),
                    child: Row(
                      mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (busy)
                          SizedBox.square(
                            dimension: 16,
                            child: RenderingPolicyScope.of(context).animate
                                ? CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ink,
                                  )
                                : Icon(Icons.more_horiz, size: 16, color: ink),
                          )
                        else if (icon != null)
                          Icon(icon, size: compact ? 18 : 20, color: ink),
                        if (busy || icon != null) const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontSize: compact ? 14 : 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

class _PillPainter extends CustomPainter {
  const _PillPainter(this.colors, this.tint, this.fill);
  final CushionColors colors;
  final Color tint;
  final double fill;

  @override
  void paint(Canvas canvas, Size size) => paintGlass(
    canvas,
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    ),
    colors: colors,
    tint: tint,
    fill: fill,
    lift: .8,
  );

  @override
  bool shouldRepaint(_PillPainter old) =>
      old.colors != colors || old.tint != tint || old.fill != fill;
}

/// A field written on a line, as on paper: a small label above, and an
/// inked rule beneath that darkens to the accent while it has the cursor.
class InkedField extends StatefulWidget {
  const InkedField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofocus = false,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.monospace = false,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure, autofocus, monospace;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final ValueChanged<String>? onChanged, onSubmitted;
  final Key? fieldKey;

  @override
  State<InkedField> createState() => _InkedFieldState();
}

class _InkedFieldState extends State<InkedField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final duration = RenderingPolicyScope.of(context).duration;
    final focused = _focus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            color: focused ? palette.accent : palette.muted,
            fontSize: 10.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: widget.fieldKey,
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                obscureText: widget.obscure,
                autocorrect: false,
                enableSuggestions: !widget.obscure,
                keyboardType: widget.keyboardType,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                cursorColor: palette.accent,
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 17,
                  letterSpacing: widget.monospace ? .6 : 0,
                  fontFeatures: widget.monospace
                      ? const [FontFeature.tabularFigures()]
                      : null,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    color: palette.muted.withValues(alpha: .7),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            ?widget.trailing,
          ],
        ),
        AnimatedContainer(
          duration: duration,
          height: focused ? 2 : 1.2,
          decoration: BoxDecoration(
            color: focused ? palette.accent : palette.rule,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

/// Opens [child] on a sheet of the page's paper, lifted clear of the
/// keyboard, with a stitched handle.
Future<T?> showPaperSheet<T>(BuildContext context, WidgetBuilder builder) {
  FocusManager.instance.primaryFocus?.unfocus();
  final palette = MorePalette.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: palette.paper,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    constraints: BoxConstraints(
      maxWidth: 620,
      maxHeight: MediaQuery.sizeOf(context).height * .9,
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StitchedHandle(),
          Flexible(child: builder(context)),
        ],
      ),
    ),
  );
}

class _StitchedHandle extends StatelessWidget {
  const _StitchedHandle();

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: CustomPaint(
            size: const Size(56, 6),
            painter: _HandlePainter(cushion),
          ),
        ),
      ),
    );
  }
}

class _HandlePainter extends CustomPainter {
  const _HandlePainter(this.colors);
  final CushionColors colors;

  @override
  void paint(Canvas canvas, Size size) => paintDimple(
    canvas,
    RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3)),
    colors,
  );

  @override
  bool shouldRepaint(_HandlePainter old) => old.colors != colors;
}

/// One line of a cushion that opens something: an icon, words, and a mark
/// saying where it goes.
class SettingsLink extends StatelessWidget {
  const SettingsLink({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.detail,
    this.outward = true,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback onTap;

  /// Leaves the app, for the browser.
  final bool outward;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final detail = this.detail;
    return Semantics(
      button: true,
      label: [title, ?detail, if (outward) 'opens in your browser'].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Springy(
          depth: .03,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Icon(icon, size: 22, color: palette.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  outward
                      ? Icons.north_east_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A hairline between lines of a cushion, inset like a stitch.
class SettingsRule extends StatelessWidget {
  const SettingsRule({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 36),
    child: Divider(height: 1, color: MorePalette.of(context).rule),
  );
}

const _legal = (
  terms: 'https://redkeep.lewiseman.com/terms.html',
  privacy: 'https://redkeep.lewiseman.com/privacy.html',
);

/// The terms and the privacy promise, opened in the browser.
class SmallPrint extends ConsumerWidget {
  const SmallPrint({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    try {
      if (await ref.read(onboardingLegalLinkLauncherProvider)(Uri.parse(url))) {
        return;
      }
    } catch (_) {
      /* Platform errors never become user-facing details. */
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this page. Try again.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsCushion(
    padding: const EdgeInsets.fromLTRB(18, 4, 16, 4),
    child: Column(
      children: [
        SettingsLink(
          icon: Icons.history_edu_outlined,
          title: 'Terms of service',
          onTap: () => unawaited(_open(context, ref, _legal.terms)),
        ),
        const SettingsRule(),
        SettingsLink(
          icon: Icons.lock_outline_rounded,
          title: 'Privacy',
          detail: 'What stays on this phone',
          onTap: () => unawaited(_open(context, ref, _legal.privacy)),
        ),
      ],
    ),
  );
}

/// The maker's mark at the very end of Settings.
class BuiltBy extends StatelessWidget {
  const BuiltBy({super.key, this.version = _version});

  /// The release, from the build. Empty in tests and unversioned builds.
  final String version;

  static const _version = String.fromEnvironment('FLUTTER_BUILD_NAME');

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 48, 0, 8),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Text(
              '✒︎',
              style: TextStyle(color: palette.muted, fontSize: 18),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Built by Lewis',
            textAlign: TextAlign.center,
            style: settingsHand(context, size: 26),
          ),
          ExcludeSemantics(
            child: CustomPaint(
              size: const Size(96, 12),
              painter: PenSquiggle(palette.accent, 1),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            version.isEmpty ? 'Redkeep' : 'Redkeep $version',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }
}
