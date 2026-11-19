import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status and navigation bar icons that read over a backdrop of
/// [background] brightness: dark icons on light pages, light on dark.
///
/// The status bar stays transparent so the page shows through it. The
/// navigation bar's own color is left to the platform.
SystemUiOverlayStyle systemOverlayFor(Brightness background) {
  final icons = background == Brightness.light
      ? Brightness.dark
      : Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    // iOS names the brightness of the backdrop, not of the icons.
    statusBarBrightness: background,
    systemNavigationBarIconBrightness: icons,
  );
}

/// [systemOverlayFor] the brightness of [background].
SystemUiOverlayStyle systemOverlayOn(Color background) =>
    systemOverlayFor(ThemeData.estimateBrightnessForColor(background));

/// The app's own status bar style beneath every route.
///
/// Android keeps whatever style was last applied until a page declares
/// another. Pages without an [AppBar] declare none, so leaving a tinted
/// note (or any page with its own style) would keep that page's icons.
/// This region sits under the navigator: any [AppBar] or
/// [AnnotatedRegion] on a page still wins, and pages without one fall back
/// to the current theme.
class SystemOverlayFallback extends StatelessWidget {
  const SystemOverlayFallback({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          theme.appBarTheme.systemOverlayStyle ??
          systemOverlayFor(theme.brightness),
      child: child,
    );
  }
}
