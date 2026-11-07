import '../features/sync/presentation/sync_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/presentation/redkeep_theme.dart';
import '../core/presentation/diary_typography.dart';
import '../features/appearance/application/appearance_typography.dart';
import '../core/presentation/rendering_policy.dart';
import '../features/appearance/application/appearance_controller.dart';
import '../features/appearance/domain/appearance_preferences.dart';
import 'app_router.dart';

class RedkeepApp extends ConsumerWidget {
  const RedkeepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceControllerProvider);
    final router = ref.watch(appRouterProvider);
    final journal = ref.watch(appearanceFontProvider(FontRole.journal)).value;
    final diaryTitle = ref
        .watch(appearanceFontProvider(FontRole.diaryTitle))
        .value;
    final diaryBody = ref
        .watch(appearanceFontProvider(FontRole.diaryBody))
        .value;
    ThemeData theme(Brightness brightness) => RedkeepTheme.forAppearance(
      brightness,
      appearance.preferences.accent,
      fonts: journal?.textTheme,
      diary: DiaryTypography(
        title: diaryTitle?.style ?? const DiaryTypography().title,
        body: diaryBody?.style ?? const DiaryTypography().body,
      ),
    );
    return MaterialApp.router(
      title: 'Redkeep',
      debugShowCheckedModeBanner: false,
      routeInformationProvider: ref.watch(navigationRouteInformationProvider),
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      backButtonDispatcher: router.backButtonDispatcher,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: switch (appearance.preferences.theme) {
        AppTheme.system => ThemeMode.system,
        AppTheme.light => ThemeMode.light,
        AppTheme.dark => ThemeMode.dark,
      },
      themeAnimationDuration: Duration.zero,
      // The note editor's built-in strings (link and selection menus).
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        FlutterQuillLocalizations.delegate,
      ],
      builder: (context, child) => RenderingPolicyHost(
        // Remain static until the stored policy is known.
        preferences: appearance.loaded
            ? appearance.preferences
            : const AppearancePreferences(reduceMotion: true),
        child: SyncHost(child: child!),
      ),
    );
  }
}
