import '../features/sync/presentation/sync_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/presentation/redkeep_theme.dart';
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
    return MaterialApp.router(
      title: 'Redkeep',
      debugShowCheckedModeBanner: false,
      routeInformationProvider: ref.watch(navigationRouteInformationProvider),
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      backButtonDispatcher: router.backButtonDispatcher,
      theme: RedkeepTheme.light,
      darkTheme: RedkeepTheme.dark,
      themeMode: switch (appearance.preferences.theme) {
        AppTheme.system => ThemeMode.system,
        AppTheme.light => ThemeMode.light,
        AppTheme.dark => ThemeMode.dark,
      },
      themeAnimationDuration: Duration.zero,
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
