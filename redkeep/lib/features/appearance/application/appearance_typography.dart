import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts_lite.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/redkeep_theme.dart';
import '../data/font_download_client.dart';
import '../data/font_preview_loader.dart';
import 'appearance_controller.dart';

enum FontRole { journal, diaryTitle, diaryBody }

class ResolvedFont {
  const ResolvedFont({this.textTheme, this.style});
  final TextTheme? textTheme;
  final TextStyle? style;
}

typedef AppearanceFontLoader = Future<ResolvedFont> Function(
  String family,
  FontRole role,
);
const fontLoadTimeout = Duration(seconds: 10);
final _loaded = <(String, FontRole), ResolvedFont>{};
final _loading = <(String, FontRole), Future<ResolvedFont>>{};

Future<ResolvedFont> _load(String family, FontRole role) async {
  final key = (family, role);
  if (_loaded[key] case final cached?) return cached;
  if (_loading[key] case final pending?) return pending;
  GoogleFontsLite.config.httpClient ??= FontDownloadClient(
    timeout: fontLoadTimeout,
  );
  final future = () async {
    TextStyle? font(TextStyle? base) =>
        base == null ? null : GoogleFontsLite.getFont(family, textStyle: base);
    final base = RedkeepTheme.light.textTheme;
    final result = role == FontRole.journal
        ? ResolvedFont(
            textTheme: TextTheme(
              displayLarge: font(base.displayLarge),
              displayMedium: font(base.displayMedium),
              displaySmall: font(base.displaySmall),
              headlineLarge: font(base.headlineLarge),
              headlineMedium: font(base.headlineMedium),
              headlineSmall: font(base.headlineSmall),
              titleLarge: font(base.titleLarge),
              titleMedium: font(base.titleMedium),
              titleSmall: font(base.titleSmall),
              bodyLarge: font(base.bodyLarge),
              bodyMedium: font(base.bodyMedium),
              bodySmall: font(base.bodySmall),
              labelLarge: font(base.labelLarge),
              labelMedium: font(base.labelMedium),
              labelSmall: font(base.labelSmall),
            ),
          )
        : ResolvedFont(
            style: font(
              role == FontRole.diaryTitle
                  ? const DiaryTypography().title
                  : const DiaryTypography().body,
            ),
          );
    await GoogleFontsLite.pendingFonts().timeout(fontLoadTimeout);
    _loaded[key] = result;
    return result;
  }();
  _loading[key] = future;
  try {
    return await future;
  } finally {
    _loading.remove(key);
  }
}

final appearanceFontLoaderProvider = Provider<AppearanceFontLoader>(
  (ref) => _load,
);
final fontPreviewLoaderProvider = Provider<FontPreviewLoader>((ref) {
  final loader = FontPreviewLoader();
  ref.onDispose(loader.dispose);
  return loader;
});
final appearanceFontProvider = FutureProvider.family<ResolvedFont, FontRole>((
  ref,
  role,
) {
  final family = ref.watch(
    appearanceControllerProvider.select(
      (state) => switch (role) {
        FontRole.journal => state.preferences.fontFamily,
        FontRole.diaryTitle => state.preferences.diaryTitleFontFamily,
        FontRole.diaryBody => state.preferences.diaryBodyFontFamily,
      },
    ),
  );
  return ref
      .watch(appearanceFontLoaderProvider)(family, role)
      .timeout(fontLoadTimeout);
}, retry: (_, _) => null);
